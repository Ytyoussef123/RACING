class_name ShoulderCharge
extends RefCounted
## Shoulder charge (double-tap the joystick when you don't have the ball): a body duel with the
## ball carrier next to you. Win it and he is knocked off the ball; lose it and you bounce off.
## The chance compares both players' strength (and a little their balance).
## Numbers: data/config/player.json (shoulder_*).


static func attempt(charger: Player, ctx: MatchContext) -> bool:
	var carrier := ctx.possession.holder
	if carrier == null or carrier.team == charger.team:
		return false
	var to := Steering.flat(carrier.position - charger.position)
	var d := to.length()
	var dir := to / d if d > 0.01 else charger.motion.facing
	# Lunge at the carrier either way: the effort is visible.
	charger.motion.velocity += dir * _cfg("shoulder_lunge_speed", 2.5)
	if d > _cfg("shoulder_reach", 1.4) or TackleRules.is_protected(carrier, ctx):
		charger.stun_timer = _cfg("shoulder_whiff_stun", 0.3)
		return false
	if ctx.rng.randf() < success_chance(charger, carrier):
		carrier.motion.velocity += dir * _cfg("shoulder_push_speed", 3.0)
		carrier.stun_timer = maxf(carrier.stun_timer, _cfg("shoulder_victim_stun", 0.5))
		carrier.handling.block_control(_cfg("shoulder_victim_cooldown", 0.7))
		ctx.possession.release(ctx.ball)
		ctx.possession.touched(charger)
		var carried := Steering.flat(ctx.ball.velocity) * _cfg("shoulder_ball_keep", 0.5)
		ctx.ball.kick(carried + dir * _cfg("shoulder_ball_push", 1.0), 0.0)
		return true
	charger.motion.velocity = -dir * _cfg("shoulder_bounce_speed", 2.0)
	charger.stun_timer = _cfg("shoulder_fail_stun", 0.5)
	carrier.motion.velocity *= _cfg("shoulder_carrier_slowdown", 0.85)
	return false


## Base chance, moved by the difference in duel power, kept between the min and max chance.
static func success_chance(charger: Player, carrier: Player) -> float:
	var chance := _cfg("shoulder_base_chance", 0.5) \
		+ (duel_power(charger) - duel_power(carrier)) * _cfg("shoulder_strength_factor", 0.01)
	return clampf(chance, _cfg("shoulder_min_chance", 0.15), _cfg("shoulder_max_chance", 0.85))


## Strength, helped a little by balance (shoulder_balance_weight in stat_effects.json).
static func duel_power(player: Player) -> float:
	return player.strength + (player.balance - 50.0) * StatEffects.num("shoulder_balance_weight", 0.3)


static func _cfg(key: String, fallback: float) -> float:
	return float(Config.get_value("player", key, fallback))
