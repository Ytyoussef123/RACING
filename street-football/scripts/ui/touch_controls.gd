class_name TouchControls
extends Control
## On-screen controls: floating joystick on the left, action buttons on the right.
## Handles every finger itself (multi-touch) and draws everything in one pass.
## Layout numbers: data/config/controls.json.

const BUTTON_IDS: Array[String] = ["shoot", "pass", "sprint", "switch"]
const BUTTON_LABELS := {"shoot": "BTN_SHOOT", "pass": "BTN_PASS", "sprint": "BTN_SPRINT", "switch": "BTN_SWITCH"}
const BUTTON_COLORS := {
	"shoot": Color(1.0, 0.36, 0.1),
	"pass": Color(0.13, 0.77, 0.85),
	"sprint": Color(1.0, 0.84, 0.1),
	"switch": Color(0.55, 0.55, 0.6),
}

var _joystick := FloatingStick.new()
var _buttons: Dictionary = {}
var _hit_scale: float = 1.25


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	for id in BUTTON_IDS:
		var button := ActionButton.new()
		button.label_key = BUTTON_LABELS[id]
		button.color = BUTTON_COLORS[id]
		_buttons[id] = button
	resized.connect(_layout)
	_layout()


func get_move_vector() -> Vector2:
	return _joystick.value()


func is_held(id: String) -> bool:
	var button: ActionButton = _buttons.get(id)
	return button != null and button.is_held()


func consume_press(id: String) -> bool:
	var button: ActionButton = _buttons.get(id)
	return button != null and button.consume_press()


## Changes a button's text (a translation key), e.g. PASS becomes TACKLE on defense.
func set_button_label(id: String, label_key: String) -> void:
	var button: ActionButton = _buttons.get(id)
	if button != null:
		button.label_key = label_key


func release_all() -> void:
	_joystick.end()
	for id in BUTTON_IDS:
		(_buttons[id] as ActionButton).release()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		release_all()


func _process(_delta: float) -> void:
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_finger_down(touch.index, touch.position)
		else:
			_finger_up(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _joystick.finger:
			_joystick.drag(drag.position)


func _finger_down(index: int, pos: Vector2) -> void:
	if _joystick.finger < 0 and _joystick.zone.has_point(pos):
		_joystick.begin(index, pos)
		return
	for id in BUTTON_IDS:
		var button: ActionButton = _buttons[id]
		if not button.is_held() and button.contains(pos, _hit_scale):
			button.press(index)
			return


func _finger_up(index: int) -> void:
	if index == _joystick.finger:
		_joystick.end()
	for id in BUTTON_IDS:
		var button: ActionButton = _buttons[id]
		if button.finger == index:
			button.release()


func _layout() -> void:
	var s := size
	var short_side := minf(s.x, s.y)
	var zone_top := _num("joystick_zone_top", 0.18)
	_joystick.zone = Rect2(0.0, s.y * zone_top, s.x * _num("joystick_zone_width", 0.45), s.y * (1.0 - zone_top))
	_joystick.radius = short_side * _num("joystick_radius", 0.13)
	_joystick.dead_zone = _num("joystick_dead_zone", 0.12)
	_joystick.rest_position = _screen_point("joystick_rest_position", Vector2(0.15, 0.72), s)
	_hit_scale = _num("button_hit_scale", 1.25)
	for id in BUTTON_IDS:
		var button: ActionButton = _buttons[id]
		button.center = _screen_point(id + "_position", Vector2(0.85, 0.75), s)
		button.radius = short_side * _num(id + "_radius", 0.09)


func _draw() -> void:
	_joystick.render(self)
	var font := get_theme_default_font()
	for id in BUTTON_IDS:
		var button: ActionButton = _buttons[id]
		var font_size := int(button.radius * 0.38)
		button.render(self, font, tr(button.label_key), font_size)


func _num(key: String, fallback: float) -> float:
	return float(Config.get_value("controls", key, fallback))


func _screen_point(key: String, fallback: Vector2, screen: Vector2) -> Vector2:
	var value: Variant = Config.get_value("controls", key, [fallback.x, fallback.y])
	if value is Array and (value as Array).size() >= 2:
		var pair: Array = value
		return Vector2(float(pair[0]) * screen.x, float(pair[1]) * screen.y)
	return fallback * screen
