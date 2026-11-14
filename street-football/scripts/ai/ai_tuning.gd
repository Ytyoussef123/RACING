class_name AiTuning
extends RefCounted
## How well an AI side plays, read from data/config/ai.json -> difficulties.<name>.

var difficulty: String = "normal"
var decision_interval: float = 0.28
var speed_factor: float = 1.0
var shot_error_degrees: float = 7.0
var shoot_range: float = 11.0
var pass_tendency: float = 0.25
var pass_pressure_distance: float = 2.2
var tackle_attempt_chance: float = 0.45
var tackle_success_bonus: float = 0.0
var keeper_save_chance: float = 0.6


static func for_difficulty(difficulty_name: String) -> AiTuning:
	var t := AiTuning.new()
	var all: Dictionary = Config.get_value("ai", "difficulties", {})
	var d: Dictionary = all.get(difficulty_name, all.get("normal", {}))
	t.difficulty = difficulty_name
	t.decision_interval = float(d.get("decision_interval", t.decision_interval))
	t.speed_factor = float(d.get("speed_factor", t.speed_factor))
	t.shot_error_degrees = float(d.get("shot_error_degrees", t.shot_error_degrees))
	t.shoot_range = float(d.get("shoot_range", t.shoot_range))
	t.pass_tendency = float(d.get("pass_tendency", t.pass_tendency))
	t.pass_pressure_distance = float(d.get("pass_pressure_distance", t.pass_pressure_distance))
	t.tackle_attempt_chance = float(d.get("tackle_attempt_chance", t.tackle_attempt_chance))
	t.tackle_success_bonus = float(d.get("tackle_success_bonus", t.tackle_success_bonus))
	t.keeper_save_chance = float(d.get("keeper_save_chance", t.keeper_save_chance))
	return t
