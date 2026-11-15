extends Node
## Headless checks of the ball in the air (LoftedKick, Kicks.lofted, HeldKick, AirControl, LoftedAI),
## run by CI:  godot --headless --path street-football res://tests/lofted_pass_test.tscn
## Prints one "TEST PASS" / "TEST FAIL" line per check, then "LOFTED TESTS DONE: N failure(s)".
## Players have no profile (neutral stats, no aim error) on the cage court; home attacks +x.

const DT := 1.0 / 60.0
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const KICKER_AT := Vector3(-12.0, 0.0, 0.0)

var _failures := 0
var _nodes: Array[Player] = []


func _ready() -> void:
	_test_held_kick_slide()
	_test_button_slide()
	_test_distance_by_power()
	_test_over_a_defender()
	_test_auto_lands_at_teammate()
	_test_lofted_through()
	_test_air_control()
	_test_ai_switch_of_play()
	print("LOFTED TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(test_name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("TEST PASS ", test_name)
	else:
		_failures += 1
		print("TEST FAIL ", test_name, " ", detail)


## [ctx, kicker, home team, away team]: the kicker holds the ball at KICKER_AT, facing +x.
func _setup() -> Array:
	for p in _nodes:
		p.queue_free()
	_nodes.clear()
	var home := Team.new()
	home.index = 0
	home.attack_sign = 1.0
	home.tuning = AiTuning.for_difficulty("normal")
	var away := Team.new()
	away.index = 1
	away.attack_sign = -1.0
	away.tuning = home.tuning
	home.opponent = away
	away.opponent = home
	var kicker := _spawn(home, KICKER_AT)
	var ctx := MatchContext.new()
	ctx.court = CourtData.load_court("cage_concrete")
	ctx.rng.seed = 9
	ctx.ball = BallPhysics.new()
	ctx.ball.place(KICKER_AT + Vector3(0.4, _radius(), 0.0))
	ctx.add_team(home)
	ctx.add_team(away)
	ctx.possession.take(kicker, ctx.ball)
	return [ctx, kicker, home, away]


func _spawn(team: Team, pos: Vector3) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	add_child(p)
	p.team = team
	team.players.append(p)
	p.reset_to(pos, Vector3.RIGHT)
	_nodes.append(p)
	return p


## Where the kicked ball first comes down (free flight, no walls), and its highest point as it
## passes x = `over_x` (or -1 if it never gets there).
func _flight(ctx: MatchContext, over_x: float = INF) -> Array:
	var sim := ctx.ball.copy()
	var height_at := -1.0
	var previous := sim.position
	for i in range(300):
		var falling := sim.velocity.y < 0.0
		sim.step(DT)
		if height_at < 0.0 and previous.x < over_x and sim.position.x >= over_x:
			height_at = sim.position.y
		previous = sim.position
		if falling and sim.velocity.y >= 0.0:
			break
	return [Vector3(sim.position.x, 0.0, sim.position.z), height_at]


func _test_held_kick_slide() -> void:
	var held := HeldKick.new()
	var released := {}
	for i in range(19):
		var intent := PlayerIntent.new()
		intent.pass_held = i < 18
		intent.pass_lofted = i < 18
		var r := held.update(intent, DT)
		if not r.is_empty():
			released = r
	_check("held kick: PASS slid up and held 0.3 s is a ball in the air with that power",
		bool(released.get("lofted", false)) and absf(float(released.get("power", -1.0)) - 17.0 / 60.0 / 0.6) < 0.02,
		"released=%s" % released)
	# The finger slides up only as it is lifted: still a ball in the air.
	held = HeldKick.new()
	released = {}
	for i in range(6):
		var intent := PlayerIntent.new()
		intent.pass_held = i < 5
		intent.pass_lofted = i == 5
		var r := held.update(intent, DT)
		if not r.is_empty():
			released = r
	_check("held kick: a slide made as the finger is lifted counts", bool(released.get("lofted", false)),
		"released=%s" % released)
	_check("held kick: the bar shows at once for a ball in the air", _bar_at_once())


func _bar_at_once() -> bool:
	var held := HeldKick.new()
	var intent := PlayerIntent.new()
	intent.through_held = true
	intent.through_lofted = true
	held.update(intent, DT)
	held.update(intent, DT)
	return held.shown()


func _test_button_slide() -> void:
	var button := ActionButton.new()
	button.press(0, Vector2(500.0, 500.0))
	button.drag(Vector2(505.0, 430.0))
	var held_slide := button.slide()
	button.release()
	var lifted_slide := button.slide()
	button.press(1, Vector2(300.0, 300.0))
	var new_press := button.slide()
	_check("button: the slide is read while held and as lifted, reset on the next press",
		held_slide.y < -60.0 and lifted_slide == held_slide and new_press == Vector2.ZERO,
		"%s %s %s" % [held_slide, lifted_slide, new_press])


func _test_distance_by_power() -> void:
	var results: Array[float] = []
	for power: float in [0.2, 0.5, 0.9]:
		var setup := _setup()
		var ctx: MatchContext = setup[0]
		var kicker: Player = setup[1]
		_spawn(setup[2], KICKER_AT + Vector3(14.0, 0.0, 0.0))
		Kicks.lofted(kicker.handling, kicker, ctx, Vector3.RIGHT, power, false)
		var landed: Vector3 = _flight(ctx)[0]
		results.append(landed.distance_to(Vector3(ctx.ball.position.x, 0.0, ctx.ball.position.z)))
	var expected: Array[float] = [LoftedKick.distance_for(0.2), LoftedKick.distance_for(0.5), LoftedKick.distance_for(0.9)]
	var ok := true
	for i in range(3):
		ok = ok and absf(results[i] - expected[i]) < 1.0
	_check("lofted: the bar sets where it comes down", ok, "landed=%s expected=%s" % [results, expected])


func _test_over_a_defender() -> void:
	var setup := _setup()
	var ctx: MatchContext = setup[0]
	var kicker: Player = setup[1]
	_spawn(setup[2], KICKER_AT + Vector3(16.0, 0.0, 0.0))
	_spawn(setup[3], KICKER_AT + Vector3(8.0, 0.0, 0.0))
	Kicks.lofted(kicker.handling, kicker, ctx, Vector3.RIGHT, LoftedKick.power_for(16.0), false)
	var height: float = _flight(ctx, KICKER_AT.x + 8.0)[1]
	_check("lofted: it flies over a defender standing half way", height > 2.2, "height=%.2f" % height)


func _test_auto_lands_at_teammate() -> void:
	var setup := _setup()
	var ctx: MatchContext = setup[0]
	var kicker: Player = setup[1]
	var mate := _spawn(setup[2], KICKER_AT + Vector3(12.0, 0.0, 8.0))
	Kicks.lofted(kicker.handling, kicker, ctx, Vector3(12.0, 0.0, 8.0).normalized(), Kicks.AUTO, false)
	var landed: Vector3 = _flight(ctx)[0]
	_check("lofted: with no power given it comes down at the teammate", landed.distance_to(mate.position) < 1.0,
		"landed=%s mate=%s" % [landed, mate.position])
	_check("lofted: the teammate is the pass target (he goes to meet it)", ctx.possession.pass_target == mate)


func _test_lofted_through() -> void:
	var setup := _setup()
	var ctx: MatchContext = setup[0]
	var kicker: Player = setup[1]
	var runner := _spawn(setup[2], KICKER_AT + Vector3(10.0, 0.0, 5.0))
	Kicks.lofted(kicker.handling, kicker, ctx, Vector3(10.0, 0.0, 5.0).normalized(), Kicks.AUTO, true)
	var landed: Vector3 = _flight(ctx)[0]
	_check("lofted through ball: it comes down in the space in front of the runner",
		landed.x > runner.position.x + 2.5, "landed=%s runner=%s" % [landed, runner.position])


func _test_air_control() -> void:
	var setup := _setup()
	var ctx: MatchContext = setup[0]
	var receiver := _spawn(setup[2], Vector3(5.0, 0.0, 0.0))
	ctx.possession = Possession.new()
	ctx.possession.stats = ctx.stats
	ctx.ball.place(Vector3(5.3, 1.2, 0.0))
	ctx.ball.velocity = Vector3(-2.0, -5.0, 0.0)
	var chest := AirControl.reachable(receiver, ctx)
	ctx.ball.place(Vector3(5.3, 2.0, 0.0))
	ctx.ball.velocity = Vector3(-2.0, -5.0, 0.0)
	var too_high := AirControl.reachable(receiver, ctx)
	ctx.ball.place(Vector3(5.3, 1.2, 0.0))
	ctx.ball.velocity = Vector3(-2.0, 3.0, 0.0)
	var rising := AirControl.reachable(receiver, ctx)
	_check("air control: a ball coming down at chest height can be taken", chest and not too_high and not rising,
		"chest=%s high=%s rising=%s" % [chest, too_high, rising])
	receiver.sheet["air_control_chance"] = 1.0
	ctx.ball.place(Vector3(5.3, 1.2, 0.0))
	ctx.ball.velocity = Vector3(-2.0, -5.0, 0.0)
	receiver.handling.update(DT, receiver, ctx)
	_check("air control: a clean first touch takes the ball", ctx.possession.holder == receiver)
	# A hard ball for a player with a poor first touch: it often bounces off him.
	receiver.sheet["air_control_chance"] = 0.0
	var heavy := 0
	var away_ok := true
	for i in range(30):
		ctx.possession = Possession.new()
		ctx.possession.stats = ctx.stats
		ctx.ball.place(Vector3(5.3, 1.2, 0.0))
		ctx.ball.velocity = Vector3(-14.0, -8.0, 0.0)
		if not AirControl.first_touch(receiver, ctx):
			heavy += 1
			away_ok = away_ok and ctx.ball.velocity.x > 0.0
	_check("air control: a poor first touch often bounces off him, away from him", heavy >= 15 and away_ok,
		"heavy=%d/30" % heavy)


func _test_ai_switch_of_play() -> void:
	var setup := _setup()
	var ctx: MatchContext = setup[0]
	var carrier: Player = setup[1]
	var home: Team = setup[2]
	var away: Team = setup[3]
	var near := _spawn(home, KICKER_AT + Vector3(6.0, 0.0, 0.0))
	var far := _spawn(home, KICKER_AT + Vector3(2.0, 0.0, 10.0))
	_spawn(away, KICKER_AT + Vector3(3.0, 0.0, 0.0))
	_spawn(away, KICKER_AT + Vector3(1.0, 0.0, 5.0))
	_spawn(away, KICKER_AT + Vector3(0.0, 0.0, -1.5))
	home.tuning = AiTuning.for_difficulty("normal")
	home.tuning.lofted_tendency = 1.0
	home.tuning.skill_tendency = 0.0
	home.tuning.lofted_power_error = 0.0
	var target := LoftedAI.target(carrier, ctx)
	_check("AI: no ground pass on, the open far teammate gets the ball in the air", target == far and near != null,
		"target=%s" % [str(target.name) if target != null else "none"])
	var intent := CarrierAI._decide(carrier, ctx)
	var expected := LoftedKick.power_for(carrier.flat_distance_to(far.position))
	_check("AI: it plays a lofted pass with the power for his distance", intent != null and intent.pass_pressed
		and intent.pass_lofted and absf(intent.kick_power - expected) < 0.02,
		"intent=%s" % [[intent.pass_lofted, intent.kick_power, expected] if intent != null else "none"])


func _radius() -> float:
	return float(Config.get_value("ball", "radius", 0.11))
