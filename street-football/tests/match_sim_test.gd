extends Node
## AI-vs-AI matches, run headless by CI:
##   godot --headless --fixed-fps 60 --path street-football res://tests/match_sim_test.tscn
## Plays MATCH_COUNT matches with fixed seeds (always the same result for the same code), one
## after the other. Checks that each reaches full time, that the ball never stays stuck, that the
## ball and players stay inside the court, and that goals are scored overall. Also prints the
## average goals per match, to keep an eye on game balance.
## Prints "TEST PASS"/"TEST FAIL" lines, then "MATCH TESTS DONE: N failure(s)".

const MATCH_SCENE := preload("res://scenes/match/match.tscn")
const MATCH_SECONDS := 150.0
const SEEDS: Array[int] = [11, 22, 33, 44, 55, 66]
const MIN_TOTAL_GOALS := 3
const STUCK_SECONDS := 8.0
## Team spacing sample: every SPACING_SAMPLE_SECONDS of play, the distance from each outfielder
## to his nearest teammate, whether two teammates stand closer than CLOSE_PAIR, and whether
## CROWD_COUNT or more of a side are within CROWD_RADIUS of the ball (players bunched around it).
const SPACING_SAMPLE_SECONDS := 0.5
const CLOSE_PAIR := 3.0
const CROWD_RADIUS := 4.0
const CROWD_COUNT := 3
## The same numbers for each side by phase of play: its side has the ball (or its pass is on the
## way to a teammate), the other side has it, or the ball is loose; and with the ball once the side
## has kept it for SETTLED_SECONDS (the shape has had time to form).
const PHASES: Array[String] = ["with the ball", "without the ball", "loose ball", "with the ball 2 s+"]
const SETTLED_SECONDS := 2.0
const SAFETY_SECONDS_PER_MATCH := 400.0

var _match: Node
var _index := -1
var _goals := 0
var _finished := false
var _final := Vector2i.ZERO
var _stuck_time := 0.0
var _elapsed := 0.0
var _results: Array[String] = []
var _total_goals := 0
var _all_finished := true
var _max_stuck := 0.0
var _out_of_bounds := false
var _score_mismatch := false
var _failures := 0
var _total_shots := 0
var _total_saves := 0
var _sample_timer := 0.0
var _spacing_sum := 0.0
var _spacing_count := 0
var _crowd_samples := 0
var _close_samples := 0
var _side_samples := 0
var _phase_sum: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _phase_count: Array[int] = [0, 0, 0, 0]
var _phase_close: Array[int] = [0, 0, 0, 0]
var _phase_crowd: Array[int] = [0, 0, 0, 0]
var _phase_sides: Array[int] = [0, 0, 0, 0]
## Side that has the ball (-1: nobody) and since when (s of this match).
var _owner := -1
var _owner_since := 0.0
## Diagnosis: how often each kind of close pair and each crowd near the ball happens, by the
## players' jobs (AttackRoles with the ball; chaser, cover, marker or zone without it).
var _pair_kinds: Dictionary = {}
var _crowd_kinds: Dictionary = {}


func _ready() -> void:
	Engine.max_fps = 0
	MatchSetup.test_mode = true
	MatchSetup.test_match_seconds = MATCH_SECONDS
	MatchSetup.court_id = "cage_concrete"
	# Fixed crews (not My Crew, which changes with the save) so the balance numbers stay comparable.
	MatchSetup.home_team_id = "concrete_kings"
	MatchSetup.away_team_id = "rooftop_rebels"
	_start_next()


func _start_next() -> void:
	_index += 1
	if _index >= SEEDS.size():
		_report()
		return
	MatchSetup.test_seed = SEEDS[_index]
	_goals = 0
	_finished = false
	_final = Vector2i.ZERO
	_stuck_time = 0.0
	_elapsed = 0.0
	_owner = -1
	_owner_since = 0.0
	_match = MATCH_SCENE.instantiate()
	add_child(_match)
	_match.goal_scored.connect(func(_team: int) -> void: _goals += 1)
	_match.full_time.connect(_on_full_time)


func _physics_process(delta: float) -> void:
	if _match == null:
		return
	_elapsed += delta
	var ctx: MatchContext = _match.ctx
	var ball := ctx.ball
	var court := ctx.court
	if ctx.possession.holder == null and ball.velocity.length() < 0.1 and _match.flow.state == MatchFlow.State.PLAYING:
		_stuck_time += delta
		_max_stuck = maxf(_max_stuck, _stuck_time)
	else:
		_stuck_time = 0.0
	if absf(ball.position.x) > court.half_length + court.goal_depth + 0.5 or absf(ball.position.z) > court.half_width + 0.5:
		_out_of_bounds = true
	for p in ctx.all_players:
		if absf(p.position.x) > court.half_length + 0.01 or absf(p.position.z) > court.half_width + 0.01:
			_out_of_bounds = true
	var owner := -1
	for team in ctx.teams:
		if _has_ball(team, ctx):
			owner = team.index
	if owner != _owner:
		_owner = owner
		_owner_since = _elapsed
	_sample_timer += delta
	if _sample_timer >= SPACING_SAMPLE_SECONDS and _match.flow.state == MatchFlow.State.PLAYING:
		_sample_timer = 0.0
		_sample_spacing(ctx)
	if _finished or _elapsed > SAFETY_SECONDS_PER_MATCH:
		_end_match()


func _sample_spacing(ctx: MatchContext) -> void:
	for team in ctx.teams:
		var phase := 2
		if _has_ball(team, ctx):
			phase = 0
		elif _has_ball(team.opponent, ctx):
			phase = 1
		var buckets: Array[int] = [phase]
		if phase == 0 and _elapsed - _owner_since >= SETTLED_SECONDS:
			buckets.append(3)
		var outfield := team.outfield()
		var near_ball := 0
		var close_pair := false
		var near_labels: Array[String] = []
		for i in range(outfield.size()):
			for j in range(i + 1, outfield.size()):
				if outfield[i].flat_distance_to(outfield[j].position) < CLOSE_PAIR:
					_count(_pair_kinds, PHASES[phase], [_label(outfield[i], team, ctx, phase), _label(outfield[j], team, ctx, phase)])
		for p in outfield:
			var nearest := INF
			for q in outfield:
				if q != p:
					nearest = minf(nearest, p.flat_distance_to(q.position))
			if nearest < INF:
				_spacing_sum += nearest
				_spacing_count += 1
				for b in buckets:
					_phase_sum[b] += nearest
					_phase_count[b] += 1
				close_pair = close_pair or nearest < CLOSE_PAIR
			if p.flat_distance_to(ctx.ball.position) < CROWD_RADIUS:
				near_ball += 1
				near_labels.append(_label(p, team, ctx, phase))
		_side_samples += 1
		for b in buckets:
			_phase_sides[b] += 1
		if near_ball >= CROWD_COUNT:
			_crowd_samples += 1
			for b in buckets:
				_phase_crowd[b] += 1
			_count(_crowd_kinds, PHASES[phase], near_labels)
		if close_pair:
			_close_samples += 1
			for b in buckets:
				_phase_close[b] += 1


## What a player is doing, for the diagnosis.
static func _label(p: Player, team: Team, ctx: MatchContext, phase: int) -> String:
	if phase == 0:
		if p == ctx.possession.holder or p == ctx.possession.pass_target:
			return "carrier"
		if p.ai.go_left > 0.0:
			return "give-go"
		if p.ai.run_left > 0.0:
			return "runner"
		var jobs: Array[String] = ["no job", "support", "forward", "cover"]
		return jobs[int(p.ai.attack_role)]
	if p == team.brain.chaser:
		return "chaser"
	if p == team.brain.cover:
		return "cover"
	return "marker" if p.ai.mark != null else "zone"


static func _count(kinds: Dictionary, phase_name: String, labels: Array) -> void:
	labels.sort()
	var parts := PackedStringArray()
	for label in labels:
		parts.append(str(label))
	var key := "%s: %s" % [phase_name, " + ".join(parts)]
	kinds[key] = int(kinds.get(key, 0)) + 1


## The side has the ball, or its pass is on the way to a teammate.
static func _has_ball(team: Team, ctx: MatchContext) -> bool:
	var holder := ctx.possession.holder
	if holder != null:
		return holder.team == team
	var target := ctx.possession.pass_target
	return target != null and target.team == team


func _on_full_time(home: int, away: int) -> void:
	_finished = true
	_final = Vector2i(home, away)


func _end_match() -> void:
	var line := "MATCH RESULT seed %d: %d - %d, goals counted %d" % [SEEDS[_index], _final.x, _final.y, _goals]
	print(line)
	var stats: MatchStats = _match.ctx.stats
	print("MATCH STATS seed %d home: %s" % [SEEDS[_index], stats.summary(0)])
	print("MATCH STATS seed %d away: %s" % [SEEDS[_index], stats.summary(1)])
	_total_shots += stats.shots[0] + stats.shots[1]
	_total_saves += stats.saves[0] + stats.saves[1]
	_results.append(line)
	_all_finished = _all_finished and _finished
	_score_mismatch = _score_mismatch or (_final.x + _final.y != _goals)
	_total_goals += _goals
	_match.queue_free()
	_match = null
	_start_next.call_deferred()


func _report() -> void:
	set_physics_process(false)
	var n := float(SEEDS.size())
	print("MATCH BALANCE: %.2f goals, %.1f shots, %.1f saves per %d-second match, longest stuck ball %.1f s"
		% [_total_goals / n, _total_shots / n, _total_saves / n, int(MATCH_SECONDS), _max_stuck])
	var sides := maxf(1.0, float(_side_samples))
	print("MATCH SPACING: %.1f m from each outfielder to his nearest teammate, %.0f %% of the time two teammates closer than %.0f m, %.0f %% of the time 3+ players of a side near the ball"
		% [_spacing_sum / maxf(1.0, float(_spacing_count)), 100.0 * _close_samples / sides, CLOSE_PAIR, 100.0 * _crowd_samples / sides])
	for k in range(PHASES.size()):
		var phase_sides := maxf(1.0, float(_phase_sides[k]))
		print("MATCH SPACING %s (%.0f %% of the time): %.1f m to the nearest teammate, %.0f %% two closer than %.0f m, %.0f %% 3+ near the ball"
			% [PHASES[k], 100.0 * _phase_sides[k] / sides, _phase_sum[k] / maxf(1.0, float(_phase_count[k])),
			100.0 * _phase_close[k] / phase_sides, CLOSE_PAIR, 100.0 * _phase_crowd[k] / phase_sides])
	for k in range(3):
		_print_kinds("close pair", _pair_kinds, PHASES[k], maxf(1.0, float(_phase_sides[k])))
		_print_kinds("crowd", _crowd_kinds, PHASES[k], maxf(1.0, float(_phase_sides[k])))
	_check("every match reaches full time", _all_finished)
	_check("goals are scored", _total_goals >= MIN_TOTAL_GOALS, "total=%d" % _total_goals)
	_check("score matches goals", not _score_mismatch)
	_check("ball never stuck", _max_stuck < STUCK_SECONDS, "%.1f s" % _max_stuck)
	_check("ball and players stay in the court", not _out_of_bounds)
	print("MATCH TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## The most frequent kinds of one phase, as a share of that phase's side samples.
func _print_kinds(what: String, kinds: Dictionary, phase_name: String, sides: float) -> void:
	var keys: Array = []
	for key in kinds.keys():
		if str(key).begins_with(phase_name + ":"):
			keys.append(key)
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(kinds[a]) > int(kinds[b]))
	for k in range(mini(keys.size(), 4)):
		print("MATCH SPACING %s %s: %.1f %%" % [what, str(keys[k]), 100.0 * int(kinds[keys[k]]) / sides])


func _check(test_name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("TEST PASS ", test_name)
	else:
		_failures += 1
		print("TEST FAIL ", test_name, " ", detail)
