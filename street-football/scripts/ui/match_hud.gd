class_name MatchHud
extends Control
## Match overlay: team names, score and clock, big messages (GOAL!, OUT, FULL TIME), shot power
## bar, name tag with stamina above the human's player, court name, formation and pause buttons.

signal pause_pressed
signal formation_pressed

@onready var _message: Label = $Message
@onready var _court_name: Label = $CourtName
@onready var _home_score: Label = $ScoreBar/HomeScore
@onready var _away_score: Label = $ScoreBar/AwayScore
@onready var _home_chip: ColorRect = $ScoreBar/HomeChip
@onready var _away_chip: ColorRect = $ScoreBar/AwayChip
@onready var _clock: Label = $ScoreBar/Clock
@onready var _home_name: Label = $ScoreBar/HomeName
@onready var _away_name: Label = $ScoreBar/AwayName
@onready var _tag: Control = $PlayerTag
@onready var _tag_name: Label = $PlayerTag/Name
@onready var _energy_back: ColorRect = $PlayerTag/Energy/Back
@onready var _energy_fill: ColorRect = $PlayerTag/Energy/Back/Fill
@onready var _power_bar: Control = $PowerBar
@onready var _power_fill: ColorRect = $PowerBar/Fill
@onready var _menu_button: Button = $MenuButton
@onready var _formation_button: Button = $FormationButton


func _ready() -> void:
	_menu_button.pressed.connect(func() -> void: pause_pressed.emit())
	_formation_button.pressed.connect(func() -> void: formation_pressed.emit())
	hide_message()
	_power_bar.visible = false


## Shows an already translated text in big letters.
func show_message(text: String) -> void:
	_message.text = text
	_message.visible = true
	# Pop: the text starts big and settles (look only).
	_message.pivot_offset = _message.size * 0.5
	_message.scale = Vector2.ONE * float(Config.get_value("animation", "message_pop_scale", 1.6))
	var tween := create_tween()
	tween.tween_property(_message, "scale", Vector2.ONE, float(Config.get_value("animation", "message_pop_seconds", 0.35))) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Short text near a player that fades out (skill move names).
func show_callout(text: String, screen_position: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.1))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(label)
	label.position = screen_position - Vector2(label.size.x * 0.5, 0.0)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 60.0, 0.9)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tween.tween_callback(label.queue_free)


func hide_message() -> void:
	_message.visible = false


func set_court_name(key: String) -> void:
	_court_name.text = tr(key)


func set_team_colors(home: Color, away: Color) -> void:
	_home_chip.color = home
	_away_chip.color = away


func set_team_names(home: String, away: String) -> void:
	_home_name.text = home
	_away_name.text = away


func set_score(home: int, away: int) -> void:
	_home_score.text = str(home)
	_away_score.text = str(away)


func set_clock(text: String) -> void:
	_clock.text = text


func set_formation_name(formation_name: String) -> void:
	_formation_button.text = formation_name


## charge 0..1; screen_position is where the bar is centered (above the player's head).
func update_power(charge: float, shown: bool, screen_position: Vector2) -> void:
	_power_bar.visible = shown
	if not shown:
		return
	_power_bar.position = screen_position - _power_bar.size * 0.5
	_power_fill.size = Vector2(_power_bar.size.x * clampf(charge, 0.0, 1.0), _power_bar.size.y)


## Name tag above the human's player; energy 0..1 drawn as a bar (green, then orange, then red).
func update_player_tag(text: String, energy: float, shown: bool, screen_position: Vector2) -> void:
	_tag.visible = shown and not text.is_empty()
	if not _tag.visible:
		return
	_tag_name.text = text
	_tag.position = screen_position - Vector2(_tag.size.x * 0.5, _tag.size.y)
	var e := clampf(energy, 0.0, 1.0)
	_energy_fill.size = Vector2(_energy_back.size.x * e, _energy_back.size.y)
	_energy_fill.color = Color(0.4, 1.0, 0.55) if e > 0.5 else (Color(1.0, 0.7, 0.2) if e > 0.25 else Color(1.0, 0.3, 0.25))
