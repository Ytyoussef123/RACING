class_name BallHandling
extends RefCounted
## What one player does with the ball: take control, dribble, shoot (hold to charge), pass,
## through pass, tackle, and bounce the ball off the body.
## A pass, through pass or shot asked a moment before the ball arrives is kept for
## kick_buffer_seconds and played first-time when the ball comes within reach.
## Numbers: data/config/player.json.

var is_charging: bool = false
## 0..1 while the shoot button is held.
var shot_charge: float = 0.0

var _cooldown: float = 0.0
var _tackle_cooldown: float = 0.0
## Kick waiting for the ball: "" (none), "pass", "through" or "shot".
var _queued: String = ""
var _queued_charge: float = 0.0
var _queue_timer: float = 0.0


func reset() -> void:
	is_charging = false
	shot_charge = 0.0
	_cooldown = 0.0
	_tackle_cooldown = 0.0
	_queued = ""
	_queue_timer = 0.0


## Stops this player from taking the ball for a while (after a kick, or when tackled).
func block_control(seconds: float) -> void:
	_cooldown = maxf(_cooldown, seconds)


func update(delta: float, player: Player, ctx: MatchContext) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_tackle_cooldown = maxf(0.0, _tackle_cooldown - delta)
	_queue_timer = maxf(0.0, _queue_timer - delta)
	if _queue_timer <= 0.0:
		_queued = ""
	var ball := ctx.ball
	var possession := ctx.possession
	var intent := player.intent
	if possession.holder == null and _cooldown <= 0.0 and player.stun_timer <= 0.0 and _can_take(player, ball):
		possession.take(player, ball)
	if intent.pass_pressed:
		_queue("pass", 0.0)
	elif intent.through_pressed:
		_queue("through", 0.0)
	var aim := _aim_direction(player, intent)
	if intent.tackle_pressed and possession.holder != player:
		if _tackle_cooldown <= 0.0:
			_tackle_cooldown = _cfg("tackle_cooldown", 0.8)
			TackleRules.attempt(player, ctx)
	elif not _queued.is_empty() and _can_kick(player, ctx):
		_play_queued(player, ctx, aim)
	elif intent.shoot_held:
		is_charging = true
		shot_charge = minf(1.0, shot_charge + delta / maxf(0.01, _cfg("shot_charge_time", 0.9)))
	elif is_charging:
		if _can_kick(player, ctx):
			_shoot(player, ctx, aim, shot_charge)
		elif possession.holder == null:
			_queue("shot", shot_charge)
		is_charging = false
		shot_charge = 0.0
	if possession.holder == player:
		_dribble(player, ctx)
	elif possession.holder == null or possession.holder.team != player.team:
		_bounce_off_body(player, ctx)


func _queue(kind: String, charge: float) -> void:
	_queued = kind
	_queued_charge = charge
	_queue_timer = _cfg("kick_buffer_seconds", 0.5)


func _play_queued(player: Player, ctx: MatchContext, aim: Vector3) -> void:
	match _queued:
		"pass":
			_pass(player, ctx, aim)
		"through":
			_through_pass(player, ctx, aim)
		"shot":
			_shoot(player, ctx, aim, _queued_charge)
	_queued = ""
	_queue_timer = 0.0
	is_charging = false
	shot_charge = 0.0


func _pass(player: Player, ctx: MatchContext, aim: Vector3) -> void:
	var target := PassTargeting.choose(player, aim, ctx)
	var kick_velocity: Vector3
	if target != null:
		kick_velocity = PassTargeting.pass_velocity(player, target)
	else:
		kick_velocity = aim * _cfg("pass_speed", 11.0) + Vector3.UP * _cfg("pass_lift", 0.0)
	_kick(player, ctx, kick_velocity, 0.0, target)


## Ground pass into the space in front of the receiver, toward the opponent's goal.
func _through_pass(player: Player, ctx: MatchContext, aim: Vector3) -> void:
	var target := PassTargeting.choose(player, aim, ctx)
	if target == null:
		_kick(player, ctx, aim * _cfg("through_space_speed", 10.0), 0.0, null)
		return
	_kick(player, ctx, PassTargeting.through_velocity(player, target, ctx), 0.0, target)


func _shoot(player: Player, ctx: MatchContext, aim: Vector3, charge: float) -> void:
	var speed := lerpf(_cfg("shot_speed_min", 12.0), _cfg("shot_speed_max", 26.0), charge)
	var lift := lerpf(_cfg("shot_lift_min", 0.5), _cfg("shot_lift_max", 5.5), charge)
	# Turning while shooting curls the ball the same way.
	var spin := player.motion.turn_rate * _cfg("shot_curve_from_turn", 0.35)
	_kick(player, ctx, aim * speed + Vector3.UP * lift, spin, null)


func _kick(player: Player, ctx: MatchContext, kick_velocity: Vector3, spin: float, target: Player) -> void:
	ctx.possession.kicked(player, target, ctx.ball)
	ctx.ball.kick(kick_velocity, spin)
	_cooldown = _cfg("kick_cooldown", 0.35)


func _dribble(player: Player, ctx: MatchContext) -> void:
	var ball := ctx.ball
	var dist := _cfg("dribble_sprint_distance", 0.9) if player.intent.sprint else _cfg("dribble_distance", 0.55)
	var target := player.position + player.motion.facing * dist
	var to_target := Vector3(target.x - ball.position.x, 0.0, target.z - ball.position.z)
	if to_target.length() > _cfg("lose_ball_distance", 1.4):
		ctx.possession.release(ball)
		_cooldown = _cfg("kick_cooldown", 0.35)
		return
	var v := player.motion.velocity + to_target * _cfg("dribble_stiffness", 14.0)
	ball.velocity.x = v.x
	ball.velocity.z = v.z


func _bounce_off_body(player: Player, ctx: MatchContext) -> void:
	var ball := ctx.ball
	if ball.position.y > player.height:
		return
	var d := Vector2(ball.position.x - player.position.x, ball.position.z - player.position.z)
	var min_dist := player.radius + ball.radius
	var dist := d.length()
	if dist >= min_dist or dist < 0.0001:
		return
	var n := d / dist
	ball.position.x = player.position.x + n.x * min_dist
	ball.position.z = player.position.z + n.y * min_dist
	var rel := Vector2(ball.velocity.x - player.motion.velocity.x, ball.velocity.z - player.motion.velocity.z)
	var vn := rel.dot(n)
	if vn < 0.0:
		var e := _cfg("body_restitution", 0.3)
		ball.velocity.x -= (1.0 + e) * vn * n.x
		ball.velocity.z -= (1.0 + e) * vn * n.y
		ctx.possession.touched(player)


func _can_take(player: Player, ball: BallPhysics) -> bool:
	if ball.position.y > _cfg("control_max_ball_height", 0.6):
		return false
	if player.flat_distance_to(ball.position) > _cfg("control_radius", 0.9):
		return false
	var rel := Vector2(ball.velocity.x - player.motion.velocity.x, ball.velocity.z - player.motion.velocity.z)
	return rel.length() <= _cfg("control_max_relative_speed", 17.0)


## True when this player can kick now: it has the ball, or the loose ball is within reach.
func _can_kick(player: Player, ctx: MatchContext) -> bool:
	if ctx.possession.holder == player:
		return true
	if ctx.possession.holder != null:
		return false
	var ball := ctx.ball
	if ball.position.y > _cfg("kick_max_ball_height", 1.0):
		return false
	return player.flat_distance_to(ball.position) <= _cfg("kick_reach", 1.1)


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
