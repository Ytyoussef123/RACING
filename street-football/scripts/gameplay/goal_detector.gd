class_name GoalDetector
extends RefCounted
## A goal counts when the whole ball has crossed the goal line, between the posts, under the bar.


## Returns +1 for the goal at +x, -1 for the goal at -x, 0 when there is no goal.
static func check(ball: BallPhysics, court: CourtData) -> int:
	var p := ball.position
	if absf(p.x) <= court.half_length + ball.radius:
		return 0
	if absf(p.z) >= court.half_goal_width or p.y >= court.goal_height:
		return 0
	return 1 if p.x > 0.0 else -1
