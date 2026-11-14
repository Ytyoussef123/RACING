class_name PassTargeting
extends RefCounted
## Pass assist: picks the teammate a pass goes to and the pass speed.
## The receiver is the teammate closest to the aim direction (wide cone), not only one exactly
## on the line; if nobody is in the cone, the teammate with the smallest angle up to
## pass_assist_max_degrees. Numbers: data/config/player.json (pass_*).


static func choose(passer: Player, aim: Vector3, ctx: MatchContext) -> Player:
	var cone := cos(deg_to_rad(_cfg("pass_cone_degrees", 70.0)))
	var assist := cos(deg_to_rad(_cfg("pass_assist_max_degrees", 120.0)))
	var min_d := _cfg("pass_target_min_distance", 1.5)
	var max_d := _cfg("pass_target_max_distance", 24.0)
	var best_in_cone: Player = null
	var best_in_cone_score := -INF
	var best_angle: Player = null
	var best_angle_cos := assist
	for mate in passer.team.players:
		if mate == passer:
			continue
		var to := Vector3(mate.position.x - passer.position.x, 0.0, mate.position.z - passer.position.z)
		var d := to.length()
		if d < min_d or d > max_d:
			continue
		var c := aim.dot(to / d)
		if c >= cone:
			var score := _score(passer, mate, c, d, ctx)
			if score > best_in_cone_score:
				best_in_cone_score = score
				best_in_cone = mate
		elif c > best_angle_cos and not mate.is_keeper:
			best_angle_cos = c
			best_angle = mate
	return best_in_cone if best_in_cone != null else best_angle


## Angle matters most, distance a little; a blocked lane or the keeper costs points.
static func _score(passer: Player, mate: Player, cos_angle: float, dist: float, ctx: MatchContext) -> float:
	var score := cos_angle * _cfg("pass_angle_weight", 3.0) - dist * _cfg("pass_distance_weight", 0.04)
	if mate.is_keeper:
		score -= 1.0
	if passer.team.opponent != null and not CarrierAI.lane_clear(passer.position, mate.position, passer.team.opponent):
		score -= _cfg("pass_blocked_penalty", 0.8)
	return score


## Ground pass toward where the receiver will be, faster for longer passes.
static func pass_velocity(passer: Player, target: Player) -> Vector3:
	var d := passer.flat_distance_to(target.position)
	var speed := clampf(_cfg("pass_speed_base", 6.0) + d * _cfg("pass_speed_per_meter", 0.55),
		_cfg("pass_speed_min", 7.0), _cfg("pass_speed_max", 16.0))
	var lead := target.motion.velocity * (d / speed) * _cfg("pass_lead_factor", 0.8)
	var to := Vector3(target.position.x + lead.x - passer.position.x, 0.0, target.position.z + lead.z - passer.position.z)
	var dir := to.normalized() if to.length() > 0.01 else passer.motion.facing
	return dir * speed + Vector3.UP * _cfg("pass_lift", 0.0)


## Through pass: aimed at the space a few meters in front of the receiver, mostly toward the
## opponent's goal and partly along his run, kept inside the court.
static func through_velocity(passer: Player, target: Player, ctx: MatchContext) -> Vector3:
	var court := ctx.court
	var forward := Vector3(passer.team.attack_sign, 0.0, 0.0)
	var run := Steering.flat(target.motion.velocity)
	var run_dir := run.normalized() if run.length() > 1.0 else forward
	var w := _cfg("through_forward_weight", 0.6)
	var lead_dir := forward * w + run_dir * (1.0 - w)
	lead_dir = lead_dir.normalized() if lead_dir.length() > 0.01 else forward
	var spot := target.position + lead_dir * _cfg("through_lead_distance", 4.0)
	var margin := _cfg("through_wall_margin", 1.0)
	spot.x = clampf(spot.x, -court.half_length + margin, court.half_length - margin)
	spot.z = clampf(spot.z, -court.half_width + margin, court.half_width - margin)
	var to := Steering.flat(spot - passer.position)
	var d := to.length()
	var speed := clampf(_cfg("through_speed_base", 5.0) + d * _cfg("through_speed_per_meter", 0.5),
		_cfg("through_speed_min", 7.0), _cfg("through_speed_max", 15.0))
	var dir := to / d if d > 0.01 else forward
	return dir * speed


static func _cfg(key: String, fallback: float) -> float:
	return float(Config.get_value("player", key, fallback))
