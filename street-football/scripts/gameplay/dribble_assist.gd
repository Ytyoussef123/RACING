class_name DribbleAssist
extends RefCounted
## Helps the player who has the ball (human or AI) reach it when needed: with the joystick
## released he goes to stop the ball, and when a pass or shot is waiting he runs onto the ball to
## play it (no kicking from a distance). Numbers: data/config/player.json (dribble_*).


static func adjust(player: Player, ctx: MatchContext) -> void:
	if ctx.possession.holder != player:
		return
	var intent := player.intent
	var wants_kick := player.handling.has_queued_kick()
	var no_input := Steering.flat(intent.move).length() < 0.2
	if not (wants_kick or no_input):
		return
	var to_ball := Steering.flat(ctx.ball.position - player.position)
	var d := to_ball.length()
	if d <= float(Config.get_value("player", "dribble_touch_reach", 0.75)) * 0.8:
		return
	var speed := 1.0 if wants_kick else float(Config.get_value("player", "dribble_trap_move", 0.6))
	intent.move = to_ball / d * speed
	intent.trap = no_input and not wants_kick
