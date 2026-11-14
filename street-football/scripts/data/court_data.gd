class_name CourtData
extends RefCounted
## One court, loaded from res://data/courts/<id>.json. All sizes are in meters.
## The court is centered on the origin: length along x (goals at +x and -x), width along z.

const COURTS_DIR := "res://data/courts/"

var id: String = ""
var name_key: String = ""
var length: float = 30.0
var width: float = 18.0
var goal_width: float = 3.0
var goal_height: float = 2.0
var goal_depth: float = 1.0
var post_radius: float = 0.06
var walls: bool = true
## Surface: how much faster the ball slows down when rolling, and how much it bounces (1 = concrete).
var ball_friction_mult: float = 1.0
var ball_bounce_mult: float = 1.0

var half_length: float:
	get:
		return length * 0.5
var half_width: float:
	get:
		return width * 0.5
var half_goal_width: float:
	get:
		return goal_width * 0.5

var _raw: Dictionary = {}


static func load_court(court_id: String) -> CourtData:
	var court := CourtData.new()
	var path := COURTS_DIR + court_id + ".json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("CourtData: cannot read %s" % path)
		return court
	var data: Dictionary = parsed
	court._raw = data
	court.id = court_id
	court.name_key = str(data.get("name_key", ""))
	court.length = float(data.get("length", court.length))
	court.width = float(data.get("width", court.width))
	court.goal_width = float(data.get("goal_width", court.goal_width))
	court.goal_height = float(data.get("goal_height", court.goal_height))
	court.goal_depth = float(data.get("goal_depth", court.goal_depth))
	court.post_radius = float(data.get("post_radius", court.post_radius))
	court.walls = bool(data.get("walls", court.walls))
	court.ball_friction_mult = float(data.get("ball_friction_mult", 1.0))
	court.ball_bounce_mult = float(data.get("ball_bounce_mult", 1.0))
	return court


## Extra numbers used only for the look of the court (line width, fence height...).
func number(key: String, fallback: float) -> float:
	return float(_raw.get(key, fallback))


func color(key: String, fallback: Color) -> Color:
	var colors: Dictionary = _raw.get("colors", {})
	if colors.has(key):
		return Color.html(str(colors[key]))
	return fallback
