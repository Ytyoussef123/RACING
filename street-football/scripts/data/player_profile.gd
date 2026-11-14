class_name PlayerProfile
extends RefCounted
## One fictional player, loaded from res://data/players/<id>.json: identity, look and the
## 25 attributes (0..99). Gameplay numbers come from these through StatEffects.

const PLAYERS_DIR := "res://data/players/"

var id: String = ""
var name: String = ""
var short_name: String = ""
var nationality: String = ""
var age: int = 0
var height_cm: float = 178.0
## "right" or "left".
var preferred_foot: String = "right"
## Weak foot accuracy, 1 (poor) to 4 (almost as good as the strong foot).
var weak_foot: int = 3
## Natural positions, best first: GK, DEF, MID, WING, ATT.
var positions: Array = []
var playstyle: String = ""
## Skill move stars, 1..5.
var skill_moves: int = 1
var special_skills: Array = []
var look: Dictionary = {}
var attributes: Dictionary = {}


static func load_player(player_id: String) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.id = player_id
	var path := PLAYERS_DIR + player_id + ".json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("PlayerProfile: cannot read %s" % path)
		return profile
	var d: Dictionary = parsed
	profile.name = str(d.get("name", player_id))
	profile.short_name = str(d.get("short_name", profile.name))
	profile.nationality = str(d.get("nationality", ""))
	profile.age = int(d.get("age", 0))
	profile.height_cm = float(d.get("height_cm", 178.0))
	profile.preferred_foot = str(d.get("preferred_foot", "right"))
	profile.weak_foot = int(d.get("weak_foot", 3))
	profile.positions = d.get("positions", [])
	profile.playstyle = str(d.get("playstyle", ""))
	profile.skill_moves = int(d.get("skill_moves", 1))
	profile.special_skills = d.get("special_skills", [])
	profile.look = d.get("look", {})
	profile.attributes = d.get("attributes", {})
	return profile


func attr(key: String) -> float:
	return float(attributes.get(key, 50.0))


func is_keeper() -> bool:
	return positions.has("GK")


func look_color(key: String, fallback: Color) -> Color:
	if look.has(key):
		return Color.html(str(look[key]))
	return fallback
