class_name PoseClips
extends RefCounted
## Recorded body movements (look only): joint angles per frame for the jointed body, converted from
## motion-capture animations by tools/mixamo_to_clip.py and stored in data/animations/<name>.json
## ({"fps", "contact", "frames": [[RigPose channels]...]}). Recorded for the right foot; side -1
## mirrors them. A clip is blended over the running pose and fades out at its end.

const FOLDER := "res://data/animations/"
const SWAP := [[RigPose.THIGH_L_X, RigPose.THIGH_R_X], [RigPose.KNEE_L, RigPose.KNEE_R],
	[RigPose.ARM_L_X, RigPose.ARM_R_X], [RigPose.ELBOW_L, RigPose.ELBOW_R]]
const SWAP_NEGATE := [[RigPose.THIGH_L_Z, RigPose.THIGH_R_Z], [RigPose.ARM_L_Z, RigPose.ARM_R_Z]]
const NEGATE := [RigPose.ROOT_Z, RigPose.HIPS_Y, RigPose.HIPS_Z, RigPose.SPINE_Y, RigPose.SPINE_Z]

static var _clips: Dictionary = {}


## The clip's frames (Array of PackedFloat32Array), empty when there is no such clip.
static func frames(clip_name: String) -> Array:
	if not _clips.has(clip_name):
		_clips[clip_name] = _load(clip_name)
	return _clips[clip_name]


static func has(clip_name: String) -> bool:
	return not frames(clip_name).is_empty()


## Blends the clip at progress t (0..1) into the pose with weight w.
static func apply(p: RigPose, clip_name: String, t: float, side: float, w: float) -> void:
	var list := frames(clip_name)
	if list.is_empty():
		return
	var at := clampf(t, 0.0, 1.0) * float(list.size() - 1)
	var i := mini(int(at), list.size() - 1)
	var j := mini(i + 1, list.size() - 1)
	var a: PackedFloat32Array = list[i]
	var b: PackedFloat32Array = list[j]
	var frame := PackedFloat32Array()
	frame.resize(RigPose.COUNT)
	for ch in range(RigPose.COUNT):
		frame[ch] = lerpf(a[ch], b[ch], at - float(i))
	if side < 0.0:
		frame = _mirrored(frame)
	for ch in range(RigPose.COUNT):
		if ch == RigPose.ROOT_Y or ch == RigPose.ROOT_FWD:
			p.add(ch, frame[ch] * w)
		else:
			p.blend(ch, frame[ch], w)


static func _mirrored(f: PackedFloat32Array) -> PackedFloat32Array:
	var out := f.duplicate()
	for pair in SWAP:
		out[pair[0]] = f[pair[1]]
		out[pair[1]] = f[pair[0]]
	for pair in SWAP_NEGATE:
		out[pair[0]] = -f[pair[1]]
		out[pair[1]] = -f[pair[0]]
	for ch in NEGATE:
		out[ch] = -f[ch]
	return out


static func _load(clip_name: String) -> Array:
	var out: Array = []
	var path := FOLDER + clip_name + ".json"
	if not FileAccess.file_exists(path):
		return out
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		return out
	for row in data.get("frames", []):
		var frame := PackedFloat32Array()
		frame.resize(RigPose.COUNT)
		for ch in range(mini(RigPose.COUNT, row.size())):
			frame[ch] = float(row[ch])
		out.append(frame)
	return out
