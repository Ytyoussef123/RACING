class_name DribbleAssist
extends RefCounted
## Helps the player who has the ball (human or AI) reach it when needed: with the joystick
## released he goes to stop the ball, when a pass or shot is waiting he runs onto the ball to
## play it (no kicking from a distance), and when he turns away from a ball that is out of reach
## he first goes to it, then turns with it (Dribbling touches it toward intent.dribble_dir).
## Numbers: data/config/player.json (dribble_*).


static func adjust(player: Player, ctx: MatchContext) -> void:
	if ctx.possession.holder != player:
		return
	var intent := player.intent
	intent.dribble_dir = Vector3.ZERO
	var wants_kick := player.handling.has_queued_kick()
	var move := Steering.flat(intent.move)
	var no_input := move.length() < 0.2
	var to_ball := Steering.flat(ctx.ball.position - player.position)
	var d := to_ball.length()
	if not (wants_kick or no_input):
		_turn_to_ball(intent, move, to_ball, d)
		return
	if d <= float(Config.get_value("player", "dribble_touch_reach", 0.75)) * 0.8:
		return
	var speed := 1.0 if wants_kick else float(Config.get_value("player", "dribble_trap_move", 0.6))
	intent.move = to_ball / d * speed
	intent.trap = no_input and not wants_kick


## Turning away from a ball that is out of reach: he goes to the ball first, keeping where he
## wants to take it in dribble_dir.
static func _turn_to_ball(intent: PlayerIntent, move: Vector3, to_ball: Vector3, d: float) -> void:
	if d <= float(Config.get_value("player", "dribble_turn_reach", 1.0)) * 0.8:
		return
	var away := cos(deg_to_rad(float(Config.get_value("player", "dribble_turn_assist_degrees", 50.0))))
	if to_ball.dot(move.normalized()) >= away * d:
		return
	intent.dribble_dir = move
	intent.move = to_ball / d * move.length()
