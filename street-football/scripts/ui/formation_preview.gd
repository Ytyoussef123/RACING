class_name FormationPreview
extends Control
## Mini court seen from above with a crew placed in a formation (SlotAssigner): one dot per
## player with his number and name. Own goal on the left, attacking to the right.

const DOT_RADIUS := 26.0

var _formation: FormationData
var _labels: Array[String] = []
var _kit: Color = Color.WHITE
var _keeper_kit: Color = Color.GRAY


func _init() -> void:
	custom_minimum_size = Vector2(900.0, 560.0)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	mouse_filter = MOUSE_FILTER_IGNORE


func show_formation(team: TeamData, formation: FormationData) -> void:
	_formation = formation
	_kit = team.color("kit", Color.WHITE)
	_keeper_kit = team.color("keeper", Color.GRAY)
	var profiles: Array[PlayerProfile] = []
	var numbers: Array[int] = []
	for entry in team.players:
		profiles.append(Roster.player(str(entry.get("id", ""))))
		numbers.append(int(entry.get("number", 0)))
	_labels.clear()
	var order := SlotAssigner.assign(profiles, formation)
	for slot in range(order.size()):
		var p := profiles[order[slot]]
		_labels.append("%d %s" % [numbers[order[slot]], p.short_name])
	queue_redraw()


func _draw() -> void:
	var pitch := Rect2(Vector2(20.0, 20.0), size - Vector2(40.0, 70.0))
	draw_rect(pitch, UiTheme.color("background_2"))
	draw_rect(pitch, UiTheme.color("text_dim"), false, 3.0)
	var mid := pitch.position.x + pitch.size.x * 0.5
	draw_line(Vector2(mid, pitch.position.y), Vector2(mid, pitch.end.y), UiTheme.color("text_dim"), 3.0)
	draw_arc(pitch.get_center(), pitch.size.y * 0.14, 0.0, TAU, 40, UiTheme.color("text_dim"), 3.0)
	if _formation == null:
		return
	var font := get_theme_default_font()
	var font_size := UiTheme.font_size("small")
	for slot in range(mini(_labels.size(), _formation.slots.size())):
		var data := _formation.slot(slot)
		var x := pitch.position.x + pitch.size.x * float(data.get("x", 0.5)) * 0.95 + 10.0
		var y := pitch.get_center().y + pitch.size.y * 0.42 * float(data.get("z", 0.0))
		var color := _keeper_kit if slot == 0 else _kit
		draw_circle(Vector2(x, y), DOT_RADIUS, color)
		draw_arc(Vector2(x, y), DOT_RADIUS, 0.0, TAU, 32, Color.BLACK, 3.0)
		draw_string(font, Vector2(x - 160.0, y + DOT_RADIUS + font_size), _labels[slot],
			HORIZONTAL_ALIGNMENT_CENTER, 320.0, font_size, UiTheme.color("text"))
