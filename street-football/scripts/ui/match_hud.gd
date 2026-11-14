class_name MatchHud
extends Control
## Match overlay: big messages (GOAL!, OUT), shot power bar above the player, court name, menu button.

signal menu_pressed

@onready var _message: Label = $Message
@onready var _court_name: Label = $CourtName
@onready var _power_bar: Control = $PowerBar
@onready var _power_fill: ColorRect = $PowerBar/Fill
@onready var _menu_button: Button = $MenuButton


func _ready() -> void:
	_menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	hide_message()
	_power_bar.visible = false


func show_message(key: String) -> void:
	_message.text = tr(key)
	_message.visible = true


func hide_message() -> void:
	_message.visible = false


func set_court_name(key: String) -> void:
	_court_name.text = tr(key)


## charge 0..1; screen_position is where the bar is centered (above the player's head).
func update_power(charge: float, shown: bool, screen_position: Vector2) -> void:
	_power_bar.visible = shown
	if not shown:
		return
	_power_bar.position = screen_position - _power_bar.size * 0.5
	_power_fill.size = Vector2(_power_bar.size.x * clampf(charge, 0.0, 1.0), _power_bar.size.y)
