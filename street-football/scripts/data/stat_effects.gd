class_name StatEffects
extends RefCounted
## Turns a player's attributes (0..99) into gameplay numbers ("stat sheet"), using
## data/config/stat_effects.json: each effect maps one attribute linearly from `low` (at stat_low)
## to `high` (at stat_high), clamped. Attributes are first scaled by the position fitness.
## Gameplay code reads the sheet with Player.stat(name, fallback); the fallback is the neutral
## value used by players without a profile (tests).


static func build_sheet(profile: PlayerProfile, role: String) -> Dictionary:
	var effects: Dictionary = Config.get_value("stat_effects", "effects", {})
	var lo := float(Config.get_value("stat_effects", "stat_low", 40.0))
	var hi := float(Config.get_value("stat_effects", "stat_high", 99.0))
	var fitness := Ratings.position_fitness(profile, role)
	var sheet := {}
	for effect_name in effects:
		var e: Dictionary = effects[effect_name]
		var value := profile.attr(str(e.get("stat", ""))) * fitness
		var t := clampf((value - lo) / maxf(1.0, hi - lo), 0.0, 1.0)
		sheet[effect_name] = lerpf(float(e.get("low", 1.0)), float(e.get("high", 1.0)), t)
	if role == "GK":
		# A keeper's movement comes from his positioning, not from his outfield speed.
		var keeper_move := float(sheet.get("keeper_move_mult", 1.0))
		sheet["run_speed_mult"] = keeper_move
		sheet["sprint_speed_mult"] = keeper_move
	return sheet


static func num(key: String, fallback: float) -> float:
	return float(Config.get_value("stat_effects", key, fallback))
