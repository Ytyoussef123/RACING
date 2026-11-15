class_name HumanInput
extends RefCounted
## Turns the touch controls (and the keyboard, for testing on a PC) into a PlayerIntent.
## The four buttons change meaning with possession, like eFootball:
##   with the ball:     THROUGH (tap/hold)  SHOOT (hold)   PASS (tap/hold)  SPRINT (hold)
##   without the ball:  MATCH-UP (hold)     TACKLE (tap)   SWITCH (tap)     PRESS (hold)
## PASS, THROUGH and CLEAR (SHOOT in our own half) kick on release: a tap with the automatic
## power, a longer hold with the power bar's (BallHandling). PASS or THROUGH with the finger slid
## up on the button: the ball goes in the air (lofted pass, lofted through ball). SHOOT with the
## finger slid: up = chip, left or right = curled shot toward the far post, down = low shot.
## Double-tap the joystick without the ball: shoulder charge. Flick it with the ball: skill move.
## Speed steps: joystick pushed softly = walk, fully = run, SPRINT = sprint; pulled hard twice with
## the ball = knock-on mode (until the stick is softened or released, or a pass / shot / skill).
## Without the ball, PRESS with the joystick moved sprints where it points; PRESS alone presses.
## Keyboard, same order: R, Space, E, Shift; WASD / arrows move; Q always switches; F shoulder;
## C skill move in the direction held; Ctrl walk; K knock-on; T lofted pass, G lofted through ball;
## V chip, B curled shot, N low shot (hold for power).

var _touch: TouchControls
var _keys_down: Dictionary = {}
## Knock-on mode is on (started by a double pull).
var _knock_on: bool = false
## What each kick button meant when it was pressed ("" while it is up): a press keeps that meaning
## until the finger is lifted, so winning or losing the ball, or crossing the halfway line, never
## turns a held button into another kick (no accidental shot after a tackle, no shot from a held
## clearance, no clearance fired by crossing the line).
var _pressed_as: Dictionary = {"shoot": "", "pass": "", "through": ""}


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
	var shot_keys := [_key_tapped(KEY_V), _key_tapped(KEY_B), _key_tapped(KEY_N)]
	var shoot_tap := _touch.consume_press("shoot") or space_tap or shot_keys.has(true)
	var t_tap := _key_tapped(KEY_T)
	var g_tap := _key_tapped(KEY_G)
	var pass_tap := _touch.consume_press("pass") or e_tap or t_tap
	var through_tap := _touch.consume_press("through") or r_tap or g_tap
	_touch.consume_press("sprint")
	var shoot_hold := _touch.is_held("shoot") or Input.is_physical_key_pressed(KEY_SPACE) \
		or not _shot_key().is_empty()
	var pass_hold := _touch.is_held("pass") or Input.is_physical_key_pressed(KEY_E) \
		or Input.is_physical_key_pressed(KEY_T)
	var through_hold := _touch.is_held("through") or Input.is_physical_key_pressed(KEY_R) \
		or Input.is_physical_key_pressed(KEY_G)
	var sprint_hold := _touch.is_held("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)
	var shoot_as := _pressed_kind("shoot", shoot_tap, shoot_hold,
		("clear" if clearing else "shot") if attacking else "tackle")
	var pass_as := _pressed_kind("pass", pass_tap, pass_hold, "pass" if attacking else "switch")
	var through_as := _pressed_kind("through", through_tap, through_hold, "through" if attacking else "match_up")
	intent.switch_pressed = q_tap
	if attacking:
		intent.clear_held = shoot_as == "clear"
		intent.shoot_held = shoot_as == "shot"
		intent.pass_held = pass_as == "pass"
		intent.through_held = through_as == "through"
		intent.pass_lofted = _slid_up("pass") or Input.is_physical_key_pressed(KEY_T)
		intent.through_lofted = _slid_up("through") or Input.is_physical_key_pressed(KEY_G)
		intent.shot_type = _shot_key()
		if intent.shot_type.is_empty() and _touch != null:
			intent.shot_type = shot_type_for(_touch.slide_direction("shoot"))
		intent.sprint = sprint_hold
		# Keeper with the ball in his hands: a double tap puts it down at his feet.
		intent.drop_ball = double_tap
		if flick != Vector2.ZERO:
			intent.skill = Vector3(flick.x, 0.0, flick.y)
		elif c_tap:
			intent.skill = intent.move if intent.move.length() > 0.3 else Vector3.RIGHT
		if double_pull != Vector2.ZERO:
			_knock_on = true
		if strength == 0.0 or intent.walk or pass_tap or through_tap or intent.shoot_held \
				or intent.clear_held or intent.skill != Vector3.ZERO:
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


## The finger slid up on `button` (more up than sideways): held, or as it was lifted.
func _slid_up(button: String) -> bool:
	return _touch != null and _touch.slide_direction(button).y < -0.7


## The shot type of a slide on SHOOT (screen axes): up = chip, down = low, left or right = curl,
## no slide = a normal shot ("").
static func shot_type_for(slide: Vector2) -> String:
	if slide == Vector2.ZERO:
		return ""
	if absf(slide.y) >= absf(slide.x):
		return "chip" if slide.y < 0.0 else "low"
	return "curl"


## Shot type keys for a PC: V chip, B curl, N low (each also works as SHOOT).
func _shot_key() -> String:
	if Input.is_physical_key_pressed(KEY_V):
		return "chip"
	if Input.is_physical_key_pressed(KEY_B):
		return "curl"
	if Input.is_physical_key_pressed(KEY_N):
		return "low"
	return ""


## What `button` means for this press: set on the press (to `now`), kept while it is held, "" once
## it is up. A tap shorter than a frame still counts for that frame.
func _pressed_kind(button: String, pressed: bool, held: bool, now: String) -> String:
	if pressed and str(_pressed_as[button]).is_empty():
		_pressed_as[button] = now
	elif not pressed and not held:
		_pressed_as[button] = ""
	return str(_pressed_as[button])


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
