class_name ShotAim
extends RefCounted
## Shots go at the goal ("tir cadre"), even when the shooter is not lined up with it: the stick
## only picks where in the goal. A stick pointing at or near the goal keeps its aim (it can still
## miss, up to shot_assist_margin past a post); a stick pointing elsewhere aims at the post on that
## side; no stick aims at the corner away from the keeper. The kick's error (finishing, distance,
## weak foot, speed, angle: KickAccuracy) then decides if it is on target.
## Numbers: data/config/player.json (shot_post_inset, shot_assist_margin).


## Point on the opponent's goal line the shot is aimed at. stick: the raw stick (ZERO = released).
static func target(player: Player, ctx: MatchContext, stick: Vector3) -> Vector3:
	var goal_x := player.team.target_goal_x(ctx.court)
	var post := maxf(0.1, ctx.court.half_goal_width - _num("shot_post_inset", 0.45))
	var flat := Vector3(stick.x, 0.0, stick.z)
	if flat.length() < 0.3:
		return Vector3(goal_x, 0.0, _away_from_keeper(player, post))
	var dir := flat.normalized()
	var ahead := goal_x - player.position.x
	if absf(dir.x) > 0.05 and signf(dir.x) == signf(ahead):
		var cross_z := player.position.z + dir.z * ahead / dir.x
		if absf(cross_z) <= ctx.court.half_goal_width + _num("shot_assist_margin", 1.5):
			return Vector3(goal_x, 0.0, cross_z)
		return Vector3(goal_x, 0.0, signf(cross_z) * post)
	if absf(dir.z) > 0.2:
		return Vector3(goal_x, 0.0, signf(dir.z) * post)
	return Vector3(goal_x, 0.0, _away_from_keeper(player, post))


## The post on the side away from the opponent keeper (else the far side from the shooter).
static func _away_from_keeper(player: Player, post: float) -> float:
	var opponent := player.team.opponent
	if opponent != null and opponent.keeper != null and absf(opponent.keeper.position.z) > 0.05:
		return -signf(opponent.keeper.position.z) * post
	if absf(player.position.z) > 0.05:
		return -signf(player.position.z) * post
	return post


static func _num(key: String, fallback: float) -> float:
	return float(Config.get_value("player", key, fallback))
