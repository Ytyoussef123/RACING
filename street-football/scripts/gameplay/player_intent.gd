class_name PlayerIntent
extends RefCounted
## What a controller (the human or the AI) wants a player to do on this frame.

## Wanted direction on the ground plane, length 0..1.
var move: Vector3 = Vector3.ZERO
var sprint: bool = false
## True while the shoot button is held (the shot goes on release).
var shoot_held: bool = false
## True only on the frame the pass button was pressed.
var pass_pressed: bool = false
## True only on the frame the through-pass button was pressed.
var through_pressed: bool = false
## True only on the frame a tackle is tried.
var tackle_pressed: bool = false
## True only on the frame the human asks to switch player.
var switch_pressed: bool = false
## True while the human holds PRESS: the player runs at the ball carrier by himself.
var press_held: bool = false
## True while the human holds MATCH-UP: the player shadows the ball carrier goal-side.
var match_up_held: bool = false
## Direction for kicks when it differs from `move` (receive assist moves to the ball while the
## joystick keeps aiming). ZERO means: use `move`, or the facing direction.
var aim: Vector3 = Vector3.ZERO
## True only on the frame the human double-taps the joystick on defense: shoulder charge.
var shoulder_pressed: bool = false
## Set by DribbleAssist: the dribbler goes to stop the ball (no touch forward).
var trap: bool = false
