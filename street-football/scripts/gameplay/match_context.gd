class_name MatchContext
extends RefCounted
## Everything the rules and the AI need to know about the match, in one object.

var court: CourtData
var ball: BallPhysics
var possession: Possession = Possession.new()
var stats: MatchStats = MatchStats.new()
var teams: Array[Team] = []
var all_players: Array[Player] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Things that happened this frame, for sounds and effects: {"kind", "position", "strength"}.
## Kinds: "pass", "shot", "tackle_won", "shoulder_won", "save", and the ball hits "ground",
## "wall", "post", "net". The match plays them and clears the list every frame.
var events: Array[Dictionary] = []


func emit_event(kind: String, at: Vector3, strength: float = 1.0, label: String = "") -> void:
	events.append({"kind": kind, "position": at, "strength": strength, "label": label})


func _init() -> void:
	possession.stats = stats


func add_team(team: Team) -> void:
	teams.append(team)
	all_players.append_array(team.players)
