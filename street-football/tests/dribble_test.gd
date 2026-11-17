extends Node
## Headless check that a dribbler never runs past his own ball (the ball left behind him while he
## keeps going), in the situations of a real match: running, sprinting, changing speed, holding a
## kick button, zigzagging, running past an opponent. Prints one "DRIBBLE" line per situation and
## "DRIBBLE TESTS DONE: N failure(s)".

const DT := 1.0 / 60.0
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
## The ball counts as left behind when it is this far behind him (along the way he runs).
const BEHIND := 0.35

var _failures := 0


func _ready() -> void:
	for scenario in ["run", "sprint", "walk", "run_partial", "run_to_sprint", "sprint_to_run", "walk_to_sprint",
			"run_hold_pass", "sprint_hold_pass", "sprint_hold_shoot", "sprint_zigzag", "run_zigzag",
			"sprint_past_opponent", "run_past_opponent", "knock_on",
			"run_onto_ball_beside", "sprint_onto_ball_beside", "sprint_onto_ball_crossing", "run_onto_ball_behind_side"]:
		_scenario(scenario)
	print("DRIBBLE TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(test_name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("TEST PASS ", test_name, " ", detail)
	else:
		_failures += 1
		print("TEST FAIL ", test_name, " ", detail)


## Runs 4 s with the ball and counts the frames where the ball is behind him.
func _scenario(scenario: String) -> void:
	var home := _make_team(0, 1.0)
	var away := _make_team(1, -1.0)
	home.opponent = away
	away.opponent = home
	var player := _spawn(home, Vector3(-18.0, 0.0, 0.0), Vector3.RIGHT)
	var opponent: Player = null
	if scenario.ends_with("past_opponent"):
		# Close to his way but not on the ball (1.5 m aside).
		opponent = _spawn(away, Vector3(-12.0, 0.0, 1.5), Vector3.LEFT)
	var ctx := MatchContext.new()
	ctx.court = CourtData.load_court("cage_concrete")
	ctx.add_team(home)
	ctx.add_team(away)
	ctx.ball = BallPhysics.new()
	var radius := float(Config.get_value("ball", "radius", 0.11))
	ctx.ball.place(Vector3(-17.45, radius, 0.0))
	# Taking a loose ball on the move: lying beside his way, crossing it, or just behind his side.
	var loose := scenario.contains("onto_ball")
	match scenario:
		"run_onto_ball_beside", "sprint_onto_ball_beside":
			ctx.ball.place(Vector3(-14.0, radius, 0.8))
		"sprint_onto_ball_crossing":
			ctx.ball.place(Vector3(-13.0, radius, 3.0))
			ctx.ball.velocity = Vector3(0.0, 0.0, -4.0)
		"run_onto_ball_behind_side":
			ctx.ball.place(Vector3(-17.2, radius, 0.85))
	if not loose:
		ctx.possession.take(player, ctx.ball)
	var taken_at := -1
	var kept := true
	var behind_frames := 0
	var worst := 0.0
	var max_ahead := 0.0
	for i in range(240):
		var t := i * DT
		var intent := PlayerIntent.new()
		intent.move = Vector3.RIGHT
		match scenario:
			"sprint", "sprint_past_opponent", "sprint_hold_pass", "sprint_hold_shoot":
				intent.sprint = true
			"walk":
				intent.walk = true
			"run_partial":
				intent.move = Vector3.RIGHT * 0.75
			"run_to_sprint":
				intent.sprint = t > 1.5
			"sprint_to_run":
				intent.sprint = t < 1.5
			"walk_to_sprint":
				intent.walk = t < 1.5
				intent.sprint = t >= 1.5
			"sprint_zigzag", "run_zigzag":
				intent.sprint = scenario == "sprint_zigzag"
				intent.move = Vector3(1.0, 0.0, 0.6 if int(t / 0.7) % 2 == 0 else -0.6).normalized()
			"knock_on":
				intent.knock_on = true
			"sprint_onto_ball_beside", "sprint_onto_ball_crossing":
				intent.sprint = true
		if scenario.ends_with("hold_pass") and t > 0.8:
			intent.pass_held = true
		if scenario.ends_with("hold_shoot") and t > 0.8:
			intent.shoot_held = true
		player.intent = intent
		if opponent != null:
			opponent.intent = PlayerIntent.new()
		DribbleAssist.adjust(player, ctx)
		player.move(DT, ctx.court, ctx.possession.holder == player)
		player.handling.update(DT, player, ctx)
		if opponent != null:
			opponent.move(DT, ctx.court, false)
			opponent.handling.update(DT, opponent, ctx)
		ctx.ball.step(DT)
		CourtBounds.resolve(ctx.ball, ctx.court)
		if loose and taken_at < 0:
			if ctx.possession.holder == player:
				taken_at = i
			elif i > 150:
				kept = false
				break
			continue
		if ctx.possession.holder != player:
			kept = false
			break
		var vel := Steering.flat(player.motion.velocity)
		# After the first half second (or the first touch of a ball he has just taken).
		if i < (taken_at + 6 if loose else 30) or vel.length() < 1.0:
			continue
		var along := Steering.flat(ctx.ball.position - player.position).dot(vel.normalized())
		max_ahead = maxf(max_ahead, along)
		worst = minf(worst, along)
		if along < -BEHIND:
			behind_frames += 1
	player.queue_free()
	if opponent != null:
		opponent.queue_free()
	var detail := "kept=%s behind_frames=%d most_behind=%.2f max_ahead=%.2f" % [kept, behind_frames, -worst, max_ahead]
	print("DRIBBLE ", scenario, ": ", detail)
	_check("dribble %s: the ball is never left behind" % scenario, kept and behind_frames == 0, detail)


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
