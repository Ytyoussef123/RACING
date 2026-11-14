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
## Kind of the last kick: "pass" (passes and through passes), "shot" or "" (anything else).
var last_kick_kind: String = ""
## Match counters (passes completed are counted here); may be null in tests.
var stats: MatchStats = null


func take(player: Player, ball: BallPhysics) -> void:
	if stats != null and last_kick_kind == "pass" and last_kicker != null and last_kicker != player \
			and last_kicker.team == player.team:
		stats.passes_completed[player.team.index] += 1
	holder = player
	ball.controlled = true
	last_touch_team = player.team.index
	pass_target = null
	last_kick_kind = ""


func release(ball: BallPhysics) -> void:
	holder = null
	ball.controlled = false


func kicked(player: Player, target: Player, ball: BallPhysics, kind: String = "") -> void:
	release(ball)
	last_touch_team = player.team.index
	last_kicker = player
	pass_target = target
	last_kick_kind = kind
	kick_count += 1


func touched(player: Player) -> void:
	last_touch_team = player.team.index
	# A pass deflected by the other team is no longer a pass to our receiver.
	if pass_target != null and pass_target.team != player.team:
		pass_target = null


func reset(ball: BallPhysics) -> void:
	release(ball)
	last_touch_team = -1
	last_kicker = null
	pass_target = null
	last_kick_kind = ""
