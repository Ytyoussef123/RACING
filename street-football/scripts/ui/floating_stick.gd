class_name FloatingStick
extends RefCounted
## Floating joystick: it appears where the thumb lands inside its zone.
## Two quick taps close together are a double tap (shoulder charge on defense).
## TouchControls feeds it fingers (with the time in seconds) and draws it.
## Sizes and tap timings are set by TouchControls from controls.json.

var zone: Rect2 = Rect2()
var radius: float = 100.0
var dead_zone: float = 0.12
var rest_position: Vector2 = Vector2.ZERO
var double_tap_seconds: float = 0.3
var tap_max_seconds: float = 0.25
var double_tap_distance: float = 150.0
## Index of the finger using the stick, -1 when free.
var finger: int = -1

var _base: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _down_time: float = 0.0
var _last_tap_time: float = -100.0
var _last_tap_pos: Vector2 = Vector2.ZERO
var _double_tap: bool = false


func begin(index: int, pos: Vector2, now: float) -> void:
	if now - _last_tap_time <= double_tap_seconds and pos.distance_to(_last_tap_pos) <= double_tap_distance:
		_double_tap = true
		_last_tap_time = -100.0
	finger = index
	_base = pos
	_knob = pos
	_down_time = now


func drag(pos: Vector2) -> void:
	_knob = _base + (pos - _base).limit_length(radius)


## Finger lifted. A short touch that barely moved counts as a tap.
func end(now: float) -> void:
	if finger >= 0 and now - _down_time <= tap_max_seconds and _knob.distance_to(_base) < radius * 0.5:
		_last_tap_time = now
		_last_tap_pos = _base
	finger = -1


## Finger lost without a real lift (app paused...): never counts as a tap.
func cancel() -> void:
	finger = -1


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
	canvas.draw_arc(base, radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, alpha), 4.0, true)
	canvas.draw_circle(knob, radius * 0.42, Color(1.0, 1.0, 1.0, alpha + 0.2))
