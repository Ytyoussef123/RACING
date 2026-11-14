extends Node
## Autoload "SaveGame": the player's progress, saved on the device (user://savegame.json):
## coins, signed players and their levels, My Crew (starters, formation), unlocked courts and the
## match record. Rules and prices: data/config/progression.json.
## Writes go to a temporary file first; a damaged save is kept as savegame.bad.json and a new one
## is started.

const MY_CREW_ID := "my_crew"

var save_path: String = "user://savegame.json"
## Tests: keep everything in memory (no file read or written).
var in_memory: bool = false

var coins: int = 0
var owned: Array[String] = []
## Player id -> level (1..max_level).
var levels: Dictionary = {}
## The 5 players who start; everyone else signed is on the bench.
var starters: Array[String] = []
var formation_id: String = ""
var courts: Array[String] = []
var record: Dictionary = {}


func _ready() -> void:
	load_or_start()


func load_or_start() -> void:
	if not in_memory and FileAccess.file_exists(save_path):
		var text := FileAccess.get_file_as_string(save_path)
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY and _read(parsed):
			_apply_levels()
			return
		push_warning("SaveGame: damaged save, starting a new one")
		var bad := FileAccess.open(save_path.get_basename() + ".bad.json", FileAccess.WRITE)
		if bad != null:
			bad.store_string(text)
	start_new()


func start_new() -> void:
	for player_id in owned:
		var old: PlayerProfile = Roster.player(player_id)
		if old != null:
			old.level_bonus = 0.0
	coins = int(_cfg("starting_coins", 500))
	owned = _strings(_cfg("starting_players", []))
	starters = _strings(_cfg("starting_starters", []))
	levels = {}
	for player_id in owned:
		levels[player_id] = 1
	formation_id = str(Config.get_value("match", "default_formation", "2-1-1"))
	courts = _strings(_cfg("starting_courts", []))
	record = {"played": 0, "wins": 0, "draws": 0, "losses": 0, "goals_for": 0, "goals_against": 0}
	_apply_levels()
	save()


func save() -> void:
	if in_memory:
		return
	var data := {
		"version": int(_cfg("save_version", 1)), "coins": coins, "owned": owned, "levels": levels,
		"starters": starters, "formation": formation_id, "courts": courts, "record": record,
	}
	var tmp_path := save_path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveGame: cannot write %s" % tmp_path)
		return
	var text := JSON.stringify(data, "\t")
	file.store_string(text)
	file.close()
	if DirAccess.rename_absolute(tmp_path, save_path) != OK:
		# Some file systems can't replace a file by renaming: write it directly instead.
		var direct := FileAccess.open(save_path, FileAccess.WRITE)
		if direct != null:
			direct.store_string(text)


# --- Squad ---------------------------------------------------------------------------------------

func bench() -> Array[String]:
	var result: Array[String] = []
	for player_id in owned:
		if not starters.has(player_id):
			result.append(player_id)
	return result


## Swaps two signed players between the starters and the bench (or two starters' places).
func swap(a: String, b: String) -> void:
	var ia := starters.find(a)
	var ib := starters.find(b)
	if ia >= 0 and ib < 0 and owned.has(b):
		starters[ia] = b
	elif ib >= 0 and ia < 0 and owned.has(a):
		starters[ib] = a
	elif ia >= 0 and ib >= 0:
		starters[ia] = b
		starters[ib] = a
	save()


func has_keeper_starting() -> bool:
	for player_id in starters:
		var p: PlayerProfile = Roster.player(player_id)
		if p != null and p.is_keeper():
			return true
	return false


## My Crew as a team for the match and the menus.
func my_crew_data() -> TeamData:
	var team := TeamData.new()
	var crew: Dictionary = _cfg("my_crew", {})
	team.id = MY_CREW_ID
	team.name = tr("MY_CREW_NAME")
	team.short_name = str(crew.get("short_name", "YOU"))
	team.home_court = str(crew.get("home_court", "cage_concrete"))
	team.colors = crew.get("colors", {})
	var number := 2
	for player_id in starters:
		var p: PlayerProfile = Roster.player(player_id)
		var shirt := 1 if p != null and p.is_keeper() else number
		if shirt != 1:
			number += 1
		team.players.append({"id": player_id, "number": shirt})
	return team


# --- Shop and upgrades ---------------------------------------------------------------------------

func player_price(profile: PlayerProfile) -> int:
	var over := maxi(0, Ratings.best_overall(profile) - int(_cfg("player_price_reference_overall", 70)))
	return int(_cfg("player_price_base", 400)) + over * int(_cfg("player_price_per_point", 60))


func buy_player(player_id: String) -> bool:
	var profile: PlayerProfile = Roster.player(player_id)
	if profile == null or owned.has(player_id) or not Roster.free_agent_ids().has(player_id):
		return false
	var price := player_price(profile)
	if coins < price:
		return false
	coins -= price
	owned.append(player_id)
	levels[player_id] = 1
	save()
	return true


func level_of(player_id: String) -> int:
	return int(levels.get(player_id, 1))


## Cost of the next level, or -1 at the maximum level.
func upgrade_cost(player_id: String) -> int:
	var level := level_of(player_id)
	var costs: Array = _cfg("level_costs", [])
	if level >= int(_cfg("max_level", 5)) or level >= costs.size():
		return -1
	return int(costs[level])


func upgrade(player_id: String) -> bool:
	var cost := upgrade_cost(player_id)
	if not owned.has(player_id) or cost < 0 or coins < cost:
		return false
	coins -= cost
	levels[player_id] = level_of(player_id) + 1
	_apply_levels()
	save()
	return true


func court_unlocked(court_id: String) -> bool:
	return courts.has(court_id)


func court_price(court_id: String) -> int:
	var prices: Dictionary = _cfg("court_prices", {})
	return int(prices.get(court_id, 0))


func unlock_court(court_id: String) -> bool:
	var price := court_price(court_id)
	if courts.has(court_id) or coins < price:
		return false
	coins -= price
	courts.append(court_id)
	save()
	return true


# --- Matches -------------------------------------------------------------------------------------

## Coins for a result (win / draw / loss + goals), scaled by the difficulty.
func reward_for(goals_for: int, goals_against: int, difficulty: String) -> int:
	var rewards: Dictionary = _cfg("rewards", {})
	var base := int(rewards.get("draw", 80))
	if goals_for > goals_against:
		base = int(rewards.get("win", 150))
	elif goals_for < goals_against:
		base = int(rewards.get("loss", 50))
	base += goals_for * int(rewards.get("per_goal", 15))
	var mults: Dictionary = _cfg("difficulty_reward_mult", {})
	return roundi(base * float(mults.get(difficulty, 1.0)))


## Adds a finished match to the record and pays the reward. Returns the coins earned.
func record_match(goals_for: int, goals_against: int, difficulty: String) -> int:
	var earned := reward_for(goals_for, goals_against, difficulty)
	coins += earned
	record["played"] = int(record.get("played", 0)) + 1
	var key := "draws"
	if goals_for > goals_against:
		key = "wins"
	elif goals_for < goals_against:
		key = "losses"
	record[key] = int(record.get(key, 0)) + 1
	record["goals_for"] = int(record.get("goals_for", 0)) + goals_for
	record["goals_against"] = int(record.get("goals_against", 0)) + goals_against
	save()
	return earned


# --- Internals -----------------------------------------------------------------------------------

func _read(d: Dictionary) -> bool:
	var read_owned := _strings(d.get("owned", []))
	var read_starters := _strings(d.get("starters", []))
	if read_owned.is_empty() or read_starters.size() != 5:
		return false
	for player_id in read_owned:
		if Roster.player_exists(player_id) == false:
			return false
	for player_id in read_starters:
		if not read_owned.has(player_id):
			return false
	coins = maxi(0, int(d.get("coins", 0)))
	owned = read_owned
	starters = read_starters
	levels = d.get("levels", {})
	formation_id = str(d.get("formation", Config.get_value("match", "default_formation", "2-1-1")))
	courts = _strings(d.get("courts", _cfg("starting_courts", [])))
	record = d.get("record", {})
	return true


## Player levels become attribute bonuses on the shared profiles (signed players are free agents,
## never in an opponent crew).
func _apply_levels() -> void:
	var per_level := float(_cfg("attribute_bonus_per_level", 2))
	for player_id in owned:
		var profile: PlayerProfile = Roster.player(player_id)
		if profile != null:
			profile.level_bonus = (level_of(player_id) - 1) * per_level


static func _strings(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for v in values:
			result.append(str(v))
	return result


func _cfg(key: String, fallback: Variant) -> Variant:
	return Config.get_value("progression", key, fallback)
