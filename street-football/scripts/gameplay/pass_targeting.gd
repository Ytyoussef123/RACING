class_name PassTargeting
extends RefCounted
## Picks the teammate a pass goes to (the best one in the aim direction) and the pass speed.
## Numbers: data/config/player.json (pass_*).


static func choose(passer: Player, aim: Vector3, ctx: MatchContext) -> Player:
	var cone := cos(deg_to_rad(_cfg("pass_cone_degrees", 40.0)))
	var min_d := _cfg("pass_target_min_distance", 1.5)
	var max_d := _cfg("pass_target_max_distance", 24.0)
	var best: Player = null
	var best_score := -INF
	for mate in passer.team.players:
		if mate == passer:
			continue
		var to := Vector3(mate.position.x - passer.position.x, 0.0, mate.position.z - passer.position.z)
		var d := to.length()
		if d < min_d or d > max_d:
			continue
		var c := aim.dot(to / d)
		if c < cone:
			continue
		var score := c * 2.0 - d * 0.05
		if mate.is_keeper:
			score -= 1.0
		if score > best_score:
			best_score = score
			best = mate
	return best


## Ground pass toward where the receiver will be, faster for longer passes.
static func pass_velocity(passer: Player, target: Player) -> Vector3:
	var d := passer.flat_distance_to(target.position)
	var speed := clampf(_cfg("pass_speed_base", 6.0) + d * _cfg("pass_speed_per_meter", 0.55),
		_cfg("pass_speed_min", 7.0), _cfg("pass_speed_max", 16.0))
	var lead := target.motion.velocity * (d / speed) * _cfg("pass_lead_factor", 0.8)
	var to := Vector3(target.position.x + lead.x - passer.position.x, 0.0, target.position.z + lead.z - passer.position.z)
	var dir := to.normalized() if to.length() > 0.01 else passer.motion.facing
	return dir * speed + Vector3.UP * _cfg("pass_lift", 0.0)


static func _cfg(key: String, fallback: float) -> float:
	return float(Config.get_value("player", key, fallback))
