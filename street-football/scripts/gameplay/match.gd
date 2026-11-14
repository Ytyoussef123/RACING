extends Node3D
## Phase 2 match: one human player, a ball and a court.
## Runs the fixed-step loop (input -> player -> ball -> camera) and the goal / out / kick-off flow.

enum State { PLAYING, STOPPED }

const MENU_SCENE := "res://scenes/boot/boot_screen.tscn"
## Height above the player's feet where the shot power bar is drawn (visual only).
const POWER_BAR_HEIGHT := 2.3

var _court: CourtData
var _input: HumanInput
var _handling := BallHandling.new()
var _state: State = State.PLAYING
var _restart_timer: float = 0.0

@onready var _builder: CourtBuilder = $Court
@onready var _ball: Ball = $Ball
@onready var _player: Player = $Player
@onready var _camera: MatchCamera = $Camera
@onready var _hud: MatchHud = $UI/Hud
@onready var _touch: TouchControls = $UI/TouchControls


func _ready() -> void:
	_court = CourtData.load_court(MatchSetup.get_court_id())
	_builder.build(_court)
	_input = HumanInput.new(_touch)
	_hud.menu_pressed.connect(_on_menu_pressed)
	_hud.set_court_name(_court.name_key)
	_player.set_selected(true)
	_kick_off()
	_camera.snap_to(_ball.physics.position, _court)


func _physics_process(delta: float) -> void:
	var intent := _input.read()
	_player.move(delta, intent.move, intent.sprint, _handling.has_ball, _court)
	if _state == State.PLAYING:
		_handling.update(delta, _player, _ball.physics, intent)
	var event := _ball.simulate(delta, _court)
	_camera.follow(delta, _ball.physics.position, _ball.physics.velocity, _court)
	if _state == State.PLAYING:
		_check_goal_or_out(event)
	else:
		_restart_timer -= delta
		if _restart_timer <= 0.0:
			_kick_off()
	_update_power_bar()


func _check_goal_or_out(event: CourtBounds.Event) -> void:
	if GoalDetector.check(_ball.physics, _court) != 0:
		_stop_play("MSG_GOAL", float(Config.get_value("match", "goal_message_seconds", 2.0)))
	elif event == CourtBounds.Event.OUT:
		_stop_play("MSG_OUT", float(Config.get_value("match", "out_message_seconds", 1.5)))


func _stop_play(message_key: String, seconds: float) -> void:
	_state = State.STOPPED
	_restart_timer = seconds
	_handling.reset(_ball.physics)
	_hud.show_message(message_key)


func _kick_off() -> void:
	_state = State.PLAYING
	_hud.hide_message()
	_handling.reset(_ball.physics)
	_ball.physics.place(Vector3(0.0, _ball.physics.radius, 0.0))
	var offset := float(Config.get_value("match", "kickoff_player_offset", 3.0))
	_player.reset_to(Vector3(-offset, 0.0, 0.0), Vector3.RIGHT)


func _update_power_bar() -> void:
	var head := _player.global_position + Vector3(0.0, POWER_BAR_HEIGHT, 0.0)
	var shown := _handling.is_charging and not _camera.is_position_behind(head)
	_hud.update_power(_handling.shot_charge, shown, _camera.unproject_position(head))


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
