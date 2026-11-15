class_name LoftedKick
extends RefCounted
## A ball played in the air (lofted pass, lofted through ball): it rises to an apex that grows with
## the distance, over the heads of the players in between, and comes down `distance` away. The
## flat speed is corrected once on a quick simulated flight (air drag), so it lands where it should.
## The power bar sets the distance: lofted_distance_min..max. Numbers: data/config/player.json.

const SIM_STEP := 1.0 / 60.0
const SIM_SECONDS := 4.0


static func distance_for(power: float) -> float:
	return lerpf(_cfg("lofted_distance_min", 5.0), _cfg("lofted_distance_max", 30.0), clampf(power, 0.0, 1.0))


## The power that lands the ball `distance` away (the AI aims its lofted passes with it).
static func power_for(distance: float) -> float:
	var low := _cfg("lofted_distance_min", 5.0)
	var high := _cfg("lofted_distance_max", 30.0)
	return clampf((distance - low) / maxf(0.01, high - low), 0.0, 1.0)


## Highest point of the flight: lofted_apex_base plus lofted_apex_per_meter per meter, clamped.
static func apex(distance: float) -> float:
	return clampf(_cfg("lofted_apex_base", 1.8) + distance * _cfg("lofted_apex_per_meter", 0.1),
		_cfg("lofted_apex_min", 2.2), _cfg("lofted_apex_max", 4.0))


## Seconds in the air (without drag): to lead a running receiver.
static func flight_time(distance: float) -> float:
	var g := _gravity()
	return 2.0 * sqrt(2.0 * g * apex(distance)) / g


## Kick velocity from `from` along `dir` (flattened) that comes down `distance` away.
static func velocity(from: Vector3, dir: Vector3, distance: float) -> Vector3:
	var flat_dir := Steering.flat(dir).normalized()
	var up := sqrt(2.0 * _gravity() * apex(distance))
	var flat_speed := distance / maxf(0.1, flight_time(distance))
	var landed := _landing_distance(from, flat_dir * flat_speed + Vector3.UP * up)
	if landed > 0.1:
		flat_speed *= distance / landed
	return flat_dir * flat_speed + Vector3.UP * up


## How far (flat) a ball kicked from `from` first comes down, in a quick simulation (no spin, walls).
static func _landing_distance(from: Vector3, kick_velocity: Vector3) -> float:
	var sim := BallPhysics.new()
	sim.place(from)
	sim.velocity = kick_velocity
	var t := 0.0
	while t < SIM_SECONDS:
		var falling := sim.velocity.y < 0.0
		sim.step(SIM_STEP)
		t += SIM_STEP
		if falling and sim.velocity.y >= 0.0:
			break
	return Steering.flat(sim.position - from).length()


static func _gravity() -> float:
	return maxf(1.0, float(Config.get_value("ball", "gravity", 9.81)))


static func _cfg(key: String, fallback: float) -> float:
	return float(Config.get_value("player", key, fallback))
