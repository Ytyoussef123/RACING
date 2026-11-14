class_name Team
extends RefCounted
## One side: its players, formation, colors, attack direction and AI tuning.

## 0 = home (the human side), 1 = away.
var index: int = 0
## +1 when the team attacks the goal at +x, -1 for the goal at -x.
var attack_sign: float = 1.0
var color: Color = Color.WHITE
var keeper_color: Color = Color.WHITE
var formation: FormationData
var players: Array[Player] = []
var keeper: Player
var opponent: Team
var brain: TeamBrain
var tuning: AiTuning


func own_goal_x(court: CourtData) -> float:
	return -attack_sign * court.half_length


func target_goal_x(court: CourtData) -> float:
	return attack_sign * court.half_length


## 0 at our own goal line, 1 at the opponent's goal line.
func to_frac(x: float, court: CourtData) -> float:
	return (x * attack_sign + court.half_length) / court.length


func frac_to_x(frac: float, court: CourtData) -> float:
	return attack_sign * (frac * court.length - court.half_length)


func outfield() -> Array[Player]:
	var result: Array[Player] = []
	for p in players:
		if not p.is_keeper:
			result.append(p)
	return result


func closest_outfield_to(pos: Vector3, exclude: Player = null) -> Player:
	var best: Player = null
	var best_dist := INF
	for p in players:
		if p.is_keeper or p == exclude:
			continue
		var d := p.flat_distance_to(pos)
		if d < best_dist:
			best_dist = d
			best = p
	return best


func nearest_distance_to(pos: Vector3) -> float:
	var best := INF
	for p in players:
		best = minf(best, p.flat_distance_to(pos))
	return best


## Applies a new formation: slot i keeps player i, roles follow the new slots.
func set_formation(new_formation: FormationData) -> void:
	formation = new_formation
	for p in players:
		p.role = formation.role(p.slot_index)
