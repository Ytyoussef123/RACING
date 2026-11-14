class_name StatBar
extends Control
## One attribute as a bar 0..99, colored by level (thresholds in ui.json -> stat_bar_colors).

var value: float = 0.0:
	set(v):
		value = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(160.0, 16.0)
	size_flags_vertical = SIZE_SHRINK_CENTER
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, UiTheme.color("background"))
	var fill := Rect2(Vector2.ZERO, Vector2(size.x * clampf(value / 99.0, 0.0, 1.0), size.y))
	draw_rect(fill, level_color(value))


static func level_color(v: float) -> Color:
	var levels: Array = Config.get_value("ui", "stat_bar_colors", [])
	for level in levels:
		var pair: Array = level
		if v >= float(pair[0]):
			return Color.html(str(pair[1]))
	return Color.WHITE
