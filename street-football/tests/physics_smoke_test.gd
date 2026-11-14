extends Node
## Headless checks of the ball and player physics, run by CI:
##   godot --headless --path street-football res://tests/physics_smoke_test.tscn
## Prints one "TEST PASS" / "TEST FAIL" line per check, then "TESTS DONE: N failure(s)".
## Not exported in the APK (export filter excludes tests/*).

const DT := 1.0 / 60.0
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _failures := 0


func _ready() -> void:
	_test_rolling_stops()
	_test_bounce_settles()
	_test_side_wall_bounce()
	_test_goal_detected_and_ball_stays_in_net()
	_test_post_bounces_back()
	_test_shot_over_goal_is_no_goal()
	_test_open_court_out()
	_test_dribble_and_shoot_scores()
	print("TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(test_name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("TEST PASS ", test_name)
	else:
		_failures += 1
		print("TEST FAIL ", test_name, " ", detail)


func _new_ball(pos: Vector3, vel: Vector3) -> BallPhysics:
	var ball := BallPhysics.new()
	ball.place(pos)
	ball.velocity = vel
	return ball


func _test_rolling_stops() -> void:
	var ball := _new_ball(Vector3(0.0, 0.11, 0.0), Vector3(10.0, 0.0, 0.0))
	var t := 0.0
	while ball.horizontal_speed() > 0.0 and t < 20.0:
		ball.step(DT)
		t += DT
	var x := ball.position.x
	_check("rolling ball stops", t < 20.0 and x > 5.0 and x < 40.0, "t=%.2f x=%.2f" % [t, x])


func _test_bounce_settles() -> void:
	var ball := _new_ball(Vector3(0.0, 2.0, 0.0), Vector3.ZERO)
	var bounced := false
	var max_after := 0.0
	for i in range(600):
		var was_falling := ball.velocity.y < 0.0
		ball.step(DT)
		if was_falling and ball.velocity.y > 0.0:
			bounced = true
		if bounced:
			max_after = maxf(max_after, ball.position.y)
	_check("ball bounces lower and settles", bounced and max_after < 1.2 and ball.is_on_ground(),
		"max_after=%.2f y=%.3f" % [max_after, ball.position.y])


func _test_side_wall_bounce() -> void:
	var court := CourtData.load_court("cage_concrete")
	var ball := _new_ball(Vector3(0.0, ball_radius(), 0.0), Vector3(0.0, 0.0, 12.0))
	var bounced := false
	var inside := true
	for i in range(120):
		ball.step(DT)
		CourtBounds.resolve(ball, court)
		if ball.velocity.z < 0.0:
			bounced = true
		if absf(ball.position.z) > court.half_width - ball.radius + 0.001:
			inside = false
	_check("side wall bounces the ball", bounced and inside)


func _test_goal_detected_and_ball_stays_in_net() -> void:
	var court := CourtData.load_court("cage_concrete")
	var ball := _new_ball(Vector3(court.half_length - 3.0, ball_radius(), 0.0), Vector3(15.0, 0.0, 0.0))
	var goal := 0
	var max_x := 0.0
	for i in range(180):
		ball.step(DT)
		CourtBounds.resolve(ball, court)
		if goal == 0:
			goal = GoalDetector.check(ball, court)
		max_x = maxf(max_x, ball.position.x)
	_check("goal detected at +x", goal == 1, "goal=%d" % goal)
	_check("ball stays in the net", max_x <= court.half_length + court.goal_depth, "max_x=%.2f" % max_x)


func _test_post_bounces_back() -> void:
	var court := CourtData.load_court("cage_concrete")
	var ball := _new_ball(Vector3(court.half_length - 2.0, ball_radius(), court.half_goal_width), Vector3(12.0, 0.0, 0.0))
	var bounced := false
	for i in range(60):
		ball.step(DT)
		CourtBounds.resolve(ball, court)
		if ball.velocity.x < 0.0:
			bounced = true
	_check("post bounces the ball back", bounced)


func _test_shot_over_goal_is_no_goal() -> void:
	var court := CourtData.load_court("cage_concrete")
	var ball := _new_ball(Vector3(court.half_length - 3.0, 3.0, 0.0), Vector3(15.0, 3.0, 0.0))
	var goal := 0
	for i in range(120):
		ball.step(DT)
		CourtBounds.resolve(ball, court)
		goal = maxi(goal, absi(GoalDetector.check(ball, court)))
	_check("shot over the bar is no goal", goal == 0)


func _test_open_court_out() -> void:
	var court := CourtData.load_court("open_lot")
	var ball := _new_ball(Vector3(0.0, ball_radius(), 0.0), Vector3(0.0, 0.0, 15.0))
	var out := false
	for i in range(120):
		ball.step(DT)
		if CourtBounds.resolve(ball, court) == CourtBounds.Event.OUT:
			out = true
			break
	_check("open court reports OUT", out)


## Whole chain: the player runs to the ball, dribbles toward the +x goal and shoots.
func _test_dribble_and_shoot_scores() -> void:
	var court := CourtData.load_court("cage_concrete")
	var player: Player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.reset_to(Vector3(-3.0, 0.0, 0.0), Vector3.RIGHT)
	var ball := _new_ball(Vector3(0.0, ball_radius(), 0.0), Vector3.ZERO)
	var handling := BallHandling.new()
	var had_ball := false
	var shot_done := false
	var charge_frames := 0
	var goal := 0
	for i in range(900):
		var intent := PlayerIntent.new()
		intent.move = Vector3.RIGHT
		if handling.has_ball and player.position.x > court.half_length - 8.0 and charge_frames < 20:
			intent.shoot_held = true
			charge_frames += 1
		player.move(DT, intent.move, intent.sprint, handling.has_ball, court)
		handling.update(DT, player, ball, intent)
		had_ball = had_ball or handling.has_ball
		if charge_frames >= 20 and not handling.has_ball:
			shot_done = true
		ball.step(DT)
		CourtBounds.resolve(ball, court)
		goal = GoalDetector.check(ball, court)
		if goal != 0:
			break
	player.queue_free()
	_check("player takes the ball", had_ball)
	_check("player shoots", shot_done)
	_check("dribble and shot score at +x", goal == 1, "goal=%d ball=%s" % [goal, ball.position])


func ball_radius() -> float:
	return float(Config.get_value("ball", "radius", 0.11))
