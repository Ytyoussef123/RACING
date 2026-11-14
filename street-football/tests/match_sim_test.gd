extends Node
## Full AI-vs-AI match, run headless by CI:
##   godot --headless --fixed-fps 60 --path street-football res://tests/match_sim_test.tscn
## Checks that the match reaches full time, that goals are scored, that the ball never
## stays stuck, and that the ball and players stay inside the court.
## Prints "TEST PASS"/"TEST FAIL" lines, then "MATCH TESTS DONE: N failure(s)".

const MATCH_SCENE := preload("res://scenes/match/match.tscn")
const MATCH_SECONDS := 150.0
const STUCK_SECONDS := 8.0
const SAFETY_SECONDS := 400.0

var _match: Node
var _goals := 0
var _finished := false
var _final := Vector2i.ZERO
var _stuck_time := 0.0
var _max_stuck := 0.0
var _out_of_bounds := false
var _elapsed := 0.0
var _failures := 0


func _ready() -> void:
	Engine.max_fps = 0
	MatchSetup.test_mode = true
	MatchSetup.test_match_seconds = MATCH_SECONDS
	MatchSetup.court_id = "cage_concrete"
	_match = MATCH_SCENE.instantiate()
	add_child(_match)
	_match.goal_scored.connect(func(_team: int) -> void: _goals += 1)
	_match.full_time.connect(_on_full_time)


func _physics_process(delta: float) -> void:
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
	if _finished or _elapsed > SAFETY_SECONDS:
		_report()


func _on_full_time(home: int, away: int) -> void:
	_finished = true
	_final = Vector2i(home, away)


func _report() -> void:
	set_physics_process(false)
	print("MATCH RESULT %d - %d, goals counted %d, longest stuck ball %.1f s" % [_final.x, _final.y, _goals, _max_stuck])
	_check("match reaches full time", _finished)
	_check("goals are scored", _goals >= 1, "goals=%d" % _goals)
	_check("score matches goals", _final.x + _final.y == _goals)
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
