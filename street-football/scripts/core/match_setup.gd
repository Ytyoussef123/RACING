extends Node
## Autoload "MatchSetup": what the next match uses.
## Menus fill it (Phase 5 will add team and formation); the match scene reads it.

var court_id: String = ""


func get_court_id() -> String:
	if court_id.is_empty():
		return str(Config.get_value("match", "default_court", "cage_concrete"))
	return court_id
