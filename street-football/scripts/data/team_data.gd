class_name TeamData
extends RefCounted
## One fictional street crew, loaded from res://data/teams/<id>.json: name, colors, home court
## and its players (player id + shirt number).

const TEAMS_DIR := "res://data/teams/"

var id: String = ""
var name: String = ""
var short_name: String = ""
var home_court: String = ""
var colors: Dictionary = {}
## [{"id": player id, "number": shirt number}, ...]
var players: Array = []


static func load_team(team_id: String) -> TeamData:
	var team := TeamData.new()
	team.id = team_id
	var path := TEAMS_DIR + team_id + ".json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("TeamData: cannot read %s" % path)
		return team
	var d: Dictionary = parsed
	team.name = str(d.get("name", team_id))
	team.short_name = str(d.get("short_name", team.name.substr(0, 3).to_upper()))
	team.home_court = str(d.get("home_court", ""))
	team.colors = d.get("colors", {})
	team.players = d.get("players", [])
	return team


func color(key: String, fallback: Color) -> Color:
	if colors.has(key):
		return Color.html(str(colors[key]))
	return fallback
