class_name PlayerCollisions
extends RefCounted
## Players can't walk through each other: overlapping bodies are pushed apart equally.


static func resolve(players: Array[Player], court: CourtData) -> void:
	var count := players.size()
	for i in range(count):
		var a := players[i]
		for j in range(i + 1, count):
			var b := players[j]
			var d := Vector2(b.position.x - a.position.x, b.position.z - a.position.z)
			var min_dist := a.radius + b.radius
			var dist := d.length()
			if dist >= min_dist:
				continue
			var n := d / dist if dist > 0.0001 else Vector2(1.0, 0.0)
			var push := (min_dist - dist) * 0.5
			a.position.x -= n.x * push
			a.position.z -= n.y * push
			b.position.x += n.x * push
			b.position.z += n.y * push
	for p in players:
		p.clamp_to_court(court)
