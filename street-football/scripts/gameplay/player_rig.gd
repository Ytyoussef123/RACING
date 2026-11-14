class_name PlayerRig
extends RefCounted
## The player's jointed body (look only), built under the Pose node of player.tscn:
## Hips -> ThighL/R -> KneeL/R (legs with shorts, socks and boots), Hips -> Spine (chest) ->
## Neck (head and hair) and Spine -> ArmL/R -> ElbowL/R (sleeves, forearms, hands or gloves).
## PlayerAnimator writes a RigPose every frame and apply() turns the joints.
## The meshes are merged per limb and colored per vertex (RigMeshBuilder); they are rebuilt when the
## kit or the look changes. Sizes: data/config/body.json, for a player of reference_height.

var root: Node3D
var hips: Node3D
var spine: Node3D
var neck: Node3D
var thigh_l: Node3D
var knee_l: Node3D
var thigh_r: Node3D
var knee_r: Node3D
var arm_l: Node3D
var elbow_l: Node3D
var arm_r: Node3D
var elbow_r: Node3D

var _colors := {}
var _hair_style := "short"
var _gloves := false
var _dirty := true
var _pelvis_mesh: MeshInstance3D
var _chest_mesh: MeshInstance3D
var _head_mesh: MeshInstance3D
var _thigh_meshes: Array[MeshInstance3D] = []
var _shin_meshes: Array[MeshInstance3D] = []
var _upper_arm_meshes: Array[MeshInstance3D] = []
var _forearm_meshes: Array[MeshInstance3D] = []


func _init() -> void:
	var skin := Color.html(str(_cfg("default_skin", "#c68a5e")))
	_colors = {
		"shirt": Color.WHITE, "shorts": Color.GRAY, "socks": Color.WHITE, "skin": skin,
		"hair": Color.html(str(_cfg("default_hair", "#1e1610"))), "boots": Color(0.1, 0.1, 0.12),
	}


## Creates the joints and their (still empty) mesh nodes under `pose_root`.
func build(pose_root: Node3D) -> void:
	root = pose_root
	var hip_y := _n("ankle_height", 0.07) + _n("shin_length", 0.41) + _n("thigh_length", 0.43)
	var hip_x := _n("hip_joint_offset", 0.092)
	var thigh := _n("thigh_length", 0.43)
	hips = _joint(root, "Hips", Vector3(0.0, hip_y, 0.0))
	thigh_l = _joint(hips, "ThighL", Vector3(hip_x, 0.0, 0.0))
	knee_l = _joint(thigh_l, "KneeL", Vector3(0.0, -thigh, 0.0))
	thigh_r = _joint(hips, "ThighR", Vector3(-hip_x, 0.0, 0.0))
	knee_r = _joint(thigh_r, "KneeR", Vector3(0.0, -thigh, 0.0))
	spine = _joint(hips, "Spine", Vector3(0.0, _n("waist_above_hips", 0.08), 0.0))
	neck = _joint(spine, "Neck", Vector3(0.0, _n("chest_length", 0.44), 0.0))
	var shoulder := Vector3(_n("shoulder_offset", 0.225), _n("shoulder_height", 0.37), 0.0)
	var upper_arm := _n("upper_arm_length", 0.26)
	arm_l = _joint(spine, "ArmL", shoulder)
	elbow_l = _joint(arm_l, "ElbowL", Vector3(0.0, -upper_arm, 0.0))
	arm_r = _joint(spine, "ArmR", Vector3(-shoulder.x, shoulder.y, shoulder.z))
	elbow_r = _joint(arm_r, "ElbowR", Vector3(0.0, -upper_arm, 0.0))
	_pelvis_mesh = _mesh_node(hips)
	_chest_mesh = _mesh_node(spine)
	_head_mesh = _mesh_node(neck)
	for side_joints in [[thigh_l, knee_l, arm_l, elbow_l], [thigh_r, knee_r, arm_r, elbow_r]]:
		_thigh_meshes.append(_mesh_node(side_joints[0]))
		_shin_meshes.append(_mesh_node(side_joints[1]))
		_upper_arm_meshes.append(_mesh_node(side_joints[2]))
		_forearm_meshes.append(_mesh_node(side_joints[3]))


## Kit colors: shirt, darker shorts, socks; keepers wear gloves.
func set_kit(kit: Color, keeper: bool) -> void:
	_colors["shirt"] = kit
	_colors["shorts"] = kit.darkened(_n("shorts_darken", 0.45))
	_colors["socks"] = kit.darkened(_n("socks_darken", 0.12))
	_gloves = keeper
	_dirty = true


## The player's own look: skin, hair color and style, boots.
func set_look(skin: Color, hair: Color, hair_style: String, boots: Color) -> void:
	_colors["skin"] = skin
	_colors["hair"] = hair
	_colors["boots"] = boots
	_hair_style = hair_style
	_dirty = true


## Boot color picked from the palette by the player id (always the same for a player).
static func boot_color_for(player_id: String) -> Color:
	var palette: Array = Config.get_value("body", "boot_colors", ["#1b1b20"])
	if palette.is_empty():
		return Color(0.1, 0.1, 0.12)
	return Color.html(str(palette[absi(hash(player_id)) % palette.size()]))


## How much lower the hips are when a standing leg has this thigh swing and knee bend (degrees):
## used so a crouch keeps the feet on the ground.
static func leg_drop(forward_deg: float, knee_deg: float) -> float:
	var thigh := _n("thigh_length", 0.43)
	var shin := _n("shin_length", 0.41)
	return thigh * (1.0 - cos(deg_to_rad(forward_deg))) + shin * (1.0 - cos(deg_to_rad(forward_deg - knee_deg)))


## Builds the meshes if the kit or the look changed since the last time.
func refresh() -> void:
	if not _dirty or root == null:
		return
	_dirty = false
	_pelvis_mesh.mesh = _build_pelvis()
	_chest_mesh.mesh = _build_chest()
	_head_mesh.mesh = _build_head()
	var thigh_mesh := _build_thigh()
	var shin_mesh := _build_shin()
	var upper_arm_mesh := _build_upper_arm()
	var forearm_mesh := _build_forearm()
	for i in range(2):
		_thigh_meshes[i].mesh = thigh_mesh
		_shin_meshes[i].mesh = shin_mesh
		_upper_arm_meshes[i].mesh = upper_arm_mesh
		_forearm_meshes[i].mesh = forearm_mesh


func apply(p: RigPose) -> void:
	var v := p.v
	root.position = Vector3(0.0, v[RigPose.ROOT_Y], v[RigPose.ROOT_FWD])
	root.rotation = Vector3(v[RigPose.ROOT_X], 0.0, v[RigPose.ROOT_Z])
	hips.rotation = Vector3(0.0, v[RigPose.HIPS_Y], v[RigPose.HIPS_Z])
	spine.rotation = Vector3(v[RigPose.SPINE_X], v[RigPose.SPINE_Y], v[RigPose.SPINE_Z])
	neck.rotation = Vector3(v[RigPose.NECK_X], 0.0, 0.0)
	thigh_l.rotation = Vector3(v[RigPose.THIGH_L_X], 0.0, v[RigPose.THIGH_L_Z])
	knee_l.rotation = Vector3(v[RigPose.KNEE_L], 0.0, 0.0)
	thigh_r.rotation = Vector3(v[RigPose.THIGH_R_X], 0.0, v[RigPose.THIGH_R_Z])
	knee_r.rotation = Vector3(v[RigPose.KNEE_R], 0.0, 0.0)
	arm_l.rotation = Vector3(v[RigPose.ARM_L_X], 0.0, v[RigPose.ARM_L_Z])
	elbow_l.rotation = Vector3(v[RigPose.ELBOW_L], 0.0, 0.0)
	arm_r.rotation = Vector3(v[RigPose.ARM_R_X], 0.0, v[RigPose.ARM_R_Z])
	elbow_r.rotation = Vector3(v[RigPose.ELBOW_R], 0.0, 0.0)


# --- Meshes (each in its joint's space; Y up, +Z forward) ---

func _build_pelvis() -> ArrayMesh:
	var r := _n("pelvis_radius", 0.17)
	var h := _n("pelvis_height", 0.21)
	var shape := RigMeshBuilder.cylinder(r, r * 1.03, h)
	var squash := Vector3(1.0, 1.0, _n("pelvis_depth", 0.72))
	return RigMeshBuilder.merge([[shape, RigMeshBuilder.at(Vector3(0.0, -0.03, 0.0), squash), _colors["shorts"]]])


func _build_chest() -> ArrayMesh:
	var length := _n("chest_length", 0.44)
	var cap := _n("shoulder_cap_height", 0.12)
	var r_top := _n("chest_radius_shoulders", 0.19)
	var r_waist := _n("chest_radius_waist", 0.155)
	var depth := Vector3(1.0, 1.0, _n("chest_depth", 0.62))
	var bottom := -0.04
	var top := length - cap * 0.5
	var shirt: Color = _colors["shirt"]
	return RigMeshBuilder.merge([
		[RigMeshBuilder.cylinder(r_top, r_waist, top - bottom), RigMeshBuilder.at(Vector3(0.0, (top + bottom) * 0.5, 0.0), depth), shirt],
		[RigMeshBuilder.sphere(r_top, cap), RigMeshBuilder.at(Vector3(0.0, top, 0.0), depth), shirt],
	])


func _build_head() -> ArrayMesh:
	var neck_len := _n("neck_length", 0.065)
	var neck_r := _n("neck_radius", 0.052)
	var head_r := _n("head_radius", 0.11)
	var head_h := _n("head_height", 0.25)
	var center := neck_len + head_h * 0.5
	var skin: Color = _colors["skin"]
	var hair: Color = _colors["hair"]
	var neck_h := neck_len + 0.06
	var parts := [
		[RigMeshBuilder.cylinder(neck_r * 0.95, neck_r * 1.08, neck_h, false), RigMeshBuilder.at(Vector3(0.0, neck_h * 0.5 - 0.04, 0.0)), skin],
		[RigMeshBuilder.sphere(head_r, head_h), RigMeshBuilder.at(Vector3(0.0, center, 0.0)), skin],
	]
	parts.append_array(_face_parts(center, head_r, head_h))
	# Hair: a cap following the head's shape, a little bigger (thickness) and taller on top,
	# tilted back so it starts above the eyes at the front and low on the nape.
	var styles: Dictionary = Config.get_value("body", "hair_styles", {})
	var style: Array = styles.get(_hair_style, [1.0, 0.012, 0.022])
	var width := float(style[0])
	if width > 0.0:
		var cap_r := head_r + float(style[1])
		var drop := _n("hair_base_drop", 0.012)
		var cap_h := head_h * 0.5 + drop + float(style[2])
		var tilt := deg_to_rad(_n("hair_tilt_degrees", -25.0))
		parts.append([RigMeshBuilder.dome(cap_r, cap_h), RigMeshBuilder.at(Vector3(0.0, center - drop, 0.0), Vector3(width, 1.0, 1.0), tilt), hair])
		if _hair_style == "long":
			var fall := _n("long_hair_drop", 0.15)
			var back := RigMeshBuilder.cylinder(cap_r * 0.92, cap_r * 0.78, fall)
			parts.append([back, RigMeshBuilder.at(Vector3(0.0, center - fall * 0.4, -0.045), Vector3(1.0, 1.0, 0.6)), hair])
	return RigMeshBuilder.merge(parts)


## Eyes, nose and ears, placed on the head's surface (head center at height `center`).
func _face_parts(center: float, head_r: float, head_h: float) -> Array:
	var skin: Color = _colors["skin"]
	var segments := int(_cfg("feature_segments", 6))
	var eye_r := _n("eye_radius", 0.016)
	var eye_x := _n("eye_spacing", 0.038)
	var eye_y := _n("eye_height", 0.02)
	var half_h := head_h * 0.5
	var eye_z := head_r * sqrt(maxf(0.0, 1.0 - pow(eye_x / head_r, 2.0) - pow(eye_y / half_h, 2.0))) - eye_r * 0.4
	var eye_color := Color.html(str(_cfg("eye_color", "#1a1410")))
	var nose_r := _n("nose_radius", 0.02)
	var nose_y := -eye_y * 0.6
	var nose_z := head_r * sqrt(maxf(0.0, 1.0 - pow(nose_y / half_h, 2.0))) - nose_r * 0.25
	var ear_r := _n("ear_radius", 0.024)
	var eye := RigMeshBuilder.sphere(eye_r, -1.0, segments)
	var ear := RigMeshBuilder.sphere(ear_r, -1.0, segments)
	return [
		[eye, RigMeshBuilder.at(Vector3(eye_x, center + eye_y, eye_z)), eye_color],
		[eye, RigMeshBuilder.at(Vector3(-eye_x, center + eye_y, eye_z)), eye_color],
		[RigMeshBuilder.sphere(nose_r, -1.0, segments), RigMeshBuilder.at(Vector3(0.0, center + nose_y, nose_z), Vector3(0.75, 1.0, 1.0)), skin.darkened(0.06)],
		[ear, RigMeshBuilder.at(Vector3(head_r + 0.002, center, -0.006), Vector3(0.55, 1.0, 0.8)), skin],
		[ear, RigMeshBuilder.at(Vector3(-head_r - 0.002, center, -0.006), Vector3(0.55, 1.0, 0.8)), skin],
	]


func _build_thigh() -> ArrayMesh:
	var length := _n("thigh_length", 0.43)
	var shorts_r := _n("shorts_leg_radius", 0.1)
	var shorts_len := _n("shorts_leg_length", 0.21)
	var knee_r := _n("knee_radius", 0.057)
	var skin: Color = _colors["skin"]
	return RigMeshBuilder.merge([
		[RigMeshBuilder.cylinder(shorts_r, shorts_r * 0.94, shorts_len), RigMeshBuilder.at(Vector3(0.0, 0.02 - shorts_len * 0.5, 0.0)), _colors["shorts"]],
		[RigMeshBuilder.cylinder(_n("thigh_radius_top", 0.078), _n("thigh_radius_knee", 0.057), length, false), RigMeshBuilder.at(Vector3(0.0, -length * 0.5, 0.0)), skin],
		[RigMeshBuilder.sphere(knee_r), RigMeshBuilder.at(Vector3(0.0, -length, 0.0)), skin],
	])


func _build_shin() -> ArrayMesh:
	var length := _n("shin_length", 0.41)
	var boot_r := _n("boot_radius", 0.045)
	var ground := -(length + _n("ankle_height", 0.07))
	var boot := RigMeshBuilder.capsule(boot_r, _n("boot_length", 0.25))
	return RigMeshBuilder.merge([
		[RigMeshBuilder.cylinder(_n("shin_radius_knee", 0.056), _n("shin_radius_ankle", 0.04), length, false), RigMeshBuilder.at(Vector3(0.0, -length * 0.5, 0.0)), _colors["socks"]],
		[boot, RigMeshBuilder.at(Vector3(0.0, ground + boot_r, _n("boot_forward", 0.055)), Vector3.ONE, PI * 0.5), _colors["boots"]],
	])


func _build_upper_arm() -> ArrayMesh:
	var length := _n("upper_arm_length", 0.26)
	var sleeve_r := _n("sleeve_radius", 0.062)
	var sleeve_len := _n("sleeve_length", 0.15)
	var arm_r := _n("upper_arm_radius", 0.047)
	var elbow_r := _n("elbow_radius", 0.04)
	var shirt: Color = _colors["shirt"]
	var skin: Color = _colors["skin"]
	return RigMeshBuilder.merge([
		[RigMeshBuilder.sphere(sleeve_r), RigMeshBuilder.at(Vector3.ZERO), shirt],
		[RigMeshBuilder.cylinder(sleeve_r, sleeve_r * 0.9, sleeve_len), RigMeshBuilder.at(Vector3(0.0, -sleeve_len * 0.5, 0.0)), shirt],
		[RigMeshBuilder.cylinder(arm_r, elbow_r, length, false), RigMeshBuilder.at(Vector3(0.0, -length * 0.5, 0.0)), skin],
		[RigMeshBuilder.sphere(elbow_r), RigMeshBuilder.at(Vector3(0.0, -length, 0.0)), skin],
	])


func _build_forearm() -> ArrayMesh:
	var length := _n("forearm_length", 0.23)
	var hand_r := _n("glove_radius", 0.056) if _gloves else _n("hand_radius", 0.044)
	var hand_color: Color = Color.html(str(_cfg("glove_color", "#f4f4f0"))) if _gloves else _colors["skin"]
	return RigMeshBuilder.merge([
		[RigMeshBuilder.cylinder(_n("forearm_radius", 0.039), _n("wrist_radius", 0.032), length, false), RigMeshBuilder.at(Vector3(0.0, -length * 0.5, 0.0)), _colors["skin"]],
		[RigMeshBuilder.sphere(hand_r, hand_r * 2.4), RigMeshBuilder.at(Vector3(0.0, -length - hand_r * 0.8, 0.0), Vector3(0.85, 1.0, 1.0)), hand_color],
	])


func _joint(parent: Node3D, joint_name: String, pos: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.name = joint_name
	joint.position = pos
	parent.add_child(joint)
	return joint


func _mesh_node(parent: Node3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


static func _n(key: String, fallback: float) -> float:
	return float(Config.get_value("body", key, fallback))


static func _cfg(key: String, fallback: Variant) -> Variant:
	return Config.get_value("body", key, fallback)
