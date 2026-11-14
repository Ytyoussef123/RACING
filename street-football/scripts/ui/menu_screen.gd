class_name MenuScreen
extends Control
## Base for menu screens: street background, a title, a content area and a footer bar.
## The Android back button calls go_back().

var content: VBoxContainer
var footer: HBoxContainer
var title_label: Label


func build_frame(title_key: String) -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(ScreenBackground.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var mx := int(Config.get_value("ui", "screen_margin_x", 72))
	var my := int(Config.get_value("ui", "screen_margin_y", 40))
	margin.add_theme_constant_override("margin_left", mx)
	margin.add_theme_constant_override("margin_right", mx)
	margin.add_theme_constant_override("margin_top", my)
	margin.add_theme_constant_override("margin_bottom", my)
	add_child(margin)
	var column := UiBuild.vbox(22)
	margin.add_child(column)
	title_label = UiBuild.label(title_key, "heading", "accent_2")
	column.add_child(title_label)
	content = UiBuild.vbox(20)
	content.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(content)
	footer = UiBuild.hbox(24)
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)


func add_footer_button(text_key: String, on_press: Callable, accent: bool = false) -> Button:
	var b := UiBuild.button(text_key, "AccentButton" if accent else "", 300.0)
	b.pressed.connect(on_press)
	footer.add_child(b)
	return b


## Back button / Android back. Override in screens.
func go_back() -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()
