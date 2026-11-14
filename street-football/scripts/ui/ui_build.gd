class_name UiBuild
extends RefCounted
## Small helpers to build menu layouts in code with the street theme (UiTheme autoload).
## Texts that are translation keys are translated automatically by Godot.


static func label(text: String, size_key: String = "body", color_key: String = "text",
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", UiTheme.font_size(size_key))
	l.add_theme_color_override("font_color", UiTheme.color(color_key))
	return l


static func button(text: String, variation: String = "", min_width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(min_width, float(Config.get_value("ui", "button_min_height", 104)))
	b.focus_mode = Control.FOCUS_NONE
	return b


## A toggle chip; chips in the same group behave like radio buttons.
static func chip(text: String, group: ButtonGroup, min_width: float = 0.0) -> Button:
	var b := button(text, "ChipButton", min_width)
	b.toggle_mode = true
	b.button_group = group
	return b


static func vbox(separation: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func hbox(separation: int) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "CardPanel"
	return panel


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func color_chip(color: Color, size: Vector2) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.custom_minimum_size = size
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect


## "GK" -> translated short position name.
static func position_name(position_id: String) -> String:
	return TranslationServer.translate("POS_" + position_id)
