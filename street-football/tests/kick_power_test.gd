extends Node
## Headless checks of the power bar for every kick (BallHandling, Kicks, KeeperHands), run by CI:
##   godot --headless --path street-football res://tests/kick_power_test.tscn
## Prints one "TEST PASS" / "TEST FAIL" line per check, then "KICK TESTS DONE: N failure(s)".
## Players have no profile (neutral stats, no aim error) on the cage court; home attacks +x.

const DT := 1.0 / 60.0
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _failures := 0


func _ready() -> void:
	_test_pass_power()
	_test_bar_shows_after_tap()
	_test_through_lead()
	_test_clear_power()
	_test_keeper_kicks()
	_test_shot_red_zone()
	_test_press_keeps_meaning()
	print("KICK TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(test_name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("TEST PASS ", test_name)
	else:
		_failures += 1
		print("TEST FAIL ", test_name, " ", detail)


## [ctx, kicker, mate]: the kicker holds the ball at (0, 0), the mate stands at `mate_at`.
func _setup(mate_at: Vector3) -> Array:
	var team := Team.new()
	team.index = 0
	team.attack_sign = 1.0
	team.tuning = AiTuning.for_difficulty("normal")
	var other := Team.new()
	other.index = 1
	other.attack_sign = -1.0
	other.tuning = team.tuning
	team.opponent = other
	other.opponent = team
	var kicker := _spawn(team, Vector3.ZERO)
	var mate := _spawn(team, mate_at)
	var ctx := MatchContext.new()
	ctx.court = CourtData.load_court("cage_concrete")
	ctx.rng.seed = 5
	ctx.ball = BallPhysics.new()
	ctx.ball.place(Vector3(0.4, _radius(), 0.0))
	ctx.add_team(team)
	ctx.add_team(other)
	ctx.possession.take(kicker, ctx.ball)
	return [ctx, kicker, mate]


func _spawn(team: Team, pos: Vector3) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	add_child(p)
	p.team = team
	team.players.append(p)
	p.reset_to(pos, Vector3.RIGHT)
	return p


func _free(setup: Array) -> void:
	setup[1].queue_free()
	setup[2].queue_free()


## Holds a kick button ("pass", "through" or "clear") for `frames` frames aiming at `aim`, then
## lets go; returns the ball's velocity just after the kick (ZERO if no kick).
func _held_kick(setup: Array, kind: String, frames: int, aim: Vector3) -> Vector3:
	var ctx: MatchContext = setup[0]
	var kicker: Player = setup[1]
	for i in range(frames + 3):
		var intent := PlayerIntent.new()
		intent.aim = aim
		intent.pass_held = kind == "pass" and i < frames
		intent.through_held = kind == "through" and i < frames
		intent.clear_held = kind == "clear" and i < frames
		kicker.intent = intent
		kicker.handling.update(DT, kicker, ctx)
		if ctx.possession.holder != kicker:
			return ctx.ball.velocity
	return Vector3.ZERO


static func _flat_speed(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _test_pass_power() -> void:
	var auto_speed := clampf(7.0 + 0.6 * 10.0, 8.0, 18.0)
	var setup := _setup(Vector3(10.0, 0.0, 0.0))
	var tap := _flat_speed(_held_kick(setup, "pass", 3, Vector3.RIGHT))
	_free(setup)
	_check("power: a tap on PASS keeps the automatic speed", absf(tap - auto_speed) < 0.05,
		"speed=%.2f auto=%.2f" % [tap, auto_speed])
	setup = _setup(Vector3(10.0, 0.0, 0.0))
	# Just past the tap time (0.3 s): the bar has barely started.
	var soft := _flat_speed(_held_kick(setup, "pass", 25, Vector3.RIGHT))
	_free(setup)
	setup = _setup(Vector3(10.0, 0.0, 0.0))
	var strong := _flat_speed(_held_kick(setup, "pass", 70, Vector3.RIGHT))
	_free(setup)
	_check("power: a short hold plays a softer pass than a tap", soft > 7.9 and soft < auto_speed - 2.0, "speed=%.2f" % soft)
	_check("power: a full hold plays a strong pass", strong > 19.5, "speed=%.2f" % strong)
	# The AI presses PASS for one frame: automatic speed, as before.
	setup = _setup(Vector3(10.0, 0.0, 0.0))
	var ctx: MatchContext = setup[0]
	var kicker: Player = setup[1]
	var intent := PlayerIntent.new()
	intent.aim = Vector3.RIGHT
	intent.pass_pressed = true
	kicker.intent = intent
	kicker.handling.update(DT, kicker, ctx)
	var ai := _flat_speed(ctx.ball.velocity)
	_free(setup)
	_check("power: the AI's pass keeps the automatic speed", absf(ai - auto_speed) < 0.05, "speed=%.2f" % ai)


func _test_bar_shows_after_tap() -> void:
	var setup := _setup(Vector3(10.0, 0.0, 0.0))
	var ctx: MatchContext = setup[0]
	var kicker: Player = setup[1]
	var shown_early := false
	var shown_later := false
	var full := 0.0
	for i in range(70):
		var intent := PlayerIntent.new()
		intent.aim = Vector3.RIGHT
		intent.pass_held = true
		kicker.intent = intent
		kicker.handling.update(DT, kicker, ctx)
		if i < 6:
			shown_early = shown_early or kicker.handling.bar_shown()
		shown_later = kicker.handling.bar_shown()
		full = kicker.handling.bar_value()
	_free(setup)
	_check("power bar: hidden during a tap, shown on a hold", not shown_early and shown_later)
	_check("power bar: fills while PASS is held", full > 0.95, "value=%.2f" % full)


func _test_through_lead() -> void:
	var aim := Vector3(2.0, 0.0, 6.0).normalized()
	var setup := _setup(Vector3(2.0, 0.0, 6.0))
	var tap := _held_kick(setup, "through", 3, aim)
	_free(setup)
	setup = _setup(Vector3(2.0, 0.0, 6.0))
	var full := _held_kick(setup, "through", 70, aim)
	_free(setup)
	var tap_dir := Vector2(tap.x, tap.z).normalized()
	var full_dir := Vector2(full.x, full.z).normalized()
	_check("through: holding longer plays the ball further in front of the runner", full_dir.x > tap_dir.x + 0.1,
		"tap=%s full=%s" % [tap_dir, full_dir])


func _test_clear_power() -> void:
	var setup := _setup(Vector3(10.0, 0.0, 0.0))
	var tap := _held_kick(setup, "clear", 3, Vector3.RIGHT)
	_free(setup)
	setup = _setup(Vector3(10.0, 0.0, 0.0))
	var soft := _held_kick(setup, "clear", 22, Vector3.RIGHT)
	_free(setup)
	setup = _setup(Vector3(10.0, 0.0, 0.0))
	var full := _held_kick(setup, "clear", 70, Vector3.RIGHT)
	_free(setup)
	_check("clear: a tap keeps the automatic clearance", absf(_flat_speed(tap) - 17.0) < 0.05 and absf(tap.y - 6.5) < 0.05,
		"v=%s" % tap)
	_check("clear: held, the bar sets its length and height", _flat_speed(soft) < 11.0 and soft.y < 4.5
		and _flat_speed(full) > 19.5 and full.y > 7.4, "soft=%s full=%s" % [soft, full])


func _test_keeper_kicks() -> void:
	var setup := _setup(Vector3(12.0, 0.0, 0.0))
	var keeper: Player = setup[1]
	var mate: Player = setup[2]
	var weak := KeeperHands.long_kick_velocity(keeper, mate, Vector3.RIGHT, 0.0)
	var strong := KeeperHands.long_kick_velocity(keeper, mate, Vector3.RIGHT, 1.0)
	_check("keeper: a long kick goes further with more power", _flat_speed(strong) > _flat_speed(weak) * 2.5,
		"weak=%s strong=%s" % [weak, strong])
	var soft_throw := KeeperHands.throw_velocity(keeper, mate, Vector3.RIGHT, 0.0)
	var hard_throw := KeeperHands.throw_velocity(keeper, mate, Vector3.RIGHT, 1.0)
	_check("keeper: the throw speed follows the bar", absf(_flat_speed(soft_throw) - 6.0) < 0.05
		and absf(_flat_speed(hard_throw) - 16.0) < 0.05, "soft=%s hard=%s" % [soft_throw, hard_throw])
	_free(setup)


## 12 m from goal, straight at the middle: below the red end the shot never clears the crossbar;
## at full power it often does (it rises more, by chance).
func _test_shot_red_zone() -> void:
	var setup := _setup(Vector3(-10.0, 0.0, 0.0))
	var ctx: MatchContext = setup[0]
	var shooter: Player = setup[1]
	var over_high := _count_over(ctx, shooter, 0.8)
	var over_full := _count_over(ctx, shooter, 1.0)
	_free(setup)
	_check("shot: below the red end it never goes over the bar", over_high == 0, "over=%d/40" % over_high)
	_check("shot: in the red end it can go over the bar", over_full >= 10, "over=%d/40" % over_full)


func _count_over(ctx: MatchContext, shooter: Player, charge: float) -> int:
	var court := ctx.court
	var goal := Vector3(court.half_length, 0.0, 0.0)
	var over := 0
	for i in range(40):
		shooter.reset_to(Vector3(goal.x - 12.4, 0.0, 0.0), Vector3.RIGHT)
		ctx.possession = Possession.new()
		ctx.possession.stats = ctx.stats
		ctx.ball.place(Vector3(goal.x - 12.0, _radius(), 0.0))
		ctx.ball.velocity = Vector3.ZERO
		ctx.possession.take(shooter, ctx.ball)
		Kicks.shoot(shooter.handling, shooter, ctx, goal, charge)
		var previous := ctx.ball.position
		for step in range(180):
			ctx.ball.step(DT)
			var now := ctx.ball.position
			if now.x >= goal.x:
				var t := (goal.x - previous.x) / maxf(0.0001, now.x - previous.x)
				if lerpf(previous.y, now.y, t) > court.goal_height + ctx.ball.radius:
					over += 1
				break
			previous = now
	return over


## A press keeps its meaning while held: a PASS pressed on defense (SWITCH) never becomes a pass
## when the ball is won, and is free again once lifted.
func _test_press_keeps_meaning() -> void:
	var input := HumanInput.new(null)
	var first := input._pressed_kind("pass", true, true, "switch")
	var held := input._pressed_kind("pass", false, true, "pass")
	var lifted := input._pressed_kind("pass", false, false, "pass")
	var again := input._pressed_kind("pass", true, true, "pass")
	_check("input: a held button keeps the meaning of its press", first == "switch" and held == "switch"
		and lifted == "" and again == "pass", "%s %s %s %s" % [first, held, lifted, again])


func _radius() -> float:
	return float(Config.get_value("ball", "radius", 0.11))
