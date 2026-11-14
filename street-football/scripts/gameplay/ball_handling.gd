class_name BallHandling
extends RefCounted
## What one player does with the ball: take control, dribble, shoot (hold to charge), pass,
## and bounce the ball off the body when not in control. Numbers: data/config/player.json.

var has_ball: bool = false
var is_charging: bool = false
## 0..1 while the shoot button is held.
var shot_charge: float = 0.0

var _cooldown: float = 0.0


## Drops control of the ball (kick-off, goal...). The ball keeps its speed.
func reset(ball: BallPhysics) -> void:
	has_ball = false
	is_charging = false
	shot_charge = 0.0
	_cooldown = 0.0
	ball.controlled = false


func update(delta: float, player: Player, ball: BallPhysics, intent: PlayerIntent) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if not has_ball and _cooldown <= 0.0 and _can_take(player, ball):
		has_ball = true
		ball.controlled = true
	var aim := _aim_direction(player, intent)
	if intent.pass_pressed and _in_kick_reach(player, ball):
		_kick(ball, aim * _cfg("pass_speed", 11.0) + Vector3.UP * _cfg("pass_lift", 0.0), 0.0)
		is_charging = false
		shot_charge = 0.0
	elif intent.shoot_held:
		is_charging = true
		shot_charge = minf(1.0, shot_charge + delta / maxf(0.01, _cfg("shot_charge_time", 0.9)))
	elif is_charging:
		if _in_kick_reach(player, ball):
			_shoot(player, ball, aim)
		is_charging = false
		shot_charge = 0.0
	if has_ball:
		_dribble(player, ball, intent.sprint)
	else:
		_bounce_off_body(player, ball)


func _shoot(player: Player, ball: BallPhysics, aim: Vector3) -> void:
	var speed := lerpf(_cfg("shot_speed_min", 12.0), _cfg("shot_speed_max", 26.0), shot_charge)
	var lift := lerpf(_cfg("shot_lift_min", 0.5), _cfg("shot_lift_max", 5.5), shot_charge)
	# Turning while shooting curls the ball the same way.
	var spin := player.motion.turn_rate * _cfg("shot_curve_from_turn", 0.35)
	_kick(ball, aim * speed + Vector3.UP * lift, spin)


func _kick(ball: BallPhysics, kick_velocity: Vector3, spin: float) -> void:
	has_ball = false
	_cooldown = _cfg("kick_cooldown", 0.35)
	ball.kick(kick_velocity, spin)


func _dribble(player: Player, ball: BallPhysics, sprint: bool) -> void:
	var dist := _cfg("dribble_sprint_distance", 0.9) if sprint else _cfg("dribble_distance", 0.55)
	var target := player.position + player.motion.facing * dist
	var to_target := Vector3(target.x - ball.position.x, 0.0, target.z - ball.position.z)
	if to_target.length() > _cfg("lose_ball_distance", 1.4):
		has_ball = false
		ball.controlled = false
		_cooldown = _cfg("kick_cooldown", 0.35)
		return
	var v := player.motion.velocity + to_target * _cfg("dribble_stiffness", 14.0)
	ball.velocity.x = v.x
	ball.velocity.z = v.z


func _bounce_off_body(player: Player, ball: BallPhysics) -> void:
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


func _can_take(player: Player, ball: BallPhysics) -> bool:
	if ball.position.y > _cfg("control_max_ball_height", 0.6):
		return false
	var d := Vector2(ball.position.x - player.position.x, ball.position.z - player.position.z)
	if d.length() > _cfg("control_radius", 0.9):
		return false
	var rel := Vector2(ball.velocity.x - player.motion.velocity.x, ball.velocity.z - player.motion.velocity.z)
	return rel.length() <= _cfg("control_max_relative_speed", 12.0)


func _in_kick_reach(player: Player, ball: BallPhysics) -> bool:
	if has_ball:
		return true
	if ball.position.y > _cfg("kick_max_ball_height", 1.0):
		return false
	var d := Vector2(ball.position.x - player.position.x, ball.position.z - player.position.z)
	return d.length() <= _cfg("kick_reach", 1.1)


func _aim_direction(player: Player, intent: PlayerIntent) -> Vector3:
	var flat := Vector3(intent.move.x, 0.0, intent.move.z)
	if flat.length() > 0.3:
		return flat.normalized()
	return player.motion.facing


func _cfg(key: String, fallback: float) -> float:
	return float(Config.get_value("player", key, fallback))
