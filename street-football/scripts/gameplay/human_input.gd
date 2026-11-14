class_name HumanInput
extends RefCounted
## Turns the touch controls (and the keyboard, for testing on a PC) into a PlayerIntent.
## Keyboard: WASD / arrows move, Shift sprint, Space shoot (hold), E pass.

var _touch: TouchControls
var _pass_key_was_down: bool = false


func _init(touch: TouchControls) -> void:
	_touch = touch


func read() -> PlayerIntent:
	var intent := PlayerIntent.new()
	var stick: Vector2 = _touch.get_move_vector()
	var keys := Vector2(
		_axis(KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT),
		_axis(KEY_W, KEY_UP, KEY_S, KEY_DOWN))
	var v: Vector2 = stick if stick.length() >= keys.length() else keys
	v = v.limit_length(1.0)
	# Screen right = world +x, screen down = world +z (toward the camera).
	intent.move = Vector3(v.x, 0.0, v.y)
	intent.sprint = _touch.is_held("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)
	intent.shoot_held = _touch.consume_press("shoot") or _touch.is_held("shoot") \
		or Input.is_physical_key_pressed(KEY_SPACE)
	var pass_key := Input.is_physical_key_pressed(KEY_E)
	intent.pass_pressed = _touch.consume_press("pass") or (pass_key and not _pass_key_was_down)
	_pass_key_was_down = pass_key
	return intent


func _axis(neg_a: Key, neg_b: Key, pos_a: Key, pos_b: Key) -> float:
	var neg := Input.is_physical_key_pressed(neg_a) or Input.is_physical_key_pressed(neg_b)
	var pos := Input.is_physical_key_pressed(pos_a) or Input.is_physical_key_pressed(pos_b)
	return (1.0 if pos else 0.0) - (1.0 if neg else 0.0)
