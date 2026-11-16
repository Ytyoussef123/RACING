class_name ModelBody
extends RefCounted
## A skinned 3D body (a Mixamo skeleton) worn instead of the coded one (look only, trial).
## The model follows the same RigPose as the coded body (running, touches, tackles: each joint
## angle turns the matching bone from its T-pose), and a kick or a pass plays the recorded
## animation on the whole skeleton, blended in and out; running plays a recorded jog in a loop.
## Files and numbers: data/config/body.json (model_*), data/config/animation.json (model_clip_*).

var _model: Node3D
var _skeleton: Skeleton3D
var _bones: Dictionary = {}
var _clips: Dictionary = {}
var _order: Array[int] = []
var _unit: float = 1.0
var _meshes: Array[MeshInstance3D] = []
var _setups: Dictionary = {}
var _rest_local: Array[Basis] = []
var _rest_global: Array[Basis] = []
var _opposite: Array[int] = []
var _phase: float = 0.0
var _run: float = 0.0
var _backward: bool = false

static var _animations: Dictionary = {}


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
	for i in _order:
		_rest_local.append(_skeleton.get_bone_rest(i).basis.orthonormalized())
		_rest_global.append(_skeleton.get_bone_global_rest(i).basis.orthonormalized())
		var bone_name := _short(_skeleton.get_bone_name(i))
		var other := bone_name.replace("Left", "Right") if bone_name.contains("Left") else bone_name.replace("Right", "Left")
		_opposite.append(int(_bones.get(other, i)))
	# model_clips: action -> {"file", "start" (s), "rate", "out" (share of the action where it fades)}.
	var clips: Dictionary = _cfg("model_clips", {})
	for action in clips:
		var setup: Dictionary = clips[action]
		var anim := _animation(str(_cfg("model_folder", "")) + str(setup.get("file", "")))
		if anim != null:
			_clips[action] = anim
			_setups[action] = setup
	_phase = fposmod(float(_model.get_instance_id()) * 0.37, 1.0)
	return true


func set_kit(kit: Color) -> void:
	for mesh in _meshes:
		var material := StandardMaterial3D.new()
		var joints := mesh.name.to_lower().contains("joint")
		material.albedo_color = kit.darkened(float(_cfg("model_joint_darken", 0.5))) if joints else kit
		material.roughness = 0.8
		mesh.material_override = material


## Advances the running cycle: `speed` m/s over `delta` seconds, `backward` when back-pedalling.
## `run` (0..1) is how much of the recorded jog replaces the coded pose (0 standing or walking).
func advance(delta: float, speed: float, backward: bool, run: float) -> void:
	_backward = backward
	_run = run
	var natural := float(_cfg("model_jog_speed", 2.5))
	var stride := float(_cfg("model_jog_stride", 2.1)) * lerpf(1.0, maxf(1.0, speed / natural), float(_cfg("model_stride_stretch", 0.5)))
	_phase = fposmod(_phase + speed * delta / maxf(0.1, stride), 1.0)


## Poses the skeleton: the RigPose first, then the recorded jog when running, then the clip of
## `action` (if any) at `time` seconds, mirrored for side -1.
func apply(p: RigPose, action: String, time: float, duration: float, side: float, keeper: bool,
		windup: String = "", windup_amount: float = 0.0) -> void:
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
	for limb in [["Left", RigPose.THIGH_L_X, RigPose.THIGH_L_Z, RigPose.KNEE_L, RigPose.ARM_L_X, RigPose.ARM_L_Z, RigPose.ELBOW_L, -1.0],
			["Right", RigPose.THIGH_R_X, RigPose.THIGH_R_Z, RigPose.KNEE_R, RigPose.ARM_R_X, RigPose.ARM_R_Z, RigPose.ELBOW_R, 1.0]]:
		var thigh: Basis = hips * Basis.from_euler(Vector3(v[limb[1]], 0.0, v[limb[2]]))
		driven[_bones[limb[0] + "UpLeg"]] = thigh
		driven[_bones[limb[0] + "Leg"]] = thigh * Basis.from_euler(Vector3(v[limb[3]], 0.0, 0.0))
		# The model's arms are level in its T-pose: ours hang down at zero.
		var down := Basis.from_euler(Vector3(0.0, 0.0, float(limb[7]) * PI * 0.5))
		var arm: Basis = spine * Basis.from_euler(Vector3(v[limb[4]], 0.0, v[limb[5]]))
		driven[_bones[limb[0] + "Arm"]] = arm * down
		driven[_bones[limb[0] + "ForeArm"]] = arm * Basis.from_euler(Vector3(v[limb[6]], 0.0, 0.0)) * down
	var globals := {}
	var locals: Array[Quaternion] = []
	locals.resize(_order.size())
	for i in _order:
		var parent := _skeleton.get_bone_parent(i)
		var parent_basis: Basis = globals[parent] if parent >= 0 and globals.has(parent) else Basis.IDENTITY
		var global_basis: Basis
		if driven.has(i):
			global_basis = (driven[i] as Basis) * _rest_global[i]
		else:
			global_basis = parent_basis * _rest_local[i]
		globals[i] = global_basis
		locals[i] = (parent_basis.inverse() * global_basis).get_rotation_quaternion()
	var hips_index: int = _bones["Hips"]
	var hips_rest := _skeleton.get_bone_rest(hips_index).origin
	var hips_at := hips_rest + Vector3(0.0, v[RigPose.ROOT_Y], v[RigPose.ROOT_FWD]) / _unit
	# The recorded jog (forward or backward) when running.
	var loco: Animation = _clips.get("jog_backward" if _backward else "jog", null)
	if loco != null and _run > 0.01:
		hips_at.y = lerpf(hips_at.y, _blend_clip(locals, loco, _phase * loco.length, _run, false, hips_index, hips_at.y), _run)
	# Wind-up while a kick is being charged: the clip's backswing, before its contact.
	var wind_key := windup + "_keeper" if keeper and _clips.has(windup + "_keeper") else windup
	if action.is_empty() and windup_amount > 0.01 and _clips.has(wind_key):
		var wind_setup: Dictionary = _setups[wind_key]
		var wind_at := maxf(0.0, float(wind_setup.get("start", 0.0)) - float(wind_setup.get("wind", 0.15)))
		var wind_w := smoothstep(0.0, float(_cfg("model_windup_full", 0.35)), windup_amount) * float(_cfg("model_windup_weight", 0.85))
		hips_at.y = lerpf(hips_at.y, _blend_clip(locals, _clips[wind_key], wind_at, wind_w, side < 0.0, hips_index, hips_at.y), wind_w)
	# The action's recorded movement.
	var key := action + "_keeper" if keeper and _clips.has(action + "_keeper") else action
	if _clips.has(key):
		var anim: Animation = _clips[key]
		var setup: Dictionary = _setups[key]
		var t := clampf(time / maxf(0.01, duration), 0.0, 1.0)
		var w := RigPose.envelope(t, float(_anim_cfg("clip_blend_in", 0.08)), float(setup.get("out", _anim_cfg("clip_blend_out", 0.6))))
		var at := clampf(float(setup.get("start", 0.0)) + time * float(setup.get("rate", 1.0)), 0.0, anim.length)
		hips_at.y = lerpf(hips_at.y, _blend_clip(locals, anim, at, w, side < 0.0, hips_index, hips_at.y), w)
	for i in _order:
		_skeleton.set_bone_pose_rotation(i, locals[i])
	_skeleton.set_bone_pose_position(hips_index, hips_at)


## Blends the clip's bone rotations at `at` seconds into `locals` with weight w (mirrored left to
## right if asked). Returns the clip's hips height (or `hips_y` when it has none).
func _blend_clip(locals: Array[Quaternion], anim: Animation, at: float, w: float, mirror: bool, hips_index: int, hips_y: float) -> float:
	var height := hips_y
	var sampled := {}
	for track in range(anim.get_track_count()):
		var path := anim.track_get_path(track)
		if path.get_subname_count() == 0:
			continue
		var name_key := _short(str(path.get_subname(0)))
		if not _bones.has(name_key):
			continue
		var bone: int = _bones[name_key]
		match anim.track_get_type(track):
			Animation.TYPE_ROTATION_3D:
				sampled[bone] = anim.rotation_track_interpolate(track, at)
			Animation.TYPE_POSITION_3D:
				if bone == hips_index:
					# Only the height: the player's place on the court is the game's.
					height = anim.position_track_interpolate(track, at).y
	if mirror:
		sampled = _mirrored(sampled)
	for bone in sampled:
		locals[bone] = locals[bone].slerp(sampled[bone], w)
	return height


## The same pose seen in a mirror: each bone takes the mirrored turn of its opposite bone.
func _mirrored(sampled: Dictionary) -> Dictionary:
	var flip := Basis.from_scale(Vector3(-1.0, 1.0, 1.0))
	var turned := {}
	var globals := {}
	for i in _order:
		var parent := _skeleton.get_bone_parent(i)
		var parent_basis: Basis = globals[parent] if parent >= 0 and globals.has(parent) else Basis.IDENTITY
		globals[i] = parent_basis * (Basis(sampled[i] as Quaternion) if sampled.has(i) else _rest_local[i])
		turned[i] = (globals[i] as Basis) * _rest_global[i].inverse()
	var out := {}
	var mirrored_globals := {}
	for i in _order:
		var parent := _skeleton.get_bone_parent(i)
		var parent_basis: Basis = mirrored_globals[parent] if parent >= 0 and mirrored_globals.has(parent) else Basis.IDENTITY
		var global_basis: Basis = (flip * (turned[_opposite[i]] as Basis) * flip) * _rest_global[i]
		mirrored_globals[i] = global_basis
		out[i] = (parent_basis.inverse() * global_basis).get_rotation_quaternion()
	return out


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


## The animation of a file, loaded once for all players.
static func _animation(path: String) -> Animation:
	if not _animations.has(path):
		_animations[path] = _load_animation(path)
	return _animations[path]


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
