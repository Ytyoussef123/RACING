class_name MatchCamera
extends Camera3D
## Fixed-angle camera above the near long side, following the ball smoothly.
## Numbers: data/config/camera.json.

var _focus: Vector3 = Vector3.ZERO
var _pitch: float
var _distance: float
var _follow_speed: float
var _look_ahead: float
var _z_follow: float
var _x_margin: float


func _ready() -> void:
	fov = _cfg("fov", 45.0)
	_pitch = deg_to_rad(_cfg("pitch_degrees", 55.0))
	_distance = _cfg("distance", 19.0)
	_follow_speed = _cfg("follow_speed", 4.0)
	_look_ahead = _cfg("look_ahead_seconds", 0.25)
	_z_follow = _cfg("z_follow_factor", 0.4)
	_x_margin = _cfg("x_limit_margin", 6.0)


func snap_to(ball_position: Vector3, court: CourtData) -> void:
	_focus = _target_for(ball_position, Vector3.ZERO, court)
	_place()


func follow(delta: float, ball_position: Vector3, ball_velocity: Vector3, court: CourtData) -> void:
	var target := _target_for(ball_position, ball_velocity, court)
	_focus = _focus.lerp(target, 1.0 - exp(-_follow_speed * delta))
	_place()


func _target_for(ball_position: Vector3, ball_velocity: Vector3, court: CourtData) -> Vector3:
	var target := ball_position + Vector3(ball_velocity.x, 0.0, ball_velocity.z) * _look_ahead
	var max_x := maxf(0.0, court.half_length - _x_margin)
	return Vector3(clampf(target.x, -max_x, max_x), 0.0, target.z * _z_follow)


func _place() -> void:
	var offset := Vector3(0.0, sin(_pitch), cos(_pitch)) * _distance
	look_at_from_position(_focus + offset, _focus, Vector3.UP)


func _cfg(key: String, fallback: float) -> float:
	return float(Config.get_value("camera", key, fallback))
