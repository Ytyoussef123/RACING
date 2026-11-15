extends Node
## Renders every screen and prints it into the log as base64 JPEG, so the layout can be reviewed
## without a phone. Run by CI with a virtual display (not headless):
##   xvfb-run godot --path street-football --rendering-driver opengl3 --resolution 2400x1080 \
##     res://tests/screenshot_tour.tscn
## Output per shot: "SHOT_BEGIN <name>", "SHOT_DATA <base64 chunk>" lines, "SHOT_END <name>".
## Then an AI-vs-AI match seen from straight above (team shape: spacing, support, runs, cover),
## and the motion study (tests/motion_study.gd): frame grids of a player running with the ball.

const SHOT_WIDTH := 1200
const CHUNK := 2000
const SETTLE_FRAMES := 8
## Top view: camera height above the center spot, frames before the first picture and between
## pictures, number of pictures, fixed match seed.
const TOP_HEIGHT := 34.0
const TOP_FOV := 50.0
const TOP_WARMUP_FRAMES := 240
const TOP_EVERY_FRAMES := 150
const TOP_SHOTS := 4
const TOP_SEED := 22

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
	var camera: MatchCamera = match_node.get_node("Camera")
	for view in ["close", "wide"]:
		camera.apply_preset(view)
		await _settle(3)
		await _shot("match_camera_" + view)
	camera.apply_preset(Settings.camera_view)
	match_node.call("_open_pause")
	await _settle(SETTLE_FRAMES)
	await _shot("match_pause")
	get_tree().paused = false
	match_node.queue_free()
	await _settle(2)
	await _top_view()
	var study: Node = load("res://tests/motion_study.gd").new()
	add_child(study)
	var images: Dictionary = await study.run()
	for shot_name in images:
		_print_image(str(shot_name), images[shot_name])
	print("SHOTS DONE")
	get_tree().quit()


## An AI-vs-AI match (fixed seed) seen from straight above, TOP_SHOTS moments apart, each cropped
## to the court: where every player stands shows the team shape.
func _top_view() -> void:
	MatchSetup.test_mode = true
	MatchSetup.test_seed = TOP_SEED
	var match_node: Node = load("res://scenes/match/match.tscn").instantiate()
	add_child(match_node)
	var court: CourtData = match_node.ctx.court
	var top := Camera3D.new()
	match_node.add_child(top)
	top.fov = TOP_FOV
	top.look_at_from_position(Vector3(0.0, TOP_HEIGHT, 0.0), Vector3.ZERO, Vector3.FORWARD)
	top.make_current()
	await _settle(TOP_WARMUP_FRAMES)
	for i in range(TOP_SHOTS):
		await _settle(TOP_EVERY_FRAMES)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		_print_image("match_top_%d" % (i + 1), _crop_court(image, top, court))
	match_node.queue_free()
	MatchSetup.test_mode = false
	MatchSetup.test_seed = 0
	await _settle(2)


func _crop_court(image: Image, camera: Camera3D, court: CourtData) -> Image:
	var scale := Vector2(image.get_size()) / get_viewport().get_visible_rect().size
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for corner: Vector3 in [Vector3(-1.0, 0.0, -1.0), Vector3(1.0, 0.0, -1.0), Vector3(-1.0, 0.0, 1.0), Vector3(1.0, 0.0, 1.0)]:
		var world := Vector3(corner.x * (court.half_length + 1.0), 0.0, corner.z * (court.half_width + 1.0))
		var p := camera.unproject_position(world) * scale
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var rect := Rect2i(Vector2i(lo), Vector2i(hi - lo)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	return image.get_region(rect) if rect.has_area() else image


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
	_print_image(shot_name, get_viewport().get_texture().get_image())


func _print_image(shot_name: String, image: Image) -> void:
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
