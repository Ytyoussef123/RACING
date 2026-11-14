extends Control
## Start screen (temporary until the Phase 5 menus): pick formation, difficulty and court, then play.
## Also switches language and shows the frame rate and device info for phone tests.

const LOCALES: Array[String] = ["en", "fr"]
const FPS_REFRESH_SECONDS := 0.5
const MATCH_SCENE := "res://scenes/match/match.tscn"
const DIFFICULTY_KEYS := {"easy": "DIFF_EASY", "normal": "DIFF_NORMAL", "hard": "DIFF_HARD"}

var _fps_timer := 0.0

@onready var _play_cage: Button = $Center/Column/PlayCageButton
@onready var _play_open: Button = $Center/Column/PlayOpenButton
@onready var _formation_button: Button = $Center/Column/SetupRow/FormationButton
@onready var _difficulty_button: Button = $Center/Column/SetupRow/DifficultyButton
@onready var _language_button: Button = $Center/Column/LanguageButton
@onready var _device_info: Label = $Center/Column/DeviceInfo
@onready var _fps_label: Label = $FpsLabel


func _ready() -> void:
	MatchSetup.formation_id = MatchSetup.get_formation_id()
	MatchSetup.difficulty = MatchSetup.get_difficulty()
	_play_cage.pressed.connect(_start_match.bind("cage_concrete"))
	_play_open.pressed.connect(_start_match.bind("open_lot"))
	_formation_button.pressed.connect(_on_formation_pressed)
	_difficulty_button.pressed.connect(_on_difficulty_pressed)
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


func _start_match(court_id: String) -> void:
	MatchSetup.court_id = court_id
	get_tree().change_scene_to_file(MATCH_SCENE)


func _on_formation_pressed() -> void:
	MatchSetup.formation_id = FormationData.next_id(MatchSetup.formation_id)
	_refresh_texts()


func _on_difficulty_pressed() -> void:
	var ids: Array = Config.get_value("match", "difficulties", ["easy", "normal", "hard"])
	var index := ids.find(MatchSetup.difficulty)
	MatchSetup.difficulty = str(ids[(index + 1) % ids.size()])
	_refresh_texts()


func _on_language_pressed() -> void:
	var current := TranslationServer.get_locale().substr(0, 2)
	var index := LOCALES.find(current)
	TranslationServer.set_locale(LOCALES[(index + 1) % LOCALES.size()])


func _refresh_texts() -> void:
	_formation_button.text = tr("FORMATION_LABEL") % MatchSetup.formation_id
	var diff_key := str(DIFFICULTY_KEYS.get(MatchSetup.difficulty, "DIFF_NORMAL"))
	_difficulty_button.text = tr("DIFFICULTY_LABEL") % tr(diff_key)
	var screen := DisplayServer.screen_get_size()
	_device_info.text = tr("DEVICE_INFO") % [
		screen.x,
		screen.y,
		OS.get_name(),
		Engine.get_version_info().get("string", "?"),
	]
