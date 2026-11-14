class_name Effects
extends Node3D
## One-shot visual effects in the match: dust puffs (tackles, shoulder duels) and goal confetti.
## Small CPU particles, fine on phones with the Compatibility renderer.


func dust(at: Vector3) -> void:
	_burst(at + Vector3.UP * 0.1, 14, 0.5, Color(0.78, 0.74, 0.66, 0.8), 1.6, Vector3.UP, 60.0, 0.08, -2.0)


func confetti(at: Vector3, colors: Array[Color]) -> void:
	for c in colors:
		_burst(at + Vector3.UP * 1.0, 36, 1.8, c, 7.0, Vector3.UP, 70.0, 0.07, -6.0)


func _burst(at: Vector3, amount: int, lifetime: float, color: Color, speed: float, direction: Vector3,
		spread_degrees: float, piece_size: float, gravity_y: float) -> void:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 0.95
	particles.local_coords = false
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * piece_size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	particles.mesh = mesh
	particles.direction = direction
	particles.spread = spread_degrees
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0.0, gravity_y, 0.0)
	particles.position = at
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(lifetime + 0.5).timeout.connect(particles.queue_free)
