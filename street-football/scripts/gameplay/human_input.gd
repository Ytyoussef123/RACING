class_name HumanInput
extends RefCounted
## Turns the touch controls (and the keyboard, for testing on a PC) into a PlayerIntent.
## The four buttons change meaning with possession, like eFootball:
##   with the ball:     THROUGH (tap)    SHOOT (hold)   PASS (tap)     SPRINT (hold)
##   without the ball:  MATCH-UP (hold)  TACKLE (tap)   SWITCH (tap)   PRESS (hold)
## Double-tap the joystick without the ball: shoulder charge. Flick it with the ball: skill move.
## Speed steps: joystick pushed softly = walk, fully = run, SPRINT = sprint; pulled hard twice with
## the ball = knock-on mode (until the stick is softened or released, or a pass / shot / skill).
## Without the ball, PRESS with the joystick moved sprints where it points; PRESS alone presses.
## Keyboard, same order: R, Space, E, Shift; WASD / arrows move; Q always switches; F shoulder;
## C skill move in the direction held; Ctrl walk; K knock-on.

var _touch: TouchControls
var _keys_down: Dictionary = {}
## Knock-on mode is on (started by a double pull).
var _knock_on: bool = false
## Set when the layout turns to attack while SHOOT/TACKLE is still held: that finger must be
## lifted before it can start a shot (no accidental shot after winning the ball).
var _shoot_locked: bool = false
var _was_attacking: bool = true


func _init(touch: TouchControls) -> void:
	_touch = touch


## clearing: our side has the ball and our player is in our own half (SHOOT becomes CLEAR).
func read(attacking: bool, clearing: bool = false) -> PlayerIntent:
	var intent := PlayerIntent.new()
	# Speed steps: the move keeps a full length; walk / run / sprint / knock-on set the speed.
	var stick := _move_vector()
	var strength := stick.length()
	if strength > 0.0:
		intent.move = stick / strength
		intent.walk = strength < float(Config.get_value("controls", "walk_threshold", 0.6)) \
			or Input.is_physical_key_pressed(KEY_CTRL)
	var double_pull := _touch.consume_stick_double_pull()
	# Key edges first, then the touch buttons (taps are always consumed so none fires later).
	var space_tap := _key_tapped(KEY_SPACE)
	var e_tap := _key_tapped(KEY_E)
	var r_tap := _key_tapped(KEY_R)
	var q_tap := _key_tapped(KEY_Q)
	var f_tap := _key_tapped(KEY_F)
	var double_tap := _touch.consume_stick_double_tap()
	var flick := _touch.consume_stick_flick()
	var c_tap := _key_tapped(KEY_C)
	var shoot_tap := _touch.consume_press("shoot") or space_tap
	var pass_tap := _touch.consume_press("pass") or e_tap
	var through_tap := _touch.consume_press("through") or r_tap
	_touch.consume_press("sprint")
	var shoot_hold := _touch.is_held("shoot") or Input.is_physical_key_pressed(KEY_SPACE)
	var through_hold := _touch.is_held("through") or Input.is_physical_key_pressed(KEY_R)
	var sprint_hold := _touch.is_held("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)
	if attacking and not _was_attacking and shoot_hold:
		_shoot_locked = true
	# A SHOOT held for a clearance must be lifted before it can start a shot.
	if clearing and shoot_hold:
		_shoot_locked = true
	if not shoot_hold:
		_shoot_locked = false
	_was_attacking = attacking
	intent.switch_pressed = q_tap
	if attacking:
		if clearing:
			intent.clear_pressed = shoot_tap
		else:
			intent.shoot_held = (shoot_hold or shoot_tap) and not _shoot_locked
		intent.pass_pressed = pass_tap
		intent.through_pressed = through_tap
		intent.sprint = sprint_hold
		if flick != Vector2.ZERO:
			intent.skill = Vector3(flick.x, 0.0, flick.y)
		elif c_tap:
			intent.skill = intent.move if intent.move.length() > 0.3 else Vector3.RIGHT
		if double_pull != Vector2.ZERO:
			_knock_on = true
		if strength == 0.0 or intent.walk or pass_tap or through_tap or intent.shoot_held \
				or intent.skill != Vector3.ZERO:
			_knock_on = false
		intent.knock_on = _knock_on or (Input.is_physical_key_pressed(KEY_K) and strength > 0.0)
	else:
		_knock_on = false
		intent.tackle_pressed = shoot_tap
		intent.switch_pressed = intent.switch_pressed or pass_tap
		intent.press_held = sprint_hold
		# PRESS with the joystick moved: sprint where it points (alone: the automatic press).
		intent.sprint = sprint_hold and strength > 0.0
		intent.match_up_held = through_hold
		intent.shoulder_pressed = double_tap or f_tap
	_touch.set_knock_on_active(intent.knock_on)
	return intent


func _move_vector() -> Vector3:
	var stick: Vector2 = _touch.get_move_vector()
	var keys := Vector2(
		_axis(KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT),
		_axis(KEY_W, KEY_UP, KEY_S, KEY_DOWN))
	var v: Vector2 = stick if stick.length() >= keys.length() else keys
	v = v.limit_length(1.0)
	# Screen right = world +x, screen down = world +z (toward the camera).
	return Vector3(v.x, 0.0, v.y)


func _key_tapped(key: Key) -> bool:
	var down := Input.is_physical_key_pressed(key)
	var was: bool = _keys_down.get(key, false)
	_keys_down[key] = down
	return down and not was


func _axis(neg_a: Key, neg_b: Key, pos_a: Key, pos_b: Key) -> float:
	var neg := Input.is_physical_key_pressed(neg_a) or Input.is_physical_key_pressed(neg_b)
	var pos := Input.is_physical_key_pressed(pos_a) or Input.is_physical_key_pressed(pos_b)
	return (1.0 if pos else 0.0) - (1.0 if neg else 0.0)
