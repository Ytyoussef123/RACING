class_name SupportAI
extends RefCounted
## AI for players without the ball: chase, mark, receive a pass, or hold the formation slot
## (getting open when a defender is close). Numbers: data/config/ai.json.


static func intent_for(player: Player, delta: float, ctx: MatchContext, brain: TeamBrain) -> PlayerIntent:
	var possession := ctx.possession
	var team := player.team
	var attacking := possession.holder != null and possession.holder.team == team
	if possession.holder == null and possession.pass_target == player:
		return Steering.seek(player, ReceiveAssist.intercept_point(player, ctx))
	if player == brain.chaser:
		return _chase(player, delta, ctx)
	if not attacking and player.ai.mark != null:
		return Steering.seek(player, _mark_point(player, player.ai.mark, ctx))
	var target := FormationPositions.slot_target(player, ctx, attacking)
	if attacking:
		target = _get_open(player, target, team)
	return Steering.seek(player, target)


static func _chase(player: Player, delta: float, ctx: MatchContext) -> PlayerIntent:
	var possession := ctx.possession
	var carrier := possession.holder
	if carrier == null:
		return Steering.seek(player, ReceiveAssist.intercept_point(player, ctx))
	# Stay goal-side of the ball carrier and try a tackle when close enough.
	var own_goal := Vector3(player.team.own_goal_x(ctx.court), 0.0, 0.0)
	var goal_side := Steering.flat(own_goal - carrier.position).normalized() * 0.6
	var intent := Steering.seek(player, carrier.position + goal_side)
	var state := player.ai
	state.tackle_timer -= delta
	var reach := float(Config.get_value("player", "tackle_reach", 1.3)) * Steering.num("tackle_reach_factor", 0.9)
	if player.flat_distance_to(ctx.ball.position) <= reach and state.tackle_timer <= 0.0:
		state.tackle_timer = Steering.num("tackle_check_interval", 0.4)
		if ctx.rng.randf() < player.team.tuning.tackle_attempt_chance:
			intent.tackle_pressed = true
	return intent


static func _mark_point(player: Player, opponent: Player, ctx: MatchContext) -> Vector3:
	var own_goal := Vector3(player.team.own_goal_x(ctx.court), 0.0, 0.0)
	var to_goal := Steering.flat(own_goal - opponent.position)
	if to_goal.length() < 0.01:
		return opponent.position
	return opponent.position + to_goal.normalized() * Steering.num("mark_distance", 1.5)


## Moves the target away from the nearest defender so the player can receive a pass.
static func _get_open(player: Player, target: Vector3, team: Team) -> Vector3:
	var open_dist := Steering.num("get_open_distance", 2.5)
	for opp in team.opponent.players:
		var to := Steering.flat(target - opp.position)
		var d := to.length()
		if d < open_dist and d > 0.01:
			return target + to / d * Steering.num("get_open_shift", 1.5)
	return target
