class_name MatchFlow
extends RefCounted
## Score, clock and the stop/restart cycle of a match.

enum State { PLAYING, STOPPED, FULL_TIME }

var state: State = State.PLAYING
var time_left: float = 180.0
var scores: Array[int] = [0, 0]
## What to do when the current stop ends: {"type": "kickoff"/"restart"/"end", ...}.
var pending: Dictionary = {}

var _stop_timer: float = 0.0


func start(seconds: float) -> void:
	time_left = seconds
	scores = [0, 0]
	state = State.PLAYING


## Runs the clock while playing. Returns true when time is up.
func tick_clock(delta: float) -> bool:
	time_left = maxf(0.0, time_left - delta)
	return time_left <= 0.0


func stop(seconds: float, action: Dictionary) -> void:
	state = State.STOPPED
	_stop_timer = seconds
	pending = action


func finish(seconds: float) -> void:
	state = State.FULL_TIME
	_stop_timer = seconds
	pending = {"type": "end"}


## Counts down a stop. Returns the pending action when the stop is over, else an empty dictionary.
func tick_stop(delta: float) -> Dictionary:
	_stop_timer -= delta
	if _stop_timer > 0.0:
		return {}
	var action := pending
	pending = {}
	if state == State.STOPPED:
		state = State.PLAYING
	return action


func clock_text() -> String:
	var total := int(ceil(time_left))
	return "%d:%02d" % [total / 60, total % 60]
