extends Node
## Headless checks of the team movement AI (AttackRoles, AttackShape, TeamBrain, CarrierAI), run by CI:
##   godot --headless --path street-football res://tests/team_ai_test.tscn
## Prints one "TEST PASS" / "TEST FAIL" line per check, then "TEAM AI TESTS DONE: N failure(s)".
## Two 1-2-1 sides on the cage court (42 x 25 m); home attacks +x.

const DT := 1.0 / 60.0
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _failures := 0
var _ctx: MatchContext
var _home: Team
var _away: Team


func _ready() -> void:
	_build()
	_test_possession()
	_test_jobs()
	_test_spacing()
	_test_run_in_behind()
	_test_through_pass_to_runner()
	_test_give_and_go()
	_test_keeper_ball_no_jobs()
	_test_defense_cover_and_marks()
	_test_press_loose_ball()
	_test_after_pass()
	_test_brains_run()
	print("TEAM AI TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(test_name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("TEST PASS ", test_name)
	else:
		_failures += 1
		print("TEST FAIL ", test_name, " ", detail)


func _build() -> void:
	_ctx = MatchContext.new()
	_ctx.court = CourtData.load_court("cage_concrete")
	_ctx.rng.seed = 7
	_ctx.ball = BallPhysics.new()
	_home = _make_team(0, 1.0)
	_away = _make_team(1, -1.0)
	_home.opponent = _away
	_away.opponent = _home
	_ctx.add_team(_home)
	_ctx.add_team(_away)


## Five players in the 1-2-1 slots (GK, DEF, MID, MID, ATT), no profiles (neutral stats).
func _make_team(index: int, attack_sign: float) -> Team:
	var team := Team.new()
	team.index = index
	team.attack_sign = attack_sign
	team.tuning = AiTuning.for_difficulty("normal")
	team.formation = FormationData.load_formation("1-2-1")
	for i in range(5):
		var p: Player = PLAYER_SCENE.instantiate()
		add_child(p)
		p.team = team
		team.players.append(p)
	team.assign_slots()
	team.brain = TeamBrain.new(team)
	return team


## Puts players where given ([x, z] per player, keeper first) and gives the ball to `carrier`
## (or leaves it loose at `ball_at` when carrier is null).
func _place(home: Array, away: Array, carrier: Player, ball_at: Vector3 = Vector3.ZERO) -> void:
	for i in range(5):
		_home.players[i].reset_to(Vector3(float(home[i][0]), 0.0, float(home[i][1])), Vector3.RIGHT)
		_away.players[i].reset_to(Vector3(float(away[i][0]), 0.0, float(away[i][1])), Vector3.LEFT)
	_ctx.possession = Possession.new()
	_ctx.possession.stats = _ctx.stats
	_ctx.ball.velocity = Vector3.ZERO
	var radius := float(Config.get_value("ball", "radius", 0.11))
	if carrier != null:
		_ctx.ball.place(carrier.position + carrier.motion.facing * 0.5 + Vector3.UP * radius)
		_ctx.possession.take(carrier, _ctx.ball)
	else:
		_ctx.ball.place(Vector3(ball_at.x, radius, ball_at.z))
	for team in _ctx.teams:
		team.brain.reset()
		team.brain.kick_seen = _ctx.possession.kick_count


## Home in possession in midfield: DEF deep, MID wide right, ATT high left; away defends.
func _attack_setup() -> void:
	_place([[-17, 0], [-8, 1], [0, 0], [3, -5], [9, 6]],
		[[17, 0], [8, -2], [10, 3], [5, 0], [2, -6]], _home.players[2])


func _test_possession() -> void:
	_attack_setup()
	var carrier := _home.players[2]
	_check("possession: our holder means attacking", AttackRoles.in_possession(_home, _ctx)
		and not AttackRoles.in_possession(_away, _ctx))
	_ctx.possession.kicked(carrier, _home.players[3], _ctx.ball, "pass")
	_check("possession: our pass on its way still means attacking", AttackRoles.in_possession(_home, _ctx)
		and AttackRoles.carrier_of(_home, _ctx) == _home.players[3] and not AttackRoles.in_possession(_away, _ctx))
	_ctx.possession.touched(_away.players[3])
	_check("possession: a pass cut out by the other side is a loose ball", not AttackRoles.in_possession(_home, _ctx)
		and not AttackRoles.in_possession(_away, _ctx))


func _test_jobs() -> void:
	_attack_setup()
	var carrier := _home.players[2]
	AttackRoles.assign(_home.brain, _ctx, null)
	var def_p := _home.players[1]
	var mid_p := _home.players[3]
	var att_p := _home.players[4]
	_check("jobs: the deep defender covers", def_p.ai.attack_role == AiPlayerState.AttackRole.COVER,
		"role=%d" % def_p.ai.attack_role)
	_check("jobs: the midfielder supports", mid_p.ai.attack_role == AiPlayerState.AttackRole.SUPPORT,
		"role=%d" % mid_p.ai.attack_role)
	_check("jobs: the striker plays forward", att_p.ai.attack_role == AiPlayerState.AttackRole.FORWARD,
		"role=%d" % att_p.ai.attack_role)
	_check("jobs: the carrier and the keeper have none", carrier.ai.attack_role == AiPlayerState.AttackRole.NONE
		and _home.players[0].ai.attack_role == AiPlayerState.AttackRole.NONE)
	var support := AttackShape.support_spot(carrier, _ctx, _home.brain.support_angle)
	var d := carrier.flat_distance_to(support)
	_check("support: 5 to 8 m from the carrier with a clear lane", d >= 5.0 and d <= 8.0
		and CarrierAI.lane_clear(carrier.position, support, _away), "spot=%s d=%.2f" % [support, d])
	var forward := AttackShape.forward_spot(_home, _ctx, _home.brain.forward_side)
	var line_x := _home.frac_to_x(AttackShape.last_defender_frac(_home, _ctx), _ctx.court)
	_check("forward: level with the last defender and wide", absf(forward.x - line_x) < 2.0
		and absf(forward.z) > 4.0, "spot=%s line=%.2f" % [forward, line_x])
	var cover := AttackShape.cover_spot(_home, _ctx, _home.brain.forward_side)
	_check("cover: well behind the ball", cover.x < _ctx.ball.position.x - 6.0, "spot=%s" % cover)
	# Ball deep in our half: the cover comes level and across, not at the carrier's heels.
	var deep_ball := _ctx.ball.position
	_ctx.ball.place(Vector3(-13.0, deep_ball.y, -3.0))
	var deep := AttackShape.cover_spot(_home, _ctx, 1.0)
	_ctx.ball.place(deep_ball)
	_check("cover: with the ball deep he stands across, away from it", Vector2(deep.x + 13.0, deep.z + 3.0).length() > 5.0
		and deep.z > 2.0, "spot=%s" % deep)
	var spots: Array[Vector3] = [support, forward, cover]
	var closest := INF
	for i in range(spots.size()):
		for j in range(i + 1, spots.size()):
			closest = minf(closest, spots[i].distance_to(spots[j]))
	_check("jobs: the three spots are well apart (4.5 m or more)", closest >= 4.5, "closest=%.2f" % closest)


func _test_spacing() -> void:
	_attack_setup()
	var p := _home.players[3]
	var mate := _home.players[4]
	var target := mate.position + Vector3(0.0, 0.0, -1.0)
	var spaced := AttackShape.spaced(p, target, _ctx)
	_check("spacing: a spot 1 m from a teammate is pushed away", mate.flat_distance_to(spaced) > 3.0,
		"d=%.2f" % mate.flat_distance_to(spaced))
	var open := AttackShape.get_open(_away.players[3].position + Vector3(0.0, 0.0, 1.0), _home)
	_check("get open: a spot next to a defender moves away from him", _away.players[3].flat_distance_to(open) > 2.0,
		"d=%.2f" % _away.players[3].flat_distance_to(open))
	# On the way to his spot he goes around the carrier, not through him.
	var carrier := _home.players[2]
	p.reset_to(carrier.position + Vector3(-5.0, 0.0, -0.5), Vector3.RIGHT)
	var beyond := carrier.position + Vector3(5.0, 0.0, 0.0)
	var step := AttackShape.around_carrier(p, beyond, carrier)
	_check("detour: the way through the carrier goes around him", step != beyond
		and carrier.flat_distance_to(step) >= 3.0, "step=%s" % step)
	var clear := carrier.position + Vector3(0.0, 0.0, -8.0)
	_check("detour: a clear way is kept", AttackShape.around_carrier(p, clear, carrier) == clear)


func _test_run_in_behind() -> void:
	_attack_setup()
	var att_p := _home.players[4]
	_home.tuning.run_rate = 1000.0
	AttackRoles.assign(_home.brain, _ctx, null)
	_home.tuning.run_rate = AiTuning.for_difficulty("normal").run_rate
	var line_x := _home.frac_to_x(AttackShape.last_defender_frac(_home, _ctx), _ctx.court)
	var spot := AttackShape.run_spot(att_p, _ctx)
	_check("run: the forward starts a run in behind", att_p.ai.run_left > 0.0, "run_left=%.2f" % att_p.ai.run_left)
	_check("run: the run goes past the last defender", spot.x > line_x + 2.0, "spot=%s line=%.2f" % [spot, line_x])
	var intent := AttackShape.intent_for(att_p, _ctx, _home.brain)
	_check("run: the runner sprints toward goal", intent.sprint and intent.move.x > 0.5, "move=%s" % intent.move)
	_ctx.possession.kicked(_home.players[2], att_p, _ctx.ball, "pass")
	_ctx.possession.touched(_away.players[1])
	_home.brain.update(DT, _ctx, null)
	_check("run: losing the ball ends the run", att_p.ai.run_left <= 0.0 and att_p.ai.run_cooldown > 0.0)


func _test_through_pass_to_runner() -> void:
	_attack_setup()
	var carrier := _home.players[2]
	var att_p := _home.players[4]
	att_p.ai.run_left = 2.0
	att_p.motion.velocity = Vector3(5.0, 0.0, 0.0)
	_home.tuning.through_tendency = 1.0
	var intent := CarrierAI._decide(carrier, _ctx)
	_home.tuning.through_tendency = AiTuning.for_difficulty("normal").through_tendency
	var to_runner := Steering.flat(att_p.position - carrier.position).normalized()
	_check("through pass: the carrier finds the runner", intent != null and intent.through_pressed
		and intent.move.dot(to_runner) > 0.99, "intent=%s" % [intent.move if intent != null else Vector3.ZERO])
	att_p.ai.run_left = 0.0
	att_p.motion.velocity = Vector3.ZERO


func _test_give_and_go() -> void:
	_attack_setup()
	var passer := _home.players[2]
	_home.tuning.give_go_chance = 1.0
	_ctx.possession.kicked(passer, _home.players[3], _ctx.ball, "pass")
	AttackRoles.tick(_home.brain, DT, _ctx)
	_home.tuning.give_go_chance = AiTuning.for_difficulty("normal").give_go_chance
	_check("give-and-go: the passer runs forward after his pass", passer.ai.go_left > 0.0
		and passer.ai.go_target.x > passer.position.x + 5.0, "go=%.2f target=%s" % [passer.ai.go_left, passer.ai.go_target])
	var intent := AttackShape.intent_for(passer, _ctx, _home.brain)
	_check("give-and-go: he sprints into the space", intent.sprint and intent.move.x > 0.5, "move=%s" % intent.move)
	# The last man back does not go: he stays behind the ball.
	_attack_setup()
	var deep := _home.players[1]
	_home.tuning.give_go_chance = 1.0
	_ctx.possession.kicked(deep, _home.players[2], _ctx.ball, "pass")
	AttackRoles.tick(_home.brain, DT, _ctx)
	_home.tuning.give_go_chance = AiTuning.for_difficulty("normal").give_go_chance
	_check("give-and-go: never by the last man back", deep.ai.go_left <= 0.0)


func _test_keeper_ball_no_jobs() -> void:
	_attack_setup()
	_ctx.possession.take(_home.players[0], _ctx.ball)
	AttackRoles.assign(_home.brain, _ctx, null)
	var none := true
	for p in _home.outfield():
		none = none and p.ai.attack_role == AiPlayerState.AttackRole.NONE
	_check("keeper's ball: everyone takes his formation slot (no jobs)", none)


func _test_defense_cover_and_marks() -> void:
	# Away attacks toward the home goal (x = -18) with the ball at (-5, 0).
	_place([[-17, 0], [-8, 0], [-3, 2], [0, -4], [4, 5]],
		[[17, 0], [-12, 4], [-9, -5], [-5, 0], [2, 0]], _away.players[3])
	_home.brain.update(DT, _ctx, null)
	var brain := _home.brain
	_check("defense: the nearest player presses", brain.chaser == _home.players[1],
		"chaser=%s" % [str(brain.chaser.name) if brain.chaser != null else "none"])
	_check("defense: the player nearest the cover point covers behind him", brain.cover == _home.players[2],
		"cover=%s" % [str(brain.cover.name) if brain.cover != null else "none"])
	var cover := SupportAI.cover_point(_home, _ctx)
	_check("defense: the cover stands between the ball and our goal", cover.x < _ctx.ball.position.x - 3.0
		and absf(cover.z) < 1.0, "cover=%s" % cover)
	var marked := [_home.players[3].ai.mark, _home.players[4].ai.mark]
	_check("defense: the two most dangerous opponents are marked, without crossing", marked.has(_away.players[1])
		and marked.has(_away.players[2]) and _home.players[3].ai.mark == _away.players[2],
		"marks=%s / %s" % [_home.players[3].ai.mark, _home.players[4].ai.mark])
	_check("defense: the presser and the cover mark nobody", brain.chaser != null and brain.cover != null
		and brain.chaser.ai.mark == null and brain.cover.ai.mark == null)


## Both brains drive every player for 2 s of a loose ball, an attack and a defense without errors.
## A loose ball is there to be won whoever touched it last: the human's buttons are the defense
## ones and PRESS (no stick) runs his player to the ball; his own pass on its way keeps the attack ones.
func _test_press_loose_ball() -> void:
	_place([[-17, 0], [-8, 1], [0, 0], [3, -5], [9, 6]],
		[[17, 0], [12, -2], [12, 3], [14, 0], [10, -6]], null, Vector3(4.0, 0.0, 0.0))
	var human := HumanControl.new(_home)
	var player := _home.players[2]
	human.select(player)
	_ctx.possession.last_touch_team = _home.index
	_check("press: a loose ball we touched last shows the defense buttons", not human.is_attacking(_ctx))
	_ctx.possession.pass_target = _home.players[4]
	_check("press: our pass on its way keeps the attack buttons", human.is_attacking(_ctx))
	_ctx.possession.pass_target = null
	var won := false
	for i in range(240):
		var intent := PlayerIntent.new()
		intent.press_held = true
		player.intent = HumanAssists.apply(player, intent, human.is_attacking(_ctx), 1.0 / 60.0, _ctx, human)
		player.move(1.0 / 60.0, _ctx.court, false)
		player.handling.update(1.0 / 60.0, player, _ctx)
		_ctx.ball.step(1.0 / 60.0)
		if _ctx.possession.holder == player:
			won = true
			break
	_check("press: held with no stick, the player runs to the loose ball and takes it", won,
		"distance=%.2f" % player.flat_distance_to(_ctx.ball.position))


## After his pass a player stops a moment facing the ball, then jogs (no sprint) before running
## again; the other side winning the ball ends it.
func _test_after_pass() -> void:
	_attack_setup()
	var passer := _home.players[2]
	_ctx.possession.kicked(passer, _home.players[3], _ctx.ball, "pass")
	AfterPass.start(passer)
	var intent := PlayerIntent.new()
	intent.move = Vector3.LEFT
	intent.sprint = true
	AfterPass.adjust(passer, intent, DT, _ctx)
	_check("after pass: he stops a moment, facing the ball", intent.move == Vector3.ZERO and not intent.sprint
		and intent.face.length() > 0.1)
	passer.ai.after_pass = 0.5
	intent = PlayerIntent.new()
	intent.move = Vector3.LEFT
	intent.sprint = true
	AfterPass.adjust(passer, intent, DT, _ctx)
	_check("after pass: then he jogs, backward facing the ball when going away from it", not intent.sprint
		and intent.move.length() < 0.75 and intent.move.length() > 0.5 and intent.face.x > 0.0, "move=%s face=%s" % [intent.move, intent.face])
	_ctx.possession.take(_away.players[3], _ctx.ball)
	intent = PlayerIntent.new()
	intent.move = Vector3.LEFT
	intent.sprint = true
	AfterPass.adjust(passer, intent, DT, _ctx)
	_check("after pass: the other side winning the ball ends it", intent.sprint and passer.ai.after_pass <= 0.0)


func _test_brains_run() -> void:
	_attack_setup()
	var ok := true
	for i in range(120):
		for team in _ctx.teams:
			team.brain.update(DT, _ctx, null)
		for p in _ctx.all_players:
			ok = ok and p.intent != null
			p.move(DT, _ctx.court, _ctx.possession.holder == p)
	_check("brains: every player gets an intent every frame", ok)
