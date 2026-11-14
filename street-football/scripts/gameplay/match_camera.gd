class_name MatchCamera
extends Camera3D
## Fixed-angle camera above the near long side, following the ball smoothly, with a short shake
## on big moments (goal, post). Three views (Close, Normal, Wide) picked in Settings.
## Numbers: data/config/camera.json (presets) and animation.json.

var _focus: Vector3 = Vector3.ZERO
var _shake_strength: float = 0.0
var _shake_left: float = 0.0
var _shake_duration: float = 0.0
var _pitch: float
var _distance: float
var _follow_speed: float
var _look_ahead: float
var _z_follow: float
var _x_margin: float


func _ready() -> void:
	_follow_speed = _cfg("follow_speed", 4.0)
	_look_ahead = _cfg("look_ahead_seconds", 0.25)
	_x_margin = _cfg("x_limit_margin", 6.0)
	apply_preset(Settings.camera_view)


## Uses one of the views of camera.json -> presets: "close", "normal" or "wide".
func apply_preset(preset_name: String) -> void:
	var view := MatchCamera.preset(preset_name)
	fov = float(view.get("fov", 45.0))
	_pitch = deg_to_rad(float(view.get("pitch_degrees", 44.0)))
	_distance = float(view.get("distance", 17.0))
	_z_follow = float(view.get("z_follow_factor", 0.5))


## The numbers of a view; an unknown name gives the default view.
static func preset(preset_name: String) -> Dictionary:
	var presets: Dictionary = Config.get_value("camera", "presets", {})
	if presets.has(preset_name):
		return presets[preset_name]
	return presets.get(str(Config.get_value("camera", "default_preset", "normal")), {})


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


## Shakes the camera for `seconds`, fading out (look only).
func shake(strength: float, seconds: float) -> void:
	if strength >= _shake_strength * (_shake_left / maxf(0.01, _shake_duration)):
		_shake_strength = strength
		_shake_left = seconds
		_shake_duration = seconds


func _place() -> void:
	var offset := Vector3(0.0, sin(_pitch), cos(_pitch)) * _distance
	var jitter := Vector3.ZERO
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - get_physics_process_delta_time())
		var amount := _shake_strength * (_shake_left / maxf(0.01, _shake_duration))
		jitter = Vector3(randf_range(-amount, amount), randf_range(-amount, amount), 0.0)
	look_at_from_position(_focus + offset + jitter, _focus + jitter, Vector3.UP)


func _cfg(key: String, fallback: float) -> float:
	return float(Config.get_value("camera", key, fallback))
