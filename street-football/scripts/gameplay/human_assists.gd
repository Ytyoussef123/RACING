class_name HumanAssists
extends RefCounted
## Assists for the human's player: receive assist while a pass comes to him; PRESS and MATCH-UP
## when his side does not have the ball. PRESS with the joystick moved is a sprint where the stick
## points, pulled a little toward the press (PressAssist.pull); released, the automatic press.


static func apply(player: Player, intent: PlayerIntent, attacking: bool, delta: float,
		ctx: MatchContext, human: HumanControl) -> PlayerIntent:
	if attacking:
		if human.is_receiving(ctx):
			return ReceiveAssist.apply(player, intent, ctx)
		return intent
	if intent.press_held:
		if Steering.flat(intent.move).length() > 0.2:
			return PressAssist.pull(player, intent, ctx)
		return PressAssist.apply(player, intent, delta, ctx)
	if intent.match_up_held:
		return MatchUpAssist.apply(player, intent, ctx)
	return intent
