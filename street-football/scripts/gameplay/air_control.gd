class_name AirControl
extends RefCounted
## First touch on a ball coming down from the air (a lofted pass, a clearance, a high bounce): it
## can be taken up to air_control_height (chest, thigh or foot) instead of only near the ground,
## by either side (a defender under the ball can win it). The touch is clean with
## air_control_chance (ball control stat), less for a faster ball (air_control_speed_penalty per
## m/s above air_control_easy_speed); missed, the ball bounces off him (heavy touch) and runs loose.
## Numbers: data/config/player.json (air_control_*, air_heavy_touch_*), stat_effects.json.


## The ball is coming down within his reach, above the height he can take it from near the ground.
static func reachable(player: Player, ctx: MatchContext) -> bool:
	var ball := ctx.ball
	if ball.velocity.y > -_cfg("air_control_min_drop_speed", 0.5):
		return false
	var low := player.stat("control_max_ball_height", _cfg("control_max_ball_height", 0.6))
	if ball.position.y <= low or ball.position.y > _cfg("air_control_height", 1.5):
		return false
	if player.flat_distance_to(ball.position) > player.stat("control_radius", _cfg("control_radius", 0.9)):
		return false
	var rel := Vector2(ball.velocity.x - player.motion.velocity.x, ball.velocity.z - player.motion.velocity.z)
	return rel.length() <= player.stat("control_max_relative_speed", _cfg("control_max_relative_speed", 17.0))


## Rolls the first touch: true when it is clean (he may take the ball), false after a heavy touch
## (the ball bounced off him, loose).
static func first_touch(player: Player, ctx: MatchContext) -> bool:
	var ball := ctx.ball
	var chance := player.stat("air_control_chance", _cfg("air_control_chance", 0.8)) \
		- maxf(0.0, ball.velocity.length() - _cfg("air_control_easy_speed", 9.0)) * _cfg("air_control_speed_penalty", 0.03)
	if ctx.rng.randf() < clampf(chance, _cfg("air_control_chance_min", 0.2), 1.0):
		return true
	var away := Steering.flat(ball.position - player.position)
	if away.length() < 0.05:
		away = player.motion.facing
	away = away.normalized()
	var side := Vector3(-away.z, 0.0, away.x) * ctx.rng.randf_range(-1.0, 1.0) * _cfg("air_heavy_touch_spread", 0.6)
	var dir := (away + side).normalized()
	ball.kick(dir * _cfg("air_heavy_touch_speed", 3.5) + Vector3.UP * _cfg("air_heavy_touch_lift", 1.5), 0.0)
	ctx.possession.touched(player)
	return false


static func _cfg(key: String, fallback: float) -> float:
	return float(Config.get_value("player", key, fallback))
