class_name BallHandling
extends RefCounted
## What one player does with the ball: take control (or steal a ball knocked too far ahead),
## dribble (see Dribbling), shoot (hold to charge), pass, through pass, clear (the kicks: Kicks),
## tackle, shoulder charge, and bounce the ball off the body.
## Power bar: SHOOT fills it from the press (shot_charge_time). PASS, THROUGH and CLEAR held by the
## human go on release: a tap keeps the automatic power, a hold past kick_tap_seconds fills the bar
## (kick_charge_time) and the bar sets the power.
## Kicks only happen with the ball within reach: a pass, through pass or shot asked when the ball
## is a little away is kept (with its aim) and played as soon as the ball is reached: first-time
## on an incoming ball, or at the next touch when dribbling.
## Player attributes (stat sheet) change control, shot power and accuracy, pass accuracy and the
## weak foot. Numbers: data/config/player.json and stat_effects.json.

var is_charging: bool = false
## 0..1 while the shoot button is held.
var shot_charge: float = 0.0
## 0..1 while PASS, THROUGH or CLEAR is held past a tap (the bar's power for that kick).
var kick_charge: float = 0.0
var dribbling: Dribbling = Dribbling.new()

var _cooldown: float = 0.0
var _tackle_cooldown: float = 0.0
var _shoulder_cooldown: float = 0.0
var _skill_cooldown: float = 0.0
## Kick waiting for the ball: "" (none), "pass", "through" or "shot".
var _queued: String = ""
var _queued_charge: float = 0.0
var _queued_aim: Vector3 = Vector3.ZERO
## For a queued shot: the point in the goal it is aimed at (ShotAim).
var _queued_point: Vector3 = Vector3.ZERO
var _queue_timer: float = 0.0
## Kick button held by the human ("pass", "through", "clear" or ""), and for how long.
var _held_kind: String = ""
var _held_time: float = 0.0


func reset() -> void:
	is_charging = false
	shot_charge = 0.0
	kick_charge = 0.0
	_held_kind = ""
	_held_time = 0.0
	_cooldown = 0.0
	_tackle_cooldown = 0.0
	_shoulder_cooldown = 0.0
	_skill_cooldown = 0.0
	_queued = ""
	_queue_timer = 0.0
	dribbling.reset()


## Stops this player from taking the ball for a while (after a kick, or when beaten).
func block_control(seconds: float) -> void:
	_cooldown = maxf(_cooldown, seconds)


func has_queued_kick() -> bool:
	return not _queued.is_empty()


## The power bar above the human's player: the shot charge, or a held pass, through or clear.
func bar_value() -> float:
	return shot_charge if is_charging else kick_charge


func bar_shown() -> bool:
	return is_charging or (not _held_kind.is_empty() and _held_time > _cfg("kick_tap_seconds", 0.18))


## After any kick (Kicks): the touch rhythm starts again and the ball cannot be retaken at once.
func after_kick() -> void:
	dribbling.reset()
	_cooldown = _cfg("kick_cooldown", 0.35)


func update(delta: float, player: Player, ctx: MatchContext) -> void:
	_tick_timers(delta)
	var ball := ctx.ball
	var possession := ctx.possession
	var intent := player.intent
	_try_take(player, ctx)
	var aim := _aim_direction(player, intent)
	var has_ball := possession.holder == player
	if intent.pass_pressed:
		_queue("pass", Kicks.AUTO, aim, has_ball)
	elif intent.through_pressed:
		_queue("through", Kicks.AUTO, aim, has_ball)
	elif intent.clear_pressed:
		_queue("clear", Kicks.AUTO, aim, has_ball)
	elif intent.skill != Vector3.ZERO and has_ball and _skill_cooldown <= 0.0:
		_skill_cooldown = float(Config.get_value("skills", "cooldown", 1.0))
		_queue("skill", 0.0, intent.skill, true)
	_track_held_kick(intent, delta, aim, has_ball)
	if intent.shoulder_pressed and not has_ball:
		if _shoulder_cooldown <= 0.0:
			_shoulder_cooldown = _cfg("shoulder_cooldown", 1.0)
			ShoulderCharge.attempt(player, ctx)
	elif intent.tackle_pressed and not has_ball:
		if _tackle_cooldown <= 0.0:
			_tackle_cooldown = _cfg("tackle_cooldown", 0.8)
			TackleRules.attempt(player, ctx)
	elif not _queued.is_empty() and _can_kick(player, ctx):
		_play_queued(player, ctx)
	elif intent.shoot_held:
		is_charging = true
		shot_charge = minf(1.0, shot_charge + delta / maxf(0.01, _cfg("shot_charge_time", 0.9)))
	elif is_charging:
		var shot_point := ShotAim.target(player, ctx, _stick(intent))
		if _can_kick(player, ctx):
			Kicks.shoot(self, player, ctx, shot_point, shot_charge)
		elif possession.holder == null or possession.holder == player:
			_queue("shot", shot_charge, aim, has_ball)
			_queued_point = shot_point
		is_charging = false
		shot_charge = 0.0
	if possession.holder == player:
		if player.ball_in_hands:
			_in_hands(player, ctx, delta)
		elif not dribbling.update(player, ctx, delta, not _queued.is_empty(), is_charging or bar_shown()):
			possession.release(ball)
			_cooldown = _cfg("kick_cooldown", 0.35)
	elif possession.holder == null or possession.holder.team != player.team:
		BodyBounce.apply(player, ctx)
	if player.ball_in_hands and possession.holder != player:
		player.ball_in_hands = false


## Keeper with the ball in his hands: hold it, put it down on a double tap, throw it when the
## time in his hands is up (keeper_hands_seconds).
func _in_hands(player: Player, ctx: MatchContext, delta: float) -> void:
	if player.intent.drop_ball:
		KeeperHands.drop(player, ctx)
		return
	KeeperHands.hold(player, ctx)
	player.hands_time += delta
	if player.hands_time >= _cfg("keeper_hands_seconds", 6.0) and _queued.is_empty():
		_queue("pass", Kicks.AUTO, KeeperAI.outlet_direction(player, ctx), true)


## PASS, THROUGH or CLEAR held by the human: released after a tap (kick_tap_seconds) the kick
## gets the automatic power; held longer, the bar fills over kick_charge_time and sets the power.
## The kick is queued on release and played as soon as the ball is in reach.
func _track_held_kick(intent: PlayerIntent, delta: float, aim: Vector3, has_ball: bool) -> void:
	var held := ""
	if intent.pass_held:
		held = "pass"
	elif intent.through_held:
		held = "through"
	elif intent.clear_held:
		held = "clear"
	var tap := _cfg("kick_tap_seconds", 0.18)
	if not held.is_empty() and held == _held_kind:
		_held_time += delta
	else:
		if not _held_kind.is_empty():
			_queue(_held_kind, Kicks.AUTO if _held_time <= tap else kick_charge, aim, has_ball)
		_held_kind = held
		_held_time = 0.0
	kick_charge = 0.0
	if not _held_kind.is_empty():
		kick_charge = clampf((_held_time - tap) / maxf(0.01, _cfg("kick_charge_time", 0.6)), 0.0, 1.0)


func _tick_timers(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_tackle_cooldown = maxf(0.0, _tackle_cooldown - delta)
	_shoulder_cooldown = maxf(0.0, _shoulder_cooldown - delta)
	_skill_cooldown = maxf(0.0, _skill_cooldown - delta)
	_queue_timer = maxf(0.0, _queue_timer - delta)
	if _queue_timer <= 0.0:
		_queued = ""


## Takes a loose ball in control range, or steals one an opponent knocked too far ahead.
func _try_take(player: Player, ctx: MatchContext) -> void:
	if _cooldown > 0.0 or player.stun_timer > 0.0 or player.ghost_timer > 0.0 or not _can_take(player, ctx):
		return
	var holder := ctx.possession.holder
	# Decided before the take (it forgets who passed last): a keeper's hands, not on a back-pass.
	var hands := KeeperHands.may_handle(player, ctx)
	if holder == null:
		ctx.possession.take(player, ctx.ball)
	elif Dribbling.can_steal(player, ctx):
		holder.handling.block_control(_cfg("dribble_steal_cooldown", 0.4))
		holder.handling.dribbling.reset()
		ctx.possession.take(player, ctx.ball)
		ctx.stats.balls_won[player.team.index] += 1
	else:
		return
	if hands:
		KeeperHands.take(player, ctx)


func _queue(kind: String, charge: float, aim: Vector3, dribbling_now: bool) -> void:
	_queued = kind
	_queued_charge = charge
	_queued_aim = aim
	_queue_timer = _cfg("kick_buffer_dribble_seconds", 1.2) if dribbling_now else _cfg("kick_buffer_seconds", 0.5)


func _play_queued(player: Player, ctx: MatchContext) -> void:
	match _queued:
		"pass":
			Kicks.pass_ball(self, player, ctx, _queued_aim, _queued_charge)
		"through":
			Kicks.through_ball(self, player, ctx, _queued_aim, _queued_charge)
		"shot":
			Kicks.shoot(self, player, ctx, _queued_point, _queued_charge)
		"clear":
			Kicks.clear(self, player, ctx, _queued_aim, _queued_charge)
		"skill":
			# A flick that makes no move (forward with nobody close) gives the cooldown back.
			if SkillMoves.perform(player, ctx, _queued_aim).is_empty():
				_skill_cooldown = 0.0
	_queued = ""
	_queue_timer = 0.0
	is_charging = false
	shot_charge = 0.0


## Ball low enough, close enough and not too fast to control (ball control, jump), or to cut
## out when the other team played it last (interception).
func _can_take(player: Player, ctx: MatchContext) -> bool:
	var ball := ctx.ball
	if ball.position.y > player.stat("control_max_ball_height", _cfg("control_max_ball_height", 0.6)):
		return false
	var radius := player.stat("control_radius", _cfg("control_radius", 0.9))
	var last := ctx.possession.last_touch_team
	if ctx.possession.holder == null and last >= 0 and last != player.team.index:
		radius = player.stat("intercept_radius", radius)
	if player.flat_distance_to(ball.position) > radius:
		return false
	var rel := Vector2(ball.velocity.x - player.motion.velocity.x, ball.velocity.z - player.motion.velocity.z)
	return rel.length() <= player.stat("control_max_relative_speed", _cfg("control_max_relative_speed", 17.0))


## True when this player can kick now: the ball (his own, or loose) is within reach.
func _can_kick(player: Player, ctx: MatchContext) -> bool:
	var holder := ctx.possession.holder
	if holder != null and holder != player:
		return false
	if player.ball_in_hands:
		return true
	var ball := ctx.ball
	if ball.position.y > _cfg("kick_max_ball_height", 1.0):
		return false
	return player.flat_distance_to(ball.position) <= _cfg("kick_reach", 1.1)


## The raw stick of the intent (its aim when set, else its move); ZERO when released.
static func _stick(intent: PlayerIntent) -> Vector3:
	var aim := Vector3(intent.aim.x, 0.0, intent.aim.z)
	return aim if aim.length() > 0.3 else Vector3(intent.move.x, 0.0, intent.move.z)


## Kick direction: the intent's aim if set, else its move direction, else where the player faces.
func _aim_direction(player: Player, intent: PlayerIntent) -> Vector3:
	var aim := Vector3(intent.aim.x, 0.0, intent.aim.z)
	if aim.length() > 0.3:
		return aim.normalized()
	var flat := Vector3(intent.move.x, 0.0, intent.move.z)
	if flat.length() > 0.3:
		return flat.normalized()
	return player.motion.facing


func _cfg(key: String, fallback: float) -> float:
	return float(Config.get_value("player", key, fallback))
