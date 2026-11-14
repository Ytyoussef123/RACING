class_name PressAssist
extends RefCounted
## PRESS (hold the SPRINT button when you don't have the ball, like eFootball's Dash & Press):
## the player sprints at the ball carrier by himself, staying goal-side, then goes for the ball
## and tackles automatically when in reach. On a loose ball he sprints to where he can meet it.
## Numbers: data/config/player.json (press_*).


static func apply(player: Player, intent: PlayerIntent, delta: float, ctx: MatchContext) -> PlayerIntent:
	var carrier := ctx.possession.holder
	if carrier != null and carrier.team == player.team:
		return intent
	intent.sprint = true
	intent.press_held = true
	if carrier == null:
		var meet := Steering.flat(ReceiveAssist.intercept_point(player, ctx) - player.position)
		if meet.length() > 0.05:
			intent.move = meet.normalized() * clampf(meet.length() / 0.5, 0.0, 1.0)
		return intent
	var ball := ctx.ball
	var dist_to_ball := player.flat_distance_to(ball.position)
	var target := ball.position
	if dist_to_ball > _cfg("press_close_distance", 2.0):
		var own_goal := Vector3(player.team.own_goal_x(ctx.court), 0.0, 0.0)
		var goal_side := Steering.flat(own_goal - carrier.position)
		if goal_side.length() > 0.01:
			target = carrier.position + goal_side.normalized() * _cfg("press_goal_side_offset", 0.6)
	var to := Steering.flat(target - player.position)
	if to.length() > 0.05:
		intent.move = to.normalized()
	player.ai.tackle_timer -= delta
	var reach := _cfg("tackle_reach", 1.3) * _cfg("press_tackle_reach_factor", 0.85)
	if dist_to_ball <= reach and player.ai.tackle_timer <= 0.0:
		player.ai.tackle_timer = _cfg("press_tackle_interval", 0.6)
		intent.tackle_pressed = true
	return intent


static func _cfg(key: String, fallback: float) -> float:
	return float(Config.get_value("player", key, fallback))
