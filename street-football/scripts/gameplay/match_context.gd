class_name MatchContext
extends RefCounted
## Everything the rules and the AI need to know about the match, in one object.

var court: CourtData
var ball: BallPhysics
var possession: Possession = Possession.new()
var teams: Array[Team] = []
var all_players: Array[Player] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func add_team(team: Team) -> void:
	teams.append(team)
	all_players.append_array(team.players)
