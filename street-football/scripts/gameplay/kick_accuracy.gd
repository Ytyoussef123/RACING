class_name KickAccuracy
extends RefCounted
## How far a kick strays from its aim (a random angle each kick): weak foot, speed mode and, for
## shots, a tight angle to the goal and shooting with the back to it. The base error comes from
## the player's stats (stat sheet). Numbers: data/config/player.json (pace_error_mult_*,
## shot_tight_*, shot_turn_error_mult) and stat_effects.json (weak_foot_error_mult).


## Turns a kick sideways by a random angle up to `degrees` (most kicks land near the aim).
static func with_error(kick_velocity: Vector3, degrees: float, ctx: MatchContext) -> Vector3:
	if degrees <= 0.0:
		return kick_velocity
	var angle := (ctx.rng.randf() + ctx.rng.randf() - 1.0) * degrees
	return kick_velocity.rotated(Vector3.UP, deg_to_rad(angle))


## Kicks aimed well to the weak-foot side are less accurate (weak_foot 1..4 stars).
static func weak_foot_mult(player: Player, aim: Vector3) -> float:
	if player.profile == null or player.profile.special_skills.has("rabona"):
		# Rabona: kicks on the weak side are done behind the standing leg, with the good foot.
		return 1.0
	var facing := player.motion.facing
	if rad_to_deg(facing.angle_to(aim)) < StatEffects.num("weak_side_degrees", 35.0):
		return 1.0
	var to_left := facing.cross(aim).y > 0.0
	var weak_is_left := player.preferred_foot != "left"
	if to_left != weak_is_left:
		return 1.0
	var mults: Array = Config.get_value("stat_effects", "weak_foot_error_mult", [2.6, 2.0, 1.5, 1.15])
	return float(mults[clampi(player.weak_foot, 1, mults.size()) - 1])


## Kicks are a little more accurate walking, a little less sprinting or in a knock-on.
static func pace_mult(player: Player) -> float:
	var intent := player.intent
	if intent.knock_on:
		return _num("pace_error_mult_knock_on", 1.2)
	if intent.sprint:
		return _num("pace_error_mult_sprint", 1.15)
	if intent.walk:
		return _num("pace_error_mult_walk", 0.85)
	return 1.0


## Shots stray more from a tight angle (the goal looks narrow) and with the back to the goal.
static func shot_angle_mult(player: Player, ctx: MatchContext, aim: Vector3) -> float:
	var goal_x := player.team.target_goal_x(ctx.court)
	var half := ctx.court.half_goal_width
	var at := Vector2(player.position.x, player.position.z)
	var goal_angle := rad_to_deg(absf((Vector2(goal_x, -half) - at).angle_to(Vector2(goal_x, half) - at)))
	var mult := 1.0
	var tight := maxf(1.0, _num("shot_tight_angle_degrees", 20.0))
	if goal_angle < tight:
		mult *= lerpf(_num("shot_tight_error_mult", 1.6), 1.0, goal_angle / tight)
	var turn := rad_to_deg(player.motion.facing.angle_to(aim))
	if turn > 90.0:
		mult *= lerpf(1.0, _num("shot_turn_error_mult", 1.5), clampf((turn - 90.0) / 90.0, 0.0, 1.0))
	return mult


static func _num(key: String, fallback: float) -> float:
	return float(Config.get_value("player", key, fallback))
