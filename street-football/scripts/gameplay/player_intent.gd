class_name PlayerIntent
extends RefCounted
## What a controller (the human or the AI) wants a player to do on this frame.

## Wanted direction on the ground plane, length 0..1.
var move: Vector3 = Vector3.ZERO
var sprint: bool = false
## Soft joystick: the player walks (walk_speed) in the `move` direction, whatever its length.
var walk: bool = false
## Knock-on mode, with the ball (joystick pulled hard twice): the ball is pushed a fixed distance
## ahead and the player runs onto it at full speed, again and again.
var knock_on: bool = false
## True while the shoot button is held (the shot goes on release).
var shoot_held: bool = false
## True only on the frame the pass button was pressed.
var pass_pressed: bool = false
## True only on the frame the through-pass button was pressed.
var through_pressed: bool = false
## True only on the frame SHOOT was pressed in our own half: a long clearance.
var clear_pressed: bool = false
## Human only: true while PASS, THROUGH, or SHOOT in our own half (CLEAR) is held. The kick goes on
## release: after a tap with the automatic power, after a longer hold with the power bar's.
var pass_held: bool = false
var through_held: bool = false
var clear_held: bool = false
## With PASS / THROUGH: the ball goes in the air (the human slid the finger up on the button, or
## the AI chose it). Its length comes from the power bar (or kick_power).
var pass_lofted: bool = false
var through_lofted: bool = false
## AI only: the power of this frame's PASS / THROUGH press, 0..1 (-1: automatic).
var kick_power: float = -1.0
## Type of the shot (ShotTypes), from a slide on SHOOT or the AI: "" normal, "low" (slide down),
## "chip" (slide up), "curl" (slide left or right: curls toward the far post).
var shot_type: String = ""
## True only on the frame the joystick is double-tapped with the ball: a keeper holding the ball
## in his hands puts it down at his feet.
var drop_ball: bool = false
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
## Where the body looks when it is not where he goes (jogging backward facing the ball).
## ZERO means: he faces where he moves.
var face: Vector3 = Vector3.ZERO
## Direction of a skill move (joystick flick with the ball), or ZERO.
var skill: Vector3 = Vector3.ZERO
## True only on the frame the human double-taps the joystick on defense: shoulder charge.
var shoulder_pressed: bool = false
## Set by DribbleAssist: the dribbler goes to stop the ball (no touch forward).
var trap: bool = false
## Set by DribbleAssist while the dribbler first goes to a ball he is turning away from: where he
## wants to take it (the next touch turns the ball that way). ZERO means: use `move`.
var dribble_dir: Vector3 = Vector3.ZERO
