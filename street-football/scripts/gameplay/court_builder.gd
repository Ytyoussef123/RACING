class_name CourtBuilder
extends Node3D
## Builds the court's look from CourtData: ground, lines, goals, and walls/fence for cage courts.
## Pure visuals: collisions are in CourtBounds. Low-poly boxes only, cheap on phones.

## Visual thickness of the side boards and fence posts (meters).
const BOARD_THICKNESS := 0.15
const FENCE_POST_SPACING := 3.0
const LINE_HEIGHT := 0.01

var _court: CourtData


func build(court: CourtData) -> void:
	_court = court
	for child in get_children():
		child.queue_free()
	_build_ground()
	_build_lines()
	for side: float in [-1.0, 1.0]:
		_build_goal(side)
	if court.walls:
		_build_walls()


func _build_ground() -> void:
	var apron := _court.number("apron", 6.0)
	var surround := PlaneMesh.new()
	surround.size = Vector2(_court.length + apron * 2.0, _court.width + apron * 2.0)
	_add(surround, Vector3(0.0, -0.02, 0.0), _mat(_court.color("surround", Color(0.23, 0.24, 0.26))))
	var pitch := PlaneMesh.new()
	pitch.size = Vector2(_court.length, _court.width)
	_add(pitch, Vector3.ZERO, _mat(_court.color("ground", Color(0.36, 0.38, 0.4))))


func _build_lines() -> void:
	var lw := _court.number("line_width", 0.1)
	var mat := _mat(_court.color("lines", Color.WHITE), true)
	var hl := _court.half_length
	var hw := _court.half_width
	var y := LINE_HEIGHT * 0.5
	# Boundary and halfway line.
	_box(Vector3(_court.length, LINE_HEIGHT, lw), Vector3(0.0, y, -hw + lw * 0.5), mat)
	_box(Vector3(_court.length, LINE_HEIGHT, lw), Vector3(0.0, y, hw - lw * 0.5), mat)
	_box(Vector3(lw, LINE_HEIGHT, _court.width), Vector3(-hl + lw * 0.5, y, 0.0), mat)
	_box(Vector3(lw, LINE_HEIGHT, _court.width), Vector3(hl - lw * 0.5, y, 0.0), mat)
	_box(Vector3(lw, LINE_HEIGHT, _court.width), Vector3(0.0, y, 0.0), mat)
	# Center circle and spot.
	var ring := TorusMesh.new()
	var r := _court.number("center_circle_radius", 2.5)
	ring.inner_radius = r - lw * 0.5
	ring.outer_radius = r + lw * 0.5
	ring.rings = 48
	ring.ring_segments = 4
	_add(ring, Vector3.ZERO, mat)
	var spot := CylinderMesh.new()
	spot.top_radius = lw * 1.5
	spot.bottom_radius = lw * 1.5
	spot.height = LINE_HEIGHT
	_add(spot, Vector3(0.0, y, 0.0), mat)
	# Goal areas.
	var depth := _court.number("goal_area_depth", 3.0)
	var area_w := _court.number("goal_area_width", 7.0)
	for side: float in [-1.0, 1.0]:
		var front_x := side * (hl - depth)
		_box(Vector3(lw, LINE_HEIGHT, area_w), Vector3(front_x, y, 0.0), mat)
		for z_sign: float in [-1.0, 1.0]:
			_box(Vector3(depth, LINE_HEIGHT, lw), Vector3(side * (hl - depth * 0.5), y, z_sign * area_w * 0.5), mat)


func _build_goal(side: float) -> void:
	var frame := _mat(_court.color("goal", Color.WHITE))
	var net := _mat(Color(1.0, 1.0, 1.0), true, 0.25)
	var hl := _court.half_length
	var hgw := _court.half_goal_width
	var gh := _court.goal_height
	var depth := _court.goal_depth
	var post := _court.post_radius * 2.0
	var back_x := side * (hl + depth)
	var mid_x := side * (hl + depth * 0.5)
	for z_sign: float in [-1.0, 1.0]:
		_box(Vector3(post, gh, post), Vector3(side * hl, gh * 0.5, z_sign * hgw), frame)
		_box(Vector3(0.05, gh, 0.05), Vector3(back_x, gh * 0.5, z_sign * hgw), frame)
		_box(Vector3(depth, 0.05, 0.05), Vector3(mid_x, gh, z_sign * hgw), frame)
		_box(Vector3(depth, gh, 0.01), Vector3(mid_x, gh * 0.5, z_sign * hgw), net)
	_box(Vector3(post, post, _court.goal_width + post), Vector3(side * hl, gh, 0.0), frame)
	_box(Vector3(0.05, 0.05, _court.goal_width), Vector3(back_x, gh, 0.0), frame)
	_box(Vector3(0.01, gh, _court.goal_width), Vector3(back_x, gh * 0.5, 0.0), net)
	_box(Vector3(depth, 0.01, _court.goal_width), Vector3(mid_x, gh, 0.0), net)


func _build_walls() -> void:
	var wall_mat := _mat(_court.color("walls", Color(0.17, 0.18, 0.2)))
	var accent := _mat(_court.color("accent", Color(1.0, 0.36, 0.1)), true)
	var h := _court.number("wall_height", 0.7)
	var t := BOARD_THICKNESS
	var hl := _court.half_length
	var hw := _court.half_width
	var full_len := _court.length + t * 2.0
	# Long side boards (near and far).
	for z_sign: float in [-1.0, 1.0]:
		_box(Vector3(full_len, h, t), Vector3(0.0, h * 0.5, z_sign * (hw + t * 0.5)), wall_mat)
	# Graffiti-style stripe on the far board.
	_box(Vector3(_court.length, 0.12, 0.02), Vector3(0.0, h - 0.1, -hw - 0.005), accent)
	# End boards, split around the goal mouth.
	var seg_len := hw + t - _court.half_goal_width
	for side: float in [-1.0, 1.0]:
		for z_sign: float in [-1.0, 1.0]:
			var z := z_sign * (_court.half_goal_width + seg_len * 0.5)
			_box(Vector3(t, h, seg_len), Vector3(side * (hl + t * 0.5), h * 0.5, z), wall_mat)
	_build_fence()


## Tall see-through fence on the far side and the ends (not on the near side: it would hide the play).
func _build_fence() -> void:
	var fence_h := _court.number("fence_height", 3.0)
	if fence_h <= 0.0:
		return
	var post_mat := _mat(Color(0.12, 0.12, 0.14))
	var mesh_mat := _mat(Color(0.8, 0.85, 0.9), true, 0.12)
	var hl := _court.half_length
	var hw := _court.half_width
	var far_z := -hw - BOARD_THICKNESS
	var count := int(ceil(_court.length / FENCE_POST_SPACING))
	for i in range(count + 1):
		var x := -hl + _court.length * float(i) / float(count)
		_box(Vector3(0.08, fence_h, 0.08), Vector3(x, fence_h * 0.5, far_z), post_mat)
	_box(Vector3(_court.length, 0.06, 0.06), Vector3(0.0, fence_h, far_z), post_mat)
	_box(Vector3(_court.length, fence_h, 0.01), Vector3(0.0, fence_h * 0.5, far_z), mesh_mat)
	for side: float in [-1.0, 1.0]:
		var end_x := side * (hl + BOARD_THICKNESS)
		_box(Vector3(0.01, fence_h, _court.width), Vector3(end_x, fence_h * 0.5, 0.0), mesh_mat)
		_box(Vector3(0.06, 0.06, _court.width), Vector3(end_x, fence_h, 0.0), post_mat)


func _box(box_size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	return _add(mesh, pos, mat)


func _add(mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _mat(albedo: Color, unshaded: bool = false, alpha: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(albedo, alpha)
	mat.roughness = 0.9
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
