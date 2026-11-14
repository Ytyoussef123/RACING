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
const SEEDS: Array[int] = [11, 22, 33]
const MIN_TOTAL_GOALS := 3
const STUCK_SECONDS := 8.0
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


func _ready() -> void:
	Engine.max_fps = 0
	MatchSetup.test_mode = true
	MatchSetup.test_match_seconds = MATCH_SECONDS
	MatchSetup.court_id = "cage_concrete"
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
	if _finished or _elapsed > SAFETY_SECONDS_PER_MATCH:
		_end_match()


func _on_full_time(home: int, away: int) -> void:
	_finished = true
	_final = Vector2i(home, away)


func _end_match() -> void:
	var line := "MATCH RESULT seed %d: %d - %d, goals counted %d" % [SEEDS[_index], _final.x, _final.y, _goals]
	print(line)
	_results.append(line)
	_all_finished = _all_finished and _finished
	_score_mismatch = _score_mismatch or (_final.x + _final.y != _goals)
	_total_goals += _goals
	_match.queue_free()
	_match = null
	_start_next.call_deferred()


func _report() -> void:
	set_physics_process(false)
	print("MATCH BALANCE: %.2f goals per %d-second match, longest stuck ball %.1f s"
		% [float(_total_goals) / SEEDS.size(), int(MATCH_SECONDS), _max_stuck])
	_check("every match reaches full time", _all_finished)
	_check("goals are scored", _total_goals >= MIN_TOTAL_GOALS, "total=%d" % _total_goals)
	_check("score matches goals", not _score_mismatch)
	_check("ball never stuck", _max_stuck < STUCK_SECONDS, "%.1f s" % _max_stuck)
	_check("ball and players stay in the court", not _out_of_bounds)
	print("MATCH TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(test_name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("TEST PASS ", test_name)
	else:
		_failures += 1
		print("TEST FAIL ", test_name, " ", detail)
