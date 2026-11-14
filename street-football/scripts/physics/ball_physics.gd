class_name BallPhysics
extends RefCounted
## Pure ball simulation, no nodes: gravity, ground bounces, rolling friction, air drag and curve.
## Walls, posts and nets are in CourtBounds. All numbers come from data/config/ball.json.

## Numerical tolerance for "touching the ground" (not a gameplay value).
const GROUND_EPSILON := 0.002

var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
## Curve amount (-max_spin..max_spin). Positive bends the path counter-clockwise seen from above.
var spin: float = 0.0
## True while a player dribbles the ball: no friction or curve, the player drives its speed.
var controlled: bool = false
## Last thing the ball hit this step ("ground", "wall", "post", "net", or ""), and how hard (m/s).
## Read by the ball node for sounds and effects, then cleared.
var last_hit: String = ""
var last_hit_speed: float = 0.0

var radius: float
var _gravity: float
var _air_drag: float
var _rolling_friction: float
var _rolling_drag: float
var _stop_speed: float
var _ground_restitution: float
var _bounce_friction: float
var _min_bounce_speed: float
var _curve_accel: float
var _curve_ground_factor: float
var _spin_decay: float
var _max_spin: float
var _friction_mult: float = 1.0
var _bounce_mult: float = 1.0


func _init() -> void:
	radius = _cfg("radius", 0.11)
	_gravity = _cfg("gravity", 9.81)
	_air_drag = _cfg("air_drag", 0.12)
	_rolling_friction = _cfg("rolling_friction", 1.6)
	_rolling_drag = _cfg("rolling_drag", 0.25)
	_stop_speed = _cfg("stop_speed", 0.05)
	_ground_restitution = _cfg("ground_restitution", 0.55)
	_bounce_friction = _cfg("ground_bounce_friction", 0.92)
	_min_bounce_speed = _cfg("min_bounce_speed", 0.6)
	_curve_accel = _cfg("curve_accel", 9.0)
	_curve_ground_factor = _cfg("curve_ground_factor", 0.25)
	_spin_decay = _cfg("spin_decay", 0.8)
	_max_spin = _cfg("max_spin", 1.0)
	position = Vector3(0.0, radius, 0.0)


func place(new_position: Vector3) -> void:
	position = new_position
	velocity = Vector3.ZERO
	spin = 0.0
	controlled = false


## Court surface (sand, rooftop...): rolling friction and bounce multipliers from the court data.
func apply_surface(friction_mult: float, bounce_mult: float) -> void:
	_rolling_friction *= friction_mult / _friction_mult
	_rolling_drag *= friction_mult / _friction_mult
	_ground_restitution = minf(0.95, _ground_restitution * bounce_mult / _bounce_mult)
	_friction_mult = friction_mult
	_bounce_mult = bounce_mult


## Independent copy of the ball's state, used to predict where it is going.
func copy() -> BallPhysics:
	var twin := BallPhysics.new()
	twin.apply_surface(_friction_mult, _bounce_mult)
	twin.position = position
	twin.velocity = velocity
	twin.spin = spin
	return twin


## Keeps the strongest hit of the step.
func report_hit(kind: String, speed: float) -> void:
	if speed > last_hit_speed:
		last_hit = kind
		last_hit_speed = speed


func kick(new_velocity: Vector3, new_spin: float) -> void:
	controlled = false
	velocity = new_velocity
	spin = clampf(new_spin, -_max_spin, _max_spin)


func is_on_ground() -> bool:
	return position.y <= radius + GROUND_EPSILON and absf(velocity.y) < GROUND_EPSILON


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func step(delta: float) -> void:
	var airborne := position.y > radius + GROUND_EPSILON or velocity.y > 0.0
	if airborne:
		velocity.y -= _gravity * delta
		velocity *= maxf(0.0, 1.0 - _air_drag * delta)
	if not controlled:
		_apply_curve(delta, airborne)
	position += velocity * delta
	_resolve_ground()
	if not controlled and is_on_ground():
		_apply_rolling(delta)


func _resolve_ground() -> void:
	if position.y >= radius:
		return
	position.y = radius
	if velocity.y < -_min_bounce_speed:
		report_hit("ground", -velocity.y)
		velocity.y = -velocity.y * _ground_restitution
		velocity.x *= _bounce_friction
		velocity.z *= _bounce_friction
	else:
		velocity.y = 0.0


func _apply_rolling(delta: float) -> void:
	var speed := horizontal_speed()
	if speed <= _stop_speed:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var new_speed := maxf(0.0, speed - _rolling_friction * delta) * maxf(0.0, 1.0 - _rolling_drag * delta)
	var ratio := new_speed / speed
	velocity.x *= ratio
	velocity.z *= ratio


func _apply_curve(delta: float, airborne: bool) -> void:
	if is_zero_approx(spin):
		return
	var speed := horizontal_speed()
	if speed > _stop_speed:
		# Horizontal direction turned +90 degrees around the up axis.
		var side := Vector3(velocity.z, 0.0, -velocity.x) / speed
		var factor := 1.0 if airborne else _curve_ground_factor
		velocity += side * spin * _curve_accel * factor * delta
	spin = move_toward(spin, 0.0, _spin_decay * delta)


func _cfg(key: String, fallback: float) -> float:
	return float(Config.get_value("ball", key, fallback))
