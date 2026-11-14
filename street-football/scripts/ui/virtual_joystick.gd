class_name VirtualJoystick
extends RefCounted
## Floating joystick: it appears where the thumb lands inside its zone.
## TouchControls feeds it fingers and draws it. Sizes are set by TouchControls from controls.json.

var zone: Rect2 = Rect2()
var radius: float = 100.0
var dead_zone: float = 0.12
var rest_position: Vector2 = Vector2.ZERO
## Index of the finger using the stick, -1 when free.
var finger: int = -1

var _base: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO


func begin(index: int, pos: Vector2) -> void:
	finger = index
	_base = pos
	_knob = pos


func drag(pos: Vector2) -> void:
	_knob = _base + (pos - _base).limit_length(radius)


func end() -> void:
	finger = -1


## Stick value, length 0..1, after the dead zone. Screen axes (y points down).
func value() -> Vector2:
	if finger < 0 or radius <= 0.0:
		return Vector2.ZERO
	var v := (_knob - _base) / radius
	var length := v.length()
	if length < dead_zone:
		return Vector2.ZERO
	return v / length * ((length - dead_zone) / (1.0 - dead_zone))


func draw(canvas: CanvasItem) -> void:
	var active := finger >= 0
	var base := _base if active else rest_position
	var knob := _knob if active else rest_position
	var alpha := 0.6 if active else 0.3
	canvas.draw_circle(base, radius, Color(1.0, 1.0, 1.0, alpha * 0.25))
	canvas.draw_arc(base, radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, alpha), 4.0, true)
	canvas.draw_circle(knob, radius * 0.42, Color(1.0, 1.0, 1.0, alpha + 0.2))
