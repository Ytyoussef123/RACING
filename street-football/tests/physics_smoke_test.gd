extends Node
## Headless checks of the ball and player physics, run by CI:
##   godot --headless --path street-football res://tests/physics_smoke_test.tscn
## Prints one "TEST PASS" / "TEST FAIL" line per check, then "TESTS DONE: N failure(s)".
## Not exported in the APK (export filter excludes tests/*).

const DT := 1.0 / 60.0
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _failures := 0


func _ready() -> void:
	_test_rolling_stops()
	_test_bounce_settles()
	_test_side_wall_bounce()
	_test_goal_detected_and_ball_stays_in_net()
	_test_post_bounces_back()
	_test_shot_over_goal_is_no_goal()
	_test_open_court_out()
	_test_dribble_and_shoot_scores()
	_test_shot_on_target()
	_test_clear()
	_test_pass_assist_finds_teammate()
	_test_receive_assist_meets_ball()
	_test_through_pass_leads_receiver()
	_test_touch_dribbling()
	_test_turn_grip()
	_test_double_pull()
	_test_steal_ball_knocked_ahead()
	_test_shoulder_charge()
	_test_skill_moves()
	_test_keeper_hands()
	print("TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(test_name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("TEST PASS ", test_name)
	else:
		_failures += 1
		print("TEST FAIL ", test_name, " ", detail)


func _new_ball(pos: Vector3, vel: Vector3) -> BallPhysics:
	var ball := BallPhysics.new()
	ball.place(pos)
	ball.velocity = vel
	return ball


func _test_rolling_stops() -> void:
	var ball := _new_ball(Vector3(0.0, 0.11, 0.0), Vector3(10.0, 0.0, 0.0))
	var t := 0.0
	while ball.horizontal_speed() > 0.0 and t < 20.0:
		ball.step(DT)
		t += DT
	var x := ball.position.x
	_check("rolling ball stops", t < 20.0 and x > 5.0 and x < 40.0, "t=%.2f x=%.2f" % [t, x])


func _test_bounce_settles() -> void:
	var ball := _new_ball(Vector3(0.0, 2.0, 0.0), Vector3.ZERO)
	var bounced := false
	var max_after := 0.0
	for i in range(600):
		var was_falling := ball.velocity.y < 0.0
		ball.step(DT)
		if was_falling and ball.velocity.y > 0.0:
			bounced = true
		if bounced:
			max_after = maxf(max_after, ball.position.y)
	_check("ball bounces lower and settles", bounced and max_after < 1.2 and ball.is_on_ground(),
		"max_after=%.2f y=%.3f" % [max_after, ball.position.y])


func _test_side_wall_bounce() -> void:
	var court := CourtData.load_court("cage_concrete")
	var ball := _new_ball(Vector3(0.0, ball_radius(), 0.0), Vector3(0.0, 0.0, 12.0))
	var bounced := false
	var inside := true
	for i in range(120):
		ball.step(DT)
		CourtBounds.resolve(ball, court)
		if ball.velocity.z < 0.0:
			bounced = true
		if absf(ball.position.z) > court.half_width - ball.radius + 0.001:
			inside = false
	_check("side wall bounces the ball", bounced and inside)


func _test_goal_detected_and_ball_stays_in_net() -> void:
	var court := CourtData.load_court("cage_concrete")
	var ball := _new_ball(Vector3(court.half_length - 3.0, ball_radius(), 0.0), Vector3(15.0, 0.0, 0.0))
	var goal := 0
	var max_x := 0.0
	for i in range(180):
		ball.step(DT)
		CourtBounds.resolve(ball, court)
		if goal == 0:
			goal = GoalDetector.check(ball, court)
		max_x = maxf(max_x, ball.position.x)
	_check("goal detected at +x", goal == 1, "goal=%d" % goal)
	_check("ball stays in the net", max_x <= court.half_length + court.goal_depth, "max_x=%.2f" % max_x)


func _test_post_bounces_back() -> void:
	var court := CourtData.load_court("cage_concrete")
	var ball := _new_ball(Vector3(court.half_length - 2.0, ball_radius(), court.half_goal_width), Vector3(12.0, 0.0, 0.0))
	var bounced := false
	for i in range(60):
		ball.step(DT)
		CourtBounds.resolve(ball, court)
		if ball.velocity.x < 0.0:
			bounced = true
	_check("post bounces the ball back", bounced)


func _test_shot_over_goal_is_no_goal() -> void:
	var court := CourtData.load_court("cage_concrete")
	var ball := _new_ball(Vector3(court.half_length - 3.0, 3.0, 0.0), Vector3(15.0, 3.0, 0.0))
	var goal := 0
	for i in range(120):
		ball.step(DT)
		CourtBounds.resolve(ball, court)
		goal = maxi(goal, absi(GoalDetector.check(ball, court)))
	_check("shot over the bar is no goal", goal == 0)


func _test_open_court_out() -> void:
	var court := CourtData.load_court("open_lot")
	var ball := _new_ball(Vector3(0.0, ball_radius(), 0.0), Vector3(0.0, 0.0, 15.0))
	var out := false
	for i in range(120):
		ball.step(DT)
		if CourtBounds.resolve(ball, court) == CourtBounds.Event.OUT:
			out = true
			break
	_check("open court reports OUT", out)


## Whole chain: the player runs to the ball, dribbles toward the +x goal and shoots.
func _test_dribble_and_shoot_scores() -> void:
	var court := CourtData.load_court("cage_concrete")
	var player: Player = PLAYER_SCENE.instantiate()
	add_child(player)
	var team := Team.new()
	team.tuning = AiTuning.for_difficulty("normal")
	team.players.append(player)
	player.team = team
	player.reset_to(Vector3(-3.0, 0.0, 0.0), Vector3.RIGHT)
	var ctx := MatchContext.new()
	ctx.court = court
	ctx.ball = _new_ball(Vector3(0.0, ball_radius(), 0.0), Vector3.ZERO)
	var had_ball := false
	var shot_done := false
	var charge_frames := 0
	var goal := 0
	for i in range(900):
		var intent := PlayerIntent.new()
		intent.move = Vector3.RIGHT
		var has_ball := ctx.possession.holder == player
		if has_ball and player.position.x > court.half_length - 8.0 and charge_frames < 20:
			intent.shoot_held = true
			charge_frames += 1
		player.intent = intent
		player.move(DT, court, has_ball)
		player.handling.update(DT, player, ctx)
		had_ball = had_ball or ctx.possession.holder == player
		if charge_frames >= 20 and ctx.possession.holder != player:
			shot_done = true
		ctx.ball.step(DT)
		CourtBounds.resolve(ctx.ball, court)
		goal = GoalDetector.check(ctx.ball, court)
		if goal != 0:
			break
	player.queue_free()
	_check("player takes the ball", had_ball)
	_check("player shoots", shot_done)
	_check("dribble and shot score at +x", goal == 1, "goal=%d ball=%s" % [goal, ctx.ball.position])


## Shot on target ("tir cadre"): shots go at the goal even when the shooter is not lined up.
func _test_shot_on_target() -> void:
	var home := _make_team(0, 1.0)
	var away := _make_team(1, -1.0)
	home.opponent = away
	away.opponent = home
	var ctx := MatchContext.new()
	ctx.court = CourtData.load_court("cage_concrete")
	var half := ctx.court.half_goal_width
	var goal_x := ctx.court.half_length
	var shooter := _spawn(home, Vector3(12.0, 0.0, 6.0), Vector3.BACK)
	var along := ShotAim.target(shooter, ctx, Vector3.BACK)
	_check("shot aim: stick along the goal line still aims inside the goal", along.z > 0.0 and along.z < half,
		"z=%.2f" % along.z)
	var at_post := ShotAim.target(shooter, ctx, (Vector3(goal_x, 0.0, -1.0) - shooter.position).normalized())
	_check("shot aim: aiming at the goal keeps the aim", absf(at_post.z + 1.0) < 0.05, "z=%.2f" % at_post.z)
	var wide := ShotAim.target(shooter, ctx, (Vector3(goal_x, 0.0, 9.0) - shooter.position).normalized())
	_check("shot aim: aiming wide of the goal goes inside the post on that side", wide.z > 0.0 and wide.z < half,
		"z=%.2f" % wide.z)
	var keeper := _spawn(away, Vector3(goal_x - 1.0, 0.0, 0.6), Vector3.LEFT)
	away.keeper = keeper
	var free := ShotAim.target(shooter, ctx, Vector3.ZERO)
	_check("shot aim: no stick aims at the corner away from the keeper", free.z < 0.0 and free.z > -half,
		"z=%.2f" % free.z)
	# A real shot while running along the goal line, stick along the run: it heads on goal.
	ctx.ball = _new_ball(shooter.position + Vector3(0.0, 0.0, 0.45) + Vector3.UP * ball_radius(), Vector3.ZERO)
	ctx.possession.take(shooter, ctx.ball)
	for i in range(14):
		var intent := PlayerIntent.new()
		intent.move = Vector3.BACK
		intent.shoot_held = i < 10
		shooter.intent = intent
		shooter.handling.update(DT, shooter, ctx)
		if ctx.possession.holder != shooter:
			break
	var v := ctx.ball.velocity
	var cross := ctx.ball.position.z + v.z * (goal_x - ctx.ball.position.x) / v.x if v.x > 0.1 else 99.0
	_check("shot on target: running along the goal line, the shot heads on goal", absf(cross) < half,
		"crosses at z=%.2f v=%s" % [cross, v])
	shooter.queue_free()
	keeper.queue_free()


## CLEAR (SHOOT in our own half): a long, high kick, never back toward our own goal.
func _test_clear() -> void:
	var team := _make_team(0, 1.0)
	var player := _spawn(team, Vector3(-10.0, 0.0, 0.0), Vector3.LEFT)
	var ctx := MatchContext.new()
	ctx.court = CourtData.load_court("cage_concrete")
	ctx.ball = _new_ball(Vector3(-10.5, ball_radius(), 0.0), Vector3.ZERO)
	ctx.possession.take(player, ctx.ball)
	var intent := PlayerIntent.new()
	intent.move = Vector3.LEFT
	intent.clear_pressed = true
	player.intent = intent
	player.handling.update(DT, player, ctx)
	var v := ctx.ball.velocity
	_check("clear: long and high, away from our own goal", v.x > 10.0 and v.y > 5.0 and ctx.possession.holder == null,
		"v=%s" % v)
	player.queue_free()


## Pass assist: a teammate 50 degrees off the joystick line still gets the pass;
## with nobody in the cone, the closest direction (up to the assist limit) is used.
func _test_pass_assist_finds_teammate() -> void:
	var team := Team.new()
	team.tuning = AiTuning.for_difficulty("normal")
	var passer: Player = PLAYER_SCENE.instantiate()
	var mate: Player = PLAYER_SCENE.instantiate()
	for p: Player in [passer, mate]:
		add_child(p)
		p.team = team
		team.players.append(p)
	passer.reset_to(Vector3.ZERO, Vector3.RIGHT)
	var angle := deg_to_rad(50.0)
	mate.reset_to(Vector3(cos(angle), 0.0, sin(angle)) * 8.0, Vector3.RIGHT)
	var ctx := MatchContext.new()
	ctx.court = CourtData.load_court("cage_concrete")
	ctx.ball = _new_ball(Vector3(0.5, ball_radius(), 0.0), Vector3.ZERO)
	_check("pass assist: teammate 50 degrees off the line", PassTargeting.choose(passer, Vector3.RIGHT, ctx) == mate)
	angle = deg_to_rad(100.0)
	mate.reset_to(Vector3(cos(angle), 0.0, sin(angle)) * 8.0, Vector3.RIGHT)
	_check("pass assist: fallback to the closest direction", PassTargeting.choose(passer, Vector3.RIGHT, ctx) == mate)
	angle = deg_to_rad(170.0)
	mate.reset_to(Vector3(cos(angle), 0.0, sin(angle)) * 8.0, Vector3.RIGHT)
	_check("pass assist: no pass backwards past the limit", PassTargeting.choose(passer, Vector3.RIGHT, ctx) == null)
	passer.queue_free()
	mate.queue_free()


## Receive assist: a pass rolling past the receiver (not at him) is met and controlled, even
## with the joystick still pushed along the pass direction.
func _test_receive_assist_meets_ball() -> void:
	var team := Team.new()
	team.tuning = AiTuning.for_difficulty("normal")
	var receiver: Player = PLAYER_SCENE.instantiate()
	add_child(receiver)
	receiver.team = team
	team.players.append(receiver)
	receiver.reset_to(Vector3(6.0, 0.0, 3.0), Vector3.LEFT)
	var ctx := MatchContext.new()
	ctx.court = CourtData.load_court("cage_concrete")
	ctx.ball = _new_ball(Vector3(0.0, ball_radius(), 0.0), Vector3(10.0, 0.0, 0.0))
	ctx.possession.pass_target = receiver
	var meet := ReceiveAssist.intercept_point(receiver, ctx)
	_check("receive assist: meeting point is on the ball's path", absf(meet.z) < 0.2 and meet.x > 0.0 and meet.x < 15.0,
		"meet=%s" % meet)
	var got_it := false
	for i in range(180):
		var stick := PlayerIntent.new()
		stick.move = Vector3.RIGHT
		receiver.intent = ReceiveAssist.apply(receiver, stick, ctx)
		receiver.move(DT, ctx.court, false)
		receiver.handling.update(DT, receiver, ctx)
		if ctx.possession.holder == receiver:
			got_it = true
			break
		ctx.ball.step(DT)
		CourtBounds.resolve(ctx.ball, ctx.court)
	receiver.queue_free()
	_check("receive assist: receiver controls the pass", got_it, "ball=%s" % ctx.ball.position)


## Through pass: aimed at the space in front of the receiver (toward the opponent's goal).
func _test_through_pass_leads_receiver() -> void:
	var team := Team.new()
	team.tuning = AiTuning.for_difficulty("normal")
	var passer: Player = PLAYER_SCENE.instantiate()
	var receiver: Player = PLAYER_SCENE.instantiate()
	for p: Player in [passer, receiver]:
		add_child(p)
		p.team = team
		team.players.append(p)
	passer.reset_to(Vector3.ZERO, Vector3.RIGHT)
	receiver.reset_to(Vector3(5.0, 0.0, 3.0), Vector3.RIGHT)
	var ctx := MatchContext.new()
	ctx.court = CourtData.load_court("cage_concrete")
	var v := PassTargeting.through_velocity(passer, receiver, ctx)
	var dir_pass := Vector2(v.x, v.z).normalized()
	var dir_receiver := Vector2(5.0, 3.0).normalized()
	var speed := Vector2(v.x, v.z).length()
	_check("through pass: aimed ahead of the receiver", dir_pass.x > dir_receiver.x + 0.05 and dir_pass.y > 0.0,
		"pass=%s receiver=%s" % [dir_pass, dir_receiver])
	_check("through pass: speed within limits", speed >= 7.0 - 0.01 and speed <= 15.0 + 0.01, "speed=%.2f" % speed)
	passer.queue_free()
	receiver.queue_free()


func _make_team(index: int, attack_sign: float) -> Team:
	var team := Team.new()
	team.index = index
	team.attack_sign = attack_sign
	team.tuning = AiTuning.for_difficulty("normal")
	return team


func _spawn(team: Team, pos: Vector3, facing: Vector3) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	add_child(p)
	p.team = team
	team.players.append(p)
	p.reset_to(pos, facing)
	return p


## Runs with the ball for 3 s in a speed mode ("walk", "run", "sprint", "knock_on"); returns
## [kept the ball all along, max lead of the ball after the first second, touches, average speed
## after the first second].
func _run_with_ball(mode: String) -> Array:
	var team := _make_team(0, 1.0)
	var player := _spawn(team, Vector3(-12.0, 0.0, 0.0), Vector3.RIGHT)
	var ctx := MatchContext.new()
	ctx.court = CourtData.load_court("cage_concrete")
	ctx.ball = _new_ball(Vector3(-11.45, ball_radius(), 0.0), Vector3.ZERO)
	ctx.possession.take(player, ctx.ball)
	var kept := true
	var max_lead := 0.0
	var touches := 0
	var last_speed := 0.0
	var covered := 0.0
	for i in range(180):
		var intent := PlayerIntent.new()
		intent.move = Vector3.RIGHT
		intent.walk = mode == "walk"
		intent.sprint = mode == "sprint"
		intent.knock_on = mode == "knock_on"
		player.intent = intent
		DribbleAssist.adjust(player, ctx)
		player.move(DT, ctx.court, ctx.possession.holder == player)
		player.handling.update(DT, player, ctx)
		ctx.ball.step(DT)
		CourtBounds.resolve(ctx.ball, ctx.court)
		if ctx.possession.holder != player:
			kept = false
			break
		var speed := ctx.ball.horizontal_speed()
		if speed > last_speed + 1.0:
			touches += 1
		last_speed = speed
		if i >= 60:
			max_lead = maxf(max_lead, ctx.ball.position.x - player.position.x)
			covered += player.motion.velocity.x * DT
	player.queue_free()
	return [kept, max_lead, touches, covered / (120.0 * DT)]


## Speed modes with the ball: walking keeps it at the feet, running touches it ahead, sprinting
## keeps it close at speed, the knock-on pushes it a fixed distance ahead and runs onto it faster.
func _test_touch_dribbling() -> void:
	var walk := _run_with_ball("walk")
	var run := _run_with_ball("run")
	var sprint := _run_with_ball("sprint")
	var knock := _run_with_ball("knock_on")
	_check("touch dribble: keeps the ball when running", bool(run[0]))
	_check("touch dribble: several touches, ball goes ahead", int(run[2]) >= 2 and float(run[1]) > 0.6,
		"touches=%d lead=%.2f" % [run[2], run[1]])
	_check("touch dribble: keeps the ball when sprinting", bool(sprint[0]))
	# Walking pace with the ball: the walk speed slowed by dribbling (player.json), give or take 30 %.
	var walk_pace := float(Config.get_value("player", "walk_speed", 1.55)) \
		* float(Config.get_value("player", "dribble_speed_factor", 0.92))
	_check("walk dribble: walking pace, ball kept at the feet", bool(walk[0]) and float(walk[3]) > walk_pace * 0.7
		and float(walk[3]) < walk_pace * 1.3 and float(walk[1]) < 0.8,
		"speed=%.2f pace=%.2f lead=%.2f" % [walk[3], walk_pace, walk[1]])
	_check("sprint dribble: faster than running, ball still close", float(sprint[1]) < 1.0
		and float(sprint[3]) > float(run[3]) * 1.2, "lead=%.2f speed=%.2f run speed=%.2f" % [sprint[1], sprint[3], run[3]])
	_check("knock-on: ball pushed 1 to 1.6 m ahead and caught again", bool(knock[0]) and int(knock[2]) >= 2
		and float(knock[1]) > 1.0 and float(knock[1]) < 1.6, "touches=%d lead=%.2f" % [knock[2], knock[1]])
	_check("knock-on: faster than sprint dribbling", float(knock[3]) > float(sprint[3]) * 1.04,
		"knock-on=%.2f sprint=%.2f" % [knock[3], sprint[3]])


## Turning grip: from full sprint a player turns wider than from a walk.
func _test_turn_grip() -> void:
	var fast := PlayerMotion.new()
	fast.reset(Vector3.RIGHT)
	fast.velocity = Vector3.RIGHT * fast.top_speed(true)
	var slow := PlayerMotion.new()
	slow.reset(Vector3.RIGHT)
	slow.velocity = Vector3.RIGHT * slow.walk_speed()
	for i in range(9):
		fast.step(DT, Vector3.BACK, true, false)
		slow.step(DT, Vector3.BACK, false, false, true)
	var fast_turn := atan2(fast.velocity.z, fast.velocity.x)
	var slow_turn := atan2(slow.velocity.z, slow.velocity.x)
	_check("turning grip: a sprinting player turns wider than a walking one", slow_turn > fast_turn + 0.3,
		"walk=%.2f sprint=%.2f rad" % [slow_turn, fast_turn])


## Joystick double pull: out, back in, out again quickly in the same direction (knock-on); too slow
## or another direction is not one.
func _test_double_pull() -> void:
	var stick := FloatingStick.new()
	stick.radius = 100.0
	stick.dead_zone = 0.12
	stick.begin(0, Vector2.ZERO, 0.0)
	stick.drag(Vector2(100.0, 0.0), 0.05)
	stick.drag(Vector2(30.0, 0.0), 0.15)
	stick.drag(Vector2(100.0, 0.0), 0.3)
	_check("double pull: quick out, in, out is a double pull", stick.consume_double_pull().x > 0.9)
	stick.begin(0, Vector2.ZERO, 1.0)
	stick.drag(Vector2(100.0, 0.0), 1.05)
	stick.drag(Vector2(30.0, 0.0), 1.2)
	stick.drag(Vector2(100.0, 0.0), 1.9)
	_check("double pull: too slow is not a double pull", stick.consume_double_pull() == Vector2.ZERO)
	stick.begin(0, Vector2.ZERO, 3.0)
	stick.drag(Vector2(100.0, 0.0), 3.05)
	stick.drag(Vector2(30.0, 0.0), 3.15)
	stick.drag(Vector2(0.0, 100.0), 3.3)
	_check("double pull: another direction is not a double pull", stick.consume_double_pull() == Vector2.ZERO)


## A ball knocked ahead of its dribbler can be stolen; a ball at his feet cannot.
func _test_steal_ball_knocked_ahead() -> void:
	var home := _make_team(0, 1.0)
	var away := _make_team(1, -1.0)
	var holder := _spawn(home, Vector3.ZERO, Vector3.RIGHT)
	var defender := _spawn(away, Vector3(2.0, 0.0, 0.3), Vector3.LEFT)
	var ctx := MatchContext.new()
	ctx.court = CourtData.load_court("cage_concrete")
	ctx.ball = _new_ball(Vector3(1.5, ball_radius(), 0.0), Vector3(1.0, 0.0, 0.0))
	ctx.possession.take(holder, ctx.ball)
	defender.intent = PlayerIntent.new()
	defender.handling.update(DT, defender, ctx)
	_check("steal: ball knocked ahead is taken by the closer opponent", ctx.possession.holder == defender)
	ctx.ball.place(Vector3(0.5, ball_radius(), 0.0))
	holder.handling.reset()
	defender.handling.reset()
	ctx.possession.take(holder, ctx.ball)
	defender.reset_to(Vector3(1.0, 0.0, 0.3), Vector3.LEFT)
	defender.handling.update(DT, defender, ctx)
	_check("steal: ball at the dribbler's feet is safe", ctx.possession.holder == holder)
	holder.queue_free()
	defender.queue_free()


## Shoulder charge: about 50 % wins with equal strength; out of reach does nothing to the ball.
func _test_shoulder_charge() -> void:
	var home := _make_team(0, 1.0)
	var away := _make_team(1, -1.0)
	var carrier := _spawn(away, Vector3.ZERO, Vector3.LEFT)
	var charger := _spawn(home, Vector3(0.0, 0.0, 1.0), Vector3.LEFT)
	var ctx := MatchContext.new()
	ctx.court = CourtData.load_court("cage_concrete")
	ctx.ball = _new_ball(Vector3(-0.55, ball_radius(), 0.0), Vector3.ZERO)
	ctx.rng.seed = 7
	var wins := 0
	var trials := 200
	for i in range(trials):
		carrier.reset_to(Vector3.ZERO, Vector3.LEFT)
		charger.reset_to(Vector3(0.0, 0.0, 1.0), Vector3.LEFT)
		ctx.ball.place(Vector3(-0.55, ball_radius(), 0.0))
		ctx.possession.reset(ctx.ball)
		ctx.possession.take(carrier, ctx.ball)
		ShoulderCharge.attempt(charger, ctx)
		if ctx.possession.holder == null:
			wins += 1
	var rate := float(wins) / float(trials)
	_check("shoulder charge: about half the duels won at equal strength", rate > 0.35 and rate < 0.65, "rate=%.2f" % rate)
	carrier.reset_to(Vector3.ZERO, Vector3.LEFT)
	charger.reset_to(Vector3(0.0, 0.0, 3.0), Vector3.LEFT)
	ctx.possession.reset(ctx.ball)
	ctx.possession.take(carrier, ctx.ball)
	ShoulderCharge.attempt(charger, ctx)
	_check("shoulder charge: out of reach keeps the ball with the carrier", ctx.possession.holder == carrier)
	charger.strength = 80.0
	carrier.strength = 40.0
	_check("shoulder charge: the stronger player has more chance",
		ShoulderCharge.success_chance(charger, carrier) > ShoulderCharge.success_chance(carrier, charger))
	carrier.queue_free()
	charger.queue_free()


## Sets up a dribbler (with optional special skills) facing +x with the ball at his feet, and an
## optional defender ahead at `defender_distance` (0 = none). Returns [ctx, dribbler, defender].
func _skill_setup(specials: Array, defender_distance: float) -> Array:
	var home := _make_team(0, 1.0)
	var away := _make_team(1, -1.0)
	home.opponent = away
	away.opponent = home
	var dribbler := _spawn(home, Vector3.ZERO, Vector3.RIGHT)
	var profile := PlayerProfile.new()
	profile.short_name = "Test"
	profile.positions = ["WING"]
	profile.skill_moves = 5
	profile.special_skills = specials
	dribbler.profile = profile
	var defender: Player = null
	if defender_distance > 0.0:
		defender = _spawn(away, Vector3(defender_distance, 0.0, 0.0), Vector3.LEFT)
	var ctx := MatchContext.new()
	ctx.court = CourtData.load_court("cage_concrete")
	ctx.ball = _new_ball(Vector3(0.55, ball_radius(), 0.0), Vector3.ZERO)
	ctx.possession.take(dribbler, ctx.ball)
	return [ctx, dribbler, defender]


func _free_setup(setup: Array) -> void:
	for i in [1, 2]:
		if setup[i] != null:
			(setup[i] as Node).queue_free()


func _test_skill_moves() -> void:
	var s := _skill_setup([], 0.0)
	var ctx: MatchContext = s[0]
	var p: Player = s[1]
	var move := SkillMoves.perform(p, ctx, Vector3.RIGHT, 0.0)
	_check("skill: forward flick with nobody close is no move (the knock-on is the double pull)",
		move == "" and ctx.possession.holder == p, "move=%s" % move)
	_free_setup(s)
	s = _skill_setup(["flip_flap"], 0.0)
	ctx = s[0]
	move = SkillMoves.perform(s[1], ctx, Vector3(0.0, 0.0, 1.0), 0.0)
	_check("skill: side flick with flip-flap is an elastico", move == "elastico" and ctx.ball.velocity.z > 3.0,
		"move=%s v=%s" % [move, ctx.ball.velocity])
	_free_setup(s)
	s = _skill_setup(["nutmeg"], 1.2)
	ctx = s[0]
	move = SkillMoves.perform(s[1], ctx, Vector3.RIGHT, 0.0)
	_check("skill: nutmeg through a defender right in front", move == "nutmeg" and (s[2] as Player).ghost_timer > 0.0,
		"move=%s" % move)
	_free_setup(s)
	s = _skill_setup(["rainbow"], 2.5)
	ctx = s[0]
	move = SkillMoves.perform(s[1], ctx, Vector3.RIGHT, 0.0)
	_check("skill: rainbow flick lifts the ball over the defender", move == "rainbow" and ctx.ball.velocity.y > 3.0,
		"move=%s v=%s" % [move, ctx.ball.velocity])
	_free_setup(s)
	s = _skill_setup([], 0.0)
	ctx = s[0]
	p = s[1]
	move = SkillMoves.perform(p, ctx, Vector3.LEFT, 0.0)
	_check("skill: back flick is a drag-back that turns the player", move == "drag_back" and p.motion.facing.x < -0.9,
		"move=%s facing=%s" % [move, p.motion.facing])
	_free_setup(s)
	s = _skill_setup([], 0.0)
	ctx = s[0]
	move = SkillMoves.perform(s[1], ctx, Vector3(0.0, 0.0, 1.0), 0.999)
	_check("skill: a failed move is a bad touch (ball lost)", move == "failed" and ctx.possession.holder == null,
		"move=%s" % move)
	_free_setup(s)


## Goalkeeper with the ball: hands in his area (safe, kept in the area, thrown or kicked long,
## put down with a double tap, thrown after 6 s); a back-pass is played with the feet.
func _test_keeper_hands() -> void:
	var home := _make_team(0, 1.0)
	var away := _make_team(1, -1.0)
	home.opponent = away
	away.opponent = home
	var ctx := MatchContext.new()
	ctx.court = CourtData.load_court("cage_concrete")
	var goal_x := home.own_goal_x(ctx.court)
	var keeper := _spawn(home, Vector3(goal_x + 1.0, 0.0, 0.0), Vector3.RIGHT)
	keeper.is_keeper = true
	home.keeper = keeper
	var mate := _spawn(home, Vector3(goal_x + 9.0, 0.0, 2.0), Vector3.LEFT)
	ctx.ball = _new_ball(Vector3(goal_x + 1.5, ball_radius(), 0.0), Vector3.ZERO)
	keeper.intent = PlayerIntent.new()
	keeper.handling.update(DT, keeper, ctx)
	keeper.handling.update(DT, keeper, ctx)
	_check("keeper: a ball he picks up in his area is in his hands", keeper.ball_in_hands
		and ctx.possession.holder == keeper and ctx.ball.position.y > 0.7, "y=%.2f" % ctx.ball.position.y)
	_check("keeper: with the ball in his hands nobody can tackle him", TackleRules.is_protected(keeper, ctx))
	for i in range(120):
		var walk := PlayerIntent.new()
		walk.move = Vector3.RIGHT
		keeper.intent = walk
		keeper.move(DT, ctx.court, true)
		keeper.handling.update(DT, keeper, ctx)
	var depth := ctx.court.number("goal_area_depth", 3.0)
	_check("keeper: with the ball in his hands he stays in his area", keeper.ball_in_hands
		and keeper.position.x - goal_x <= depth + 0.01, "from line=%.2f" % (keeper.position.x - goal_x))
	var kick := PlayerIntent.new()
	kick.move = Vector3.RIGHT
	kick.through_pressed = true
	keeper.intent = kick
	keeper.handling.update(DT, keeper, ctx)
	_check("keeper: a long kick from his hands goes high and far", ctx.possession.holder == null
		and ctx.ball.velocity.y > 5.0 and ctx.ball.velocity.x > 6.0, "v=%s" % ctx.ball.velocity)
	# A back-pass from a teammate: played with the feet, and then he can be tackled.
	_reset_keeper(keeper, ctx, goal_x)
	ctx.possession.kicked(mate, keeper, ctx.ball, "pass")
	keeper.handling.update(DT, keeper, ctx)
	_check("keeper: a back-pass is played with his feet", ctx.possession.holder == keeper and not keeper.ball_in_hands)
	_check("keeper: with the ball at his feet he can be tackled", not TackleRules.is_protected(keeper, ctx))
	# In his hands again, then a double tap puts the ball down.
	_reset_keeper(keeper, ctx, goal_x)
	keeper.handling.update(DT, keeper, ctx)
	var drop := PlayerIntent.new()
	drop.drop_ball = true
	keeper.intent = drop
	keeper.handling.update(DT, keeper, ctx)
	_check("keeper: a double tap puts the ball down at his feet", not keeper.ball_in_hands
		and ctx.possession.holder == keeper and ctx.ball.position.y < 0.3, "y=%.2f" % ctx.ball.position.y)
	# Held too long: after 6 s he throws it to the teammate.
	_reset_keeper(keeper, ctx, goal_x)
	var thrown := false
	for i in range(int(6.6 / DT)):
		keeper.intent = PlayerIntent.new()
		keeper.handling.update(DT, keeper, ctx)
		if ctx.possession.holder != keeper and i > 1:
			thrown = true
			break
	_check("keeper: after 6 s in his hands he throws the ball", thrown and ctx.ball.velocity.x > 0.0,
		"v=%s" % ctx.ball.velocity)
	keeper.queue_free()
	mate.queue_free()


## Keeper back in front of his goal with a loose ball at his feet, nobody's pass on record.
func _reset_keeper(keeper: Player, ctx: MatchContext, goal_x: float) -> void:
	keeper.reset_to(Vector3(goal_x + 1.0, 0.0, 0.0), Vector3.RIGHT)
	keeper.intent = PlayerIntent.new()
	ctx.possession = Possession.new()
	ctx.possession.stats = ctx.stats
	ctx.ball.place(Vector3(goal_x + 1.5, ball_radius(), 0.0))


func ball_radius() -> float:
	return float(Config.get_value("ball", "radius", 0.11))
