class_name AfterPass
extends RefCounted
## What a player does just after his pass (AI players, and the human's player once the control has
## gone to the receiver): he stops for a moment looking at the ball, then jogs to his next place
## (backward, still facing the ball, when that place is behind him; forward otherwise), and only
## then runs again. A give-and-go or a run in behind starts right after the short stop, at running
## pace (no sprint) until the jog time is over.
## The other side winning the ball ends it at once. Numbers: data/config/ai.json (after_pass_*).


## Called when `player` has just passed the ball.
static func start(player: Player) -> void:
	player.ai.after_pass = Steering.num("after_pass_settle_seconds", 0.25) + Steering.num("after_pass_jog_seconds", 1.2)


static func adjust(player: Player, intent: PlayerIntent, delta: float, ctx: MatchContext) -> void:
	var state := player.ai
	if state.after_pass <= 0.0:
		return
	state.after_pass -= delta
	var holder := ctx.possession.holder
	if holder == player or (holder != null and holder.team != player.team):
		state.after_pass = 0.0
		return
	var to_ball := Steering.flat(ctx.ball.position - player.position)
	if state.after_pass > Steering.num("after_pass_jog_seconds", 1.2):
		intent.move = Vector3.ZERO
		intent.sprint = false
		intent.face = to_ball
		return
	intent.sprint = false
	# A give-and-go or a run in behind: at running pace first, the sprint comes after.
	if state.run_left > 0.0 or state.go_left > 0.0:
		return
	intent.move = intent.move.limit_length(Steering.num("after_pass_jog_speed", 0.7))
	if intent.move.dot(to_ball) < 0.0:
		intent.face = to_ball
