extends Node
## Autoload "MatchSetup": what the next match uses. The start screen fills it
## (Phase 5 menus will replace it); the match scene reads it.

var court_id: String = ""
var formation_id: String = ""
var difficulty: String = ""
var home_team_id: String = ""
var away_team_id: String = ""
## Tests only: both teams are AI, the match length is overridden, and full time does not leave the scene.
var test_mode: bool = false
var test_match_seconds: float = 0.0


func get_court_id() -> String:
	return court_id if not court_id.is_empty() else str(Config.get_value("match", "default_court", "cage_concrete"))


func get_formation_id() -> String:
	return formation_id if not formation_id.is_empty() else str(Config.get_value("match", "default_formation", "2-1-1"))


func get_difficulty() -> String:
	return difficulty if not difficulty.is_empty() else str(Config.get_value("match", "default_difficulty", "normal"))


func get_match_seconds() -> float:
	if test_mode and test_match_seconds > 0.0:
		return test_match_seconds
	return float(Config.get_value("match", "match_seconds", 180.0))


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


## Next opponent in the roster order (skipping the home team), for the start screen.
func next_away_team_id() -> String:
	var ids: Array[String] = Roster.team_ids()
	var index := ids.find(get_away_team_id())
	for step in range(1, ids.size() + 1):
		var candidate := ids[(index + step) % ids.size()]
		if candidate != get_home_team_id():
			return candidate
	return get_away_team_id()
