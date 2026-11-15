class_name AttackRoles
extends RefCounted
## Jobs of the players without the ball while their side has it, given by the team brain at each
## decision tick: SUPPORT (a short pass next to the carrier), FORWARD (high and wide; makes runs in
## behind the last defender) and COVER (stays behind the ball). The players nearest the job spots
## take the jobs; a player keeps his job unless another is clearly closer, and his formation role
## prefers its job (role_jobs: a defender covers, a striker goes forward). Also the timers of the
## runs and of the give-and-go (the passer runs forward after his pass).
## Spots: AttackShape. Numbers: data/config/ai.json (role_*, run_*, give_go_*).

## Every way to give the first n jobs to n players: PERMUTATIONS[n][k][i] = job of player i
## (0 support, 1 forward, 2 cover).
const PERMUTATIONS := [[], [[0]], [[0, 1], [1, 0]], [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]]


## True when our side has the ball, or our pass is on its way to a teammate.
static func in_possession(team: Team, ctx: MatchContext) -> bool:
	return carrier_of(team, ctx) != null


## The player the shape is built around: our holder, or the teammate our pass is going to.
static func carrier_of(team: Team, ctx: MatchContext) -> Player:
	var holder := ctx.possession.holder
	if holder != null:
		return holder if holder.team == team else null
	var target := ctx.possession.pass_target
	return target if target != null and target.team == team else null


## Every frame: counts the run and give-and-go timers down (a run also ends at its spot), and
## starts a give-and-go for the player of ours who just passed (not the last man back).
static func tick(brain: TeamBrain, delta: float, ctx: MatchContext) -> void:
	var outfield := brain.team.outfield()
	for p in outfield:
		var s := p.ai
		s.go_left = maxf(0.0, s.go_left - delta)
		s.run_cooldown = maxf(0.0, s.run_cooldown - delta)
		if s.run_left > 0.0:
			s.run_left -= delta
			if s.run_left <= 0.0 or p.flat_distance_to(AttackShape.run_spot(p, ctx)) < Steering.num("run_arrive_distance", 1.2):
				end_run(p)
	var possession := ctx.possession
	if possession.kick_count == brain.kick_seen:
		return
	brain.kick_seen = possession.kick_count
	var passer := possession.last_kicker
	if passer == null or passer.team != brain.team or passer.is_keeper or possession.last_kick_kind != "pass":
		return
	if _deepest(outfield, ctx) == passer or ctx.rng.randf() >= brain.team.tuning.give_go_chance:
		return
	passer.ai.go_left = Steering.num("give_go_seconds", 1.6)
	passer.ai.go_target = AttackShape.give_go_spot(passer, ctx)


## Decision tick while our side has the ball: gives the players without the ball their jobs and
## maybe sends the forward on a run in behind.
static func assign(brain: TeamBrain, ctx: MatchContext, human_player: Player) -> void:
	var team := brain.team
	var carrier := carrier_of(team, ctx)
	var off: Array[Player] = []
	for p in team.outfield():
		if p == carrier or p == human_player:
			_stand_down(p)
		else:
			off.append(p)
	if carrier == null or carrier.is_keeper:
		# Our keeper has the ball: everyone takes his formation slot to offer an outlet.
		for p in off:
			p.ai.attack_role = AiPlayerState.AttackRole.NONE
		return
	var ball_z := ctx.ball.position.z
	if absf(ball_z) >= Steering.num("forward_side_switch_z", 2.5):
		brain.forward_side = -signf(ball_z)
	var forward_spot := AttackShape.forward_spot(team, ctx, brain.forward_side)
	var cover_spot := AttackShape.cover_spot(team, ctx)
	brain.support_angle = AttackShape.best_support_angle(carrier, ctx, brain.support_angle, [forward_spot, cover_spot])
	var spots := [AttackShape.support_spot(carrier, ctx, brain.support_angle), forward_spot, cover_spot]
	_give_jobs(off, spots)
	_maybe_run(team, off, carrier, ctx)


## Our side lost the ball: no more jobs, runs or give-and-go.
static func clear(team: Team) -> void:
	for p in team.players:
		_stand_down(p)


static func end_run(p: Player) -> void:
	p.ai.run_left = 0.0
	p.ai.run_cooldown = Steering.num("run_cooldown", 2.5)


static func _stand_down(p: Player) -> void:
	p.ai.attack_role = AiPlayerState.AttackRole.NONE
	p.ai.go_left = 0.0
	if p.ai.run_left > 0.0:
		end_run(p)


## The cheapest way to give the jobs: the sum of the distances to the job spots, minus
## role_keep_bonus for each player keeping his job and role_job_bonus when the job suits his
## formation role. A player running in behind stays the forward.
static func _give_jobs(off: Array[Player], spots: Array) -> void:
	var n := mini(off.size(), spots.size())
	if n == 0:
		return
	var keep := Steering.num("role_keep_bonus", 3.0)
	var suits := Steering.num("role_job_bonus", 2.0)
	var role_jobs: Dictionary = Config.get_value("ai", "role_jobs", {})
	var best: Array = PERMUTATIONS[n][0]
	var best_cost := INF
	for perm: Array in PERMUTATIONS[n]:
		var cost := 0.0
		var allowed := true
		for i in range(n):
			var job: int = perm[i]
			var p := off[i]
			var role := _job(job)
			if p.ai.run_left > 0.0 and role != AiPlayerState.AttackRole.FORWARD:
				allowed = false
				break
			var spot: Vector3 = spots[job]
			cost += p.flat_distance_to(spot)
			if p.ai.attack_role == role:
				cost -= keep
			if str(role_jobs.get(p.role, "")) == _job_name(job):
				cost -= suits
		if allowed and cost < best_cost:
			best_cost = cost
			best = perm
	for i in range(off.size()):
		if i < n:
			var job: int = best[i]
			off[i].ai.attack_role = _job(job)
		else:
			off[i].ai.attack_role = AiPlayerState.AttackRole.NONE


## The forward starts a run in behind the last defender now and then (run_rate per second, by
## difficulty) while the carrier faces forward and the run stays within passing range.
static func _maybe_run(team: Team, off: Array[Player], carrier: Player, ctx: MatchContext) -> void:
	if ctx.possession.holder != carrier:
		return
	for p in off:
		var s := p.ai
		if s.attack_role != AiPlayerState.AttackRole.FORWARD or s.run_left > 0.0 or s.run_cooldown > 0.0:
			continue
		s.run_z = AttackShape.run_lane(p, ctx)
		if AttackShape.may_run(p, carrier, ctx) \
				and ctx.rng.randf() < team.tuning.run_rate * team.tuning.decision_interval:
			s.run_left = Steering.num("run_seconds", 2.4)


static func _job(index: int) -> AiPlayerState.AttackRole:
	if index == 0:
		return AiPlayerState.AttackRole.SUPPORT
	if index == 1:
		return AiPlayerState.AttackRole.FORWARD
	return AiPlayerState.AttackRole.COVER


static func _job_name(index: int) -> String:
	if index == 0:
		return "support"
	if index == 1:
		return "forward"
	return "cover"


## The outfield player nearest our own goal.
static func _deepest(players: Array[Player], ctx: MatchContext) -> Player:
	var best: Player = null
	var best_frac := INF
	for p in players:
		var frac := p.team.to_frac(p.position.x, ctx.court)
		if frac < best_frac:
			best_frac = frac
			best = p
	return best
