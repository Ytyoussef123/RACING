class_name TackleRules
extends RefCounted
## A tackle: in reach of an opponent's ball, it may knock the ball loose; a miss slows the tackler.
## Tackling when nobody has the ball is a slide for nothing (he is slow to get up).
## Numbers: data/config/player.json (tackle_*), plus the AI difficulty bonus.


## slide: the human's TACKLE (and the AI now and then). Otherwise a standing tackle: decided at
## once, a miss slows him.
static func attempt(tackler: Player, ctx: MatchContext, slide: bool = true) -> bool:
	var possession := ctx.possession
	var carrier := possession.holder
	var ball := ctx.ball
	if not slide:
		if carrier == null or carrier.team == tackler.team:
			return false
		tackler.animate("tackle_stand")
		tackler.tackle_pending = true
		if not _resolve(tackler, ctx) and tackler.tackle_pending:
			tackler.tackle_pending = false
			tackler.stun_timer = _cfg("tackle_whiff_stun", 0.35)
			return false
		return ctx.possession.holder != carrier
	# TACKLE is a slide: a running slide at speed, a slide tackle from slow or standing. He slides
	# on along his way, and the ball is his if it comes in reach during the slide (slide_update).
	var speed := Steering.flat(tackler.motion.velocity).length()
	var running := speed >= _cfg("slide_run_speed", 2.5)
	tackler.animate("tackle_run" if running else "tackle")
	tackler.start_slide(_cfg("slide_seconds", 0.8), maxf(speed * _cfg("slide_speed_mult", 1.2), _cfg("slide_min_speed", 4.5)))
	tackler.tackle_pending = true
	return _resolve(tackler, ctx)


## Called every frame: a slide in progress wins (or misses) the ball when it comes in reach; a
## slide that never reaches it is a miss (the tackler is slow to get up).
static func slide_update(tackler: Player, ctx: MatchContext) -> void:
	if not tackler.tackle_pending:
		return
	if tackler.slide_time <= 0.0:
		tackler.tackle_pending = false
		tackler.stun_timer = maxf(tackler.stun_timer, _cfg("tackle_whiff_stun", 0.35))
		return
	_resolve(tackler, ctx)


static func _resolve(tackler: Player, ctx: MatchContext) -> bool:
	var possession := ctx.possession
	var carrier := possession.holder
	var ball := ctx.ball
	if carrier == null or carrier.team == tackler.team:
		return false
	if tackler.flat_distance_to(ball.position) > _cfg("tackle_reach", 1.3):
		return false
	tackler.tackle_pending = false
	if is_protected(carrier, ctx):
		tackler.stun_timer = _cfg("tackle_whiff_stun", 0.35)
		return false
	if ctx.rng.randf() >= success_chance(tackler, carrier):
		tackler.stun_timer = _cfg("tackle_fail_stun", 0.6)
		return false
	possession.release(ball)
	carrier.handling.block_control(_cfg("tackle_victim_cooldown", 0.6))
	ball.kick(tackler.motion.facing * _cfg("tackle_ball_speed", 2.5), 0.0)
	possession.touched(tackler)
	ctx.stats.balls_won[tackler.team.index] += 1
	ctx.emit_event("tackle_won", ball.position)
	return true


## Tackler's tackling, the AI difficulty bonus, and the carrier's balance (harder to knock over).
static func success_chance(tackler: Player, carrier: Player) -> float:
	var chance := tackler.stat("tackle_success", _cfg("tackle_success", 0.55))
	if tackler.team.tuning != null:
		chance += tackler.team.tuning.tackle_success_bonus
	chance += carrier.stat("tackle_resist", 0.0)
	return clampf(chance, 0.05, 0.95)


## A keeper with the ball in his hands (always inside his goal area) cannot be tackled; with the
## ball at his feet he can, like anyone.
static func is_protected(carrier: Player, _ctx: MatchContext) -> bool:
	return carrier.ball_in_hands


static func _cfg(key: String, fallback: float) -> float:
	return float(Config.get_value("player", key, fallback))
