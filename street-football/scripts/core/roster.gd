extends Node
## Autoload "Roster": every fictional player (data/players/*.json) and street crew
## (data/teams/*.json), loaded once at start. New players and crews are added as data files only.

const PLAYERS_DIR := "res://data/players/"
const TEAMS_DIR := "res://data/teams/"

var _players: Dictionary = {}
var _teams: Dictionary = {}
var _team_ids: Array[String] = []


func _ready() -> void:
	for player_id in _json_ids(PLAYERS_DIR):
		_players[player_id] = PlayerProfile.load_player(player_id)
	for team_id in _json_ids(TEAMS_DIR):
		_teams[team_id] = TeamData.load_team(team_id)
		_team_ids.append(team_id)


func player(player_id: String) -> PlayerProfile:
	if not _players.has(player_id):
		push_error("Roster: unknown player '%s'" % player_id)
		return null
	return _players[player_id]


func team(team_id: String) -> TeamData:
	if not _teams.has(team_id):
		push_error("Roster: unknown team '%s'" % team_id)
		return null
	return _teams[team_id]


func has_team(team_id: String) -> bool:
	return _teams.has(team_id)


func team_ids() -> Array[String]:
	return _team_ids


func player_ids() -> Array:
	return _players.keys()


static func _json_ids(dir_path: String) -> Array[String]:
	var ids: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("Roster: cannot open %s" % dir_path)
		return ids
	for file_name in dir.get_files():
		if file_name.get_extension() == "json":
			ids.append(file_name.get_basename())
	ids.sort()
	return ids
