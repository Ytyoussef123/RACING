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
## Chance per decision to try a skill move when pressed (scaled by the player's skill stars).
var skill_tendency: float = 0.15
## Team movement: runs in behind per second (when the forward may run), chance per decision to
## play a through pass to a runner, chance that a passer runs forward after his pass.
var run_rate: float = 0.5
var through_tendency: float = 0.55
var give_go_chance: float = 0.6
## Ball in the air to a far, open teammate when no ground pass is on: chance per decision, and how
## far off its power can be (0..1 of the bar).
var lofted_tendency: float = 0.35
var lofted_power_error: float = 0.07
## Shot types (AiShots): chances of a chip (keeper off his line), a curled shot (edge of the box)
## and a low shot (close in), and how far off a chip's or curl's power can be (0..1 of the bar).
var chip_tendency: float = 0.3
var curl_tendency: float = 0.2
var low_tendency: float = 0.25
var shot_power_error: float = 0.08


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
	t.skill_tendency = float(d.get("skill_tendency", t.skill_tendency))
	t.run_rate = float(d.get("run_rate", t.run_rate))
	t.through_tendency = float(d.get("through_tendency", t.through_tendency))
	t.give_go_chance = float(d.get("give_go_chance", t.give_go_chance))
	t.lofted_tendency = float(d.get("lofted_tendency", t.lofted_tendency))
	t.lofted_power_error = float(d.get("lofted_power_error", t.lofted_power_error))
	t.chip_tendency = float(d.get("chip_tendency", t.chip_tendency))
	t.curl_tendency = float(d.get("curl_tendency", t.curl_tendency))
	t.low_tendency = float(d.get("low_tendency", t.low_tendency))
	t.shot_power_error = float(d.get("shot_power_error", t.shot_power_error))
	return t
