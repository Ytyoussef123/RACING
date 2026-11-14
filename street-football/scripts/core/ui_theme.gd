extends Node
## Autoload "UiTheme": builds the street-style theme from data/config/ui.json and applies it to
## every screen. Type variations: "AccentButton" (filled orange), "ChipButton" (toggle chip),
## "CardPanel" (rounded card).

var theme: Theme


func _ready() -> void:
	theme = _build()
	get_tree().root.theme = theme


func color(key: String) -> Color:
	var colors: Dictionary = Config.get_value("ui", "colors", {})
	return Color.html(str(colors.get(key, "#ff00ff")))


func font_size(key: String) -> int:
	var sizes: Dictionary = Config.get_value("ui", "font_sizes", {})
	return int(sizes.get(key, 32))


func _build() -> Theme:
	var t := Theme.new()
	t.default_font_size = font_size("body")
	var radius := int(Config.get_value("ui", "corner_radius", 14))
	# Buttons: dark slabs with an orange stripe on the left, like street tape.
	t.set_stylebox("normal", "Button", _box(color("button"), color("accent"), radius, 6))
	t.set_stylebox("hover", "Button", _box(color("button_hover"), color("accent_2"), radius, 6))
	t.set_stylebox("pressed", "Button", _box(color("accent"), color("accent_2"), radius, 6))
	t.set_stylebox("focus", "Button", _outline(color("accent_2"), radius))
	t.set_stylebox("disabled", "Button", _box(color("panel"), color("panel_border"), radius, 6))
	t.set_color("font_color", "Button", color("text"))
	t.set_color("font_hover_color", "Button", color("text"))
	t.set_color("font_pressed_color", "Button", color("background"))
	t.set_color("font_focus_color", "Button", color("text"))
	t.set_color("font_disabled_color", "Button", color("text_dim"))
	t.set_font_size("font_size", "Button", font_size("button"))
	# Accent button: the main action on a screen.
	t.set_type_variation("AccentButton", "Button")
	t.set_stylebox("normal", "AccentButton", _box(color("accent"), color("accent_2"), radius, 6))
	t.set_stylebox("hover", "AccentButton", _box(color("accent").lightened(0.15), color("accent_2"), radius, 6))
	t.set_stylebox("pressed", "AccentButton", _box(color("accent_2"), color("accent"), radius, 6))
	t.set_color("font_color", "AccentButton", color("background"))
	t.set_color("font_hover_color", "AccentButton", color("background"))
	# Chip: a choice among several (formation, difficulty...). Pressed = selected.
	t.set_type_variation("ChipButton", "Button")
	t.set_stylebox("normal", "ChipButton", _box(color("button"), color("panel_border"), radius, 0))
	t.set_stylebox("hover", "ChipButton", _box(color("button_hover"), color("panel_border"), radius, 0))
	t.set_stylebox("pressed", "ChipButton", _box(color("accent_3"), color("accent_3"), radius, 0))
	t.set_stylebox("hover_pressed", "ChipButton", _box(color("accent_3").lightened(0.1), color("accent_3"), radius, 0))
	t.set_color("font_pressed_color", "ChipButton", color("background"))
	t.set_color("font_hover_pressed_color", "ChipButton", color("background"))
	t.set_font_size("font_size", "ChipButton", font_size("body"))
	# Cards and labels.
	t.set_type_variation("CardPanel", "PanelContainer")
	var card := _box(color("panel"), color("panel_border"), radius, 0)
	card.set_border_width_all(2)
	card.set_content_margin_all(28)
	t.set_stylebox("panel", "CardPanel", card)
	t.set_color("font_color", "Label", color("text"))
	t.set_color("font_outline_color", "Label", Color.BLACK)
	return t


## Flat box with a colored stripe on its left side (stripe 0 = plain border).
func _box(fill: Color, stripe: Color, radius: int, stripe_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.border_color = stripe
	box.border_width_left = stripe_width
	box.content_margin_left = 28.0 + stripe_width
	box.content_margin_right = 28.0
	box.content_margin_top = 14.0
	box.content_margin_bottom = 14.0
	return box


func _outline(outline: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.set_corner_radius_all(radius)
	box.border_color = outline
	box.set_border_width_all(4)
	return box
