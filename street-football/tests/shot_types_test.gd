extends Node
## Headless checks of the shot types (ShotTypes, Kicks.shoot, KeeperSave, KeeperAI coming out,
## AiShots), run by CI:  godot --headless --path street-football res://tests/shot_types_test.tscn
## Prints one "TEST PASS" / "TEST FAIL" line per check, then "SHOT TYPES TESTS DONE: N failure(s)".
## Players have no profile (neutral stats, no aim error) on the cage court; home attacks +x.

const DT := 1.0 / 60.0
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _failures := 0
var _nodes: Array[Player] = []


func _ready() -> void:
	_test_slide_types()
	_test_low()
	_test_chip()
	_test_curl()
	_test_skill()
	_test_keeper_save()
	_test_keeper_comes_out()
	_test_ai_choice()
	_test_held_shot_type()
	print("SHOT TYPES TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(test_name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("TEST PASS ", test_name)
	else:
		_failures += 1
		print("TEST FAIL ", test_name, " ", detail)


## [ctx, shooter, home, away, keeper]: the shooter holds the ball at `at` facing +x; the away
## keeper stands `keeper_out` m off his line (x = +18 goal).
func _setup(at: Vector3, keeper_out: float = 1.0) -> Array:
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
	away.tuning = AiTuning.for_difficulty("normal")
	home.opponent = away
	away.opponent = home
	var ctx := MatchContext.new()
	ctx.court = CourtData.load_court("cage_concrete")
	ctx.rng.seed = 3
	var shooter := _spawn(home, at)
	var keeper := _spawn(away, Vector3(ctx.court.half_length - keeper_out, 0.0, 0.0))
	keeper.is_keeper = true
	away.keeper = keeper
	ctx.ball = BallPhysics.new()
	ctx.ball.place(at + Vector3(0.4, _radius(), 0.0))
	ctx.add_team(home)
	ctx.add_team(away)
	ctx.possession.take(shooter, ctx.ball)
	return [ctx, shooter, home, away, keeper]


func _spawn(team: Team, pos: Vector3) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	add_child(p)
	p.team = team
	team.players.append(p)
	p.reset_to(pos, Vector3.RIGHT)
	_nodes.append(p)
	return p


## Free flight of the kicked ball (no walls, no keeper): where it crosses the goal line x = 18
## (Vector3.INF if it never does), its highest point before that, and where it first lands.
func _flight(ctx: MatchContext) -> Dictionary:
	var sim := ctx.ball.copy()
	var goal_x := ctx.court.half_length
	var cross := Vector3.INF
	var max_y := sim.position.y
	var landed := Vector3.INF
	var previous := sim.position
	for i in range(240):
		var falling := sim.velocity.y < 0.0
		sim.step(DT)
		if previous.x < goal_x and sim.position.x >= goal_x and cross == Vector3.INF:
			var t := (goal_x - previous.x) / maxf(0.0001, sim.position.x - previous.x)
			cross = previous.lerp(sim.position, t)
		if cross == Vector3.INF:
			max_y = maxf(max_y, sim.position.y)
		if falling and sim.velocity.y >= 0.0 and landed == Vector3.INF:
			landed = sim.position
		previous = sim.position
	return {"cross": cross, "max_y": max_y, "landed": landed}


func _shoot(at: Vector3, type: String, charge: float, keeper_out: float = 1.0) -> Dictionary:
	var setup := _setup(at, keeper_out)
	var ctx: MatchContext = setup[0]
	var shooter: Player = setup[1]
	var goal := Vector3(ctx.court.half_length, 0.0, 0.0)
	Kicks.shoot(shooter.handling, shooter, ctx, goal, charge, type)
	var result := _flight(ctx)
	result["velocity"] = ctx.ball.velocity
	result["from"] = ctx.ball.position
	return result


func _test_slide_types() -> void:
	var ok := HumanInput.shot_type_for(Vector2(0.1, -1.0)) == "chip" and HumanInput.shot_type_for(Vector2(0.0, 1.0)) == "low" \
		and HumanInput.shot_type_for(Vector2(1.0, 0.2)) == "curl" and HumanInput.shot_type_for(Vector2(-1.0, -0.3)) == "curl" \
		and HumanInput.shot_type_for(Vector2.ZERO) == ""
	_check("slide: up chip, down low, left or right curl, none normal", ok)


func _test_low() -> void:
	var low := _shoot(Vector3(6.0, 0.0, 0.0), "low", 0.6)
	var cross: Vector3 = low["cross"]
	_check("low shot: stays on the ground and reaches the goal", float(low["max_y"]) < 0.2 and cross != Vector3.INF
		and absf(cross.z) < 1.5, "max_y=%.2f cross=%s" % [float(low["max_y"]), cross])


func _test_chip() -> void:
	var at := Vector3(6.0, 0.0, 0.0)
	var setup := _setup(at)
	var ctx: MatchContext = setup[0]
	var ideal := ShotTypes.chip_ideal_power(ctx.ball.position, Vector3(ctx.court.half_length, 0.0, 0.0))
	var good := _shoot(at, "chip", ideal)
	var good_cross: Vector3 = good["cross"]
	_check("chip: the right power drops it under the bar", good_cross != Vector3.INF and good_cross.y > 0.3
		and good_cross.y < 1.9, "ideal=%.2f cross=%s" % [ideal, good_cross])
	var strong := _shoot(at, "chip", 1.0)
	var strong_cross: Vector3 = strong["cross"]
	_check("chip: too much power flies over the bar", strong_cross != Vector3.INF and strong_cross.y > 2.2,
		"cross=%s" % strong_cross)
	var soft := _shoot(at, "chip", 0.1)
	var soft_landed: Vector3 = soft["landed"]
	_check("chip: too little power comes down short", soft_landed != Vector3.INF and soft_landed.x < ctx.court.half_length - 2.0,
		"landed=%s" % soft_landed)
	_check("chip: it rises well above a keeper's reach", float(good["max_y"]) > 2.8, "max_y=%.2f" % float(good["max_y"]))


func _test_curl() -> void:
	var at := Vector3(6.0, 0.0, -5.0)
	var setup := _setup(at)
	var ctx: MatchContext = setup[0]
	var shooter: Player = setup[1]
	var ideal := ShotTypes.curl_ideal_power(shooter, ctx)
	var good := _shoot(at, "curl", ideal)
	var cross: Vector3 = good["cross"]
	var v: Vector3 = good["velocity"]
	var from: Vector3 = good["from"]
	var straight_z := from.z + v.z / v.x * (ctx.court.half_length - from.x)
	_check("curl: the right power goes in inside the far post", cross != Vector3.INF and cross.z > 0.3 and cross.z < 1.45
		and cross.y < 1.95, "ideal=%.2f cross=%s" % [ideal, cross])
	_check("curl: it starts wide of the far post and curls back in", straight_z > cross.z + 0.5,
		"straight=%.2f cross=%.2f" % [straight_z, cross.z])
	var soft := _shoot(at, "curl", ideal - 0.25)
	var soft_cross: Vector3 = soft["cross"]
	_check("curl: too little power curls into the middle", soft_cross != Vector3.INF and soft_cross.z < cross.z - 0.3,
		"soft=%s ideal=%s" % [soft_cross, cross])
	var strong := _shoot(at, "curl", ideal + 0.25)
	var strong_cross: Vector3 = strong["cross"]
	_check("curl: too much power goes wider or over the bar", strong_cross != Vector3.INF
		and (strong_cross.z > cross.z + 0.2 or strong_cross.y > 2.0), "strong=%s ideal=%s" % [strong_cross, cross])
	var right := _shoot(Vector3(6.0, 0.0, 5.0), "curl", ideal)
	var right_cross: Vector3 = right["cross"]
	_check("curl: from the other side it curls to the other post", right_cross != Vector3.INF and right_cross.z < -0.3
		and right_cross.z > -1.45, "cross=%s" % right_cross)


func _test_skill() -> void:
	var setup := _setup(Vector3(6.0, 0.0, 0.0))
	var good: Player = setup[1]
	var poor := _spawn(setup[2], Vector3(0.0, 0.0, 3.0))
	good.sheet["shot_error_degrees"] = 0.8
	poor.sheet["shot_error_degrees"] = 6.0
	var good_power := ShotTypes.skilled(good, 0.6, 0.9)
	var poor_power := ShotTypes.skilled(poor, 0.6, 0.9)
	_check("good-power zone: a better finisher's shot stays closer to the ideal power",
		absf(good_power - 0.6) < absf(poor_power - 0.6) - 0.1, "good=%.2f poor=%.2f" % [good_power, poor_power])


func _test_keeper_save() -> void:
	var setup := _setup(Vector3(6.0, 0.0, 0.0))
	var ctx: MatchContext = setup[0]
	var keeper: Player = setup[4]
	ctx.possession.release(ctx.ball)
	var at_him := _save_chance(ctx, keeper, Vector3(20.0, 0.0, 0.0), 0.0)
	var corner := _save_chance(ctx, keeper, Vector3(20.0, 0.0, 5.6), 0.0)
	var slow := _save_chance(ctx, keeper, Vector3(11.0, 0.0, 0.0), 0.0)
	var fast := _save_chance(ctx, keeper, Vector3(26.0, 0.0, 0.0), 0.0)
	var curled := _save_chance(ctx, keeper, Vector3(20.0, 0.0, 0.0), 0.8)
	_check("keeper: a shot at him is saved more often than one in the corner", at_him > corner + 0.15,
		"at_him=%.2f corner=%.2f" % [at_him, corner])
	_check("keeper: a faster shot is saved less often", slow > fast, "slow=%.2f fast=%.2f" % [slow, fast])
	_check("keeper: a curling shot is saved less often", curled < at_him, "curled=%.2f straight=%.2f" % [curled, at_him])


func _save_chance(ctx: MatchContext, keeper: Player, velocity: Vector3, spin: float) -> float:
	ctx.ball.place(Vector3(12.0, 1.0, 0.0))
	ctx.ball.kick(velocity, spin)
	return KeeperSave.chance(keeper, ctx)


func _test_keeper_comes_out() -> void:
	var near := _keeper_line_distance(Vector3(14.0, 0.0, 0.0))
	var far := _keeper_line_distance(Vector3(2.0, 0.0, 0.0))
	_check("keeper: comes off his line as an attacker with the ball closes in", near > far + 0.6,
		"near=%.2f far=%.2f" % [near, far])


## How far off his line the keeper stands after 3 s with an attacker holding the ball at `at`.
func _keeper_line_distance(at: Vector3) -> float:
	var setup := _setup(at)
	var ctx: MatchContext = setup[0]
	var keeper: Player = setup[4]
	for i in range(180):
		keeper.intent = KeeperAI.intent_for(keeper, DT, ctx)
		keeper.move(DT, ctx.court, false)
	return ctx.court.half_length - keeper.position.x


func _test_ai_choice() -> void:
	var setup := _setup(Vector3(8.0, 0.0, 0.0), 3.0)
	var ctx: MatchContext = setup[0]
	var shooter: Player = setup[1]
	var home: Team = setup[2]
	home.tuning.chip_tendency = 1.0
	home.tuning.curl_tendency = 0.0
	home.tuning.low_tendency = 0.0
	var out_choice := AiShots.choose(shooter, ctx, 10.0)
	setup = _setup(Vector3(8.0, 0.0, 0.0), 0.5)
	ctx = setup[0]
	shooter = setup[1]
	home = setup[2]
	home.tuning.chip_tendency = 1.0
	home.tuning.curl_tendency = 0.0
	home.tuning.low_tendency = 0.0
	var line_choice := AiShots.choose(shooter, ctx, 10.0)
	_check("AI: chips a keeper off his line, not one on it", out_choice == "chip" and line_choice == "",
		"out=%s line=%s" % [out_choice, line_choice])
	var charge := AiShots.charge(shooter, ctx, "curl", Vector3.ZERO, 0.5)
	_check("AI: a curled shot gets about the ideal power, below the red end",
		absf(charge - ShotTypes.curl_ideal_power(shooter, ctx)) <= home.tuning.shot_power_error + 0.001 and charge < 0.85,
		"charge=%.2f" % charge)


## SHOOT held with a slide down, then released with no slide: still a low shot (kept from the hold).
func _test_held_shot_type() -> void:
	var setup := _setup(Vector3(6.0, 0.0, 0.0))
	var ctx: MatchContext = setup[0]
	var shooter: Player = setup[1]
	for i in range(31):
		var intent := PlayerIntent.new()
		intent.move = Vector3.RIGHT
		intent.shoot_held = i < 30
		intent.shot_type = "low" if i < 30 else ""
		shooter.intent = intent
		shooter.handling.update(DT, shooter, ctx)
	_check("held SHOOT: the slide's shot type is kept for the release", ctx.possession.holder != shooter
		and absf(ctx.ball.velocity.y) < 0.01 and ctx.ball.velocity.x > 8.0, "v=%s" % ctx.ball.velocity)


func _radius() -> float:
	return float(Config.get_value("ball", "radius", 0.11))
