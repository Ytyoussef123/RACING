class_name KeeperAI
extends RefCounted
## Goalkeeper AI: stays between the ball and the goal, moves across to cover shots,
## rushes loose balls near goal, saves (catch or parry), then passes out. Numbers: data/config/ai.json.


static func intent_for(keeper: Player, delta: float, ctx: MatchContext) -> PlayerIntent:
	var team := keeper.team
	var court := ctx.court
	var ball := ctx.ball
	var possession := ctx.possession
	var state := keeper.ai
	if possession.holder == keeper:
		return _distribute(keeper, delta, ctx)
	state.hold_timer = 0.0
	var goal_x := team.own_goal_x(court)
	var s := team.attack_sign
	var line_offset := Steering.num("keeper_line_offset", 1.0)
	var line_x := goal_x + s * line_offset
	var max_z := court.half_goal_width - Steering.num("keeper_z_inset", 0.2)
	# A ball flying at our goal: get across to where it will cross the keeper's line.
	var v := ball.velocity
	if possession.holder == null and -v.x * s > 3.0:
		var t := (line_x - ball.position.x) / v.x
		if t > 0.0 and t < 1.5:
			var cross_z := clampf(ball.position.z + v.z * t, -max_z - 0.5, max_z + 0.5)
			return Steering.seek(keeper, Vector3(line_x, 0.0, cross_z), true)
	# A loose ball close to goal: come out and take it.
	if possession.holder == null and keeper.flat_distance_to(ball.position) < Steering.num("keeper_rush_distance", 4.0) \
			and team.to_frac(ball.position.x, court) < 0.2:
		return Steering.seek(keeper, ball.position, true)
	# Otherwise stand on the line between the goal center and the ball.
	var goal_center := Vector3(goal_x, 0.0, 0.0)
	var to_ball := Steering.flat(ball.position - goal_center)
	if to_ball.length() < 0.01:
		to_ball = Vector3(s, 0.0, 0.0)
	var target := goal_center + to_ball.normalized() * line_offset
	target.z = clampf(target.z, -max_z, max_z)
	target.x = goal_x + s * maxf(0.4, absf(target.x - goal_x))
	return Steering.seek(keeper, target, false)


## Called every frame before ball handling: one save roll per shot that comes within reach.
static func try_save(keeper: Player, ctx: MatchContext) -> void:
	var possession := ctx.possession
	var ball := ctx.ball
	var state := keeper.ai
	if possession.holder != null or possession.kick_count == state.last_save_kick:
		return
	if possession.last_kicker != null and possession.last_kicker.team == keeper.team:
		return
	var s := keeper.team.attack_sign
	var speed := ball.velocity.length()
	if -ball.velocity.x * s < 1.0 or speed < Steering.num("keeper_save_min_speed", 7.0):
		return
	# Diving decides the reach, reflexes the save chance, handling whether he holds the ball.
	if keeper.flat_distance_to(ball.position) > keeper.stat("keeper_reach", Steering.num("keeper_reach", 1.6)):
		return
	if ball.position.y > Steering.num("keeper_reach_height", 2.3):
		return
	state.last_save_kick = possession.kick_count
	var save_chance := minf(0.97, keeper.team.tuning.keeper_save_chance * keeper.stat("keeper_save_mult", 1.0))
	if ctx.rng.randf() >= save_chance:
		return
	ctx.stats.saves[keeper.team.index] += 1
	keeper.animate_dive(ball.position)
	ctx.emit_event("save", ball.position, speed)
	if speed <= keeper.stat("keeper_catch_speed", Steering.num("keeper_catch_speed", 18.0)):
		ball.place(keeper.position + keeper.motion.facing * 0.5 + Vector3.UP * ball.radius)
		possession.take(keeper, ball)
	else:
		var spread := Steering.num("keeper_parry_spread", 3.0)
		ball.kick(Vector3(-ball.velocity.x * 0.35, Steering.num("keeper_parry_lift", 2.5),
			ball.velocity.z * 0.4 + ctx.rng.randf_range(-spread, spread)), 0.0)
		possession.touched(keeper)
		keeper.handling.block_control(0.4)


## Holding the ball: wait a moment, then pass to the most open teammate.
static func _distribute(keeper: Player, delta: float, ctx: MatchContext) -> PlayerIntent:
	var state := keeper.ai
	var intent := PlayerIntent.new()
	state.hold_timer += delta
	if state.hold_timer < Steering.num("keeper_hold_seconds", 1.0):
		return intent
	state.hold_timer = 0.0
	var target := _best_outlet(keeper, ctx)
	if target != null:
		intent.move = Steering.flat(target.position - keeper.position).normalized()
	else:
		intent.move = Vector3(keeper.team.attack_sign, 0.0, 0.0)
	intent.pass_pressed = true
	return intent


static func _best_outlet(keeper: Player, ctx: MatchContext) -> Player:
	var best: Player = null
	var best_open := -INF
	for mate in keeper.team.outfield():
		var d := keeper.flat_distance_to(mate.position)
		if d < 3.0 or d > 20.0:
			continue
		var open := keeper.team.opponent.nearest_distance_to(mate.position)
		if not CarrierAI.lane_clear(keeper.position, mate.position, keeper.team.opponent):
			open -= 5.0
		if open > best_open:
			best_open = open
			best = mate
	return best
