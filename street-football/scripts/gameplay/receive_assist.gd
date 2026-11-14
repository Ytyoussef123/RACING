class_name ReceiveAssist
extends RefCounted
## Receive assist: the player a pass is aimed at runs by himself to the earliest point where he
## can meet the ball, then waits there, so a pass is not lost because the receiver stood still
## or ran the wrong way. The joystick keeps aiming a first-time shot or pass.
## intercept_point() is also used by PRESS and MATCH-UP on a loose ball, and by the AI.
## Numbers: data/config/player.json (receive_*).


## Earliest point of the ball's predicted path (walls included) this player can reach in time,
## or where the ball will be at the end of the prediction.
static func intercept_point(player: Player, ctx: MatchContext) -> Vector3:
	var sim := ctx.ball.copy()
	var step := 1.0 / maxf(1.0, _cfg("receive_prediction_rate", 20.0))
	var horizon := _cfg("receive_prediction_seconds", 2.0)
	var speed := _cfg("sprint_speed", 7.8) * player.motion.speed_factor * _cfg("receive_speed_margin", 0.85)
	var reach := _cfg("control_radius", 0.9)
	var max_height := _cfg("control_max_ball_height", 0.6)
	var t := 0.0
	while t < horizon:
		sim.step(step)
		CourtBounds.resolve(sim, ctx.court)
		t += step
		if sim.position.y > max_height:
			continue
		var run := maxf(0.0, player.flat_distance_to(sim.position) - reach)
		if run <= speed * t:
			return Vector3(sim.position.x, 0.0, sim.position.z)
	return Vector3(sim.position.x, 0.0, sim.position.z)


static func apply(player: Player, intent: PlayerIntent, ctx: MatchContext) -> PlayerIntent:
	var assisted := PlayerIntent.new()
	var stick := Steering.flat(intent.move)
	assisted.aim = stick if stick.length() > 0.3 else Vector3(player.team.attack_sign, 0.0, 0.0)
	assisted.shoot_held = intent.shoot_held
	assisted.pass_pressed = intent.pass_pressed
	assisted.through_pressed = intent.through_pressed
	var target := intercept_point(player, ctx)
	var to := Steering.flat(target - player.position)
	var d := to.length()
	if d > 0.15:
		assisted.move = to / d * clampf(d / _cfg("receive_arrive_distance", 0.8), 0.0, 1.0)
	assisted.sprint = d > _cfg("receive_sprint_distance", 2.5)
	return assisted


static func _cfg(key: String, fallback: float) -> float:
	return float(Config.get_value("player", key, fallback))
