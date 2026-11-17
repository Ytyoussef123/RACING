class_name Kicks
extends RefCounted
## The kicks: pass (and the keeper's throw from his hands), through pass (and his long kick), shot,
## clearance, and the lofted pass / lofted through ball, with their speed, lift, spin and accuracy.
## `power` is 0..1 from the power bar when the button was held, or AUTO for a tap (and for the
## AI): the game picks the strength by itself, as before the power bar.
## In the red end of the bar (kick_red_zone..1) a pass or clearance is harder to place, and a shot
## rises more, by chance (more for weaker finishers): it can fly over the crossbar.
## Numbers: data/config/player.json (pass_*, through_*, shot_*, clear_*, keeper_*, kick_*).

const AUTO := -1.0


static func pass_ball(handling: BallHandling, player: Player, ctx: MatchContext, aim: Vector3, power: float) -> void:
	var target := PassTargeting.choose(player, aim, ctx)
	var kick_velocity: Vector3
	if player.ball_in_hands:
		kick_velocity = KeeperHands.throw_velocity(player, target, aim, power)
	elif target != null:
		kick_velocity = PassTargeting.pass_velocity(player, target,
			by_power(power, AUTO, _cfg("pass_power_speed_min", 8.0), _cfg("pass_power_speed_max", 20.0)))
	else:
		var speed := by_power(power, _cfg("pass_speed", 13.0), _cfg("pass_power_speed_min", 8.0),
			_cfg("pass_power_speed_max", 20.0))
		kick_velocity = aim * speed + Vector3.UP * _cfg("pass_lift", 0.0)
	var error := player.stat("keeper_kick_error_degrees" if player.is_keeper else "pass_error_degrees", 0.0)
	if player.ball_in_hands:
		error *= _cfg("keeper_throw_error_mult", 0.6)
	error *= KickAccuracy.weak_foot_mult(player, aim) * KickAccuracy.pace_mult(player) * red_zone_mult(power)
	kick_velocity = KickAccuracy.with_error(kick_velocity, error, ctx)
	ctx.stats.passes[player.team.index] += 1
	kick(handling, player, ctx, kick_velocity, 0.0, target, "pass")


## Ground pass into the space in front of the receiver, toward the opponent's goal; held, the bar
## sets how far in front of him (through_power_lead_*). From the keeper's hands: a long kick.
static func through_ball(handling: BallHandling, player: Player, ctx: MatchContext, aim: Vector3, power: float) -> void:
	var target := PassTargeting.choose(player, aim, ctx)
	var error := player.stat("keeper_kick_error_degrees" if player.is_keeper else "through_error_degrees", 0.0)
	error *= KickAccuracy.weak_foot_mult(player, aim) * KickAccuracy.pace_mult(player) * red_zone_mult(power)
	ctx.stats.passes[player.team.index] += 1
	if player.ball_in_hands:
		var long_kick := KeeperHands.long_kick_velocity(player, target, aim, power)
		kick(handling, player, ctx, KickAccuracy.with_error(long_kick, error, ctx), 0.0, target, "pass")
		return
	if target == null:
		var speed := by_power(power, _cfg("through_space_speed", 10.0), _cfg("through_power_speed_min", 7.0),
			_cfg("through_power_speed_max", 17.0))
		kick(handling, player, ctx, KickAccuracy.with_error(aim * speed, error, ctx), 0.0, null, "pass")
		return
	var lead := by_power(power, AUTO, _cfg("through_power_lead_min", 2.0), _cfg("through_power_lead_max", 10.0))
	kick(handling, player, ctx, KickAccuracy.with_error(PassTargeting.through_velocity(player, target, ctx, lead),
		error, ctx), 0.0, target, "pass")


## A shot at `target`, a point in the opponent's goal (ShotAim); `charge` 0..1 from the bar;
## `type` from a slide on SHOOT: "" normal, "low", "chip" or "curl" (ShotTypes).
static func shoot(handling: BallHandling, player: Player, ctx: MatchContext, target: Vector3, charge: float,
		type: String = "") -> void:
	var aim := Steering.flat(target - ctx.ball.position).normalized()
	var kick_velocity: Vector3
	var spin: float
	var type_error := 1.0
	if type == "low":
		var low := ShotTypes.low(player, aim, charge)
		kick_velocity = low["velocity"]
		spin = float(low["spin"])
		type_error = red_zone_mult(charge)
	elif type == "chip":
		var chip := ShotTypes.chip(player, ctx, target, charge)
		kick_velocity = chip["velocity"]
		spin = float(chip["spin"])
		type_error = _cfg("shot_chip_error_mult", 1.0)
	elif type == "curl":
		var curl := ShotTypes.curl(player, ctx, charge)
		kick_velocity = curl["velocity"]
		kick_velocity.y += red_zone_lift(player, charge, ctx)
		spin = float(curl["spin"])
		aim = Steering.flat(kick_velocity).normalized()
		type_error = _cfg("shot_curl_error_mult", 0.7)
	else:
		var speed := lerpf(_cfg("shot_speed_min", 12.0), _cfg("shot_speed_max", 26.0), charge)
		speed *= player.stat("shot_speed_mult", 1.0)
		var lift := lerpf(_cfg("shot_lift_min", 0.5), _cfg("shot_lift_max", 5.5), charge) + red_zone_lift(player, charge, ctx)
		kick_velocity = aim * speed + Vector3.UP * lift
		# Turning while shooting curls the ball the same way.
		spin = player.motion.turn_rate * _cfg("shot_curve_from_turn", 0.35)
	# Accuracy: finishing, plus long shots beyond long_shot_distance, worse on the weak foot,
	# better first-time for players with that special skill.
	var first_time := ctx.possession.holder != player
	var goal := Vector3(player.team.target_goal_x(ctx.court), 0.0, 0.0)
	var beyond := maxf(0.0, player.flat_distance_to(goal) - StatEffects.num("long_shot_distance", 12.0))
	var error := player.stat("shot_error_degrees", 0.0) + beyond * player.stat("long_shot_error_per_meter", 0.0)
	error *= KickAccuracy.weak_foot_mult(player, aim) * KickAccuracy.pace_mult(player) \
		* KickAccuracy.shot_angle_mult(player, ctx, aim)
	if first_time and player.profile != null and player.profile.special_skills.has("first_time_shot"):
		error *= float(Config.get_value("skills", "first_time_shot_error_mult", 0.6))
	ctx.stats.shots[player.team.index] += 1
	ctx.possession.last_shot_type = type
	kick(handling, player, ctx, KickAccuracy.with_error(kick_velocity, error * type_error, ctx), spin, null, "shot")


## SHOOT in our own half: a long, high kick away from our goal, where the stick points; held, the
## bar sets how long and high (clear_power_*).
static func clear(handling: BallHandling, player: Player, ctx: MatchContext, aim: Vector3, power: float) -> void:
	var dir := Steering.flat(aim).normalized()
	if dir.x * player.team.attack_sign < 0.0:
		dir.x = -dir.x
	var error := player.stat("through_error_degrees", 0.0) * _cfg("clear_error_mult", 1.5)
	error *= KickAccuracy.weak_foot_mult(player, dir) * KickAccuracy.pace_mult(player) * red_zone_mult(power)
	var speed := by_power(power, _cfg("clear_speed", 17.0), _cfg("clear_power_speed_min", 10.0),
		_cfg("clear_power_speed_max", 20.0))
	var lift := by_power(power, _cfg("clear_lift", 6.5), _cfg("clear_power_lift_min", 4.0),
		_cfg("clear_power_lift_max", 7.5))
	kick(handling, player, ctx, KickAccuracy.with_error(dir * speed + Vector3.UP * lift, error, ctx), 0.0, null, "clear")


## A ball in the air (PASS or THROUGH with the finger slid up): toward the teammate on the stick's
## side, where he will be when it comes down (a through ball: the space in front of him), landing
## as far as the bar says (LoftedKick). AUTO (no power given) lands it at him.
static func lofted(handling: BallHandling, player: Player, ctx: MatchContext, aim: Vector3, power: float,
		through: bool) -> void:
	var target := PassTargeting.choose(player, aim, ctx)
	var dir := Steering.flat(aim).normalized()
	var auto_distance := LoftedKick.distance_for(0.5)
	if target != null:
		var spot := PassTargeting.through_spot(player, target, ctx) if through else target.position
		if not through:
			var flight := LoftedKick.flight_time(player.flat_distance_to(spot))
			spot += Steering.flat(target.motion.velocity) * flight * _cfg("pass_lead_factor", 0.8)
		var to := Steering.flat(spot - ctx.ball.position)
		if to.length() > 0.01:
			dir = to.normalized()
			auto_distance = to.length()
	var distance := by_power(power, auto_distance, LoftedKick.distance_for(0.0), LoftedKick.distance_for(1.0))
	var error := player.stat("keeper_kick_error_degrees" if player.is_keeper else "through_error_degrees", 0.0)
	error *= KickAccuracy.weak_foot_mult(player, dir) * KickAccuracy.pace_mult(player) * red_zone_mult(power)
	ctx.stats.passes[player.team.index] += 1
	var kick_velocity := LoftedKick.velocity(ctx.ball.position, dir, distance)
	kick(handling, player, ctx, KickAccuracy.with_error(kick_velocity, error, ctx), 0.0, target, "pass")


static func kick(handling: BallHandling, player: Player, ctx: MatchContext, kick_velocity: Vector3, spin: float,
		target: Player, kind: String) -> void:
	player.ball_in_hands = false
	ctx.possession.kicked(player, target, ctx.ball, kind)
	player.animate("pass" if kind == "pass" else ("chip" if kind == "shot" and ctx.possession.last_shot_type == "chip" else "kick"), 1.0, player.flat_distance_to(ctx.ball.position))
	ctx.emit_event("shot" if kind == "shot" else "pass", ctx.ball.position, kick_velocity.length())
	ctx.ball.kick(kick_velocity, spin)
	# The ball leaves his foot: his own body does not deflect it (kicks across the body).
	player.ghost_timer = maxf(player.ghost_timer, _cfg("kick_pass_through_seconds", 0.15))
	handling.after_kick()
	if kind == "pass" and not player.is_keeper:
		AfterPass.start(player)


## The value of a kick from the bar: `auto` for a tap (power AUTO), else low..high by power.
static func by_power(power: float, auto: float, low: float, high: float) -> float:
	if power < 0.0:
		return auto
	return lerpf(low, high, clampf(power, 0.0, 1.0))


## How deep the power is in the red end of the bar: 0 below kick_red_zone (and for AUTO), 1 full.
static func red_amount(power: float) -> float:
	var start := _cfg("kick_red_zone", 0.85)
	if power <= start:
		return 0.0
	return clampf((power - start) / maxf(0.01, 1.0 - start), 0.0, 1.0)


## Aim error multiplier of a pass or clearance kicked in the red end (too hard to place well).
static func red_zone_mult(power: float) -> float:
	return 1.0 + red_amount(power) * (_cfg("kick_red_error_mult", 1.6) - 1.0)


## Extra rise of a shot in the red end: random up to shot_red_lift at full power, times the
## shooter's finishing error over shot_red_reference_degrees (clamped): it can clear the crossbar.
static func red_zone_lift(player: Player, charge: float, ctx: MatchContext) -> float:
	var red := red_amount(charge)
	if red <= 0.0:
		return 0.0
	var reference := _cfg("shot_red_reference_degrees", 3.0)
	var scale := clampf(player.stat("shot_error_degrees", reference) / maxf(0.01, reference),
		_cfg("shot_red_scale_min", 0.4), _cfg("shot_red_scale_max", 1.6))
	return ctx.rng.randf() * red * _cfg("shot_red_lift", 4.5) * scale


static func _cfg(key: String, fallback: float) -> float:
	return float(Config.get_value("player", key, fallback))
