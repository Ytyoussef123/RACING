class_name RestartPlacer
extends RefCounted
## Puts players and ball in place for kick-offs and for restarts after the ball went out
## (kick-in, corner, goal kick on open courts). Numbers: data/config/match.json.


static func kickoff(ctx: MatchContext, kicking: Team) -> void:
	var court := ctx.court
	ctx.possession.reset(ctx.ball)
	ctx.ball.place(Vector3(0.0, ctx.ball.radius, 0.0))
	for team in ctx.teams:
		team.brain.reset()
		for p in team.players:
			var pos: Vector3
			if p.is_keeper:
				pos = Vector3(team.own_goal_x(court) + team.attack_sign * 1.0, 0.0, 0.0)
			else:
				pos = FormationPositions.kickoff_position(p, court, team == kicking)
			p.reset_to(pos, Vector3(team.attack_sign, 0.0, 0.0))
	var taker := most_attacking(kicking)
	var offset := float(Config.get_value("match", "kickoff_taker_offset", 0.6))
	taker.reset_to(Vector3(-kicking.attack_sign * offset, 0.0, 0.0), Vector3(kicking.attack_sign, 0.0, 0.0))


## Decides the restart after the ball left an open court. Returns {key, team, spot, keeper}.
static func plan_out(ctx: MatchContext) -> Dictionary:
	var court := ctx.court
	var p := ctx.ball.position
	var inset := float(Config.get_value("match", "restart_inset", 0.4))
	var last := ctx.possession.last_touch_team
	if absf(p.x) <= court.half_length:
		var team := _team_not(ctx, last)
		var spot := Vector3(clampf(p.x, -court.half_length + 1.0, court.half_length - 1.0), 0.0,
			signf(p.z) * (court.half_width - inset))
		return {"key": "MSG_KICK_IN", "team": team, "spot": spot, "keeper": false}
	var end_sign := signf(p.x)
	var defending := ctx.teams[0] if ctx.teams[0].own_goal_x(court) * end_sign > 0.0 else ctx.teams[1]
	if last == defending.index:
		var corner := Vector3(end_sign * (court.half_length - inset), 0.0, signf(p.z) * (court.half_width - inset))
		return {"key": "MSG_CORNER", "team": defending.opponent, "spot": corner, "keeper": false}
	var goal_kick := Vector3(defending.own_goal_x(court) + defending.attack_sign * 1.2, 0.0, 0.0)
	return {"key": "MSG_GOAL_KICK", "team": defending, "spot": goal_kick, "keeper": true}


static func apply_restart(ctx: MatchContext, plan: Dictionary) -> void:
	var team: Team = plan["team"]
	var spot: Vector3 = plan["spot"]
	var taker: Player = team.keeper if bool(plan["keeper"]) else team.closest_outfield_to(spot)
	var into := Steering.flat(Vector3.ZERO - spot)
	into = into.normalized() if into.length() > 0.01 else Vector3(team.attack_sign, 0.0, 0.0)
	ctx.possession.reset(ctx.ball)
	ctx.ball.place(spot + Vector3.UP * ctx.ball.radius)
	taker.reset_to(spot - into * 0.6, into)
	ctx.possession.take(taker, ctx.ball)
	var clear := float(Config.get_value("match", "restart_clear_distance", 3.0))
	for opp in team.opponent.players:
		var to := Steering.flat(opp.position - spot)
		if to.length() < clear:
			var push := to.normalized() if to.length() > 0.01 else into
			opp.position = spot + push * clear
			opp.clamp_to_court(ctx.court)


static func _team_not(ctx: MatchContext, team_index: int) -> Team:
	if team_index == 0:
		return ctx.teams[1]
	if team_index == 1:
		return ctx.teams[0]
	return ctx.teams[ctx.rng.randi_range(0, 1)]


static func most_attacking(team: Team) -> Player:
	var best: Player = null
	var best_x := -INF
	for p in team.outfield():
		var x := float(team.formation.slot(p.slot_index).get("x", 0.0))
		if x > best_x:
			best_x = x
			best = p
	return best
