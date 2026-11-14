extends Node
## Headless checks of progression, run by CI:
##   godot --headless --path street-football res://tests/progression_test.tscn
## New save, rewards, shop, upgrades, squad swaps, courts, saving and loading, a damaged save,
## court surfaces and My Crew as a team.
## Prints "TEST PASS"/"TEST FAIL" lines, then "PROGRESSION TESTS DONE: N failure(s)".

const TEST_SAVE := "user://test_savegame.json"

var _failures := 0


func _ready() -> void:
	SaveGame.save_path = TEST_SAVE
	SaveGame.in_memory = false
	_test_new_save()
	_test_rewards()
	_test_shop()
	_test_upgrades()
	_test_squad()
	_test_courts()
	_test_save_and_load()
	_test_damaged_save()
	_test_surfaces()
	_test_my_crew_team()
	for path in [TEST_SAVE, TEST_SAVE.get_basename() + ".bad.json", TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("PROGRESSION TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(test_name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("TEST PASS ", test_name)
	else:
		_failures += 1
		print("TEST FAIL ", test_name, " ", detail)


func _test_new_save() -> void:
	SaveGame.start_new()
	_check("new save: starting coins", SaveGame.coins == 500)
	_check("new save: 7 rookies, 5 starters, 2 on the bench",
		SaveGame.owned.size() == 7 and SaveGame.starters.size() == 5 and SaveGame.bench().size() == 2)
	_check("new save: a keeper starts", SaveGame.has_keeper_starting())
	_check("new save: two courts unlocked", SaveGame.court_unlocked("cage_concrete") and SaveGame.court_unlocked("open_lot")
		and not SaveGame.court_unlocked("beach_sand"))
	_check("new save: rookies are free agents, not crew players", Roster.free_agent_ids().has("bruno_sallestra")
		and not Roster.free_agent_ids().has("teo_varmanetti"))


func _test_rewards() -> void:
	_check("rewards: win 3-1 on normal = 150 + 3 x 15", SaveGame.reward_for(3, 1, "normal") == 195)
	_check("rewards: draw 1-1 on hard = (80 + 15) x 1.4", SaveGame.reward_for(1, 1, "hard") == 133)
	_check("rewards: loss 0-2 on easy = 50 x 0.8", SaveGame.reward_for(0, 2, "easy") == 40)
	SaveGame.start_new()
	var earned := SaveGame.record_match(2, 1, "normal")
	_check("rewards: a match pays and is recorded", earned == 180 and SaveGame.coins == 680
		and int(SaveGame.record["wins"]) == 1 and int(SaveGame.record["played"]) == 1)


func _test_shop() -> void:
	SaveGame.start_new()
	_check("shop: too expensive with 500 coins", not SaveGame.buy_player("kaito_shimazu"))
	SaveGame.coins = 5000
	var price := SaveGame.player_price(Roster.player("kaito_shimazu"))
	_check("shop: buying a free agent", SaveGame.buy_player("kaito_shimazu") and SaveGame.coins == 5000 - price
		and SaveGame.bench().has("kaito_shimazu"))
	_check("shop: cannot buy twice", not SaveGame.buy_player("kaito_shimazu"))
	_check("shop: crew players are not for sale", not SaveGame.buy_player("teo_varmanetti"))
	_check("shop: better players cost more", SaveGame.player_price(Roster.player("bayo_ruiz_okun"))
		> SaveGame.player_price(Roster.player("seun_adegboro")))


func _test_upgrades() -> void:
	SaveGame.start_new()
	SaveGame.coins = 10000
	var profile: PlayerProfile = Roster.player("moussa_kandere")
	var before := profile.attr("finishing")
	var overall_before := Ratings.best_overall(profile)
	_check("upgrade: level 2 costs 250", SaveGame.upgrade_cost("moussa_kandere") == 250 and SaveGame.upgrade("moussa_kandere")
		and SaveGame.coins == 9750)
	_check("upgrade: attributes go up", profile.attr("finishing") == before + 2.0
		and Ratings.best_overall(profile) > overall_before)
	while SaveGame.upgrade_cost("moussa_kandere") >= 0:
		SaveGame.upgrade("moussa_kandere")
	_check("upgrade: stops at the max level", SaveGame.level_of("moussa_kandere") == 5 and not SaveGame.upgrade("moussa_kandere"))
	SaveGame.start_new()
	_check("upgrade: a new save resets the bonus", profile.level_bonus == 0.0)


func _test_squad() -> void:
	SaveGame.start_new()
	SaveGame.swap("moussa_kandere", "rayan_ouaddi")
	_check("squad: swap starter and bench", SaveGame.starters.has("rayan_ouaddi") and SaveGame.bench().has("moussa_kandere"))
	SaveGame.swap("bruno_sallestra", "tomas_velarrubia")
	_check("squad: benching the keeper is allowed but noticed", not SaveGame.has_keeper_starting())


func _test_courts() -> void:
	SaveGame.start_new()
	_check("courts: too expensive at first", not SaveGame.unlock_court("beach_sand"))
	SaveGame.coins = 2000
	_check("courts: unlock with coins", SaveGame.unlock_court("beach_sand") and SaveGame.court_unlocked("beach_sand")
		and SaveGame.coins == 2000 - SaveGame.court_price("beach_sand"))


func _test_save_and_load() -> void:
	SaveGame.start_new()
	SaveGame.coins = 3000
	SaveGame.buy_player("seun_adegboro")
	SaveGame.upgrade("ilyes_benzerrak")
	SaveGame.unlock_court("rooftop_cage")
	var coins := SaveGame.coins
	SaveGame.coins = 0
	SaveGame.owned.clear()
	SaveGame.load_or_start()
	_check("save: coins, players, levels and courts come back", SaveGame.coins == coins
		and SaveGame.owned.has("seun_adegboro") and SaveGame.level_of("ilyes_benzerrak") == 2
		and SaveGame.court_unlocked("rooftop_cage"), "coins=%d" % SaveGame.coins)
	_check("save: level bonus applied after loading", Roster.player("ilyes_benzerrak").level_bonus == 2.0)


func _test_damaged_save() -> void:
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	SaveGame.load_or_start()
	_check("damaged save: a new save starts", SaveGame.coins == 500 and SaveGame.owned.size() == 7)
	_check("damaged save: the bad file is kept", FileAccess.file_exists(TEST_SAVE.get_basename() + ".bad.json"))


func _test_surfaces() -> void:
	var concrete := BallPhysics.new()
	var sand := BallPhysics.new()
	sand.apply_surface(1.9, 0.7)
	var distances: Array[float] = []
	for ball: BallPhysics in [concrete, sand]:
		ball.place(Vector3(0.0, ball.radius, 0.0))
		ball.velocity = Vector3(10.0, 0.0, 0.0)
		for i in range(1200):
			ball.step(1.0 / 60.0)
		distances.append(ball.position.x)
	_check("surfaces: the ball rolls shorter on sand", distances[1] < distances[0] * 0.75,
		"concrete=%.1f sand=%.1f" % [distances[0], distances[1]])
	var copy := sand.copy()
	copy.place(Vector3(0.0, copy.radius, 0.0))
	copy.velocity = Vector3(10.0, 0.0, 0.0)
	for i in range(1200):
		copy.step(1.0 / 60.0)
	_check("surfaces: the prediction copy keeps the surface", is_equal_approx(copy.position.x, distances[1]))


func _test_my_crew_team() -> void:
	SaveGame.start_new()
	var team: TeamData = Roster.team(SaveGame.MY_CREW_ID)
	var keepers := 0
	var ones := 0
	for entry in team.players:
		if Roster.player(str(entry["id"])).is_keeper():
			keepers += 1
		if int(entry["number"]) == 1:
			ones += 1
	_check("my crew: 5 starters with one keeper wearing 1", team.players.size() == 5 and keepers == 1 and ones == 1)
	_check("my crew: can be chosen at home, never as an opponent",
		Roster.home_team_ids().has(SaveGame.MY_CREW_ID) and not Roster.team_ids().has(SaveGame.MY_CREW_ID))
