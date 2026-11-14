extends Node
## Autoload "Roster": every fictional player (data/players/*.json) and street crew
## (data/teams/*.json), loaded once at start. New players and crews are added as data files only.
## "my_crew" is the player's own squad (built by SaveGame); players in no crew are free agents.

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


func player_exists(player_id: String) -> bool:
	return _players.has(player_id)


func player(player_id: String) -> PlayerProfile:
	if not _players.has(player_id):
		push_error("Roster: unknown player '%s'" % player_id)
		return null
	return _players[player_id]


func team(team_id: String) -> TeamData:
	if team_id == SaveGame.MY_CREW_ID:
		return SaveGame.my_crew_data()
	if not _teams.has(team_id):
		push_error("Roster: unknown team '%s'" % team_id)
		return null
	return _teams[team_id]


func has_team(team_id: String) -> bool:
	return team_id == SaveGame.MY_CREW_ID or _teams.has(team_id)


## The street crews (possible opponents).
func team_ids() -> Array[String]:
	return _team_ids


## Crews you can play with: My Crew first, then the street crews (exhibition).
func home_team_ids() -> Array[String]:
	var ids: Array[String] = [SaveGame.MY_CREW_ID]
	ids.append_array(_team_ids)
	return ids


## Players who are in no crew: My Crew's players and the shop.
func free_agent_ids() -> Array[String]:
	var in_crews := {}
	for team_id in _team_ids:
		for entry in (_teams[team_id] as TeamData).players:
			in_crews[str(entry.get("id", ""))] = true
	var result: Array[String] = []
	for player_id in _players.keys():
		if not in_crews.has(player_id):
			result.append(str(player_id))
	result.sort()
	return result


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
