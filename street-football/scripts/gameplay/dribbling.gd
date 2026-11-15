class_name Dribbling
extends RefCounted
## Dribbling with touches, like a real player: when moving, he knocks the ball a little ahead and
## catches up with it; sprinting knocks it further (faster, but riskier). Standing still or with
## the joystick released, the ball is stopped and kept at the feet. A ball knocked ahead of its
## dribbler can be stolen by an opponent who gets to it first.
## Each touch is done by a foot (Player.animate_touch): running onto the ball, the foot starts its
## swing a little before the ball is in reach (dribble_touch_windup) and the touch lands when the
## foot gets there; turning with the ball, it is touched at once with the foot on its side.
## Four modes, from the dribbler's intent (Mode): walk (soft joystick: tiny touches, ball at the
## feet), run (full joystick), sprint (SPRINT: faster, ball still close), knock-on (joystick pulled
## hard twice: the ball is pushed knock_on_distance ahead and he runs onto it, again and again).
## Numbers: data/config/player.json (dribble_*, knock_on_*).

enum Mode { WALK, RUN, SPRINT, KNOCK_ON }

var _touch_timer: float = 0.0
## Seconds until a started touch lands (the foot is on its way to the ball); 0 = none.
var _windup: float = 0.0
## The last touch was a knock-on push: the ball stays his (sprint leash) until his next touch, even
## if the knock-on mode ends while he chases it.
var _long_touch: bool = false


func reset() -> void:
	_touch_timer = 0.0
	_windup = 0.0
	_long_touch = false


## Runs every frame for the player who has the ball. Returns false when the ball got too far.
func update(player: Player, ctx: MatchContext, delta: float, kick_waiting: bool, charging: bool) -> bool:
	var ball := ctx.ball
	var to_ball := Steering.flat(ball.position - player.position)
	var dist := to_ball.length()
	var mode := mode_of(player, charging)
	var fast := mode == Mode.SPRINT or mode == Mode.KNOCK_ON or _long_touch
	if dist > (_cfg("dribble_leash_sprint", 3.6) if fast else _cfg("dribble_leash", 2.4)):
		return false
	var reach := _cfg("dribble_touch_reach", 0.75)
	var touch_reach := _reach_for(mode)
	# Where he wants to take the ball (DribbleAssist may be walking him to it first).
	var wanted := player.intent.dribble_dir if player.intent.dribble_dir != Vector3.ZERO else player.intent.move
	var move := Steering.flat(wanted)
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
		if _windup <= 0.0 and not kick_waiting and dist <= touch_reach * _cfg("dribble_windup_reach_margin", 1.3):
			_touch(player, ctx, to_ball, dir, player_along, mode, charging)
		return true
	if kick_waiting or _touch_timer > 0.0:
		return true
	var redirect := cos(deg_to_rad(_cfg("dribble_touch_redirect_degrees", 35.0)))
	var off_course := ball_vel.length() > 0.5 and ball_vel.normalized().dot(dir) < redirect
	var behind := to_ball.dot(dir) < 0.15
	if off_course or behind:
		# Turning with the ball: touched at once, with the foot on its side, toward where he goes.
		if dist <= _cfg("dribble_turn_reach", 0.85):
			player.animate_touch(_foot(player, to_ball), 0.0)
			_turn_touch(player, ctx, to_ball, move, mode)
		return true
	if ball_vel.dot(dir) > player_along + 0.3:
		return true
	# Running onto the ball: the swing starts when the ball will be in reach at the end of it.
	var lead := _cfg("dribble_touch_windup", 0.1)
	var closing := maxf(0.0, player_along - ball_vel.dot(dir))
	if dist - closing * lead > touch_reach:
		return true
	player.animate_touch(_foot(player, to_ball), lead)
	if lead <= 0.0:
		_touch(player, ctx, to_ball, dir, player_along, mode, charging)
	else:
		_windup = lead
	return true


## The dribbling mode from the dribbler's intent. Charging a shot never knocks the ball far.
static func mode_of(player: Player, charging: bool = false) -> Mode:
	var intent := player.intent
	if intent.knock_on and not charging:
		return Mode.KNOCK_ON
	if intent.sprint or intent.knock_on:
		return Mode.SPRINT
	if intent.walk:
		return Mode.WALK
	return Mode.RUN


## How close the ball must be (predicted) for the next touch, by mode.
static func _reach_for(mode: Mode) -> float:
	match mode:
		Mode.WALK:
			return _cfg("dribble_walk_reach", 0.42)
		Mode.SPRINT:
			return _cfg("dribble_sprint_reach", 0.5)
		Mode.KNOCK_ON:
			return _cfg("knock_on_reach", 0.6)
	return _cfg("dribble_touch_reach", 0.75)


## True when `player` (an opponent of the dribbler) is closer to a ball knocked ahead of him.
static func can_steal(player: Player, ctx: MatchContext) -> bool:
	var holder := ctx.possession.holder
	if holder == null or holder.team == player.team:
		return false
	var holder_dist := holder.flat_distance_to(ctx.ball.position)
	var exposed := holder.stat("dribble_exposed_distance", _cfg("dribble_exposed_distance", 0.8))
	return holder_dist > exposed and player.flat_distance_to(ctx.ball.position) < holder_dist


## A touch ahead: the ball gets the player's speed plus an extra that depends on the mode. The
## knock-on push is computed so the ball stops being ahead at exactly knock_on_distance.
func _touch(player: Player, ctx: MatchContext, to_ball: Vector3, dir: Vector3, player_along: float,
		mode: Mode, charging: bool) -> void:
	var ball := ctx.ball
	var extra: float
	if mode == Mode.KNOCK_ON:
		extra = _knock_on_push(to_ball.dot(dir), player_along)
	else:
		if charging:
			extra = _cfg("dribble_touch_extra_min", 1.2)
		elif mode == Mode.SPRINT:
			extra = _cfg("dribble_touch_extra_sprint", 1.4)
		elif mode == Mode.WALK:
			extra = _cfg("dribble_walk_extra", 0.5)
		else:
			var run_speed := _cfg("run_speed", 5.5) * player.motion.speed_factor
			extra = lerpf(_cfg("dribble_touch_extra_min", 1.2), _cfg("dribble_touch_extra_run", 1.7),
				clampf(player_along / maxf(0.1, run_speed), 0.0, 1.0))
		# Good dribblers keep their touches closer (the knock-on distance stays exact).
		extra *= player.stat("dribble_touch_extra_mult", 1.0)
	# Push along the wanted direction, steering the ball back onto the line in front of him.
	var lateral := to_ball - dir * to_ball.dot(dir)
	var v := dir * (player_along + extra) - lateral * _cfg("dribble_touch_centering", 2.5)
	ball.velocity.x = v.x
	ball.velocity.z = v.z
	_touch_timer = _cfg("dribble_touch_interval", 0.2)
	_long_touch = mode == Mode.KNOCK_ON
	ctx.possession.touched(player)


## Extra speed for a knock-on push from `ahead` meters: the ball, slowed by the ground (dribble
## friction, rolling friction and drag at the player's speed), gets knock_on_distance ahead of him.
static func _knock_on_push(ahead: float, player_speed: float) -> float:
	var slowing := _cfg("dribble_ball_friction", 3.0) + float(Config.get_value("ball", "rolling_friction", 1.6)) \
		+ float(Config.get_value("ball", "rolling_drag", 0.25)) * player_speed
	var gap := maxf(0.0, _cfg("knock_on_distance", 1.3) - maxf(0.0, ahead))
	return minf(sqrt(2.0 * slowing * gap), _cfg("knock_on_max_push", 6.0))


## Turning with the ball: the touch sends it to a point just ahead of where the player will be
## once he has turned (his speed builds up toward the new direction while he still slides the old
## way), so the ball turns with him instead of being left at his side.
func _turn_touch(player: Player, ctx: MatchContext, to_ball: Vector3, move: Vector3, mode: Mode) -> void:
	var ball := ctx.ball
	var time := _cfg("dribble_turn_touch_time", 0.3)
	var dir := move.normalized()
	var player_vel := Steering.flat(player.motion.velocity)
	var target_speed: float
	var lead: float
	match mode:
		Mode.WALK:
			target_speed = player.motion.walk_speed(true)
			lead = _cfg("dribble_walk_turn_lead", 0.4) * player.stat("dribble_touch_extra_mult", 1.0)
		Mode.SPRINT:
			target_speed = player.motion.top_speed(true, true)
			lead = _cfg("dribble_sprint_turn_lead", 0.55) * player.stat("dribble_touch_extra_mult", 1.0)
		Mode.KNOCK_ON:
			target_speed = player.motion.knock_on_speed()
			lead = _cfg("knock_on_distance", 1.3)
		_:
			target_speed = move.limit_length(1.0).length() * player.motion.top_speed(false, true)
			lead = _cfg("dribble_turn_touch_lead", 0.6) * player.stat("dribble_touch_extra_mult", 1.0)
	var target_vel := dir * target_speed
	var player_moves := (player_vel + target_vel) * 0.5 * time
	var travel := player_moves + dir * lead - to_ball
	var distance := travel.length()
	if distance > 0.001:
		# Average speed over the time, plus what friction takes off on the way.
		var friction := _cfg("dribble_ball_friction", 3.0) + float(Config.get_value("ball", "rolling_friction", 1.6))
		var speed := minf(distance / time + friction * time * 0.5, _cfg("dribble_turn_touch_max_speed", 9.0))
		ball.velocity.x = travel.x / distance * speed
		ball.velocity.z = travel.z / distance * speed
	_touch_timer = _cfg("dribble_touch_interval", 0.2)
	_long_touch = mode == Mode.KNOCK_ON
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
	_long_touch = false
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
