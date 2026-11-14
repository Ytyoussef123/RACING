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


func contains(pos: Vector2, hit_scale: float) -> bool:
	return pos.distance_to(center) <= radius * hit_scale


func press(index: int) -> void:
	finger = index
	_presses += 1


func release() -> void:
	finger = -1


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
