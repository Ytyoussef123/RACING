class_name Ball
extends Node3D
## The match ball node: owns the BallPhysics simulation and shows it (rolling mesh and shadow).

## Small lift so the shadow does not flicker with the ground (visual only).
const SHADOW_LIFT := 0.012

var physics: BallPhysics

@onready var _visual: Node3D = $Visual
@onready var _body: Node3D = $Visual/Body
@onready var _shadow: Node3D = $Shadow
@onready var _trail: CPUParticles3D = $Trail


func _ready() -> void:
	physics = BallPhysics.new()
	_body.scale = Vector3.ONE * physics.radius
	_update_visual(0.0)


## One fixed physics step: movement, then walls / posts / nets. Returns OUT on open courts.
func simulate(delta: float, court: CourtData) -> CourtBounds.Event:
	physics.last_hit = ""
	physics.last_hit_speed = 0.0
	physics.step(delta)
	var event := CourtBounds.resolve(physics, court)
	_update_visual(delta)
	return event


func _update_visual(delta: float) -> void:
	position = physics.position
	var travelled := Vector3(physics.velocity.x, 0.0, physics.velocity.z) * delta
	var dist := travelled.length()
	if dist > 0.0001:
		var axis := Vector3.UP.cross(travelled / dist)
		_visual.rotate(axis, dist / physics.radius)
		_visual.basis = _visual.basis.orthonormalized()
	_trail.emitting = physics.horizontal_speed() > float(Config.get_value("animation", "ball_trail_min_speed", 14.0))
	var height := physics.position.y - physics.radius
	_shadow.position = Vector3(0.0, -physics.position.y + SHADOW_LIFT, 0.0)
	var shadow_size := physics.radius * lerpf(1.3, 0.6, clampf(height / 3.0, 0.0, 1.0))
	_shadow.scale = Vector3(shadow_size, 1.0, shadow_size)
