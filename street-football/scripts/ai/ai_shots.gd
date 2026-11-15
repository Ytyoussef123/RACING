class_name AiShots
extends RefCounted
## The AI's shot type and power (ShotTypes): a chip when the keeper is off his line, a curled shot
## from the edge of the box, a low shot close in, each by a chance per difficulty; a chip or curl
## gets the ideal power for its distance, give or take shot_power_error (by difficulty), kept below
## the red end of the bar. Numbers: data/config/ai.json (ai_chip_*, ai_curl_*, ai_low_*).


static func choose(player: Player, ctx: MatchContext, dist_to_goal: float) -> String:
	var tuning := player.team.tuning
	var keeper := player.team.opponent.keeper
	var keeper_out := 0.0
	if keeper != null:
		keeper_out = absf(keeper.position.x - player.team.target_goal_x(ctx.court))
	if keeper_out >= Steering.num("ai_chip_keeper_out", 1.8) \
			and dist_to_goal >= Steering.num("ai_chip_min_distance", 6.0) \
			and dist_to_goal <= Steering.num("ai_chip_max_distance", 15.0) and ctx.rng.randf() < tuning.chip_tendency:
		return "chip"
	if dist_to_goal >= Steering.num("ai_curl_min_distance", 8.0) and dist_to_goal <= Steering.num("ai_curl_max_distance", 16.0) \
			and ctx.rng.randf() < tuning.curl_tendency:
		return "curl"
	if dist_to_goal <= Steering.num("ai_low_max_distance", 8.0) and ctx.rng.randf() < tuning.low_tendency:
		return "low"
	return ""


## The bar's charge for a chip or curl (the ideal power, give or take the difficulty's error), or
## `normal` (the usual charge by distance) for the other shots.
static func charge(player: Player, ctx: MatchContext, type: String, aim_point: Vector3, normal: float) -> float:
	var ideal: float
	if type == "chip":
		ideal = ShotTypes.chip_ideal_power(ctx.ball.position, aim_point)
	elif type == "curl":
		ideal = ShotTypes.curl_ideal_power(player, ctx)
	else:
		return normal
	var error := player.team.tuning.shot_power_error
	var below_red := float(Config.get_value("player", "kick_red_zone", 0.85)) - 0.01
	return clampf(ideal + ctx.rng.randf_range(-error, error), 0.0, below_red)
