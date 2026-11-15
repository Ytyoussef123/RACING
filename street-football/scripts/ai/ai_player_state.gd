class_name AiPlayerState
extends RefCounted
## What one AI-driven player remembers between frames.

enum Action { NONE, DRIBBLE, SHOOT }
## Job of a player without the ball while his side has it (AttackRoles, AttackShape).
enum AttackRole { NONE, SUPPORT, FORWARD, COVER }

var action: Action = Action.NONE
## Time until the next decision (reaction time comes from the difficulty).
var think_timer: float = 0.0
## Direction chosen at the last decision (dribble or shot aim).
var aim: Vector3 = Vector3.RIGHT
## Seconds the shoot button is still held for the current shot, and its type (ShotTypes).
var charge_left: float = 0.0
var shot_type: String = ""
## Opponent this player marks when defending, or null.
var mark: Player = null
var tackle_timer: float = 0.0
var attack_role: AttackRole = AttackRole.NONE
## Run in behind the last defender: seconds left, seconds before the next one may start, and
## the lane (z) of the run.
var run_left: float = 0.0
var run_cooldown: float = 0.0
var run_z: float = 0.0
## Give-and-go after his pass: seconds left of the run forward, and where he runs.
var go_left: float = 0.0
var go_target: Vector3 = Vector3.ZERO
## Keeper: time holding the ball, and the last shot already rolled for a save.
var hold_timer: float = 0.0
var last_save_kick: int = -1


func reset() -> void:
	action = Action.NONE
	think_timer = 0.0
	charge_left = 0.0
	shot_type = ""
	mark = null
	tackle_timer = 0.0
	attack_role = AttackRole.NONE
	run_left = 0.0
	run_cooldown = 0.0
	go_left = 0.0
	hold_timer = 0.0
