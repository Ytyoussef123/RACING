class_name Dribbling
extends RefCounted
## Dribbling with touches, like a real player: when moving, he knocks the ball a little ahead and
## catches up with it; sprinting knocks it further (faster, but riskier). Standing still or with
## the joystick released, the ball is stopped and kept at the feet. A ball knocked ahead of its
## dribbler can be stolen by an opponent who gets to it first.
## Each touch is done by a foot (Player.animate_touch): running onto the ball, the foot starts its
## swing a little before the ball is in reach (dribble_touch_windup) and the touch lands when the
## foot gets there; turning with the ball, it is touched at once with the foot on its side.
## Numbers: data/config/player.json (dribble_*).

var _touch_timer: float = 0.0
## Seconds until a started touch lands (the foot is on its way to the ball); 0 = none.
var _windup: float = 0.0


func reset() -> void:
	_touch_timer = 0.0
	_windup = 0.0


## Runs every frame for the player who has the ball. Returns false when the ball got too far.
func update(player: Player, ctx: MatchContext, delta: float, kick_waiting: bool, charging: bool) -> bool:
	var ball := ctx.ball
	var to_ball := Steering.flat(ball.position - player.position)
	var dist := to_ball.length()
	var sprint := player.intent.sprint
	if dist > (_cfg("dribble_leash_sprint", 3.6) if sprint else _cfg("dribble_leash", 2.4)):
		return false
	var reach := _cfg("dribble_touch_reach", 0.75)
	var move := Steering.flat(player.intent.move)
	if player.intent.trap or move.length() < 0.2:
		_windup = 0.0
		if dist <= reach:
			_hold_at_feet(player, ball)
		else:
			ball.controlled = false
			_slow_ball(ball, delta, _cfg("dribble_stop_friction", 8.0))
		return true
	ball.controlled = false
	_slow_ball(ball, delta, _cfg("dribble_ball_friction", 3.0))
	_touch_timer = maxf(0.0, _touch_timer - delta)
	var dir := move.normalized()
	var ball_vel := Steering.flat(ball.velocity)
	var player_along := maxf(0.0, Steering.flat(player.motion.velocity).dot(dir))
	if _windup > 0.0:
		_windup -= delta
		# The foot reaches the ball now (unless a kick takes over or the ball got away).
		if _windup <= 0.0 and not kick_waiting and dist <= reach * _cfg("dribble_windup_reach_margin", 1.3):
			_touch(player, ctx, to_ball, dir, player_along, sprint, charging)
		return true
	if kick_waiting or _touch_timer > 0.0:
		return true
	var redirect := cos(deg_to_rad(_cfg("dribble_touch_redirect_degrees", 35.0)))
	var off_course := ball_vel.length() > 0.5 and ball_vel.normalized().dot(dir) < redirect
	var behind := to_ball.dot(dir) < 0.15
	if off_course or behind:
		# Turning with the ball: touched at once, with the foot on its side.
		if dist <= reach:
			player.animate_touch(_foot(player, to_ball), 0.0)
			_touch(player, ctx, to_ball, dir, player_along, sprint, charging)
		return true
	if ball_vel.dot(dir) > player_along + 0.3:
		return true
	# Running onto the ball: the swing starts when the ball will be in reach at the end of it.
	var lead := _cfg("dribble_touch_windup", 0.1)
	var closing := maxf(0.0, player_along - ball_vel.dot(dir))
	if dist - closing * lead > reach:
		return true
	player.animate_touch(_foot(player, to_ball), lead)
	if lead <= 0.0:
		_touch(player, ctx, to_ball, dir, player_along, sprint, charging)
	else:
		_windup = lead
	return true


## True when `player` (an opponent of the dribbler) is closer to a ball knocked ahead of him.
static func can_steal(player: Player, ctx: MatchContext) -> bool:
	var holder := ctx.possession.holder
	if holder == null or holder.team == player.team:
		return false
	var holder_dist := holder.flat_distance_to(ctx.ball.position)
	var exposed := holder.stat("dribble_exposed_distance", _cfg("dribble_exposed_distance", 0.8))
	return holder_dist > exposed and player.flat_distance_to(ctx.ball.position) < holder_dist


func _touch(player: Player, ctx: MatchContext, to_ball: Vector3, dir: Vector3, player_along: float,
		sprint: bool, charging: bool) -> void:
	var ball := ctx.ball
	var extra: float
	if charging:
		extra = _cfg("dribble_touch_extra_min", 1.6)
	elif sprint:
		extra = _cfg("dribble_touch_extra_sprint", 4.5)
	else:
		var run_speed := _cfg("run_speed", 5.5) * player.motion.speed_factor
		extra = lerpf(_cfg("dribble_touch_extra_min", 1.6), _cfg("dribble_touch_extra_run", 2.6),
			clampf(player_along / maxf(0.1, run_speed), 0.0, 1.0))
	# Good dribblers keep their touches closer.
	extra *= player.stat("dribble_touch_extra_mult", 1.0)
	# Push along the wanted direction, steering the ball back onto the line in front of him.
	var lateral := to_ball - dir * to_ball.dot(dir)
	var v := dir * (player_along + extra) - lateral * _cfg("dribble_touch_centering", 2.5)
	ball.velocity.x = v.x
	ball.velocity.z = v.z
	_touch_timer = _cfg("dribble_touch_interval", 0.2)
	ctx.possession.touched(player)


## Foot for a touch: +1 right / -1 left, the one on the ball's side, else the preferred foot.
static func _foot(player: Player, to_ball: Vector3) -> float:
	var facing := player.motion.facing
	var side := to_ball.dot(Vector3(-facing.z, 0.0, facing.x))
	if absf(side) > _cfg("dribble_foot_side_offset", 0.12):
		return signf(side)
	return -1.0 if player.preferred_foot == "left" else 1.0


## Ball stopped under the sole: it follows the feet closely.
func _hold_at_feet(player: Player, ball: BallPhysics) -> void:
	ball.controlled = true
	var target := player.position + player.motion.facing * _cfg("dribble_distance", 0.55)
	var to_target := Vector3(target.x - ball.position.x, 0.0, target.z - ball.position.z)
	var v := player.motion.velocity + to_target * _cfg("dribble_stiffness", 14.0)
	ball.velocity.x = v.x
	ball.velocity.z = v.z


## Extra slowing of a dribbled ball on the ground (soft touches keep it close).
static func _slow_ball(ball: BallPhysics, delta: float, deceleration: float) -> void:
	if ball.position.y > ball.radius + 0.02:
		return
	var speed := Vector2(ball.velocity.x, ball.velocity.z).length()
	if speed < 0.0001:
		return
	var ratio := maxf(0.0, speed - deceleration * delta) / speed
	ball.velocity.x *= ratio
	ball.velocity.z *= ratio


static func _cfg(key: String, fallback: float) -> float:
	return float(Config.get_value("player", key, fallback))
