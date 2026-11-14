extends Node
## Autoload "MatchSetup": what the next match uses. The start screen fills it
## (Phase 5 menus will replace it); the match scene reads it.

var court_id: String = ""
var formation_id: String = ""
var difficulty: String = ""
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
