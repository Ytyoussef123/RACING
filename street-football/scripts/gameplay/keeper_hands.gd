class_name KeeperHands
extends RefCounted
## The goalkeeper with the ball in his hands. He takes it in his hands when he catches a shot or
## picks up a loose ball inside his own goal area, but not a back-pass from a teammate (that one
## he plays with his feet), and at a goal kick. With the ball in his hands nobody can tackle him
## and he cannot leave his goal area; he throws it (PASS), kicks it long (THROUGH), clears it
## (SHOOT), or puts it down at his feet (joystick double tap) to play like any player. After
## keeper_hands_seconds he throws it to the best teammate (BallHandling).
## Numbers: data/config/player.json (keeper_hands_*, keeper_throw_*, keeper_long_kick_*).


## Inside his own goal area (court goal_area_depth from the goal line, goal_area_width wide).
static func in_area(player: Player, ctx: MatchContext) -> bool:
	var court := ctx.court
	var from_line := (player.position.x - player.team.own_goal_x(court)) * player.team.attack_sign
	return from_line <= court.number("goal_area_depth", 3.0) \
		and absf(player.position.z) <= court.number("goal_area_width", 7.0) * 0.5


## May this keeper take the ball in his hands now? In his area, and not a back-pass.
static func may_handle(keeper: Player, ctx: MatchContext) -> bool:
	if not keeper.is_keeper or not in_area(keeper, ctx):
		return false
	var possession := ctx.possession
	var kicker := possession.last_kicker
	var back_pass := possession.last_kick_kind == "pass" and kicker != null and kicker != keeper \
		and kicker.team == keeper.team
	return not back_pass


## Takes the ball in his hands (catch, pick-up, goal kick).
static func take(keeper: Player, ctx: MatchContext) -> void:
	keeper.ball_in_hands = true
	keeper.hands_time = 0.0
	hold(keeper, ctx)


## The ball held in front of his chest, never over his own goal line.
static func hold(keeper: Player, ctx: MatchContext) -> void:
	var ball := ctx.ball
	var s := keeper.team.attack_sign
	var goal_x := keeper.team.own_goal_x(ctx.court)
	var at := keeper.position + keeper.motion.facing * _num("keeper_hands_forward", 0.3)
	var margin := _num("keeper_hands_line_margin", 0.3)
	if (at.x - goal_x) * s < margin:
		at.x = goal_x + s * margin
	ball.controlled = true
	ball.position = Vector3(at.x, _num("keeper_hands_height", 1.0), at.z)
	ball.velocity = Vector3(keeper.motion.velocity.x, 0.0, keeper.motion.velocity.z)


## Puts the ball down at his feet: from now on he plays it like any player.
static func drop(keeper: Player, ctx: MatchContext) -> void:
	keeper.ball_in_hands = false
	var ball := ctx.ball
	var feet := keeper.position + keeper.motion.facing * _num("dribble_distance", 0.48)
	ball.place(Vector3(feet.x, ball.radius, feet.z))
	ball.velocity = Vector3(keeper.motion.velocity.x, 0.0, keeper.motion.velocity.z)
	ball.controlled = true


## With the ball in his hands he stays inside his goal area.
static func clamp_to_area(keeper: Player, court: CourtData) -> void:
	var s := keeper.team.attack_sign
	var goal_x := keeper.team.own_goal_x(court)
	var depth := court.number("goal_area_depth", 3.0)
	var half_w := court.number("goal_area_width", 7.0) * 0.5
	if (keeper.position.x - goal_x) * s > depth:
		keeper.position.x = goal_x + s * depth
		if keeper.motion.velocity.x * s > 0.0:
			keeper.motion.velocity.x = 0.0
	if absf(keeper.position.z) > half_w:
		var side := signf(keeper.position.z)
		keeper.position.z = side * half_w
		if keeper.motion.velocity.z * side > 0.0:
			keeper.motion.velocity.z = 0.0


## Throw: a short, low, accurate ball from the hands, to a teammate or along the aim.
static func throw_velocity(keeper: Player, target: Player, aim: Vector3) -> Vector3:
	var flat: Vector3
	if target != null:
		flat = PassTargeting.pass_velocity(keeper, target)
		flat.y = 0.0
	else:
		flat = aim * _num("pass_speed", 11.0)
	return flat + Vector3.UP * _num("keeper_throw_lift", 1.5)


## Long kick from the hands: high, landing near the teammate (or far along the aim).
static func long_kick_velocity(keeper: Player, target: Player, aim: Vector3) -> Vector3:
	var lift := _num("keeper_long_kick_lift", 7.0)
	if target == null:
		return aim * _num("keeper_long_kick_space_speed", 16.0) + Vector3.UP * lift
	var to := Steering.flat(target.position - keeper.position)
	var flight := 2.0 * lift / maxf(1.0, float(Config.get_value("ball", "gravity", 9.81)))
	var speed := clampf(to.length() * _num("keeper_long_kick_landing", 0.9) / flight,
		_num("keeper_long_kick_speed_min", 8.0), _num("keeper_long_kick_speed_max", 20.0))
	return to.normalized() * speed + Vector3.UP * lift


static func _num(key: String, fallback: float) -> float:
	return float(Config.get_value("player", key, fallback))
