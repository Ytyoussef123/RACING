class_name MatchStats
extends RefCounted
## Counters per team (index 0 = home, 1 = away) for the results screen and the balance tests.

var shots: Array[int] = [0, 0]
## Saves made by each team's keeper.
var saves: Array[int] = [0, 0]
var passes: Array[int] = [0, 0]
var passes_completed: Array[int] = [0, 0]
## Ball won by a tackle, a shoulder charge or a steal.
var balls_won: Array[int] = [0, 0]
## Seconds each team had the ball.
var possession_time: Array[float] = [0.0, 0.0]


## Share of possession for a team, 0..100.
func possession_percent(team_index: int) -> int:
	var total := possession_time[0] + possession_time[1]
	if total <= 0.0:
		return 50
	return roundi(possession_time[team_index] / total * 100.0)


func summary(team_index: int) -> String:
	return "shots %d, saves by keeper %d, passes %d/%d, balls won %d, possession %d%%" % [
		shots[team_index], saves[team_index], passes_completed[team_index], passes[team_index],
		balls_won[team_index], possession_percent(team_index)]
