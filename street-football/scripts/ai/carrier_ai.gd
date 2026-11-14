class_name CarrierAI
extends RefCounted
## AI for the player with the ball: shoot when in range, pass when pressed or a teammate is
## better placed, otherwise dribble toward goal around defenders. Numbers: data/config/ai.json.


static func intent_for(player: Player, delta: float, ctx: MatchContext) -> PlayerIntent:
	var state := player.ai
	var tuning := player.team.tuning
	if state.action == AiPlayerState.Action.SHOOT:
		return _continue_shot(player, delta)
	state.think_timer -= delta
	if state.think_timer <= 0.0 or state.action == AiPlayerState.Action.NONE:
		state.think_timer = tuning.decision_interval
		var decided := _decide(player, ctx)
		if decided != null:
			return decided
	return _dribble_intent(player, ctx)


static func _decide(player: Player, ctx: MatchContext) -> PlayerIntent:
	var team := player.team
	var court := ctx.court
	var tuning := team.tuning
	var state := player.ai
	var goal := Vector3(team.target_goal_x(court), 0.0, 0.0)
	var dist_to_goal := player.flat_distance_to(goal)
	var frac := team.to_frac(player.position.x, court)
	if dist_to_goal < tuning.shoot_range and frac > Steering.num("shot_min_frac", 0.6) and _good_shot(player, ctx, dist_to_goal):
		_start_shot(player, ctx, dist_to_goal)
		return _continue_shot(player, 0.0)
	var pressure := team.opponent.nearest_distance_to(player.position)
	if pressure < tuning.pass_pressure_distance or ctx.rng.randf() < tuning.pass_tendency:
		var target := best_pass(player, ctx)
		if target != null:
			var intent := PlayerIntent.new()
			intent.move = Steering.flat(target.position - player.position).normalized()
			intent.pass_pressed = true
			state.action = AiPlayerState.Action.NONE
			return intent
	state.action = AiPlayerState.Action.DRIBBLE
	return null


## Worth a shot: the goal is not seen at too tight an angle, and no outfield defender stands in
## the shot's path (unless very close to goal).
static func _good_shot(player: Player, ctx: MatchContext, dist_to_goal: float) -> bool:
	var court := ctx.court
	var goal_x := player.team.target_goal_x(court)
	var to_near := Vector2(goal_x - player.position.x, court.half_goal_width - player.position.z)
	var to_far := Vector2(goal_x - player.position.x, -court.half_goal_width - player.position.z)
	if rad_to_deg(absf(to_near.angle_to(to_far))) < Steering.num("shot_min_goal_angle_degrees", 9.0):
		return false
	if dist_to_goal < Steering.num("shot_close_distance", 6.0):
		return true
	var from := Vector2(player.position.x, player.position.z)
	var to := Vector2(goal_x, 0.0)
	var width := Steering.num("shot_lane_width", 0.5)
	for opp in player.team.opponent.outfield():
		var p := Vector2(opp.position.x, opp.position.z)
		if Geometry2D.get_closest_point_to_segment(p, from, to).distance_to(p) < width:
			return false
	return true


static func _start_shot(player: Player, ctx: MatchContext, dist_to_goal: float) -> void:
	var team := player.team
	var court := ctx.court
	var state := player.ai
	var inset := Steering.num("shot_corner_inset", 0.35)
	var corner_z := court.half_goal_width - inset
	var keeper := team.opponent.keeper
	if keeper != null and keeper.position.z > 0.0:
		corner_z = -corner_z
	var aim_point := Vector3(team.target_goal_x(court), 0.0, corner_z)
	var aim := Steering.flat(aim_point - player.position).normalized()
	var error := deg_to_rad(ctx.rng.randf_range(-1.0, 1.0) * team.tuning.shot_error_degrees)
	state.aim = aim.rotated(Vector3.UP, error)
	var charge := lerpf(Steering.num("shot_charge_min", 0.25), Steering.num("shot_charge_max", 0.75),
		clampf(dist_to_goal / team.tuning.shoot_range, 0.0, 1.0))
	state.charge_left = charge * float(Config.get_value("player", "shot_charge_time", 0.9))
	state.action = AiPlayerState.Action.SHOOT


## Holds the shoot button (aiming) until the charge is reached, then releases it.
static func _continue_shot(player: Player, delta: float) -> PlayerIntent:
	var state := player.ai
	var intent := PlayerIntent.new()
	intent.move = state.aim
	state.charge_left -= delta
	if state.charge_left > 0.0:
		intent.shoot_held = true
	else:
		state.action = AiPlayerState.Action.NONE
		state.think_timer = 0.0
	return intent


static func _dribble_intent(player: Player, ctx: MatchContext) -> PlayerIntent:
	var team := player.team
	var court := ctx.court
	var goal := Vector3(team.target_goal_x(court), 0.0, 0.0)
	var dir := Steering.flat(goal - player.position).normalized()
	var avoid_dist := Steering.num("dribble_avoid_distance", 3.0)
	var space := INF
	for opp in team.opponent.players:
		var to := Steering.flat(opp.position - player.position)
		var d := to.length()
		if d < 0.01:
			continue
		if dir.dot(to / d) > 0.3:
			space = minf(space, d)
		if d < avoid_dist and dir.dot(to / d) > 0.2:
			# Step around the defender, to the side away from him.
			var side := Vector3(-dir.z, 0.0, dir.x)
			var away := -signf(side.dot(to))
			if away == 0.0:
				away = 1.0
			dir = (dir + side * away * (1.0 - d / avoid_dist) * 1.2).normalized()
	var margin := Steering.num("wall_margin", 1.5)
	if absf(player.position.z) > court.half_width - margin:
		dir.z -= signf(player.position.z) * 0.6
		dir = dir.normalized()
	var intent := PlayerIntent.new()
	intent.move = dir
	intent.sprint = space > Steering.num("dribble_sprint_space", 4.0)
	return intent


## Best open teammate further up the court with a clear lane, or null.
static func best_pass(player: Player, ctx: MatchContext) -> Player:
	var team := player.team
	var court := ctx.court
	var best: Player = null
	var best_score := Steering.num("pass_min_score", 0.3)
	var my_frac := team.to_frac(player.position.x, court)
	for mate in team.outfield():
		if mate == player:
			continue
		var d := player.flat_distance_to(mate.position)
		if d < Steering.num("pass_min_distance", 3.0) or d > Steering.num("pass_max_distance", 20.0):
			continue
		var openness := minf(team.opponent.nearest_distance_to(mate.position), 5.0)
		var progress := team.to_frac(mate.position.x, court) - my_frac
		var score := progress * 3.0 + openness * 0.3
		if not lane_clear(player.position, mate.position, team.opponent):
			score -= 5.0
		if score > best_score:
			best_score = score
			best = mate
	return best


static func lane_clear(from: Vector3, to: Vector3, opponents: Team) -> bool:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var width := Steering.num("pass_lane_width", 1.0)
	for opp in opponents.players:
		var p := Vector2(opp.position.x, opp.position.z)
		var closest := Geometry2D.get_closest_point_to_segment(p, a, b)
		if closest.distance_to(p) < width:
			return false
	return true
