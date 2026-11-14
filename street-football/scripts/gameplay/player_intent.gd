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
## True only on the frame a tackle is tried.
var tackle_pressed: bool = false
## True only on the frame the human asks to switch player.
var switch_pressed: bool = false
## True while the human holds PRESS: the player runs at the ball carrier by himself.
var press_held: bool = false
