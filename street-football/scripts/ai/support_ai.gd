class_name SupportAI
extends RefCounted
## AI for players without the ball: receive a pass; with the ball on our side, take the job
## given by the team brain (AttackShape); without it, chase, cover behind the chaser, mark, or
## hold the formation slot. Numbers: data/config/ai.json.


static func intent_for(player: Player, delta: float, ctx: MatchContext, brain: TeamBrain) -> PlayerIntent:
	var possession := ctx.possession
	if possession.holder == null and possession.pass_target == player:
		return Steering.seek(player, ReceiveAssist.intercept_point(player, ctx))
	if AttackRoles.in_possession(player.team, ctx):
		return AttackShape.intent_for(player, ctx, brain)
	if player == brain.chaser:
		return _chase(player, delta, ctx)
	if player == brain.cover:
		return Steering.seek(player, cover_point(player.team, ctx))
	if player.ai.mark != null:
		return Steering.seek(player, _mark_point(player, player.ai.mark, ctx))
	return Steering.seek(player, FormationPositions.slot_target(player, ctx, false))


## Second defender: between the ball and our goal, cover_defend_depth behind the ball (at most
## half way to the goal), so a carrier who beats the chaser meets him next.
static func cover_point(team: Team, ctx: MatchContext) -> Vector3:
	var own_goal := Vector3(team.own_goal_x(ctx.court), 0.0, 0.0)
	var ball := Steering.flat(ctx.ball.position)
	var to_goal := own_goal - ball
	var d := to_goal.length()
	if d < 0.01:
		return own_goal
	return ball + to_goal / d * minf(Steering.num("cover_defend_depth", 4.5), d * 0.5)


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
		if ctx.rng.randf() < player.team.tuning.tackle_attempt_chance * player.stat("tackle_attempt_mult", 1.0):
			intent.tackle_pressed = true
	return intent


static func _mark_point(player: Player, opponent: Player, ctx: MatchContext) -> Vector3:
	var own_goal := Vector3(player.team.own_goal_x(ctx.court), 0.0, 0.0)
	var to_goal := Steering.flat(own_goal - opponent.position)
	if to_goal.length() < 0.01:
		return opponent.position
	return opponent.position + to_goal.normalized() * player.stat("mark_distance", Steering.num("mark_distance", 1.5))
