class_name Possession
extends RefCounted
## Who has the ball. Only one player can control it at a time.

## Player dribbling the ball, or null when it is loose.
var holder: Player = null
## Team index (0/1) of the last player who touched the ball, -1 at kick-off.
var last_touch_team: int = -1
## Increases at every kick; lets the keeper roll one save per shot.
var kick_count: int = 0
var last_kicker: Player = null
## Teammate a pass was aimed at, until someone controls the ball.
var pass_target: Player = null


func take(player: Player, ball: BallPhysics) -> void:
	holder = player
	ball.controlled = true
	last_touch_team = player.team.index
	pass_target = null


func release(ball: BallPhysics) -> void:
	holder = null
	ball.controlled = false


func kicked(player: Player, target: Player, ball: BallPhysics) -> void:
	release(ball)
	last_touch_team = player.team.index
	last_kicker = player
	pass_target = target
	kick_count += 1


func touched(player: Player) -> void:
	last_touch_team = player.team.index


func reset(ball: BallPhysics) -> void:
	release(ball)
	last_touch_team = -1
	last_kicker = null
	pass_target = null
