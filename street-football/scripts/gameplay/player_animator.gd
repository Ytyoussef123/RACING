class_name PlayerAnimator
extends RefCounted
## Procedural animation of the jointed body (PlayerRig), look only. Every frame it builds a RigPose:
##  - walking (slow) blends into running (faster): smaller swings, nearly straight arms, upright,
##    the body highest in mid-step instead of in flight;
##  - running cycle from the distance covered: thighs and knees (the knee folds in the swing),
##    opposite arms with bent elbows, hips and shoulders twisting against each other, bob;
##  - idle stance when standing (keepers: ready stance), breathing and weight shift;
##  - whole-body lean with acceleration, and into turns;
##  - when the player moves at an angle to where he faces (turning, back-pedalling), the hips turn
##    toward the way he goes and the legs step that way, so the feet don't slide;
##  - dribble touch: the foot reaches the ball when the touch lands (Dribbling starts it a little
##    earlier), the running cycle is steered so that leg is the one swinging forward;
##  - short actions on top (PlayerActions): kick, tackle, shoulder, dive, skill, celebrate.
## Numbers: data/config/animation.json.

## Keepers stand in a ready stance.
var keeper: bool = false
## A keeper holding the ball in his hands: both arms in front.
var holding: bool = false

var _rig: PlayerRig
var _pose: RigPose = RigPose.new()
var _cfg: Dictionary
var _phase: float = 0.0
var _move: float = 0.0
var _accel: float = 0.0
var _prev_forward: float = 0.0
var _turn_lean: float = 0.0
## Angle between where the player goes and where he faces (radians, + = to his right), smoothed.
var _travel: float = 0.0
## 1 when walking, 0 when running (from the speed).
var _walk: float = 0.0
var _clock: float = 0.0
var _action: String = ""
## A kick being charged ("pass" or "kick") and how far (0..1): the body winds up (ModelBody).
var windup: String = ""
var windup_amount: float = 0.0
var windup_side: float = 1.0
## A skinned 3D body worn instead of the coded one (ModelBody), or null.
var model: ModelBody = null
var _action_time: float = 0.0
var _action_duration: float = 0.3
var _side: float = 1.0
var _reach: float = 0.0
## Dribble touch: time since it started (< 0: none), time to the contact, foot (+1 right).
var _touch_time: float = -1.0
var _touch_lead: float = 0.1
var _touch_side: float = 1.0


func _init(rig: PlayerRig) -> void:
	_rig = rig
	_cfg = Config.get_section("animation")
	# Different breathing / sway timing per player (look only, no random numbers used).
	_clock = fposmod(float(get_instance_id()) * 0.618, 10.0)


## Short action: "kick", "tackle", "shoulder", "dive", "skill", "celebrate".
## side: +1 right / -1 left. reach: ball distance for a kick (the body lunges toward a far ball).
func play(action: String, side: float = 1.0, reach: float = 0.0) -> void:
	_action = action
	_action_time = 0.0
	_side = 1.0 if side >= 0.0 else -1.0
	_reach = reach
	_action_duration = maxf(0.05, _n(action + "_seconds", 0.3))


## Dribble touch with the right (+1) or left (-1) foot, reaching the ball in `lead` seconds.
func play_touch(side: float, lead: float) -> void:
	_touch_time = 0.0
	_touch_lead = maxf(0.0, lead)
	_touch_side = 1.0 if side >= 0.0 else -1.0


func update(delta: float, velocity: Vector3, facing: Vector3, turn_rate: float, top_speed: float) -> void:
	_clock += delta
	var speed := Vector2(velocity.x, velocity.z).length()
	var forward := velocity.x * facing.x + velocity.z * facing.z
	var sideways := velocity.z * facing.x - velocity.x * facing.z
	var target_move := smoothstep(_n("move_blend_min_speed", 0.15), _n("move_blend_full_speed", 1.1), speed)
	_move = move_toward(_move, target_move, delta * _n("move_blend_rate", 6.0))
	_advance_phase(delta, speed, forward)
	_update_leans(delta, speed, forward, turn_rate)
	_update_travel(delta, speed, forward, sideways)
	var sprint := clampf(speed / maxf(1.0, top_speed), 0.0, 1.0)
	_walk = 1.0 - smoothstep(_n("walk_gait_full_speed", 1.7), _n("run_gait_speed", 2.4), speed)
	_pose.clear()
	_running_pose(sprint)
	_idle_pose()
	_touch_layer(delta)
	if not _action.is_empty():
		_action_time += delta
		var t := clampf(_action_time / _action_duration, 0.0, 1.0)
		PlayerActions.apply(_pose, _action, t, _side, _reach, _cfg)
		if t >= 1.0:
			_action = ""
	if holding:
		for side in [-1.0, 1.0]:
			_pose.blend_arm(side, _n("hold_arm_forward", 55.0), _n("hold_arm_out", 14.0), _n("hold_elbow", 70.0), 1.0)
	# The head stays level when the body leans.
	_pose.v[RigPose.NECK_X] = -(_pose.v[RigPose.ROOT_X] + _pose.v[RigPose.SPINE_X]) * _n("head_stabilize", 0.7)
	_rig.apply(_pose)
	if model != null:
		var backward := forward < _n("backpedal_threshold", -0.4) * speed
		model.advance(delta, speed, backward, _move)
		model.apply(_pose, _action, _action_time, _action_duration, _side if not _action.is_empty() else windup_side, keeper, windup, windup_amount)


## The running cycle advances with the distance covered (longer strides when faster), backward
## when back-pedalling. During a dribble touch it is steered so the touching leg swings forward
## exactly when the foot meets the ball.
func _advance_phase(delta: float, speed: float, forward: float) -> void:
	var cycle := _n("gait_cycle_min", 1.2) + _n("gait_cycle_per_speed", 0.3) * speed
	var direction := -1.0 if forward < _n("backpedal_threshold", -0.4) * speed else 1.0
	var rate := speed / maxf(0.1, cycle) * TAU * direction
	if _touch_time >= 0.0 and _touch_time < _touch_lead:
		var left := _touch_lead - _touch_time
		# Left leg forward at phase PI/2, right leg at -PI/2.
		var wanted := PI * 0.5 * (-_touch_side)
		var error := wrapf(wanted - (_phase + rate * left), -PI, PI)
		var limit := deg_to_rad(_n("touch_phase_steer_max_degrees", 110.0))
		rate += clampf(error, -limit, limit) / maxf(0.02, left)
	_phase = fposmod(_phase + rate * delta, TAU)


func _update_leans(delta: float, speed: float, forward: float, turn_rate: float) -> void:
	if delta <= 0.0:
		return
	var accel := (forward - _prev_forward) / delta
	_prev_forward = forward
	_accel = lerpf(_accel, accel, 1.0 - exp(-_n("accel_smoothing", 8.0) * delta))
	# Centripetal lean: tan(angle) = speed * turn rate / g, toned down.
	var lean := rad_to_deg(atan(speed * turn_rate / 9.81)) * _n("turn_lean_factor", 0.5)
	var max_lean := _n("turn_lean_max_degrees", 18.0)
	lean = clampf(lean, -max_lean, max_lean)
	_turn_lean = lerpf(_turn_lean, lean, 1.0 - exp(-_n("turn_lean_smoothing", 8.0) * delta))


## Direction of travel against the facing, measured from the running direction (forward, or
## backward when back-pedalling), limited to a quarter turn.
func _update_travel(delta: float, speed: float, forward: float, sideways: float) -> void:
	var angle := 0.0
	if speed > 0.3:
		var backward := forward < _n("backpedal_threshold", -0.4) * speed
		angle = atan2(-sideways, -forward) if backward else atan2(sideways, forward)
		angle = clampf(angle, -PI * 0.5, PI * 0.5)
	_travel = lerpf(_travel, angle, 1.0 - exp(-_n("travel_smoothing", 12.0) * delta))


func _running_pose(sprint: float) -> void:
	var m := _move
	var w := _walk
	var s := sin(_phase)
	var hip := lerpf(lerpf(_n("hip_swing_jog", 24.0), _n("hip_swing_sprint", 46.0), sprint), _n("walk_hip_degrees", 20.0), w) * m
	var bias := _n("hip_forward_bias", 6.0) * sprint * m * (1.0 - w)
	var knee_stance := lerpf(_n("knee_stance", 14.0), _n("walk_knee_stance", 4.0), w) * m
	var knee_swing := lerpf(lerpf(_n("knee_swing_jog", 60.0), _n("knee_swing_sprint", 105.0), sprint), _n("walk_knee_swing", 50.0), w) * m
	var knee_offset := deg_to_rad(_n("knee_phase_offset_degrees", 23.0))
	var arm := lerpf(lerpf(_n("arm_swing_jog", 20.0), _n("arm_swing_sprint", 50.0), sprint), _n("walk_arm_degrees", 14.0), w) * m
	var arm_bias := _n("arm_forward_bias", 6.0) * m * (1.0 - w)
	var elbow_run := lerpf(_n("elbow_run", 88.0), _n("walk_elbow", 16.0), w) * m
	var elbow_swing := _n("elbow_swing", 18.0) * m * (1.0 - w * 0.6)
	var arm_out := _n("arm_out_degrees", 7.0)
	# Part of the travel angle turns the hips, the rest swings the legs sideways.
	var hips_turn := _travel * _n("travel_hips_share", 0.5) * m
	var leg_angle := _travel * m - hips_turn
	for leg in [-1.0, 1.0]:
		# Left leg (-1) follows the phase, the right leg is half a cycle later.
		var phase: float = _phase if leg < 0.0 else _phase + PI
		var fold := pow(maxf(0.0, cos(phase + knee_offset)), 2.0)
		var swing: float = hip * sin(phase) + bias
		_pose.blend_leg(leg, swing * cos(leg_angle), knee_stance + knee_swing * fold, leg * swing * sin(leg_angle), 1.0)
		# Each arm swings with the opposite leg; the elbow bends more when it comes forward.
		var arm_swing := -sin(phase)
		_pose.blend_arm(leg, arm * arm_swing + arm_bias, arm_out, elbow_run + elbow_swing * maxf(0.0, arm_swing), 1.0)
	var twist := deg_to_rad(_n("torso_twist_degrees", 8.0)) * s * m * (1.0 - w * 0.5)
	var hips_twist := deg_to_rad(_n("hips_twist_degrees", 7.0)) * s * m * (1.0 - w * 0.5)
	# The chest keeps facing ahead while the hips turn toward the way he goes.
	_pose.v[RigPose.HIPS_Y] = -hips_twist - hips_turn
	_pose.v[RigPose.SPINE_Y] = twist + hips_twist + hips_turn
	# Running: highest in flight. Walking: highest in mid-step, lowest with both feet down.
	var run_bob := _n("run_bob", 0.045) * (0.4 + 0.6 * sprint) * s * s - _n("run_crouch", 0.035) * sprint
	var walk_bob := _n("walk_bob", 0.025) * (1.0 - s * s)
	_pose.v[RigPose.ROOT_Y] = lerpf(run_bob, walk_bob, w) * m
	var accel_lean := clampf(_accel * _n("accel_lean_per_ms2", 0.8), -_n("brake_lean_max_degrees", 9.0),
		_n("accel_lean_max_degrees", 12.0))
	_pose.v[RigPose.ROOT_X] = deg_to_rad(accel_lean) * m
	_pose.v[RigPose.SPINE_X] = deg_to_rad(lerpf(_n("run_lean_degrees", 10.0) * sprint, _n("walk_lean_degrees", 3.0), w)) * m
	_pose.v[RigPose.ROOT_Z] = -deg_to_rad(_turn_lean)


## Standing: feet apart, knees a little bent, arms hanging, breathing and a slow weight shift.
## Keepers stand ready (crouched, arms forward). Faded out as the player starts running.
func _idle_pose() -> void:
	var w := 1.0 - _move
	if w <= 0.001:
		return
	var stance := _n("idle_stance_degrees", 4.0)
	var knee := _n("idle_knee_degrees", 9.0)
	var thigh := 0.0
	var lean := 0.0
	var arm_forward := 0.0
	var arm_out := _n("arm_out_degrees", 7.0)
	var elbow := _n("elbow_idle", 14.0)
	if keeper:
		knee = _n("keeper_ready_knee", 30.0)
		thigh = _n("keeper_ready_thigh", 14.0)
		lean = _n("keeper_ready_lean", 12.0)
		arm_forward = _n("keeper_ready_arm_forward", 30.0)
		arm_out = _n("keeper_ready_arm_out", 22.0)
		elbow = _n("keeper_ready_elbow", 50.0)
	for side in [-1.0, 1.0]:
		_pose.blend_leg(side, thigh, knee, stance, w)
		_pose.blend_arm(side, arm_forward, arm_out, elbow, w)
	var breath := sin(_clock * TAU * _n("idle_breath_hz", 0.3))
	var sway := sin(_clock * TAU * _n("idle_sway_hz", 0.22))
	_pose.blend(RigPose.SPINE_X, deg_to_rad(lean + _n("idle_breath_degrees", 1.2) * breath), w)
	_pose.blend(RigPose.HIPS_Z, deg_to_rad(_n("idle_sway_degrees", 1.5)) * sway, w)
	# Bent knees lower the hips so the feet stay on the ground.
	_pose.blend(RigPose.ROOT_Y, -PlayerRig.leg_drop(thigh, knee), w)


## The touching leg goes from its running position to the ball (reached at the contact time),
## follows through a little, then hands back to the running cycle.
func _touch_layer(delta: float) -> void:
	if _touch_time < 0.0:
		return
	_touch_time += delta
	var lead := _touch_lead
	var follow := _n("touch_follow_seconds", 0.16)
	var total := lead + follow
	if _touch_time >= total:
		_touch_time = -1.0
		return
	var w: float
	if _touch_time < lead:
		w = smoothstep(0.0, lead, _touch_time)
	else:
		w = 1.0 - smoothstep(lead + follow * 0.3, total, _touch_time)
	var through := smoothstep(lead, lead + follow * 0.4, _touch_time)
	# Walking touches are small pushes with the inside of the foot.
	var reach_thigh := lerpf(_n("touch_thigh_degrees", 40.0), _n("touch_walk_thigh_degrees", 24.0), _walk)
	var thigh := reach_thigh + _n("touch_follow_degrees", 10.0) * through * (1.0 - _walk * 0.5)
	_pose.blend_leg(_touch_side, thigh, _n("touch_knee_degrees", 14.0), 0.0, w)


func _n(key: String, fallback: float) -> float:
	return float(_cfg.get(key, fallback))
