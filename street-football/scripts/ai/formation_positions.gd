class_name FormationPositions
extends RefCounted
## Where each player should stand: the formation slot, shifted with the ball
## (up the court when attacking, back and tighter when defending). Numbers: data/config/ai.json.


static func slot_target(player: Player, ctx: MatchContext, attacking: bool) -> Vector3:
	var team := player.team
	var court := ctx.court
	var slot := team.formation.slot(player.slot_index)
	var shifts: Dictionary = Config.get_value("ai", "role_shift", {})
	var shift := float(shifts.get(player.role, 0.4))
	var ball_frac := team.to_frac(ctx.ball.position.x, court)
	var frac := float(slot.get("x", 0.4)) + (ball_frac - 0.5) * shift
	if attacking:
		frac += Steering.num("attack_push", 0.08)
	else:
		frac -= Steering.num("defend_drop", 0.06)
	frac = clampf(frac, Steering.num("slot_frac_min", 0.06), Steering.num("slot_frac_max", 0.9))
	var z := float(slot.get("z", 0.0)) * (court.half_width - 1.0)
	if not attacking:
		z *= Steering.num("defend_compress", 0.75)
	z += ctx.ball.position.z * Steering.num("z_ball_follow", 0.25)
	z = clampf(z, -court.half_width + 0.8, court.half_width - 0.8)
	return Vector3(team.frac_to_x(frac, court), 0.0, z)


## Kick-off position: the slot squeezed into the team's own half,
## out of the center circle for the team that does not kick off.
static func kickoff_position(player: Player, court: CourtData, kicking: bool) -> Vector3:
	var team := player.team
	var slot := team.formation.slot(player.slot_index)
	var max_frac := 0.47
	if not kicking:
		max_frac = 0.5 - (court.number("center_circle_radius", 2.5) + 0.6) / court.length
	var frac := minf(float(slot.get("x", 0.4)) * 0.6, max_frac)
	var z := float(slot.get("z", 0.0)) * (court.half_width - 1.5)
	return Vector3(team.frac_to_x(frac, court), 0.0, z)
