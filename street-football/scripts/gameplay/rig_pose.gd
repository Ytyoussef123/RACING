class_name RigPose
extends RefCounted
## One frame of the body pose (look only): every joint angle of PlayerRig, written by
## PlayerAnimator (running) and PlayerActions (kick, dive...), then applied by PlayerRig.
## Values are the joints' own rotations, in radians (positions in meters). Godot conventions:
## thigh / arm X < 0 swings the limb forward, knee > 0 bends it, elbow < 0 bends it,
## Z > 0 moves a left limb outward (a right limb goes outward with Z < 0), root X > 0 leans
## forward and root Z > 0 leans to the right. Helpers below take degrees and a side
## (+1 right, -1 left) so actions can be written once for either foot.

const ROOT_Y := 0
const ROOT_FWD := 1
const ROOT_X := 2
const ROOT_Z := 3
const HIPS_Y := 4
const HIPS_Z := 5
const SPINE_X := 6
const SPINE_Y := 7
const SPINE_Z := 8
const NECK_X := 9
const THIGH_L_X := 10
const THIGH_L_Z := 11
const KNEE_L := 12
const THIGH_R_X := 13
const THIGH_R_Z := 14
const KNEE_R := 15
const ARM_L_X := 16
const ARM_L_Z := 17
const ELBOW_L := 18
const ARM_R_X := 19
const ARM_R_Z := 20
const ELBOW_R := 21
const COUNT := 22

var v := PackedFloat32Array()


func _init() -> void:
	v.resize(COUNT)
	v.fill(0.0)


func clear() -> void:
	v.fill(0.0)


## Moves channel `ch` toward `value` by weight w (0 keeps it, 1 replaces it).
func blend(ch: int, value: float, w: float) -> void:
	v[ch] = lerpf(v[ch], value, w)


func add(ch: int, value: float) -> void:
	v[ch] += value


## Leg of one side (+1 right, -1 left) toward a pose given in degrees: forward swing of the
## thigh, knee bend, and outward spread.
func blend_leg(side: float, forward_deg: float, knee_deg: float, out_deg: float, w: float) -> void:
	var right := side > 0.0
	blend(THIGH_R_X if right else THIGH_L_X, -deg_to_rad(forward_deg), w)
	blend(KNEE_R if right else KNEE_L, deg_to_rad(knee_deg), w)
	blend(THIGH_R_Z if right else THIGH_L_Z, -side * deg_to_rad(out_deg), w)


## Arm of one side toward a pose in degrees: forward swing, outward raise, elbow bend.
func blend_arm(side: float, forward_deg: float, out_deg: float, elbow_deg: float, w: float) -> void:
	var right := side > 0.0
	blend(ARM_R_X if right else ARM_L_X, -deg_to_rad(forward_deg), w)
	blend(ARM_R_Z if right else ARM_L_Z, -side * deg_to_rad(out_deg), w)
	blend(ELBOW_R if right else ELBOW_L, -deg_to_rad(elbow_deg), w)


## Smooth in-out weight over an action's progress t (0..1): rises until `attack`, falls after `release`.
static func envelope(t: float, attack: float, release: float) -> float:
	var rise := smoothstep(0.0, maxf(0.001, attack), t) if attack > 0.0 else 1.0
	return rise * (1.0 - smoothstep(release, 1.0, t))
