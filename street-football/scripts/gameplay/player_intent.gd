class_name PlayerIntent
extends RefCounted
## What a controller (the human now, the AI in Phase 3) wants a player to do on this frame.

## Wanted direction on the ground plane, length 0..1.
var move: Vector3 = Vector3.ZERO
var sprint: bool = false
## True while the shoot button is held (the shot goes on release).
var shoot_held: bool = false
## True only on the frame the pass button was pressed.
var pass_pressed: bool = false
