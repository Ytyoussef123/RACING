class_name Steering
extends RefCounted
## Small movement helpers shared by the AI: run to a point, slowing down on arrival.


static func seek(player: Player, target: Vector3, sprint_allowed: bool = true) -> PlayerIntent:
	var intent := PlayerIntent.new()
	var to := Vector3(target.x - player.position.x, 0.0, target.z - player.position.z)
	var d := to.length()
	if d < 0.25:
		return intent
	intent.move = to / d * clampf(d / num("arrive_distance", 1.5), 0.2, 1.0)
	intent.sprint = sprint_allowed and d > num("sprint_distance", 6.0)
	return intent


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Reads a number from data/config/ai.json.
static func num(key: String, fallback: float) -> float:
	return float(Config.get_value("ai", key, fallback))
