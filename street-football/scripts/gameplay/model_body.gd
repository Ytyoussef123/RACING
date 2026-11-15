class_name ModelBody
extends RefCounted
## A skinned 3D body (a Mixamo skeleton) worn instead of the coded one (look only, trial).
## The model follows the same RigPose as the coded body (running, touches, tackles: each joint
## angle turns the matching bone from its T-pose), and a kick or a pass plays the recorded
## animation on the whole skeleton, from the contact on, blended in and out.
## Files and numbers: data/config/body.json (model_*), data/config/animation.json (model_clip_*).

var _model: Node3D
var _skeleton: Skeleton3D
var _bones: Dictionary = {}
var _clips: Dictionary = {}
var _order: Array[int] = []
var _unit: float = 1.0
var _meshes: Array[MeshInstance3D] = []


## Loads the model under `parent`, sized to `height` meters. False when it cannot be used.
func build(parent: Node3D, height: float) -> bool:
	var scene: PackedScene = _load_scene(str(_cfg("model_scene", "")))
	if scene == null:
		return false
	_model = scene.instantiate()
	parent.add_child(_model)
	_skeleton = _find(_model, "Skeleton3D") as Skeleton3D
	if _skeleton == null:
		_model.queue_free()
		return false
	for i in range(_skeleton.get_bone_count()):
		_bones[_short(_skeleton.get_bone_name(i))] = i
		_order.append(i)
	for key in ["Hips", "Spine", "Neck", "LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg",
			"LeftArm", "LeftForeArm", "RightArm", "RightForeArm"]:
		if not _bones.has(key):
			_model.queue_free()
			return false
	var top := float(_skeleton.get_bone_global_rest(_bones.get("HeadTop_End", _bones["Neck"])).origin.y)
	var low := float(_skeleton.get_bone_global_rest(_bones.get("LeftToeBase", _bones["LeftLeg"])).origin.y)
	var skeleton_scale := absf((_model.global_transform.affine_inverse() * _skeleton.global_transform).basis.get_scale().y)
	var tall := maxf(0.01, (top - low) * skeleton_scale)
	var factor := height / tall
	_model.scale = Vector3.ONE * factor
	_model.position = Vector3(0.0, -low * skeleton_scale * factor + float(_cfg("model_foot_height", 0.03)), 0.0)
	_unit = maxf(0.0001, skeleton_scale * factor)
	_collect_meshes(_model)
	var clips: Dictionary = _cfg("model_clips", {})
	for action in clips:
		var anim := _load_animation(str(clips[action]))
		if anim != null:
			_clips[action] = anim
	return true


func set_kit(kit: Color) -> void:
	for mesh in _meshes:
		var material := StandardMaterial3D.new()
		var joints := mesh.name.to_lower().contains("joint")
		material.albedo_color = kit.darkened(float(_cfg("model_joint_darken", 0.5))) if joints else kit
		material.roughness = 0.8
		mesh.material_override = material


## Poses the skeleton: the RigPose first, then the clip of `action` (if any) at `time` seconds.
func apply(p: RigPose, action: String, time: float, duration: float) -> void:
	if _skeleton == null:
		return
	var v := p.v
	var root := Basis.from_euler(Vector3(v[RigPose.ROOT_X], 0.0, v[RigPose.ROOT_Z]))
	var hips := root * Basis.from_euler(Vector3(0.0, v[RigPose.HIPS_Y], v[RigPose.HIPS_Z]))
	var spine := hips * Basis.from_euler(Vector3(v[RigPose.SPINE_X], v[RigPose.SPINE_Y], v[RigPose.SPINE_Z]))
	var driven := {
		_bones["Hips"]: hips, _bones["Spine"]: spine,
		_bones["Neck"]: spine * Basis.from_euler(Vector3(v[RigPose.NECK_X], 0.0, 0.0)),
	}
	for side in [["Left", RigPose.THIGH_L_X, RigPose.THIGH_L_Z, RigPose.KNEE_L, RigPose.ARM_L_X, RigPose.ARM_L_Z, RigPose.ELBOW_L, -1.0],
			["Right", RigPose.THIGH_R_X, RigPose.THIGH_R_Z, RigPose.KNEE_R, RigPose.ARM_R_X, RigPose.ARM_R_Z, RigPose.ELBOW_R, 1.0]]:
		var thigh: Basis = hips * Basis.from_euler(Vector3(v[side[1]], 0.0, v[side[2]]))
		driven[_bones[side[0] + "UpLeg"]] = thigh
		driven[_bones[side[0] + "Leg"]] = thigh * Basis.from_euler(Vector3(v[side[3]], 0.0, 0.0))
		# The model's arms are level in its T-pose: ours hang down at zero.
		var down := Basis.from_euler(Vector3(0.0, 0.0, float(side[7]) * PI * 0.5))
		var arm: Basis = spine * Basis.from_euler(Vector3(v[side[4]], 0.0, v[side[5]]))
		driven[_bones[side[0] + "Arm"]] = arm * down
		driven[_bones[side[0] + "ForeArm"]] = arm * Basis.from_euler(Vector3(v[side[6]], 0.0, 0.0)) * down
	var globals := {}
	for i in _order:
		var parent := _skeleton.get_bone_parent(i)
		var parent_basis: Basis = globals[parent] if parent >= 0 and globals.has(parent) else Basis.IDENTITY
		var rest_local := _skeleton.get_bone_rest(i).basis.orthonormalized()
		var global_basis: Basis
		if driven.has(i):
			global_basis = (driven[i] as Basis) * _skeleton.get_bone_global_rest(i).basis.orthonormalized()
		else:
			global_basis = parent_basis * rest_local
		globals[i] = global_basis
		_skeleton.set_bone_pose_rotation(i, (parent_basis.inverse() * global_basis).get_rotation_quaternion())
	var hips_index: int = _bones["Hips"]
	var hips_rest := _skeleton.get_bone_rest(hips_index).origin
	_skeleton.set_bone_pose_position(hips_index, hips_rest + Vector3(0.0, v[RigPose.ROOT_Y], v[RigPose.ROOT_FWD]) / _unit)
	if _clips.has(action):
		_apply_clip(_clips[action], action, time, duration, hips_index, hips_rest)


func _apply_clip(anim: Animation, action: String, time: float, duration: float, hips_index: int, hips_rest: Vector3) -> void:
	var t := clampf(time / maxf(0.01, duration), 0.0, 1.0)
	var w := RigPose.envelope(t, float(_anim_cfg("clip_blend_in", 0.08)), float(_anim_cfg("clip_blend_out", 0.6)))
	var at := float(_anim_cfg("model_clip_start_" + action, 0.0)) + time
	at = clampf(at, 0.0, anim.length)
	for track in range(anim.get_track_count()):
		var path := anim.track_get_path(track)
		if path.get_subname_count() == 0:
			continue
		var key := _short(str(path.get_subname(0)))
		if not _bones.has(key):
			continue
		var bone: int = _bones[key]
		match anim.track_get_type(track):
			Animation.TYPE_ROTATION_3D:
				var q := anim.rotation_track_interpolate(track, at)
				_skeleton.set_bone_pose_rotation(bone, _skeleton.get_bone_pose_rotation(bone).slerp(q, w))
			Animation.TYPE_POSITION_3D:
				if bone == hips_index:
					# Only the height: the player's place on the court is the game's.
					var y := anim.position_track_interpolate(track, at).y
					var now := _skeleton.get_bone_pose_position(bone)
					_skeleton.set_bone_pose_position(bone, Vector3(hips_rest.x, lerpf(now.y, y, w), now.z))


func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_meshes.append(node)
	for child in node.get_children():
		_collect_meshes(child)


static func _find(node: Node, type: String) -> Node:
	if node.is_class(type):
		return node
	for child in node.get_children():
		var found := _find(child, type)
		if found != null:
			return found
	return null


static func _load_scene(path: String) -> PackedScene:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


## The animation of an imported file with the most tracks (the real take).
static func _load_animation(path: String) -> Animation:
	var scene := _load_scene(path)
	if scene == null:
		return null
	var node := scene.instantiate()
	var player := _find(node, "AnimationPlayer") as AnimationPlayer
	var best: Animation = null
	if player != null:
		for anim_name in player.get_animation_list():
			var anim := player.get_animation(anim_name)
			if anim_name != "RESET" and (best == null or anim.get_track_count() > best.get_track_count()
					or (anim.get_track_count() == best.get_track_count() and str(anim_name).contains("mixamo"))):
				best = anim
	node.free()
	return best


## "mixamorig:LeftArm" or "mixamorig_LeftArm" -> "LeftArm".
static func _short(bone: String) -> String:
	var cut := maxi(bone.rfind(":"), bone.find("_") if bone.begins_with("mixamorig") else -1)
	return bone.substr(cut + 1)


static func _cfg(key: String, fallback: Variant) -> Variant:
	return Config.get_value("body", key, fallback)


static func _anim_cfg(key: String, fallback: Variant) -> Variant:
	return Config.get_value("animation", key, fallback)
