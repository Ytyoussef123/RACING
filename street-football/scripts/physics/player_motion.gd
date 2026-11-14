class_name PlayerMotion
extends RefCounted
## Pure player movement on the ground plane: acceleration, sprint and turning.
## Numbers come from data/config/player.json (Phase 4 will scale them by player stats).

var velocity: Vector3 = Vector3.ZERO
## Unit vector the player looks at (on the ground plane).
var facing: Vector3 = Vector3.RIGHT
## Turning speed measured on the last step, rad/s. Positive = counter-clockwise seen from above.
var turn_rate: float = 0.0

var _run_speed: float
var _sprint_speed: float
var _dribble_factor: float
var _acceleration: float
var _deceleration: float
var _turn_speed: float
var _dribble_turn_speed: float


func _init() -> void:
	_run_speed = _cfg("run_speed", 5.5)
	_sprint_speed = _cfg("sprint_speed", 7.8)
	_dribble_factor = _cfg("dribble_speed_factor", 0.92)
	_acceleration = _cfg("acceleration", 22.0)
	_deceleration = _cfg("deceleration", 28.0)
	_turn_speed = deg_to_rad(_cfg("turn_speed_degrees", 720.0))
	_dribble_turn_speed = deg_to_rad(_cfg("dribble_turn_speed_degrees", 540.0))


func reset(new_facing: Vector3) -> void:
	velocity = Vector3.ZERO
	turn_rate = 0.0
	var flat := Vector3(new_facing.x, 0.0, new_facing.z)
	facing = flat.normalized() if flat.length() > 0.001 else Vector3.RIGHT


## move: wanted direction on the ground, length 0..1 (joystick strength).
func step(delta: float, move: Vector3, sprint: bool, dribbling: bool) -> void:
	var max_speed := _sprint_speed if sprint else _run_speed
	if dribbling:
		max_speed *= _dribble_factor
	var wanted := Vector3(move.x, 0.0, move.z).limit_length(1.0)
	var target := wanted * max_speed
	var rate := _acceleration if wanted.length() > 0.05 else _deceleration
	velocity = velocity.move_toward(target, rate * delta)
	_turn(delta, wanted, dribbling)


func _turn(delta: float, wanted: Vector3, dribbling: bool) -> void:
	var old_yaw := atan2(facing.x, facing.z)
	if wanted.length() > 0.1:
		var target_yaw := atan2(wanted.x, wanted.z)
		var max_turn := (_dribble_turn_speed if dribbling else _turn_speed) * delta
		var diff := wrapf(target_yaw - old_yaw, -PI, PI)
		var new_yaw := old_yaw + clampf(diff, -max_turn, max_turn)
		facing = Vector3(sin(new_yaw), 0.0, cos(new_yaw))
	var turned := wrapf(atan2(facing.x, facing.z) - old_yaw, -PI, PI)
	turn_rate = turned / delta if delta > 0.0 else 0.0


func _cfg(key: String, fallback: float) -> float:
	return float(Config.get_value("player", key, fallback))
