extends Node
## Headless checks of the player data and of the attributes' effect on gameplay, run by CI:
##   godot --headless --path street-football res://tests/stats_test.tscn
## Prints "TEST PASS"/"TEST FAIL" lines, then "STATS TESTS DONE: N failure(s)".

const DT := 1.0 / 60.0
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ATTRIBUTES: Array[String] = ["finishing", "shot_power", "long_shots", "heading",
	"dribbling", "ball_control", "tight_possession", "low_pass", "lofted_pass", "vision",
	"speed", "acceleration", "stamina", "strength", "balance", "jump",
	"tackling", "interception", "marking", "aggression",
	"gk_reflexes", "gk_diving", "gk_handling", "gk_positioning", "gk_kicking"]

var _failures := 0
var _court: CourtData


func _ready() -> void:
	_court = CourtData.load_court("cage_concrete")
	_test_roster_data()
	_test_slot_assignment()
	_test_speed_changes_running()
	_test_dribbling_changes_touches()
	_test_finishing_changes_accuracy()
	_test_stamina_changes_tiredness()
	_test_tackling_and_balance()
	_test_keeper_attributes()
	_test_position_fitness()
	print("STATS TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(test_name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("TEST PASS ", test_name)
	else:
		_failures += 1
		print("TEST FAIL ", test_name, " ", detail)


func _test_roster_data() -> void:
	var playstyles: Array = Config.get_value("ratings", "playstyles", [])
	var skills: Array = Config.get_value("ratings", "special_skills", [])
	var positions: Array = Config.get_value("ratings", "positions", [])
	var ids := Roster.player_ids()
	_check("roster: 30 players", ids.size() == 30, "found %d" % ids.size())
	_check("roster: 6 teams", Roster.team_ids().size() == 6, "found %d" % Roster.team_ids().size())
	var problems: Array[String] = []
	var names := {}
	for player_id in ids:
		var p: PlayerProfile = Roster.player(str(player_id))
		if names.has(p.name):
			problems.append("duplicate name " + p.name)
		names[p.name] = true
		for a in ATTRIBUTES:
			var v: Variant = p.attributes.get(a)
			if v == null or float(v) < 0.0 or float(v) > 99.0:
				problems.append("%s.%s" % [player_id, a])
		if not playstyles.has(p.playstyle):
			problems.append("%s playstyle %s" % [player_id, p.playstyle])
		for s in p.special_skills:
			if not skills.has(s):
				problems.append("%s skill %s" % [player_id, s])
		for pos in p.positions:
			if not positions.has(pos):
				problems.append("%s position %s" % [player_id, pos])
		if p.positions.is_empty() or p.weak_foot < 1 or p.weak_foot > 4 or p.skill_moves < 1 or p.skill_moves > 5:
			problems.append("%s positions/weak foot/skill stars" % player_id)
		if not ["right", "left"].has(p.preferred_foot):
			problems.append("%s foot" % player_id)
		var overall := Ratings.best_overall(p)
		if overall < 60 or overall > 95:
			problems.append("%s overall %d" % [player_id, overall])
	_check("roster: every player has valid data", problems.is_empty(), str(problems))
	var seen := {}
	var team_problems: Array[String] = []
	for team_id in Roster.team_ids():
		var team: TeamData = Roster.team(team_id)
		var keepers := 0
		if team.players.size() != 5:
			team_problems.append("%s has %d players" % [team_id, team.players.size()])
		for entry in team.players:
			var pid := str(entry.get("id", ""))
			if seen.has(pid) or Roster.player(pid) == null:
				team_problems.append("%s: player %s missing or in two teams" % [team_id, pid])
			seen[pid] = true
			if Roster.player(pid) != null and Roster.player(pid).is_keeper():
				keepers += 1
		if keepers != 1:
			team_problems.append("%s has %d keepers" % [team_id, keepers])
	_check("roster: 6 crews of 5, one keeper each, nobody twice", team_problems.is_empty(), str(team_problems))


func _test_slot_assignment() -> void:
	var problems: Array[String] = []
	for team_id in Roster.team_ids():
		var team: TeamData = Roster.team(team_id)
		var profiles: Array[PlayerProfile] = []
		for entry in team.players:
			profiles.append(Roster.player(str(entry.get("id", ""))))
		for formation_id in FormationData.all_ids():
			var formation := FormationData.load_formation(str(formation_id))
			var order := SlotAssigner.assign(profiles, formation)
			if not profiles[order[0]].is_keeper():
				problems.append("%s %s: no keeper in goal" % [team_id, formation_id])
			var used := {}
			for i in order:
				used[i] = true
			if used.size() != 5:
				problems.append("%s %s: a player is used twice" % [team_id, formation_id])
	_check("slots: keeper in goal and everyone placed once, every crew and formation", problems.is_empty(), str(problems))


func _profile(overrides: Dictionary, positions: Array = ["MID"]) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.id = "test"
	p.name = "Test Player"
	p.short_name = "T. Player"
	p.positions = positions
	p.height_cm = 178.0
	for a in ATTRIBUTES:
		p.attributes[a] = 60.0
	for k in overrides:
		p.attributes[k] = overrides[k]
	return p


func _player(overrides: Dictionary, role: String = "MID", positions: Array = ["MID"]) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child(player)
	var team := Team.new()
	team.tuning = AiTuning.for_difficulty("normal")
	player.team = team
	team.players.append(player)
	player.apply_profile(_profile(overrides, positions), role, 1)
	player.reset_to(Vector3(-16.0, 0.0, 0.0), Vector3.RIGHT)
	return player


func _sprint(player: Player, seconds: float, stay_in_place: bool) -> void:
	for i in range(int(seconds / DT)):
		var intent := PlayerIntent.new()
		intent.move = Vector3.RIGHT
		intent.sprint = true
		player.intent = intent
		player.move(DT, _court, false)
		if stay_in_place:
			player.position = Vector3.ZERO


func _test_speed_changes_running() -> void:
	var fast := _player({"speed": 95.0, "acceleration": 95.0})
	var slow := _player({"speed": 45.0, "acceleration": 45.0})
	_sprint(fast, 2.0, false)
	_sprint(slow, 2.0, false)
	_check("speed: a fast player covers more ground", fast.position.x > slow.position.x + 1.5,
		"fast=%.2f slow=%.2f" % [fast.position.x, slow.position.x])
	fast.queue_free()
	slow.queue_free()


func _test_dribbling_changes_touches() -> void:
	var good := _player({"dribbling": 95.0, "tight_possession": 95.0})
	var poor := _player({"dribbling": 45.0, "tight_possession": 45.0})
	_check("dribbling: good dribblers touch the ball closer",
		good.stat("dribble_touch_extra_mult", 1.0) < poor.stat("dribble_touch_extra_mult", 1.0))
	_check("tight possession: harder to steal from",
		good.stat("dribble_exposed_distance", 0.8) > poor.stat("dribble_exposed_distance", 0.8))
	good.queue_free()
	poor.queue_free()


func _test_finishing_changes_accuracy() -> void:
	var sharp := _player({"finishing": 95.0, "shot_power": 95.0, "low_pass": 95.0, "long_shots": 95.0})
	var poor := _player({"finishing": 45.0, "shot_power": 45.0, "low_pass": 45.0, "long_shots": 45.0})
	_check("finishing: smaller shot error", sharp.stat("shot_error_degrees", 0.0) < poor.stat("shot_error_degrees", 0.0))
	_check("shot power: faster shots", sharp.stat("shot_speed_mult", 1.0) > poor.stat("shot_speed_mult", 1.0))
	_check("low pass: smaller pass error", sharp.stat("pass_error_degrees", 0.0) < poor.stat("pass_error_degrees", 0.0))
	_check("long shots: less extra error from far",
		sharp.stat("long_shot_error_per_meter", 0.0) < poor.stat("long_shot_error_per_meter", 0.0))
	sharp.queue_free()
	poor.queue_free()


func _test_stamina_changes_tiredness() -> void:
	var fit := _player({"stamina": 95.0})
	var tired := _player({"stamina": 45.0})
	_sprint(fit, 10.0, true)
	_sprint(tired, 10.0, true)
	_check("stamina: a fit player tires less", fit.energy > tired.energy + 0.3,
		"fit=%.2f tired=%.2f" % [fit.energy, tired.energy])
	_check("stamina: a tired player is slower", tired.motion.top_speed(true) < fit.motion.top_speed(true),
		"fit=%.2f tired=%.2f" % [fit.motion.top_speed(true), tired.motion.top_speed(true)])
	fit.queue_free()
	tired.queue_free()


func _test_tackling_and_balance() -> void:
	var good := _player({"tackling": 90.0})
	var poor := _player({"tackling": 40.0})
	var steady := _player({"balance": 95.0})
	var wobbly := _player({"balance": 40.0})
	_check("tackling: better tacklers win the ball more often",
		TackleRules.success_chance(good, wobbly) > TackleRules.success_chance(poor, wobbly))
	_check("balance: steady carriers are harder to tackle",
		TackleRules.success_chance(good, steady) < TackleRules.success_chance(good, wobbly))
	var strong := _player({"strength": 90.0})
	_check("strength: stronger players win shoulder duels more often",
		ShoulderCharge.success_chance(strong, wobbly) > ShoulderCharge.success_chance(wobbly, strong))
	for p: Player in [good, poor, steady, wobbly, strong]:
		p.queue_free()


func _test_keeper_attributes() -> void:
	var great := _player({"gk_reflexes": 92.0, "gk_diving": 92.0, "gk_handling": 92.0}, "GK", ["GK"])
	var weak := _player({"gk_reflexes": 45.0, "gk_diving": 45.0, "gk_handling": 45.0}, "GK", ["GK"])
	_check("keeper: diving gives more reach", great.stat("keeper_reach", 0.0) > weak.stat("keeper_reach", 0.0))
	_check("keeper: reflexes give more saves", great.stat("keeper_save_mult", 0.0) > weak.stat("keeper_save_mult", 0.0))
	_check("keeper: handling holds faster shots", great.stat("keeper_catch_speed", 0.0) > weak.stat("keeper_catch_speed", 0.0))
	great.queue_free()
	weak.queue_free()


func _test_position_fitness() -> void:
	var defender := _profile({"tackling": 85.0, "marking": 85.0, "interception": 85.0}, ["DEF"])
	_check("fitness: natural position is best", Ratings.position_fitness(defender, "DEF") == 1.0)
	_check("fitness: adjacent position costs a little",
		Ratings.position_fitness(defender, "MID") < 1.0 and Ratings.position_fitness(defender, "MID") > Ratings.position_fitness(defender, "ATT"))
	_check("fitness: an outfielder in goal is poor", Ratings.position_fitness(defender, "GK") <= 0.6)
	var in_role := _player({"speed": 80.0}, "DEF", ["DEF"])
	var out_of_role := _player({"speed": 80.0}, "ATT", ["DEF"])
	_check("fitness: out of position the same player is a bit slower",
		out_of_role.motion.top_speed(true) < in_role.motion.top_speed(true))
	in_role.queue_free()
	out_of_role.queue_free()
