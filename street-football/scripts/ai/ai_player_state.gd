class_name AiPlayerState
extends RefCounted
## What one AI-driven player remembers between frames.

enum Action { NONE, DRIBBLE, SHOOT }

var action: Action = Action.NONE
## Time until the next decision (reaction time comes from the difficulty).
var think_timer: float = 0.0
## Direction chosen at the last decision (dribble or shot aim).
var aim: Vector3 = Vector3.RIGHT
## Seconds the shoot button is still held for the current shot.
var charge_left: float = 0.0
## Opponent this player marks when defending, or null.
var mark: Player = null
var tackle_timer: float = 0.0
## Keeper: time holding the ball, and the last shot already rolled for a save.
var hold_timer: float = 0.0
var last_save_kick: int = -1


func reset() -> void:
	action = Action.NONE
	think_timer = 0.0
	charge_left = 0.0
	mark = null
	tackle_timer = 0.0
	hold_timer = 0.0
