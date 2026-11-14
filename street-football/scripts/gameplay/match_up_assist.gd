class_name MatchUpAssist
extends RefCounted
## MATCH-UP (hold, when you don't have the ball): the player shadows the ball carrier from the
## goal side at a short distance and follows his moves without diving in; tap TACKLE when ready.
## On a loose ball he moves to where he can meet it. Numbers: data/config/player.json (match_up_*).


static func apply(player: Player, intent: PlayerIntent, ctx: MatchContext) -> PlayerIntent:
	var carrier := ctx.possession.holder
	if carrier != null and carrier.team == player.team:
		return intent
	var target: Vector3
	if carrier == null:
		target = ReceiveAssist.intercept_point(player, ctx)
	else:
		var own_goal := Vector3(player.team.own_goal_x(ctx.court), 0.0, 0.0)
		var goal_side := Steering.flat(own_goal - carrier.position)
		goal_side = goal_side.normalized() if goal_side.length() > 0.01 else Vector3(-player.team.attack_sign, 0.0, 0.0)
		var lead := Steering.flat(carrier.motion.velocity) * _cfg("match_up_lead_seconds", 0.25)
		target = carrier.position + lead + goal_side * _cfg("match_up_contain_distance", 1.6)
	var assisted := PlayerIntent.new()
	assisted.match_up_held = true
	assisted.tackle_pressed = intent.tackle_pressed
	assisted.switch_pressed = intent.switch_pressed
	assisted.shoulder_pressed = intent.shoulder_pressed
	var to := Steering.flat(target - player.position)
	var d := to.length()
	if d > 0.1:
		assisted.move = to / d * clampf(d / _cfg("match_up_arrive_distance", 0.8), 0.0, 1.0)
	assisted.sprint = d > _cfg("match_up_sprint_distance", 3.5)
	return assisted


static func _cfg(key: String, fallback: float) -> float:
	return float(Config.get_value("player", key, fallback))
