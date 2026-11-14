extends MenuScreen
## Main menu: quick match, my crew, settings. The Android back button quits the app here.

const VERSION_TEXT := "v0.5"


func _ready() -> void:
	build_frame("")
	title_label.visible = false
	var hero := UiBuild.vbox(4)
	hero.add_child(UiBuild.label("TITLE", "title", "text"))
	hero.add_child(UiBuild.label("MENU_TAGLINE", "body", "accent_2"))
	content.add_child(hero)
	var buttons := UiBuild.vbox(18)
	buttons.size_flags_horizontal = SIZE_SHRINK_BEGIN
	buttons.size_flags_vertical = SIZE_EXPAND_FILL
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu_button(buttons, "MENU_QUICK_MATCH", "team_select", true)
	_menu_button(buttons, "MENU_MY_CREW", "squad", false)
	_menu_button(buttons, "MENU_SETTINGS", "settings", false)
	content.add_child(buttons)
	footer.alignment = BoxContainer.ALIGNMENT_BEGIN
	var info := UiBuild.label(_device_info(), "small", "text_dim")
	info.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	footer.add_child(info)


func go_back() -> void:
	get_tree().quit()


func _menu_button(parent: Container, text_key: String, screen_id: String, accent: bool) -> void:
	var b := UiBuild.button(text_key, "AccentButton" if accent else "", 680.0)
	b.pressed.connect(func() -> void: Screens.go(screen_id))
	parent.add_child(b)


func _device_info() -> String:
	var screen := DisplayServer.screen_get_size()
	return "%s  ·  %s" % [VERSION_TEXT, tr("DEVICE_INFO") % [screen.x, screen.y, OS.get_name(),
		Engine.get_version_info().get("string", "?")]]
