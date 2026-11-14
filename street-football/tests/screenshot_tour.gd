extends Node
## Renders every screen and prints it into the log as base64 JPEG, so the layout can be reviewed
## without a phone. Run by CI with a virtual display (not headless):
##   xvfb-run godot --path street-football --rendering-driver opengl3 --resolution 2400x1080 \
##     res://tests/screenshot_tour.tscn
## Output per shot: "SHOT_BEGIN <name>", "SHOT_DATA <base64 chunk>" lines, "SHOT_END <name>".

const SHOT_WIDTH := 1200
const CHUNK := 2000
const SETTLE_FRAMES := 8

var _sample_result := {
	"home_id": "concrete_kings", "away_id": "rooftop_rebels", "home_score": 3, "away_score": 2,
	"goals": [{"team": 0, "scorer": "T. Varmanetti", "own_goal": false, "time": "0:48"},
		{"team": 1, "scorer": "B. Lemoreau", "own_goal": false, "time": "1:30"},
		{"team": 0, "scorer": "D. Fenwick-Ashe", "own_goal": false, "time": "2:05"},
		{"team": 1, "scorer": "M. Obadunmi", "own_goal": true, "time": "2:31"},
		{"team": 0, "scorer": "Y. Belkaroun", "own_goal": false, "time": "2:58"}],
	"stats": {"shots": [11, 8], "saves": [4, 5], "passes_completed": [24, 17], "balls_won": [13, 10],
		"possession": [56, 44]},
}


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	Screens.test_mode = true
	MatchSetup.test_mode = false
	MatchSetup.last_result = _sample_result
	_tour.call_deferred()


func _tour() -> void:
	SaveGame.in_memory = true
	SaveGame.start_new()
	for screen_id in ["main_menu", "team_select", "formation_select", "court_select", "settings", "results", "squad", "shop"]:
		await _shot_screen(screen_id, screen_id)
	TranslationServer.set_locale("fr")
	await _shot_screen("team_select", "team_select_fr")
	await _shot_screen("court_select", "court_select_fr")
	TranslationServer.set_locale("en")
	var squad := _open("squad")
	await _settle(SETTLE_FRAMES)
	var card := _find_card(squad)
	if card != null:
		var profile: PlayerProfile = Roster.player("teo_varmanetti")
		card.show_player(profile, 7)
	await _shot("player_card")
	squad.queue_free()
	await _settle(2)
	var match_node: Node = load("res://scenes/match/match.tscn").instantiate()
	add_child(match_node)
	await _settle(150)
	await _shot("match")
	match_node.call("_open_pause")
	await _settle(SETTLE_FRAMES)
	await _shot("match_pause")
	get_tree().paused = false
	print("SHOTS DONE")
	get_tree().quit()


func _open(screen_id: String) -> Node:
	var screens: Dictionary = Config.get_value("ui", "screens", {})
	var screen: Node = load(str(screens[screen_id])).instantiate()
	add_child(screen)
	return screen


func _shot_screen(screen_id: String, shot_name: String) -> void:
	var screen := _open(screen_id)
	await _settle(SETTLE_FRAMES)
	await _shot(shot_name)
	screen.queue_free()
	await _settle(2)


func _settle(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var height := int(round(float(image.get_height()) * SHOT_WIDTH / float(image.get_width())))
	image.resize(SHOT_WIDTH, height, Image.INTERPOLATE_BILINEAR)
	var data := Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.82))
	print("SHOT_BEGIN ", shot_name)
	var i := 0
	while i < data.length():
		print("SHOT_DATA ", data.substr(i, CHUNK))
		i += CHUNK
	print("SHOT_END ", shot_name)


func _find_card(node: Node) -> PlayerCard:
	if node is PlayerCard:
		return node
	for child in node.get_children():
		var found := _find_card(child)
		if found != null:
			return found
	return null
