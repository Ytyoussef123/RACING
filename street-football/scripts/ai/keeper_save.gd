class_name KeeperSave
extends RefCounted
## How likely the keeper saves this shot (rolled once, when it comes within his reach): his
## difficulty chance and reflexes, times the shot itself:
##   placement: how far from him it will pass (keeper_save_center_mult at him .. corner_mult at the
##              edge of his reach);
##   speed:     keeper_save_slow_mult at 10 m/s .. fast_mult at 26 m/s;
##   height:    keeper_save_high_mult when it passes above keeper_save_high_height (top corners),
##              keeper_save_low_mult below keeper_save_low_height (he has to get down);
##   curl:      minus keeper_save_spin_penalty at full spin.
## A chip over his head never comes within his reach (KeeperAI.try_save checks the height).
## Numbers: data/config/ai.json (keeper_save_*).


static func chance(keeper: Player, ctx: MatchContext) -> float:
	var ball := ctx.ball
	var base := keeper.team.tuning.keeper_save_chance * keeper.stat("keeper_save_mult", 1.0)
	var reach := keeper.stat("keeper_reach", Steering.num("keeper_reach", 1.6))
	var cross := crossing(keeper, ball)
	var offset := clampf(absf(cross.z - keeper.position.z) / maxf(0.1, reach), 0.0, 1.0)
	var mult := lerpf(Steering.num("keeper_save_center_mult", 1.45), Steering.num("keeper_save_corner_mult", 0.75), offset)
	var fast := clampf((ball.velocity.length() - 10.0) / 16.0, 0.0, 1.0)
	mult *= lerpf(Steering.num("keeper_save_slow_mult", 1.1), Steering.num("keeper_save_fast_mult", 0.9), fast)
	if cross.y > Steering.num("keeper_save_high_height", 1.6):
		mult *= Steering.num("keeper_save_high_mult", 0.75)
	elif cross.y < Steering.num("keeper_save_low_height", 0.4):
		mult *= Steering.num("keeper_save_low_mult", 0.85)
	mult *= 1.0 - minf(1.0, absf(ball.spin)) * Steering.num("keeper_save_spin_penalty", 0.45)
	return clampf(base * mult, Steering.num("keeper_save_min_chance", 0.03), 0.97)


## Where the ball will pass the keeper's position along the goal (x): its z there and its height.
static func crossing(keeper: Player, ball: BallPhysics) -> Vector3:
	var vx := ball.velocity.x
	if absf(vx) < 0.1:
		return ball.position
	var t := clampf((keeper.position.x - ball.position.x) / vx, 0.0, 1.0)
	var g := float(Config.get_value("ball", "gravity", 9.81))
	return Vector3(keeper.position.x, ball.position.y + ball.velocity.y * t - 0.5 * g * t * t,
		ball.position.z + ball.velocity.z * t)
