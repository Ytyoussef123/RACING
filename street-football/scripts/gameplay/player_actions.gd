class_name PlayerActions
extends RefCounted
## Short body actions drawn on top of the running pose (look only), for the jointed body:
## kick, tackle, shoulder charge, keeper dive, skill move and goal celebration.
## t: progress 0..1 through the action; side: +1 right, -1 left (kicking foot, dive or charge side).
## Each action blends its own pose in and out (RigPose.envelope). Numbers: data/config/animation.json.


static func apply(p: RigPose, action: String, t: float, side: float, reach: float, cfg: Dictionary) -> void:
	match action:
		"kick", "pass", "chip":
			if PoseClips.has(action):
				_clip_kick(p, action, t, side, reach, cfg)
			else:
				_kick(p, t, side, reach, cfg)
		"tackle", "tackle_stand":
			_tackle(p, t, side, cfg)
		"shoulder":
			_shoulder(p, t, side, cfg)
		"dive":
			_dive(p, t, side, cfg)
		"skill":
			_skill(p, t, side, cfg)
		"celebrate":
			_celebrate(p, t, cfg)


## The ball has just left: the foot is at the contact point, then follows through high while
## the other leg stays planted and the arms open for balance. A far ball makes the body lunge.
static func _kick(p: RigPose, t: float, side: float, reach: float, cfg: Dictionary) -> void:
	var w := RigPose.envelope(t, 0.04, 0.55)
	var follow := smoothstep(0.0, 0.4, t)
	var thigh := lerpf(_n(cfg, "kick_contact_thigh", 30.0), _n(cfg, "kick_follow_thigh", 78.0), follow)
	var knee := lerpf(_n(cfg, "kick_contact_knee", 25.0), _n(cfg, "kick_follow_knee", 6.0), follow)
	p.blend_leg(side, thigh, knee, 0.0, w)
	p.blend_leg(-side, 8.0, _n(cfg, "kick_plant_knee", 22.0), 4.0, w)
	p.blend_arm(-side, 20.0, _n(cfg, "kick_arm_out", 55.0), 30.0, w)
	p.blend_arm(side, -30.0, _n(cfg, "kick_arm_out", 55.0) * 0.5, 25.0, w)
	p.blend(RigPose.SPINE_X, -deg_to_rad(_n(cfg, "kick_lean_back_degrees", 9.0)), w)
	p.blend(RigPose.ROOT_X, 0.0, w)
	var lunge := clampf(reach - _n(cfg, "kick_foot_reach", 0.6), 0.0, _n(cfg, "kick_lunge_max", 0.25))
	p.add(RigPose.ROOT_FWD, lunge * w * (1.0 - smoothstep(0.1, 0.7, t)))


## A recorded kick or pass (PoseClips "kick" / "pass"): it starts as the ball leaves the foot and
## fades back into the run; a far ball still makes the body lunge.
static func _clip_kick(p: RigPose, clip: String, t: float, side: float, reach: float, cfg: Dictionary) -> void:
	var w := RigPose.envelope(t, _n(cfg, "clip_blend_in", 0.08), _n(cfg, "clip_blend_out", 0.6))
	PoseClips.apply(p, clip, t, side, w)
	var lunge := clampf(reach - _n(cfg, "kick_foot_reach", 0.6), 0.0, _n(cfg, "kick_lunge_max", 0.25))
	p.add(RigPose.ROOT_FWD, lunge * w * (1.0 - smoothstep(0.1, 0.7, t)))


## Stab at the ball: body low and forward, one leg straight out, arms open.
static func _tackle(p: RigPose, t: float, side: float, cfg: Dictionary) -> void:
	var w := RigPose.envelope(t, 0.15, 0.7)
	p.blend_leg(side, _n(cfg, "tackle_leg_degrees", 60.0), 10.0, 10.0, w)
	p.blend_leg(-side, -10.0, 50.0, 0.0, w)
	for arm in [-1.0, 1.0]:
		p.blend_arm(arm, 20.0, 40.0, 30.0, w)
	p.blend(RigPose.SPINE_X, deg_to_rad(_n(cfg, "tackle_lean_degrees", 25.0)), w)
	p.add(RigPose.ROOT_Y, -_n(cfg, "tackle_drop", 0.12) * w)


## Shoulder into the opponent on `side`: body leans that way, elbow tucked, knees bent.
static func _shoulder(p: RigPose, t: float, side: float, cfg: Dictionary) -> void:
	var w := RigPose.envelope(t, 0.2, 0.6)
	p.add(RigPose.ROOT_Z, deg_to_rad(_n(cfg, "shoulder_roll_degrees", 14.0)) * side * w)
	p.add(RigPose.SPINE_Z, deg_to_rad(_n(cfg, "shoulder_bend_degrees", 10.0)) * side * w)
	p.blend_arm(side, 15.0, 25.0, 100.0, w)
	for leg in [-1.0, 1.0]:
		p.blend_leg(leg, 10.0, 25.0, 6.0, w)
	p.add(RigPose.ROOT_Y, -_n(cfg, "shoulder_drop", 0.05) * w)


## Keeper dive to `side`: the whole body falls sideways, arms stretched above the head.
static func _dive(p: RigPose, t: float, side: float, cfg: Dictionary) -> void:
	var w := RigPose.envelope(t, 0.12, 0.75)
	p.add(RigPose.ROOT_Z, deg_to_rad(_n(cfg, "dive_roll_degrees", 78.0)) * side * w)
	p.add(RigPose.ROOT_Y, -_n(cfg, "dive_drop", 0.35) * w)
	p.add(RigPose.SPINE_Z, deg_to_rad(10.0) * side * w)
	for arm in [-1.0, 1.0]:
		p.blend_arm(arm, 0.0, _n(cfg, "dive_arm_degrees", 165.0), 5.0, w)
	p.blend_leg(side, 15.0, 20.0, 12.0, w)
	p.blend_leg(-side, 5.0, 25.0, 0.0, w)


## Skill move: a small hop, the body leans and one leg sweeps over the ball.
static func _skill(p: RigPose, t: float, side: float, cfg: Dictionary) -> void:
	var w := RigPose.envelope(t, 0.2, 0.6)
	var arc := sin(t * PI)
	p.add(RigPose.ROOT_Y, _n(cfg, "skill_hop", 0.12) * arc)
	p.add(RigPose.ROOT_Z, deg_to_rad(_n(cfg, "skill_roll_degrees", 16.0)) * side * arc)
	p.blend_leg(side, _n(cfg, "skill_leg_forward", 30.0), 35.0, _n(cfg, "skill_leg_out", 30.0), w)
	for arm in [-1.0, 1.0]:
		p.blend_arm(arm, 10.0, 45.0, 30.0, w)


## Goal: jumps with both arms up, knees bending at each landing.
static func _celebrate(p: RigPose, t: float, cfg: Dictionary) -> void:
	var w := RigPose.envelope(t, 0.05, 0.9)
	var bounce := absf(sin(t * PI * _n(cfg, "celebrate_jumps", 4.0)))
	p.add(RigPose.ROOT_Y, bounce * _n(cfg, "celebrate_jump", 0.35) * w)
	var pump := 20.0 + 40.0 * (1.0 - bounce)
	for side in [-1.0, 1.0]:
		p.blend_arm(side, 25.0, _n(cfg, "celebrate_arm_degrees", 150.0), pump, w)
		p.blend_leg(side, 10.0, 10.0 + 30.0 * (1.0 - bounce), 5.0, w)


static func _n(cfg: Dictionary, key: String, fallback: float) -> float:
	return float(cfg.get(key, fallback))
