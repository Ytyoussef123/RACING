extends Node3D
## Motion study for the screenshot tour (CI, rendered, not headless): one player runs with the ball,
## sprints, turns and shoots on a plain pitch, stepped by hand at 60 Hz, and frames are put in grids
## (left to right, top to bottom) so the running animation, the foot touches and the ball at the feet
## can be checked on images. Also a line-up of bodies (kits, looks, poses) to check the model itself.
## run() returns {shot name: Image}.

const DT := 1.0 / 60.0
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const BALL_SCENE := preload("res://scenes/ball/ball.tscn")
const GRID := 4

var _camera: Camera3D
var _ctx: MatchContext
var _player: Player
var _ball: Ball
var _shots: Dictionary = {}


func run() -> Dictionary:
	_build_stage()
	_ctx = MatchContext.new()
	_ctx.court = CourtData.load_court("cage_concrete")
	_ball = BALL_SCENE.instantiate()
	add_child(_ball)
	_ctx.ball = _ball.physics
	_player = _spawn(Roster.player("teo_varmanetti"), "MID", Color(0.85, 0.15, 0.12), false)
	_player.position = Vector3(-14.0, 0.0, 0.0)
	await _run_sequence("motion_walk_side", "walk", true)
	await _run_sequence("motion_run_side", "run", true)
	await _run_sequence("motion_sprint_side", "sprint", true)
	await _run_sequence("motion_knockon_side", "knock_on", true)
	await _turn_and_shoot("motion_turn_game")
	_player.queue_free()
	_ball.queue_free()
	await _lineup("body_lineup")
	return _shots


## Runs with the ball along +x in a speed mode ("walk", "run", "sprint", "knock_on") and takes 16
## frames 0.1 s apart.
func _run_sequence(shot_name: String, mode: String, side_view: bool) -> void:
	_reset_with_ball(Vector3(-15.0, 0.0, 0.0), Vector3.RIGHT)
	var sprint := mode == "sprint"
	var walk := mode == "walk"
	var knock_on := mode == "knock_on"
	for i in range(30):
		_step(Vector3.RIGHT, sprint, false, walk, knock_on)
	var frames: Array[Image] = []
	for f in range(GRID * GRID):
		for i in range(6):
			_step(Vector3.RIGHT, sprint, false, walk, knock_on)
		_report(shot_name, f)
		frames.append(await _capture(side_view))
	_shots[shot_name] = _grid(frames)


## Jogs right, turns up the pitch, runs right again and shoots, seen from the match camera.
func _turn_and_shoot(shot_name: String) -> void:
	_reset_with_ball(Vector3(-8.0, 0.0, 2.0), Vector3.RIGHT)
	var plan := []
	for i in range(36):
		plan.append([Vector3.RIGHT, false, false])
	for i in range(30):
		plan.append([Vector3.FORWARD, false, false])
	for i in range(30):
		plan.append([Vector3.RIGHT, true, false])
	for i in range(18):
		plan.append([Vector3.RIGHT, false, true])
	for i in range(60):
		plan.append([Vector3.RIGHT, false, false])
	var frames: Array[Image] = []
	var every := maxi(1, int(plan.size() / float(GRID * GRID)))
	for i in range(plan.size()):
		var step: Array = plan[i]
		_step(step[0], step[1], step[2])
		if i % every == every - 1 and frames.size() < GRID * GRID:
			_report(shot_name, frames.size())
			frames.append(await _capture(false))
	_shots[shot_name] = _grid(frames)


## Eight bodies facing the camera: idle, keeper ready, jog, sprint, kick, dribble touch, tackle, dive.
## Actions are frozen at a telling moment: kick just after contact, touch at contact, tackle at its
## lowest, dive in the air (to the right of the picture, where there is room). Then a close-up
## of the first three heads (face, hair).
func _lineup(shot_name: String) -> void:
	var team_ids: Array = Roster.team_ids()
	var poses := ["idle", "keeper", "jog", "pass", "kick", "kick_late", "tackle", "dive"]
	var freeze_at := {"pass": 0.12, "kick": 0.08, "kick_late": 0.22, "tackle": 0.15, "dive": 0.25}
	var bodies: Array[Player] = []
	for i in range(poses.size()):
		var team: TeamData = Roster.team(str(team_ids[i % team_ids.size()]))
		var entry: Dictionary = team.players[(i * 2) % team.players.size()]
		var keeper: bool = poses[i] in ["keeper", "dive"]
		var kit := team.color("keeper" if keeper else "kit", Color.WHITE)
		var p := _spawn(Roster.player(str(entry.get("id", ""))), "GK" if keeper else "MID", kit, keeper)
		p.reset_to(Vector3(-4.375 + i * 1.25, 0.0, 0.0), Vector3.BACK)
		bodies.append(p)
	for i in range(bodies.size()):
		if poses[i] == "jog":
			bodies[i].motion.velocity = Vector3.BACK * 2.6
	for i in range(30):
		for p in bodies:
			p.update_look(DT)
	for i in range(bodies.size()):
		match poses[i]:
			"kick", "kick_late":
				bodies[i].animate("kick", 1.0, 0.6)
			"pass":
				bodies[i].animate("pass", 1.0, 0.6)
			"tackle":
				bodies[i].animate("tackle")
			"dive":
				bodies[i].animate("dive", -1.0)
	var step := DT * 0.25
	var elapsed := 0.0
	while elapsed < 0.25:
		elapsed += step
		for i in range(bodies.size()):
			if elapsed <= float(freeze_at.get(poses[i], 1.0)):
				bodies[i].update_look(step)
	_camera.fov = 42.0
	_camera.look_at_from_position(Vector3(0.6, 1.5, 6.6), Vector3(0.6, 0.9, 0.0), Vector3.UP)
	await _settle()
	await RenderingServer.frame_post_draw
	_shots[shot_name] = get_viewport().get_texture().get_image()
	_camera.fov = 30.0
	_camera.look_at_from_position(Vector3(-3.125, 1.62, 2.2), Vector3(-3.125, 1.52, 0.0), Vector3.UP)
	await _settle()
	await RenderingServer.frame_post_draw
	_shots[shot_name + "_heads"] = get_viewport().get_texture().get_image()
	for p in bodies:
		p.queue_free()


## One log line per frame, to check the ball against the player with numbers.
func _report(shot_name: String, frame: int) -> void:
	var to_ball := _ball.physics.position - _player.position
	var lead := to_ball.dot(_player.motion.facing)
	print("MOTION %s %02d lead=%.2f side=%.2f ball=%.2f player=%.2f holder=%s" % [shot_name, frame, lead,
		to_ball.dot(Vector3(-_player.motion.facing.z, 0.0, _player.motion.facing.x)), _ball.physics.horizontal_speed(),
		Vector2(_player.motion.velocity.x, _player.motion.velocity.z).length(), _ctx.possession.holder == _player])


func _step(move: Vector3, sprint: bool, shoot: bool = false, walk: bool = false, knock_on: bool = false) -> void:
	var intent := PlayerIntent.new()
	intent.move = move
	intent.sprint = sprint
	intent.walk = walk
	intent.knock_on = knock_on
	intent.shoot_held = shoot
	_player.intent = intent
	DribbleAssist.adjust(_player, _ctx)
	_player.move(DT, _ctx.court, _ctx.possession.holder == _player)
	_player.handling.update(DT, _player, _ctx)
	_ball.simulate(DT, _ctx.court)
	_player.update_look(DT)
	_ctx.events.clear()


func _reset_with_ball(pos: Vector3, facing: Vector3) -> void:
	_player.reset_to(pos, facing)
	_ball.physics.place(pos + facing * 0.48 + Vector3.UP * _ball.physics.radius)
	_ball.physics.velocity = Vector3.ZERO
	_ctx.possession = Possession.new()
	_ctx.possession.stats = _ctx.stats
	_ctx.possession.take(_player, _ball.physics)


## Side view: close, from the near touchline. Otherwise the match camera's angle and distance.
func _capture(side_view: bool) -> Image:
	var at := _player.position
	if side_view:
		_camera.fov = 40.0
		_camera.look_at_from_position(at + Vector3(0.0, 1.3, 5.5), at + Vector3(0.0, 0.85, 0.0), Vector3.UP)
	else:
		var view := MatchCamera.preset(str(Config.get_value("camera", "default_preset", "normal")))
		var pitch := deg_to_rad(float(view.get("pitch_degrees", 44.0)))
		_camera.fov = float(view.get("fov", 45.0))
		var offset := Vector3(0.0, sin(pitch), cos(pitch)) * float(view.get("distance", 17.0))
		_camera.look_at_from_position(at + offset, at, Vector3.UP)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var w := image.get_width()
	var h := image.get_height()
	var size := Vector2i(int(h * 0.62), int(h * 0.62)) if side_view else Vector2i(int(h * 0.44), int(h * 0.33))
	var crop := image.get_region(Rect2i(Vector2i((w - size.x) / 2, (h - size.y) / 2), size))
	crop.convert(Image.FORMAT_RGB8)
	return crop


func _grid(frames: Array[Image]) -> Image:
	if frames.is_empty():
		return Image.create_empty(8, 8, false, Image.FORMAT_RGB8)
	var tile := frames[0].get_size()
	var grid := Image.create_empty(tile.x * GRID, tile.y * GRID, false, Image.FORMAT_RGB8)
	grid.fill(Color(0.1, 0.1, 0.1))
	for i in range(frames.size()):
		var pos := Vector2i((i % GRID) * tile.x, (i / GRID) * tile.y)
		grid.blit_rect(frames[i], Rect2i(Vector2i.ZERO, tile), pos)
		# A thin dark line between frames.
		grid.fill_rect(Rect2i(pos, Vector2i(tile.x, 2)), Color(0.05, 0.05, 0.05))
		grid.fill_rect(Rect2i(pos, Vector2i(2, tile.y)), Color(0.05, 0.05, 0.05))
	return grid


func _spawn(profile: PlayerProfile, role: String, kit: Color, keeper: bool) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	add_child(p)
	p.set_process(false)
	var team := Team.new()
	team.tuning = AiTuning.for_difficulty("normal")
	team.players.append(p)
	p.team = team
	p.is_keeper = keeper
	if profile != null:
		p.apply_profile(profile, role, 7)
	p.set_kit(kit)
	p.reset_to(p.position, Vector3.RIGHT)
	return p


func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.15, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 1.0)
	env.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.95, 0.6, 0.0)
	sun.light_energy = 1.1
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 50.0)
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.22, 0.45, 0.2)
	plane.material = grass
	ground.mesh = plane
	add_child(ground)
	# Lines every 2 m show how fast the feet and the ball move against the ground.
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.85, 0.9, 0.85)
	for i in range(-20, 21):
		var line := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.004, 50.0)
		box.material = line_mat
		line.mesh = box
		line.position = Vector3(i * 2.0, 0.002, 0.0)
		add_child(line)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.make_current()


func _settle() -> void:
	for i in range(3):
		await get_tree().process_frame
