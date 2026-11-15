class_name ShotTypes
extends RefCounted
## The shot types chosen by a slide on SHOOT; the power bar always sets only the power.
##   "low"  (slide down): along the ground, never over the bar; the bar sets its speed.
##   "chip" (slide up): a lob that comes down behind a keeper off his line; the bar sets where it
##          comes down: too little falls short, right drops under the bar, too much flies over
##          (the right power crosses the line at shot_chip_cross_height from any distance).
##   "curl" (slide left or right): starts wide of the far post and curls back inside it. Right
##          power goes in the corner; a bit too much hits the post or the bar (faster, less curve,
##          higher); too much flies over; too little curls into the middle (the keeper's ball).
## The good-power zone: a better finisher's shot stays closer to the ideal power for that distance
## (shot_skill_damp_*). Each returns {"velocity": Vector3, "spin": float}.
## Numbers: data/config/player.json (shot_low_*, shot_chip_*, shot_curl_*, shot_skill_damp_*).

const SIM_STEP := 1.0 / 60.0
const SIM_FRAMES := 180


static func low(player: Player, aim: Vector3, charge: float) -> Dictionary:
	var speed := lerpf(_cfg("shot_low_speed_min", 11.0), _cfg("shot_low_speed_max", 24.0), charge) \
		* player.stat("shot_speed_mult", 1.0)
	return {"velocity": Steering.flat(aim).normalized() * speed,
		"spin": player.motion.turn_rate * _cfg("shot_curve_from_turn", 0.35)}


## A chip at `target` (a point on the goal line, ShotAim).
static func chip(player: Player, ctx: MatchContext, target: Vector3, charge: float) -> Dictionary:
	var from := ctx.ball.position
	var power := skilled(player, chip_ideal_power(from, target), charge)
	var distance := lerpf(_cfg("shot_chip_distance_min", 4.0), _cfg("shot_chip_distance_max", 24.0), power)
	return {"velocity": LoftedKick.velocity_with_apex(from, target - from, distance, _chip_apex(distance)), "spin": 0.0}


## The power that brings a chip down through the goal line at shot_chip_cross_height: it comes down
## a little past the line, closer to it for a short chip (its fall is steeper).
static func chip_ideal_power(from: Vector3, target: Vector3) -> float:
	var low := _cfg("shot_chip_distance_min", 4.0)
	var high := _cfg("shot_chip_distance_max", 24.0)
	var d := Steering.flat(target - from).length()
	var cross := _cfg("shot_chip_cross_height", 1.2) - from.y
	var beyond := 0.0
	for i in range(2):
		var apex := _chip_apex(d + beyond)
		beyond = cross * d / maxf(0.5, 4.0 * apex - 2.0 * cross)
	return clampf((d + beyond - low) / maxf(0.01, high - low), 0.0, 1.0)


static func _chip_apex(distance: float) -> float:
	return clampf(_cfg("shot_chip_apex_base", 2.6) + distance * _cfg("shot_chip_apex_per_meter", 0.06),
		_cfg("shot_chip_apex_min", 2.8), _cfg("shot_chip_apex_max", 4.2))


## A curled shot to shot_curl_post_inset inside the far post, shot_curl_height high: aimed so that,
## at the ideal power for this distance, the curl brings it back there from wide of the post.
static func curl(player: Player, ctx: MatchContext, charge: float) -> Dictionary:
	var from := ctx.ball.position
	var target := curl_target(player, ctx)
	var to := Steering.flat(target - from)
	var d := maxf(0.5, to.length())
	var ideal := curl_ideal_power(player, ctx)
	var power := skilled(player, ideal, charge)
	var mult := player.stat("shot_speed_mult", 1.0)
	var ideal_speed := _curl_speed(ideal) * mult
	var ideal_lift := _lift_to(from, target, d, ideal_speed)
	var lift := ideal_lift + (power - ideal) * _cfg("shot_curl_lift_per_power", 6.0)
	# The spin bends it toward the middle of the goal, back from the far side.
	var dir := to / d
	var bend := Vector3(0.0, 0.0, -signf(target.z))
	var spin := _cfg("shot_curl_spin", 0.8) * signf(Vector3(dir.z, 0.0, -dir.x).dot(bend))
	var launch := _aim_for_curl(from, dir, target, ideal_speed, ideal_lift, spin)
	return {"velocity": launch * _curl_speed(power) * mult + Vector3.UP * lift, "spin": spin}


static func curl_target(player: Player, ctx: MatchContext) -> Vector3:
	var court := ctx.court
	return Vector3(player.team.target_goal_x(court), _cfg("shot_curl_height", 1.3),
		far_side(player, ctx) * (court.half_goal_width - _cfg("shot_curl_post_inset", 0.5)))


## The ideal power of a curled shot from here: grows with the distance.
static func curl_ideal_power(player: Player, ctx: MatchContext) -> float:
	var d := Steering.flat(curl_target(player, ctx) - ctx.ball.position).length()
	return clampf(_cfg("shot_curl_ideal_base", 0.3) + d * _cfg("shot_curl_ideal_per_meter", 0.025),
		_cfg("shot_curl_ideal_min", 0.35), _cfg("shot_curl_ideal_max", 0.85))


## The far post's side (+1 / -1 in z): opposite the shooter; from the middle, away from the keeper.
static func far_side(player: Player, ctx: MatchContext) -> float:
	var z := ctx.ball.position.z
	if absf(z) >= _cfg("shot_curl_center_band", 1.0):
		return -signf(z)
	var keeper: Player = player.team.opponent.keeper if player.team.opponent != null else null
	if keeper != null and absf(keeper.position.z) > 0.05:
		return -signf(keeper.position.z)
	return 1.0


## The power the shot really gets: a better finisher stays closer to the ideal one (his finishing
## error over shot_red_reference_degrees, clamped shot_skill_damp_min..max, scales the mistake).
static func skilled(player: Player, ideal: float, charge: float) -> float:
	var reference := _cfg("shot_red_reference_degrees", 3.0)
	var damp := clampf(player.stat("shot_error_degrees", reference) / maxf(0.01, reference),
		_cfg("shot_skill_damp_min", 0.5), _cfg("shot_skill_damp_max", 1.3))
	return clampf(ideal + (charge - ideal) * damp, 0.0, 1.0)


static func _curl_speed(power: float) -> float:
	return lerpf(_cfg("shot_curl_speed_min", 12.0), _cfg("shot_curl_speed_max", 24.0), clampf(power, 0.0, 1.0))


## Lift that brings a ball kicked at `speed` to the target's height at the goal line (no drag).
static func _lift_to(from: Vector3, target: Vector3, distance: float, speed: float) -> float:
	var t := distance / maxf(1.0, speed)
	var g := float(Config.get_value("ball", "gravity", 9.81))
	return (target.y - from.y + 0.5 * g * t * t) / t


## Launch direction that curls into `target` at the goal line: corrected twice on simulated flights.
static func _aim_for_curl(from: Vector3, dir: Vector3, target: Vector3, speed: float, lift: float,
		spin: float) -> Vector3:
	var launch := dir
	for i in range(3):
		var cross := _goal_line_crossing(from, launch * speed + Vector3.UP * lift, spin, target.x)
		if cross == Vector3.INF:
			break
		var miss := cross.z - target.z
		var angle := atan2(miss, maxf(1.0, absf(target.x - from.x))) * signf(launch.x)
		launch = launch.rotated(Vector3.UP, angle)
	return launch


## Where a ball kicked from `from` crosses x = goal_x (simulated, no walls), or Vector3.INF.
static func _goal_line_crossing(from: Vector3, kick_velocity: Vector3, spin: float, goal_x: float) -> Vector3:
	var sim := BallPhysics.new()
	sim.place(from)
	sim.kick(kick_velocity, spin)
	var side := signf(goal_x - from.x)
	var previous := sim.position
	for i in range(SIM_FRAMES):
		sim.step(SIM_STEP)
		if (sim.position.x - goal_x) * side >= 0.0:
			var t := (goal_x - previous.x) / maxf(0.0001, absf(sim.position.x - previous.x)) * side
			return previous.lerp(sim.position, clampf(t, 0.0, 1.0))
		previous = sim.position
	return Vector3.INF


static func _cfg(key: String, fallback: float) -> float:
	return float(Config.get_value("player", key, fallback))
