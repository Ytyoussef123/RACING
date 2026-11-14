extends Node
## Autoload "Settings": the player's preferences (language, FPS counter, touch button size),
## saved on the device in user://settings.cfg. Adds the FPS overlay on top of every screen.

const SAVE_PATH := "user://settings.cfg"
const FPS_OVERLAY := preload("res://scenes/ui/fps_overlay.tscn")

## "" = the phone's language.
var language: String = ""
var show_fps: bool = false
## Key in ui.json -> controls_scales: "small", "normal" or "large".
var controls_size: String = "normal"

var _fps_overlay: CanvasLayer


func _ready() -> void:
	_load()
	if not language.is_empty():
		TranslationServer.set_locale(language)
	_fps_overlay = FPS_OVERLAY.instantiate()
	get_tree().root.add_child.call_deferred(_fps_overlay)
	_fps_overlay.visible = show_fps


func controls_scale() -> float:
	var scales: Dictionary = Config.get_value("ui", "controls_scales", {})
	return float(scales.get(controls_size, 1.0))


func set_language(locale: String) -> void:
	language = locale
	TranslationServer.set_locale(locale)
	save()


func set_show_fps(on: bool) -> void:
	show_fps = on
	_fps_overlay.visible = on
	save()


func set_controls_size(size_key: String) -> void:
	controls_size = size_key
	save()


func save() -> void:
	var file := ConfigFile.new()
	file.set_value("display", "language", language)
	file.set_value("display", "show_fps", show_fps)
	file.set_value("controls", "size", controls_size)
	file.save(SAVE_PATH)


func _load() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return
	language = str(file.get_value("display", "language", ""))
	show_fps = bool(file.get_value("display", "show_fps", false))
	controls_size = str(file.get_value("controls", "size", "normal"))
