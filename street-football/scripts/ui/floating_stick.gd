class_name FloatingStick
extends RefCounted
## Floating joystick: it appears where the thumb lands inside its zone.
## Two quick taps close together are a double tap (shoulder charge on defense); a quick swipe and
## release is a flick (skill move with the ball). Pushed to the edge, back toward the middle and to
## the edge again quickly, in about the same direction, is a double pull (knock-on with the ball).
## The ring lights up when the stick is pushed far enough to run (walk below walk_threshold).
## TouchControls feeds it fingers (with the time in seconds) and draws it.
## Sizes and tap timings are set by TouchControls from controls.json.

var zone: Rect2 = Rect2()
var radius: float = 100.0
var dead_zone: float = 0.12
var rest_position: Vector2 = Vector2.ZERO
var double_tap_seconds: float = 0.3
var tap_max_seconds: float = 0.25
var double_tap_distance: float = 150.0
var flick_max_seconds: float = 0.22
## Minimum swipe length for a flick, as a fraction of the radius.
var flick_min_fraction: float = 0.55
## Index of the finger using the stick, -1 when free.
var finger: int = -1
## Under this stick value (after the dead zone) the player walks; beyond it he runs.
var walk_threshold: float = 0.6
## Double pull: out beyond pull_out, back under pull_in, out again, all within double_pull_seconds.
var pull_out: float = 0.9
var pull_in: float = 0.6
var double_pull_seconds: float = 0.5
var double_pull_max_degrees: float = 45.0
## Ring colors: run zone, and knock-on mode (knock_on_active is set from the input).
var run_color: Color = Color(1.0, 0.82, 0.23)
var knock_on_color: Color = Color(1.0, 0.48, 0.1)
var knock_on_active: bool = false

var _base: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _down_time: float = 0.0
var _last_tap_time: float = -100.0
var _last_tap_pos: Vector2 = Vector2.ZERO
var _double_tap: bool = false
var _flick: Vector2 = Vector2.ZERO
## Double pull tracking: 0 = nothing, 1 = pushed out, 2 = back in after a push.
var _pull_stage: int = 0
var _pull_time: float = 0.0
var _pull_dir: Vector2 = Vector2.ZERO
var _double_pull: Vector2 = Vector2.ZERO


func begin(index: int, pos: Vector2, now: float) -> void:
	if now - _last_tap_time <= double_tap_seconds and pos.distance_to(_last_tap_pos) <= double_tap_distance:
		_double_tap = true
		_last_tap_time = -100.0
	finger = index
	_base = pos
	_knob = pos
	_down_time = now
	_pull_stage = 0


## Thumb moved; `now` (seconds) lets quick pulls be measured.
func drag(pos: Vector2, now: float = -1.0) -> void:
	_knob = _base + (pos - _base).limit_length(radius)
	if now >= 0.0:
		_track_pulls(now)


## Out, back in, out again within double_pull_seconds of the first push, same direction.
func _track_pulls(now: float) -> void:
	var v := value()
	var strength := v.length()
	if _pull_stage > 0 and now - _pull_time > double_pull_seconds:
		_pull_stage = 0
	match _pull_stage:
		0:
			if strength >= pull_out:
				_start_pull(now, v)
		1:
			if strength <= pull_in:
				_pull_stage = 2
		2:
			if strength >= pull_out:
				if v.normalized().dot(_pull_dir) >= cos(deg_to_rad(double_pull_max_degrees)):
					_double_pull = v.normalized()
					_pull_stage = 0
				else:
					_start_pull(now, v)


func _start_pull(now: float, v: Vector2) -> void:
	_pull_stage = 1
	_pull_time = now
	_pull_dir = v.normalized()


## Finger lifted. A short touch that barely moved counts as a tap.
func end(now: float) -> void:
	var swipe := _knob - _base
	if finger >= 0 and now - _down_time <= tap_max_seconds and swipe.length() < radius * 0.5:
		_last_tap_time = now
		_last_tap_pos = _base
	elif finger >= 0 and now - _down_time <= flick_max_seconds and swipe.length() >= radius * flick_min_fraction:
		_flick = swipe.normalized()
	finger = -1


## Finger lost without a real lift (app paused...): never counts as a tap.
func cancel() -> void:
	finger = -1
	_pull_stage = 0


## Direction of the last flick (screen axes), once; ZERO when there was none.
func consume_flick() -> Vector2:
	var flick := _flick
	_flick = Vector2.ZERO
	return flick


## Direction of the last double pull (screen axes), once; ZERO when there was none.
func consume_double_pull() -> Vector2:
	var pull := _double_pull
	_double_pull = Vector2.ZERO
	return pull


## True once after a double tap.
func consume_double_tap() -> bool:
	var tapped := _double_tap
	_double_tap = false
	return tapped


## Stick value, length 0..1, after the dead zone. Screen axes (y points down).
func value() -> Vector2:
	if finger < 0 or radius <= 0.0:
		return Vector2.ZERO
	var v := (_knob - _base) / radius
	var length := v.length()
	if length < dead_zone:
		return Vector2.ZERO
	return v / length * ((length - dead_zone) / (1.0 - dead_zone))


func render(canvas: CanvasItem) -> void:
	var active := finger >= 0
	var base := _base if active else rest_position
	var knob := _knob if active else rest_position
	var alpha := 0.6 if active else 0.3
	canvas.draw_circle(base, radius, Color(1.0, 1.0, 1.0, alpha * 0.25))
	var ring := Color(1.0, 1.0, 1.0, alpha)
	if active and knock_on_active:
		ring = knock_on_color
	elif active and value().length() >= walk_threshold:
		ring = run_color
	canvas.draw_arc(base, radius, 0.0, TAU, 48, ring, 4.0 if ring.a < 0.99 else 6.0, true)
	canvas.draw_circle(knob, radius * 0.42, Color(1.0, 1.0, 1.0, alpha + 0.2))
