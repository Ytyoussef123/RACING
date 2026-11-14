extends Node
## Autoload "MatchSetup": what the next match uses (crews, formation, court, difficulty, length),
## filled by the quick match screens and read by the match scene; also keeps the last result.

var court_id: String = ""
var formation_id: String = ""
var difficulty: String = ""
var home_team_id: String = ""
var away_team_id: String = ""
## Match length chosen on the court screen (0 = default from match.json).
var match_minutes: int = 0
## Last finished match, for the results screen: scores, goals, stats.
var last_result: Dictionary = {}
## Tests only: both teams are AI, the match length is overridden, and full time does not leave the scene.
var test_mode: bool = false
var test_match_seconds: float = 0.0
## Tests only: fixed random seed so a test match always plays out the same way (0 = random).
var test_seed: int = 0


func get_court_id() -> String:
	return court_id if not court_id.is_empty() else str(Config.get_value("match", "default_court", "cage_concrete"))


func get_formation_id() -> String:
	return formation_id if not formation_id.is_empty() else str(Config.get_value("match", "default_formation", "2-1-1"))


func get_difficulty() -> String:
	return difficulty if not difficulty.is_empty() else str(Config.get_value("match", "default_difficulty", "normal"))


func get_match_seconds() -> float:
	if test_mode and test_match_seconds > 0.0:
		return test_match_seconds
	return get_match_minutes() * 60.0


func get_match_minutes() -> int:
	if match_minutes > 0:
		return match_minutes
	return roundi(float(Config.get_value("match", "match_seconds", 180.0)) / 60.0)


func get_home_team_id() -> String:
	if not home_team_id.is_empty():
		return home_team_id
	return str(Config.get_value("match", "default_home_team", "concrete_kings"))


func get_away_team_id() -> String:
	if not away_team_id.is_empty() and away_team_id != get_home_team_id():
		return away_team_id
	var fallback := str(Config.get_value("match", "default_away_team", "rooftop_rebels"))
	if fallback != get_home_team_id():
		return fallback
	for team_id in Roster.team_ids():
		if team_id != get_home_team_id():
			return team_id
	return fallback


## The crew `step` places away in the roster order, skipping `skip` (e.g. the home crew).
func cycle_team(current: String, step: int, skip: String) -> String:
	var ids: Array[String] = Roster.team_ids()
	var index := ids.find(current)
	for i in range(1, ids.size() + 1):
		var candidate := ids[posmod(index + step * i, ids.size())]
		if candidate != skip:
			return candidate
	return current
