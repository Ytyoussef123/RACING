class_name CourtBounds
extends RefCounted
## Keeps the ball in the court: side and end walls (cage courts), goal posts, crossbar and nets.
## On open courts (no walls) it reports when the ball leaves the court.
## Restitution values come from data/config/ball.json.

enum Event { NONE, OUT }


static func resolve(ball: BallPhysics, court: CourtData) -> Event:
	var post_e := float(Config.get_value("ball", "post_restitution", 0.6))
	for side: float in [-1.0, 1.0]:
		_collide_posts(ball, court, side, post_e)
		_collide_crossbar(ball, court, side, post_e)
	if _in_goal_box(ball, court):
		_keep_in_net(ball, court, float(Config.get_value("ball", "net_restitution", 0.15)))
		return Event.NONE
	if court.walls:
		_bounce_off_walls(ball, court, float(Config.get_value("ball", "wall_restitution", 0.7)))
		return Event.NONE
	return Event.OUT if _is_out(ball, court) else Event.NONE


## Ball center is behind a goal line, between the posts and under the crossbar.
static func _in_goal_box(ball: BallPhysics, court: CourtData) -> bool:
	var p := ball.position
	return absf(p.x) > court.half_length and absf(p.z) < court.half_goal_width and p.y < court.goal_height


## The part of the end line where the goal is open (no end wall there).
static func _in_goal_mouth(ball: BallPhysics, court: CourtData) -> bool:
	return absf(ball.position.z) < court.half_goal_width and ball.position.y < court.goal_height + ball.radius


static func _is_out(ball: BallPhysics, court: CourtData) -> bool:
	var p := ball.position
	return absf(p.z) > court.half_width + ball.radius or absf(p.x) > court.half_length + ball.radius


static func _bounce_off_walls(ball: BallPhysics, court: CourtData, e: float) -> void:
	var p := ball.position
	var v := ball.velocity
	var max_z := court.half_width - ball.radius
	if absf(p.z) > max_z:
		var sz := signf(p.z)
		p.z = sz * max_z
		if v.z * sz > 0.0:
			ball.report_hit("wall", absf(v.z))
			v.z = -v.z * e
			ball.spin *= 0.5
	var max_x := court.half_length - ball.radius
	if absf(p.x) > max_x and not _in_goal_mouth(ball, court):
		var sx := signf(p.x)
		p.x = sx * max_x
		if v.x * sx > 0.0:
			ball.report_hit("wall", absf(v.x))
			v.x = -v.x * e
			ball.spin *= 0.5
	ball.position = p
	ball.velocity = v


static func _keep_in_net(ball: BallPhysics, court: CourtData, e: float) -> void:
	var p := ball.position
	var v := ball.velocity
	var side_limit := court.half_goal_width - ball.radius
	if absf(p.z) > side_limit:
		var sz := signf(p.z)
		p.z = sz * side_limit
		if v.z * sz > 0.0:
			v.z = -v.z * e
	var back_limit := court.half_length + court.goal_depth - ball.radius
	if absf(p.x) > back_limit:
		var sx := signf(p.x)
		p.x = sx * back_limit
		if v.x * sx > 0.0:
			ball.report_hit("net", absf(v.x))
			v.x = -v.x * e
	var roof := court.goal_height - ball.radius
	if p.y > roof:
		p.y = roof
		if v.y > 0.0:
			v.y = -v.y * e
	ball.spin = 0.0
	ball.position = p
	ball.velocity = v


## Posts are vertical cylinders at the two ends of each goal line.
static func _collide_posts(ball: BallPhysics, court: CourtData, side: float, e: float) -> void:
	if ball.position.y > court.goal_height + ball.radius:
		return
	for post_z: float in [-court.half_goal_width, court.half_goal_width]:
		var d := Vector2(ball.position.x - side * court.half_length, ball.position.z - post_z)
		var n := _push_direction(d, ball.radius + court.post_radius)
		if n == Vector2.ZERO:
			continue
		var min_dist := ball.radius + court.post_radius
		ball.position.x = side * court.half_length + n.x * min_dist
		ball.position.z = post_z + n.y * min_dist
		var vn := ball.velocity.x * n.x + ball.velocity.z * n.y
		if vn < 0.0:
			ball.report_hit("post", -vn)
			ball.velocity.x -= (1.0 + e) * vn * n.x
			ball.velocity.z -= (1.0 + e) * vn * n.y
			ball.spin = 0.0


## The crossbar is a horizontal cylinder along z, on top of the goal.
static func _collide_crossbar(ball: BallPhysics, court: CourtData, side: float, e: float) -> void:
	if absf(ball.position.z) > court.half_goal_width:
		return
	var d := Vector2(ball.position.x - side * court.half_length, ball.position.y - court.goal_height)
	var n := _push_direction(d, ball.radius + court.post_radius)
	if n == Vector2.ZERO:
		return
	var min_dist := ball.radius + court.post_radius
	ball.position.x = side * court.half_length + n.x * min_dist
	ball.position.y = court.goal_height + n.y * min_dist
	var vn := ball.velocity.x * n.x + ball.velocity.y * n.y
	if vn < 0.0:
		ball.report_hit("post", -vn)
		ball.velocity.x -= (1.0 + e) * vn * n.x
		ball.velocity.y -= (1.0 + e) * vn * n.y
		ball.spin = 0.0


## Unit vector pushing the ball away from a bar, or ZERO when they don't touch.
static func _push_direction(offset: Vector2, min_dist: float) -> Vector2:
	var dist := offset.length()
	if dist >= min_dist or dist < 0.0001:
		return Vector2.ZERO
	return offset / dist
