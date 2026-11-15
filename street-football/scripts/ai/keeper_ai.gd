class_name KeeperAI
extends RefCounted
## Goalkeeper AI: stays between the ball and the goal (further off his line as a carrier closes
## in: keeper_out_*), moves across to cover shots, rushes loose balls near goal, saves (KeeperSave:
## the chance depends on the shot; catch in his goal area, else parry), then plays it out: a throw
## to a close teammate, a long kick otherwise (KeeperHands). Numbers: data/config/ai.json.


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
	# Otherwise stand on the line between the goal center and the ball, coming off the line as an
	# opponent with the ball closes in (narrows the angle; a chip can then beat him).
	var goal_center := Vector3(goal_x, 0.0, 0.0)
	var to_ball := Steering.flat(ball.position - goal_center)
	if to_ball.length() < 0.01:
		to_ball = Vector3(s, 0.0, 0.0)
	var out := line_offset
	if possession.holder != null and possession.holder.team != team:
		var start := Steering.num("keeper_out_start_distance", 10.0)
		var full := Steering.num("keeper_out_full_distance", 5.0)
		var near := clampf((start - to_ball.length()) / maxf(0.1, start - full), 0.0, 1.0)
		out = lerpf(line_offset, Steering.num("keeper_out_max", 2.5), near)
	var target := goal_center + to_ball.normalized() * minf(out, maxf(line_offset, to_ball.length() * 0.5))
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
	# A ball already behind him (a chip over his head) can no longer be saved.
	if (ball.position.x - keeper.position.x) * s < -Steering.num("keeper_behind_margin", 0.3):
		return
	# Diving decides the reach, reflexes the save chance, handling whether he holds the ball.
	if keeper.flat_distance_to(ball.position) > keeper.stat("keeper_reach", Steering.num("keeper_reach", 1.6)):
		return
	if ball.position.y > Steering.num("keeper_reach_height", 2.3):
		return
	state.last_save_kick = possession.kick_count
	if ctx.rng.randf() >= KeeperSave.chance(keeper, ctx):
		return
	ctx.stats.saves[keeper.team.index] += 1
	keeper.animate_dive(ball.position)
	ctx.emit_event("save", ball.position, speed)
	# He catches only in his own goal area (with his hands); elsewhere he blocks it away.
	if speed <= keeper.stat("keeper_catch_speed", Steering.num("keeper_catch_speed", 18.0)) \
			and KeeperHands.in_area(keeper, ctx):
		possession.take(keeper, ball)
		KeeperHands.take(keeper, ctx)
	else:
		var spread := Steering.num("keeper_parry_spread", 3.0)
		ball.kick(Vector3(-ball.velocity.x * Steering.num("keeper_parry_back", 0.35), Steering.num("keeper_parry_lift", 2.5),
			ball.velocity.z * Steering.num("keeper_parry_side", 0.4) + ctx.rng.randf_range(-spread, spread)), 0.0)
		possession.touched(keeper)
		keeper.handling.block_control(Steering.num("keeper_parry_block_seconds", 0.4))


## Holding the ball: wait a moment, then play it to the most open teammate: a throw when he is
## close, a long kick from the hands otherwise (a pass with the feet after a back-pass).
static func _distribute(keeper: Player, delta: float, ctx: MatchContext) -> PlayerIntent:
	var state := keeper.ai
	var intent := PlayerIntent.new()
	state.hold_timer += delta
	if state.hold_timer < Steering.num("keeper_hold_seconds", 1.0):
		return intent
	state.hold_timer = 0.0
	var target := best_outlet(keeper, ctx)
	intent.move = outlet_direction(keeper, ctx, target)
	var far := target == null or keeper.flat_distance_to(target.position) > Steering.num("keeper_throw_max_distance", 14.0)
	if keeper.ball_in_hands and far:
		intent.through_pressed = true
	else:
		intent.pass_pressed = true
	return intent


## Direction to play the ball out: toward the best outlet, else straight up the court.
static func outlet_direction(keeper: Player, ctx: MatchContext, target: Player = null) -> Vector3:
	if target == null:
		target = best_outlet(keeper, ctx)
	if target != null:
		return Steering.flat(target.position - keeper.position).normalized()
	return Vector3(keeper.team.attack_sign, 0.0, 0.0)


static func best_outlet(keeper: Player, ctx: MatchContext) -> Player:
	var best: Player = null
	var best_open := -INF
	for mate in keeper.team.outfield():
		var d := keeper.flat_distance_to(mate.position)
		if d < Steering.num("keeper_outlet_min_distance", 3.0) or d > Steering.num("keeper_outlet_max_distance", 26.0):
			continue
		var open := keeper.team.opponent.nearest_distance_to(mate.position)
		if not CarrierAI.lane_clear(keeper.position, mate.position, keeper.team.opponent):
			open -= Steering.num("keeper_outlet_blocked_penalty", 5.0)
		if open > best_open:
			best_open = open
			best = mate
	return best
