extends Control
## Phase 1 boot screen. Proves the project runs on the phone:
## touch input (tap counter), landscape layout, EN/FR translations and frame rate.

const LOCALES: Array[String] = ["en", "fr"]
const FPS_REFRESH_SECONDS := 0.5

var _tap_count := 0
var _fps_timer := 0.0

@onready var _tap_button: Button = $Center/Column/TapButton
@onready var _language_button: Button = $Center/Column/LanguageButton
@onready var _device_info: Label = $Center/Column/DeviceInfo
@onready var _fps_label: Label = $FpsLabel


func _ready() -> void:
	_tap_button.pressed.connect(_on_tap_pressed)
	_language_button.pressed.connect(_on_language_pressed)
	get_viewport().size_changed.connect(_refresh_texts)
	_refresh_texts()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_texts()


func _process(delta: float) -> void:
	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = FPS_REFRESH_SECONDS
		_fps_label.text = tr("FPS_LABEL") % int(Engine.get_frames_per_second())


func _on_tap_pressed() -> void:
	_tap_count += 1
	_refresh_texts()


func _on_language_pressed() -> void:
	var current := TranslationServer.get_locale().substr(0, 2)
	var index := LOCALES.find(current)
	TranslationServer.set_locale(LOCALES[(index + 1) % LOCALES.size()])


func _refresh_texts() -> void:
	if _tap_count > 0:
		_tap_button.text = tr("TAP_COUNT") % _tap_count
	else:
		_tap_button.text = tr("TAP_TEST")
	var screen := DisplayServer.screen_get_size()
	_device_info.text = tr("DEVICE_INFO") % [
		screen.x,
		screen.y,
		OS.get_name(),
		Engine.get_version_info().get("string", "?"),
	]
