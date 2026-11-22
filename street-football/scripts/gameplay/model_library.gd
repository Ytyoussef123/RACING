class_name ModelLibrary
extends RefCounted
## Reads the 3D files of the skinned body (ModelBody): the GLB exported by MotionForge Studio, whose
## movements are found by name, and the moment each movement's ball ("Ballon") leaves the foot.
## Older single-movement files (FBX) are still read whole. Every file is read once for all players.

static var _animations: Dictionary = {}
## GLB path -> {movement name: Animation}, read once.
static var _libraries: Dictionary = {}
## Animation -> the time its ball leaves the foot (-1: no ball), found once.
static var _kicks: Dictionary = {}


static func find(node: Node, type: String) -> Node:
	if node.is_class(type):
		return node
	for child in node.get_children():
		var found := find(child, type)
		if found != null:
			return found
	return null


static func load_scene(path: String) -> PackedScene:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


## The animation of a file, loaded once for all players.
static func animation(path: String) -> Animation:
	if not _animations.has(path):
		_animations[path] = _load_animation(path)
	return _animations[path]


## The animation of an imported file with the most tracks (the real take).
static func _load_animation(path: String) -> Animation:
	var scene := load_scene(path)
	if scene == null:
		return null
	var node := scene.instantiate()
	var player := find(node, "AnimationPlayer") as AnimationPlayer
	var best: Animation = null
	if player != null:
		for anim_name in player.get_animation_list():
			var anim := player.get_animation(anim_name)
			if anim_name != "RESET" and (best == null or anim.get_track_count() > best.get_track_count()
					or (anim.get_track_count() == best.get_track_count() and str(anim_name).contains("mixamo"))):
				best = anim
	node.free()
	return best


## A movement of a GLB by its name (all of them read once per file).
static func animation_named(path: String, anim_name: String) -> Animation:
	if not _libraries.has(path):
		var found := {}
		var scene := load_scene(path)
		if scene != null:
			var node := scene.instantiate()
			var player := find(node, "AnimationPlayer") as AnimationPlayer
			if player != null:
				for full_name in player.get_animation_list():
					var anim := player.get_animation(full_name)
					found[str(full_name)] = anim
					found[str(full_name).get_slice("/", str(full_name).get_slice_count("/") - 1)] = anim
			node.free()
		_libraries[path] = found
	return _libraries[path].get(anim_name, null)


## When the movement's ball ("Ballon") first moves fast (model_kick_speed m/s): the kick. -1
## when the movement has no ball.
static func kick_time(anim: Animation) -> float:
	if _kicks.has(anim):
		return _kicks[anim]
	var result := -1.0
	for track in range(anim.get_track_count()):
		var path := str(anim.track_get_path(track))
		if anim.track_get_type(track) != Animation.TYPE_POSITION_3D or not path.get_slice(":", 0).ends_with("Ballon"):
			continue
		var step := 1.0 / 60.0
		var fast := float(_cfg("model_kick_speed", 2.0))
		var before := anim.position_track_interpolate(track, 0.0)
		var t := step
		while t <= anim.length:
			var now := anim.position_track_interpolate(track, t)
			if Vector2(now.x - before.x, now.z - before.z).length() / step > fast:
				result = t - step
				break
			before = now
			t += step
		break
	_kicks[anim] = result
	return result


## "mixamorig:LeftArm", "mixamorig_LeftArm" or "mixamorigLeftArm" -> "LeftArm".
static func short(bone: String) -> String:
	var short_name := bone.substr(bone.rfind(":") + 1)
	if short_name.begins_with("mixamorig"):
		short_name = short_name.substr(9).lstrip("_0123456789")
	return short_name




static func _cfg(key: String, fallback: Variant) -> Variant:
	return Config.get_value("body", key, fallback)
