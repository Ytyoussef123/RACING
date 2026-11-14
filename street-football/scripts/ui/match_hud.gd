class_name MatchHud
extends Control
## Match overlay: score and clock, big messages (GOAL!, OUT, FULL TIME), shot power bar,
## court name, formation button and menu button.

signal menu_pressed
signal formation_pressed

@onready var _message: Label = $Message
@onready var _court_name: Label = $CourtName
@onready var _home_score: Label = $ScoreBar/HomeScore
@onready var _away_score: Label = $ScoreBar/AwayScore
@onready var _home_chip: ColorRect = $ScoreBar/HomeChip
@onready var _away_chip: ColorRect = $ScoreBar/AwayChip
@onready var _clock: Label = $ScoreBar/Clock
@onready var _power_bar: Control = $PowerBar
@onready var _power_fill: ColorRect = $PowerBar/Fill
@onready var _menu_button: Button = $MenuButton
@onready var _formation_button: Button = $FormationButton


func _ready() -> void:
	_menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	_formation_button.pressed.connect(func() -> void: formation_pressed.emit())
	hide_message()
	_power_bar.visible = false


## Shows an already translated text in big letters.
func show_message(text: String) -> void:
	_message.text = text
	_message.visible = true


func hide_message() -> void:
	_message.visible = false


func set_court_name(key: String) -> void:
	_court_name.text = tr(key)


func set_team_colors(home: Color, away: Color) -> void:
	_home_chip.color = home
	_away_chip.color = away


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
