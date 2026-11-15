class_name PlayerMotion
extends RefCounted
## Pure player movement on the ground plane: acceleration, speed modes and turning.
## Speed modes: walk (soft joystick, fixed walking speed), run (the move length scales the run
## speed), sprint, and knock-on (with the ball: full sprint speed, the ball being pushed ahead).
## Turning grip depends on the speed: sharper turns when slow, wider at full sprint.
## Base numbers come from data/config/player.json; the player's stat sheet scales them
## (apply_sheet) and tiredness lowers the top speed (energy_mult).

var velocity: Vector3 = Vector3.ZERO
## Unit vector the player looks at (on the ground plane).
var facing: Vector3 = Vector3.RIGHT
## Turning speed measured on the last step, rad/s. Positive = counter-clockwise seen from above.
var turn_rate: float = 0.0
## Multiplies the top speed: the AI difficulty.
var speed_factor: float = 1.0
## Multiplies the top speed: tiredness (1.0 = fresh), set by Player every frame.
var energy_mult: float = 1.0

var _run_speed: float
var _sprint_speed: float
var _dribble_factor: float
var _acceleration: float
var _deceleration: float
var _turn_speed: float
var _dribble_turn_speed: float
var _walk_speed: float
var _grip_walk: float
var _grip_sprint: float
var _knock_on_factor: float
# From the stat sheet (1.0 = average player).
var _run_mult: float = 1.0
var _sprint_mult: float = 1.0
var _accel_mult: float = 1.0
var _turn_mult: float = 1.0
var _dribble_turn_mult: float = 1.0


func _init() -> void:
	_run_speed = _cfg("run_speed", 5.5)
	_sprint_speed = _cfg("sprint_speed", 7.8)
	_dribble_factor = _cfg("dribble_speed_factor", 0.92)
	_acceleration = _cfg("acceleration", 22.0)
	_deceleration = _cfg("deceleration", 28.0)
	_turn_speed = deg_to_rad(_cfg("turn_speed_degrees", 720.0))
	_dribble_turn_speed = deg_to_rad(_cfg("dribble_turn_speed_degrees", 540.0))
	_walk_speed = _cfg("walk_speed", 2.2)
	_grip_walk = _cfg("turn_grip_walk", 1.3)
	_grip_sprint = _cfg("turn_grip_sprint", 0.6)
	_knock_on_factor = _cfg("knock_on_speed_factor", 1.0)


## Takes the movement numbers from a stat sheet (StatEffects); missing ones stay neutral.
func apply_sheet(sheet: Dictionary) -> void:
	_run_mult = float(sheet.get("run_speed_mult", 1.0))
	_sprint_mult = float(sheet.get("sprint_speed_mult", 1.0))
	_accel_mult = float(sheet.get("acceleration_mult", 1.0))
	_turn_mult = float(sheet.get("turn_speed_mult", 1.0))
	_dribble_turn_mult = float(sheet.get("dribble_turn_speed_mult", 1.0))
	_dribble_factor = float(sheet.get("dribble_speed_factor", _cfg("dribble_speed_factor", 0.92)))


func reset(new_facing: Vector3) -> void:
	velocity = Vector3.ZERO
	turn_rate = 0.0
	var flat := Vector3(new_facing.x, 0.0, new_facing.z)
	facing = flat.normalized() if flat.length() > 0.001 else Vector3.RIGHT


## Current top speed, m/s.
func top_speed(sprint: bool, dribbling: bool = false) -> float:
	var speed := (_sprint_speed * _sprint_mult if sprint else _run_speed * _run_mult) * speed_factor * energy_mult
	return speed * _dribble_factor if dribbling else speed


## Walking speed (soft joystick), m/s.
func walk_speed(dribbling: bool = false) -> float:
	var speed := _walk_speed * _run_mult * speed_factor * energy_mult
	return speed * _dribble_factor if dribbling else speed


## Knock-on speed: full sprint, without the dribbling slowdown (the ball is pushed ahead).
func knock_on_speed() -> float:
	return top_speed(true, false) * _knock_on_factor


## move: wanted direction on the ground, length 0..1 (joystick strength). walk: the player walks
## at walk_speed whatever the length. knock_on (with the ball): he runs at knock_on_speed.
func step(delta: float, move: Vector3, sprint: bool, dribbling: bool, walk: bool = false,
		knock_on: bool = false) -> void:
	var wanted := Vector3(move.x, 0.0, move.z).limit_length(1.0)
	var moving := wanted.length() > 0.05
	var target: Vector3
	if knock_on and dribbling:
		target = wanted.normalized() * knock_on_speed() if moving else Vector3.ZERO
	elif walk:
		target = wanted.normalized() * walk_speed(dribbling) if moving else Vector3.ZERO
	else:
		target = wanted * top_speed(sprint, dribbling)
	var rate := _acceleration * _accel_mult if moving else _deceleration
	var grip := _grip(Vector2(velocity.x, velocity.z).length())
	_accelerate(target, rate, grip, delta)
	_turn(delta, wanted, dribbling, grip)


## Moves the velocity toward the target at `rate`; the part of the change that turns the run
## (across the current direction) goes `grip` times as fast. grip 1 = straight toward the target.
func _accelerate(target: Vector3, rate: float, grip: float, delta: float) -> void:
	var diff := target - velocity
	var dist := diff.length()
	if dist < 0.0001:
		velocity = target
		return
	var change := diff / dist * rate * delta
	var speed := velocity.length()
	if speed > 0.1:
		var along_dir := velocity / speed
		var along := along_dir * change.dot(along_dir)
		change = along + (change - along) * grip
	if change.length() >= dist:
		velocity = target
	else:
		velocity += change


## Turning grip at this speed: turn_grip_walk at walking pace, 1 at run speed, turn_grip_sprint
## at full sprint, linear in between.
func _grip(speed: float) -> float:
	var walk := _walk_speed * _run_mult
	var run := _run_speed * _run_mult
	var sprint := _sprint_speed * _sprint_mult
	if speed <= walk:
		return _grip_walk
	if speed <= run:
		return lerpf(_grip_walk, 1.0, (speed - walk) / maxf(0.01, run - walk))
	return lerpf(1.0, _grip_sprint, clampf((speed - run) / maxf(0.01, sprint - run), 0.0, 1.0))


func _turn(delta: float, wanted: Vector3, dribbling: bool, grip: float = 1.0) -> void:
	var old_yaw := atan2(facing.x, facing.z)
	if wanted.length() > 0.1:
		var target_yaw := atan2(wanted.x, wanted.z)
		var turn_speed := _dribble_turn_speed * _dribble_turn_mult if dribbling else _turn_speed * _turn_mult
		var max_turn := turn_speed * grip * delta
		var diff := wrapf(target_yaw - old_yaw, -PI, PI)
		var new_yaw := old_yaw + clampf(diff, -max_turn, max_turn)
		facing = Vector3(sin(new_yaw), 0.0, cos(new_yaw))
	var turned := wrapf(atan2(facing.x, facing.z) - old_yaw, -PI, PI)
	turn_rate = turned / delta if delta > 0.0 else 0.0


func _cfg(key: String, fallback: float) -> float:
	return float(Config.get_value("player", key, fallback))
