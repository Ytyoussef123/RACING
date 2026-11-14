class_name TackleRules
extends RefCounted
## A tackle: in reach of an opponent's ball, it may knock the ball loose; a miss slows the tackler.
## Numbers: data/config/player.json (tackle_*), plus the AI difficulty bonus.


static func attempt(tackler: Player, ctx: MatchContext) -> bool:
	var possession := ctx.possession
	var carrier := possession.holder
	var ball := ctx.ball
	var in_reach := tackler.flat_distance_to(ball.position) <= _cfg("tackle_reach", 1.3)
	if carrier == null or carrier.team == tackler.team or not in_reach or _is_protected(carrier, ctx):
		tackler.stun_timer = _cfg("tackle_whiff_stun", 0.35)
		return false
	var chance := _cfg("tackle_success", 0.55) + tackler.team.tuning.tackle_success_bonus
	if ctx.rng.randf() >= chance:
		tackler.stun_timer = _cfg("tackle_fail_stun", 0.6)
		return false
	possession.release(ball)
	carrier.handling.block_control(_cfg("tackle_victim_cooldown", 0.6))
	ball.kick(tackler.motion.facing * _cfg("tackle_ball_speed", 2.5), 0.0)
	possession.touched(tackler)
	return true


## A keeper holding the ball inside his own goal area cannot be tackled.
static func _is_protected(carrier: Player, ctx: MatchContext) -> bool:
	if not carrier.is_keeper:
		return false
	var court := ctx.court
	var depth := court.number("goal_area_depth", 3.0)
	var half_w := court.number("goal_area_width", 7.0) * 0.5
	var from_line := absf(carrier.position.x - carrier.team.own_goal_x(court))
	return from_line <= depth and absf(carrier.position.z) <= half_w


static func _cfg(key: String, fallback: float) -> float:
	return float(Config.get_value("player", key, fallback))
