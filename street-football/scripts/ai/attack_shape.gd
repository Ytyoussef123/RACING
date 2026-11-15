class_name AttackShape
extends RefCounted
## Where the players without the ball go while their side has it (jobs from AttackRoles):
## support next to the carrier at an angle with a clear lane, forward high and wide on the side
## away from the ball (or running in behind the last defender), cover behind the ball, and the
## passer's give-and-go run. Every spot then steps away from an opponent standing on it and from
## teammates closer than spacing_min, so the team spreads out instead of bunching.
## Numbers: data/config/ai.json (support_*, forward_*, cover_*, run_*, give_go_*, spacing_*).


## Intent of a player without the ball while his side has it.
static func intent_for(player: Player, ctx: MatchContext, brain: TeamBrain) -> PlayerIntent:
	var s := player.ai
	var carrier := AttackRoles.carrier_of(player.team, ctx)
	var target: Vector3
	var sprint := false
	if s.go_left > 0.0:
		target = s.go_target
		sprint = true
	elif s.run_left > 0.0:
		target = run_spot(player, ctx)
		sprint = true
	else:
		if carrier != null and s.attack_role == AiPlayerState.AttackRole.SUPPORT:
			target = support_spot(carrier, ctx, brain.support_angle)
		elif s.attack_role == AiPlayerState.AttackRole.FORWARD:
			target = forward_spot(player.team, ctx, brain.forward_side)
		elif s.attack_role == AiPlayerState.AttackRole.COVER:
			target = cover_spot(player.team, ctx, brain.forward_side)
		else:
			target = FormationPositions.slot_target(player, ctx, true)
		target = get_open(target, player.team)
	target = spaced(player, target, ctx)
	var intent := Steering.seek(player, target)
	# Far from his spot (the ball just changed sides, or the carrier ran away): he sprints there.
	if s.attack_role != AiPlayerState.AttackRole.NONE \
			and player.flat_distance_to(target) > Steering.num("job_sprint_distance", 4.5):
		sprint = true
	if sprint and intent.move != Vector3.ZERO:
		intent.sprint = true
	return intent


## Support: support_distance from where the carrier will be in support_lead_seconds, `angle`
## degrees from straight toward goal.
static func support_spot(carrier: Player, ctx: MatchContext, angle: float) -> Vector3:
	return clamp_to_court(_anchor(carrier) + _direction(carrier.team, angle) * Steering.num("support_distance", 6.5), ctx.court)


## Decision tick: the support angle (support_angles, both sides) with the clearest lane from the
## carrier, most room from opponents, some progress, away from the walls and from the other
## teammates' spots (`avoid`, Vector3s); the current angle gets support_keep_bonus.
static func best_support_angle(carrier: Player, ctx: MatchContext, current: float, avoid: Array) -> float:
	var angles: Array = Config.get_value("ai", "support_angles", [45.0, 90.0, 135.0])
	var best_angle := current
	var best_score := -INF
	for base in angles:
		for side in [-1.0, 1.0]:
			var angle: float = float(base) * float(side)
			var score := _support_score(carrier, ctx, angle, avoid)
			if absf(angle - current) < 0.5:
				score += Steering.num("support_keep_bonus", 0.6)
			if score > best_score:
				best_score = score
				best_angle = angle
	return best_angle


## Forward: level with the opponent's last outfield defender (pinning him back), at least
## forward_min_ahead in front of the ball, wide on side `side` (+1 / -1 in z).
static func forward_spot(team: Team, ctx: MatchContext, side: float) -> Vector3:
	var court := ctx.court
	var frac := last_defender_frac(team, ctx) - Steering.num("forward_gap", 1.0) / court.length
	frac = maxf(frac, team.to_frac(ctx.ball.position.x, court) + Steering.num("forward_min_ahead", 3.0) / court.length)
	frac = minf(frac, Steering.num("slot_frac_max", 0.9))
	var z := side * Steering.num("forward_width", 0.6) * (court.half_width - 1.0)
	return clamp_to_court(Vector3(team.frac_to_x(frac, court), 0.0, z), court)


## Cover: cover_attack_depth behind the ball, near the middle. When the ball is too deep for that
## (cover_min_frac), he comes level with it and moves across to side `side` (cover_wide_z), so the
## carrier has a square pass instead of a teammate at his heels.
static func cover_spot(team: Team, ctx: MatchContext, side: float) -> Vector3:
	var court := ctx.court
	var ball := ctx.ball.position
	var depth := Steering.num("cover_attack_depth", 10.0) / court.length
	var frac := team.to_frac(ball.x, court) - depth
	var min_frac := Steering.num("cover_min_frac", 0.15)
	var z := ball.z * Steering.num("cover_z_follow", 0.3)
	if frac < min_frac:
		var wide := side * Steering.num("cover_wide_z", 0.45) * (court.half_width - 1.0)
		z = lerpf(z, wide, clampf((min_frac - frac) / (depth * 0.5), 0.0, 1.0))
	return clamp_to_court(Vector3(team.frac_to_x(maxf(frac, min_frac), court), 0.0, z), court)


## Run in behind: run_depth beyond the opponent's last outfield defender (not past
## run_max_frac), in the lane chosen when the run started.
static func run_spot(player: Player, ctx: MatchContext) -> Vector3:
	var team := player.team
	var court := ctx.court
	var frac := minf(last_defender_frac(team, ctx) + Steering.num("run_depth", 3.0) / court.length,
		Steering.num("run_max_frac", 0.88))
	return clamp_to_court(Vector3(team.frac_to_x(frac, court), 0.0, player.ai.run_z), court)


## Lane of a run: from where the forward stands, bent toward the middle (run_center_pull).
static func run_lane(player: Player, ctx: MatchContext) -> float:
	var limit := ctx.court.half_width - Steering.num("run_lane_margin", 2.0)
	return clampf(player.position.z * (1.0 - Steering.num("run_center_pull", 0.4)), -limit, limit)


## A run is worth making: the carrier faces forward, there is room behind the last defender,
## the forward is not already past him, and the run's spot stays within passing range.
static func may_run(player: Player, carrier: Player, ctx: MatchContext) -> bool:
	var team := player.team
	var court := ctx.court
	if carrier.motion.facing.x * team.attack_sign < Steering.num("run_facing_min", 0.2):
		return false
	var line := last_defender_frac(team, ctx)
	if (1.0 - line) * court.length < Steering.num("run_min_space", 5.0):
		return false
	if team.to_frac(player.position.x, court) > line:
		return false
	return carrier.flat_distance_to(run_spot(player, ctx)) <= Steering.num("run_max_pass_distance", 20.0)


## Give-and-go: give_go_distance up the court from where he passed, a little toward the middle,
## and give_go_side_step to the side away from the receiver (not into him); not past slot_frac_max.
static func give_go_spot(passer: Player, ctx: MatchContext, receiver: Player) -> Vector3:
	var team := passer.team
	var court := ctx.court
	var frac := team.to_frac(passer.position.x, court) + Steering.num("give_go_distance", 7.0) / court.length
	frac = minf(frac, Steering.num("slot_frac_max", 0.9))
	var z := passer.position.z * (1.0 - Steering.num("give_go_center_pull", 0.3))
	if receiver != null:
		var away := -signf(receiver.position.z - passer.position.z)
		z += (away if away != 0.0 else 1.0) * Steering.num("give_go_side_step", 2.0)
	return clamp_to_court(Vector3(team.frac_to_x(frac, court), 0.0, z), court)


## How far up the court (0..1, seen from `team`) the opponent's outfield player nearest his own
## goal stands: the line a run in behind goes past.
static func last_defender_frac(team: Team, ctx: MatchContext) -> float:
	var best := -1.0
	for opp in team.opponent.outfield():
		best = maxf(best, team.to_frac(opp.position.x, ctx.court))
	return best if best >= 0.0 else Steering.num("slot_frac_max", 0.9)


## Steps away from the nearest opponent standing within get_open_distance of the spot.
static func get_open(target: Vector3, team: Team) -> Vector3:
	var nearest: Player = null
	var best := Steering.num("get_open_distance", 2.5)
	for opp in team.opponent.players:
		var d := opp.flat_distance_to(target)
		if d < best and d > 0.01:
			best = d
			nearest = opp
	if nearest == null:
		return target
	return target + Steering.flat(target - nearest.position) / best * Steering.num("get_open_shift", 1.5)


## Pushes the spot away from every teammate closer than spacing_min (by spacing_push of the
## missing distance), so teammates spread out; then keeps it on the court.
static func spaced(player: Player, target: Vector3, ctx: MatchContext) -> Vector3:
	var min_gap := Steering.num("spacing_min", 5.0)
	var push := Steering.num("spacing_push", 0.7)
	var result := target
	for mate in player.team.outfield():
		if mate == player:
			continue
		var away := Steering.flat(target - mate.position)
		var d := away.length()
		if d < min_gap:
			var dir := away / d if d > 0.01 else Vector3.BACK
			result += dir * (min_gap - d) * push
	return clamp_to_court(result, ctx.court)


static func clamp_to_court(spot: Vector3, court: CourtData) -> Vector3:
	var margin := Steering.num("shape_wall_margin", 1.0)
	return Vector3(clampf(spot.x, -court.half_length + margin, court.half_length - margin), 0.0,
		clampf(spot.z, -court.half_width + margin, court.half_width - margin))


static func _support_score(carrier: Player, ctx: MatchContext, angle: float, avoid: Array) -> float:
	var team := carrier.team
	var raw := _anchor(carrier) + _direction(team, angle) * Steering.num("support_distance", 6.5)
	var spot := clamp_to_court(raw, ctx.court)
	var score := cos(deg_to_rad(angle)) * Steering.num("support_forward_weight", 0.8)
	score -= Steering.flat(raw - spot).length() * Steering.num("support_wall_weight", 1.0)
	score += minf(team.opponent.nearest_distance_to(spot), Steering.num("pass_open_cap", 5.0)) \
		* Steering.num("support_open_weight", 0.4)
	if CarrierAI.lane_clear(carrier.position, spot, team.opponent):
		score += Steering.num("support_lane_bonus", 2.0)
	var crowd := Steering.num("support_crowd_distance", 6.0)
	for other: Vector3 in avoid:
		var d := Steering.flat(spot - other).length()
		if d < crowd:
			score -= (crowd - d) * Steering.num("support_crowd_weight", 0.5)
	return score


## Where the carrier will be in support_lead_seconds (the support keeps up with a running carrier).
static func _anchor(carrier: Player) -> Vector3:
	return carrier.position + Steering.flat(carrier.motion.velocity) * Steering.num("support_lead_seconds", 0.4)


## Unit vector `angle` degrees from straight toward the opponent's goal (turning around the vertical).
static func _direction(team: Team, angle: float) -> Vector3:
	return Vector3(team.attack_sign, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(angle))
