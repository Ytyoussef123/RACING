class_name ScreenBackground
extends Control
## Street-style background for menus: dark asphalt with a few diagonal "tape" stripes in the
## accent colors (drawn, no image). Colors from data/config/ui.json.


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), UiTheme.color("background"))
	draw_rect(Rect2(0.0, s.y * 0.72, s.x, s.y * 0.28), UiTheme.color("background_2"))
	_stripe(Vector2(s.x * 0.62, 0.0), s.y * 0.11, UiTheme.color("accent"), 0.9, s)
	_stripe(Vector2(s.x * 0.70, 0.0), s.y * 0.035, UiTheme.color("accent_2"), 0.85, s)
	_stripe(Vector2(s.x * 0.86, 0.0), s.y * 0.05, UiTheme.color("accent_3"), 0.35, s)


## A slanted band from the top edge down to the bottom edge.
func _stripe(top_left: Vector2, width: float, color: Color, alpha: float, s: Vector2) -> void:
	var slant := s.y * 0.45
	var points := PackedVector2Array([
		top_left,
		top_left + Vector2(width, 0.0),
		Vector2(top_left.x + width - slant, s.y),
		Vector2(top_left.x - slant, s.y),
	])
	draw_colored_polygon(points, Color(color, alpha * 0.22))
