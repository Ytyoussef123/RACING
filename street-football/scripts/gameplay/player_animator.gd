class_name PlayerAnimator
extends RefCounted
## Procedural animation for the low-poly players (no rig): running legs, bob and lean, plus short
## actions: kick, tackle, shoulder, keeper dive, goal celebration. Look only.
## Numbers: data/config/animation.json.

var _pose: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _phase: float = 0.0
var _action: String = ""
var _action_time: float = 0.0
var _action_duration: float = 0.3
## Kicking leg (+1 right, -1 left) or dive / shoulder side (+1 right, -1 left).
var _side: float = 1.0


func _init(pose: Node3D, left_leg: Node3D, right_leg: Node3D) -> void:
	_pose = pose
	_left_leg = left_leg
	_right_leg = right_leg


func play(action: String, side: float = 1.0) -> void:
	_action = action
	_action_time = 0.0
	_side = 1.0 if side >= 0.0 else -1.0
	_action_duration = maxf(0.05, _num(action + "_seconds", 0.3))


func update(delta: float, speed: float, top_speed: float) -> void:
	_phase = fposmod(_phase + speed * delta / maxf(0.1, _num("stride_length", 1.5)) * TAU, TAU)
	var run := clampf(speed / maxf(1.0, top_speed), 0.0, 1.0)
	var swing := sin(_phase) * deg_to_rad(_num("leg_swing_degrees", 38.0)) * run
	var left := swing
	var right := -swing
	var lean := deg_to_rad(_num("run_lean_degrees", 8.0)) * run
	var height := absf(sin(_phase)) * _num("run_bob", 0.05) * run
	var roll := 0.0
	if not _action.is_empty():
		_action_time += delta
		var t := clampf(_action_time / _action_duration, 0.0, 1.0)
		var pulse := sin(t * PI)
		match _action:
			"kick":
				# Forward swing is a negative rotation of the leg around its hip.
				var kick := -deg_to_rad(_num("kick_swing_degrees", 75.0)) * pulse
				if _side > 0.0:
					right = kick
				else:
					left = kick
				lean -= deg_to_rad(_num("kick_lean_back_degrees", 8.0)) * pulse
			"tackle":
				lean += deg_to_rad(_num("tackle_lean_degrees", 30.0)) * pulse
				right = -deg_to_rad(_num("kick_swing_degrees", 75.0)) * 0.6 * pulse
			"shoulder":
				roll = deg_to_rad(_num("shoulder_roll_degrees", 20.0)) * pulse * _side
			"dive":
				roll = deg_to_rad(_num("dive_roll_degrees", 80.0)) * pulse * _side
				height -= _num("dive_drop", 0.35) * pulse
			"celebrate":
				height += absf(sin(t * PI * _num("celebrate_jumps", 4.0))) * _num("celebrate_jump", 0.35)
		if t >= 1.0:
			_action = ""
	_left_leg.rotation.x = left
	_right_leg.rotation.x = right
	_pose.rotation = Vector3(lean, 0.0, roll)
	_pose.position.y = height


func _num(key: String, fallback: float) -> float:
	return float(Config.get_value("animation", key, fallback))
