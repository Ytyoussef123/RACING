class_name ActionButton
extends RefCounted
## A round on-screen action button (shoot, pass, sprint). TouchControls feeds it fingers and draws it.

var center: Vector2 = Vector2.ZERO
var radius: float = 80.0
var color: Color = Color.WHITE
var label_key: String = ""
## Index of the finger holding the button, -1 when released.
var finger: int = -1

var _presses: int = 0
## Where the finger went down and where it is now; how far it had slid when it was lifted.
var _press_pos: Vector2 = Vector2.ZERO
var _finger_pos: Vector2 = Vector2.ZERO
var _last_slide: Vector2 = Vector2.ZERO


func contains(pos: Vector2, hit_scale: float) -> bool:
	return pos.distance_to(center) <= radius * hit_scale


func press(index: int, pos: Vector2 = Vector2.ZERO) -> void:
	finger = index
	_presses += 1
	_press_pos = pos
	_finger_pos = pos
	_last_slide = Vector2.ZERO


func drag(pos: Vector2) -> void:
	_finger_pos = pos


func release() -> void:
	if finger >= 0:
		_last_slide = _finger_pos - _press_pos
	finger = -1


## How far the finger slid since the press (screen pixels): while held, or at its release (until
## the next press).
func slide() -> Vector2:
	return _finger_pos - _press_pos if finger >= 0 else _last_slide


func is_held() -> bool:
	return finger >= 0


## True if the button was pressed since the last call, even for a tap shorter than a frame.
func consume_press() -> bool:
	var pressed := _presses > 0
	_presses = 0
	return pressed


func render(canvas: CanvasItem, font: Font, text: String, font_size: int) -> void:
	var held := is_held()
	canvas.draw_circle(center, radius, Color(color, 0.85 if held else 0.45))
	canvas.draw_arc(center, radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.8), 3.0, true)
	var text_pos := Vector2(center.x - radius, center.y + font_size * 0.35)
	canvas.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, Color.WHITE)
