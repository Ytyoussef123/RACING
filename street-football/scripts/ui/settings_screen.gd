extends MenuScreen
## Settings: language, FPS counter, size of the touch buttons. Saved on the device (Settings).

const LANGUAGES := [["en", "English"], ["fr", "Français"]]
const SIZES := [["small", "SIZE_SMALL"], ["normal", "SIZE_NORMAL"], ["large", "SIZE_LARGE"]]


func _ready() -> void:
	build_frame("MENU_SETTINGS")
	var lang_row := _row("SETTING_LANGUAGE")
	var lang_group := ButtonGroup.new()
	var current := TranslationServer.get_locale().substr(0, 2)
	for lang in LANGUAGES:
		var code := str(lang[0])
		var chip := UiBuild.chip(str(lang[1]), lang_group, 300.0)
		chip.name = "Lang_" + code
		chip.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		chip.button_pressed = code == current
		chip.pressed.connect(func() -> void: Settings.set_language(code))
		lang_row.add_child(chip)
	var fps_row := _row("SETTING_SHOW_FPS")
	var fps_group := ButtonGroup.new()
	for option in [[true, "ON"], [false, "OFF"]]:
		var on := bool(option[0])
		var chip := UiBuild.chip(str(option[1]), fps_group, 220.0)
		chip.name = "Fps_on" if on else "Fps_off"
		chip.button_pressed = on == Settings.show_fps
		chip.pressed.connect(func() -> void: Settings.set_show_fps(on))
		fps_row.add_child(chip)
	_on_off_row("SETTING_SOUND", "Sound", Settings.sound_on, func(on: bool) -> void: Settings.set_sound_on(on))
	_on_off_row("SETTING_MUSIC", "Music", Settings.music_on, func(on: bool) -> void: Settings.set_music_on(on))
	var size_row := _row("SETTING_CONTROLS_SIZE")
	var size_group := ButtonGroup.new()
	for size_option in SIZES:
		var key := str(size_option[0])
		var chip := UiBuild.chip(str(size_option[1]), size_group, 260.0)
		chip.name = "Size_" + key
		chip.button_pressed = key == Settings.controls_size
		chip.pressed.connect(func() -> void: Settings.set_controls_size(key))
		size_row.add_child(chip)
	add_footer_button("BTN_BACK", go_back)


func go_back() -> void:
	Screens.go("main_menu")


func _on_off_row(title_key: String, prefix: String, current: bool, apply: Callable) -> void:
	var row := _row(title_key)
	var group := ButtonGroup.new()
	for option in [[true, "ON"], [false, "OFF"]]:
		var on := bool(option[0])
		var chip := UiBuild.chip(str(option[1]), group, 220.0)
		chip.name = prefix + ("_on" if on else "_off")
		chip.button_pressed = on == current
		chip.pressed.connect(func() -> void: apply.call(on))
		row.add_child(chip)


func _row(title_key: String) -> HBoxContainer:
	var row := UiBuild.hbox(20)
	var title := UiBuild.label(title_key, "body", "accent_3")
	title.custom_minimum_size = Vector2(520.0, 0.0)
	row.add_child(title)
	content.add_child(row)
	return row
