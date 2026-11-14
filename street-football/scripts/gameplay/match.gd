extends Node3D
## 5v5 match: builds the court and the two teams, then runs the fixed-step loop:
## input -> switching -> AI intents -> movement -> collisions -> saves -> ball handling -> ball
## -> goal / out / clock. Score and clock are in MatchFlow, restarts in RestartPlacer.

signal goal_scored(team_index: int)
signal full_time(home_score: int, away_score: int)

const MENU_SCENE := "res://scenes/boot/boot_screen.tscn"
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
## Height above the player's feet where the shot power bar is drawn (visual only).
const POWER_BAR_HEIGHT := 2.3

var ctx := MatchContext.new()
var flow := MatchFlow.new()

var _input: HumanInput
var _human: HumanControl
var _frame: int = 0

@onready var _builder: CourtBuilder = $Court
@onready var _ball: Ball = $Ball
@onready var _players_root: Node3D = $Players
@onready var _camera: MatchCamera = $Camera
@onready var _hud: MatchHud = $UI/Hud
@onready var _touch: TouchControls = $UI/TouchControls


func _ready() -> void:
	ctx.rng.randomize()
	ctx.court = CourtData.load_court(MatchSetup.get_court_id())
	ctx.ball = _ball.physics
	_builder.build(ctx.court)
	_build_teams()
	_input = HumanInput.new(_touch)
	if not MatchSetup.test_mode:
		_human = HumanControl.new(ctx.teams[0])
	_touch.visible = _human != null
	_hud.menu_pressed.connect(_on_menu_pressed)
	_hud.formation_pressed.connect(_on_formation_pressed)
	_hud.set_court_name(ctx.court.name_key)
	_hud.set_team_colors(ctx.teams[0].color, ctx.teams[1].color)
	_hud.set_formation_name(ctx.teams[0].formation.id)
	flow.start(MatchSetup.get_match_seconds())
	_kick_off(ctx.teams[ctx.rng.randi_range(0, 1)])
	_camera.snap_to(ctx.ball.position, ctx.court)


func _build_teams() -> void:
	var home_kit := Color.html(str(Config.get_value("match", "home_color", "#ff5c1a")))
	var away_kit := Color.html(str(Config.get_value("match", "away_color", "#20c4d8")))
	var home_gk := Color.html(str(Config.get_value("match", "home_keeper_color", "#ffd61a")))
	var away_gk := Color.html(str(Config.get_value("match", "away_keeper_color", "#7a5cff")))
	var mates_tuning := AiTuning.for_difficulty(str(Config.get_value("ai", "teammates_difficulty", "normal")))
	var opp_tuning := AiTuning.for_difficulty(MatchSetup.get_difficulty())
	var home_speed := mates_tuning.speed_factor if MatchSetup.test_mode else 1.0
	var home := TeamFactory.build(_players_root, PLAYER_SCENE, 0, MatchSetup.get_formation_id(),
		home_kit, home_gk, mates_tuning, home_speed)
	var away := TeamFactory.build(_players_root, PLAYER_SCENE, 1,
		str(Config.get_value("ai", "opponent_formation", "1-2-1")), away_kit, away_gk, opp_tuning, opp_tuning.speed_factor)
	home.opponent = away
	away.opponent = home
	ctx.add_team(home)
	ctx.add_team(away)


func _physics_process(delta: float) -> void:
	_frame += 1
	var human_player: Player = _human.controlled if _human != null else null
	if _human != null:
		var attacking := _human.is_attacking(ctx)
		var intent := _input.read(attacking)
		_human.update(delta, intent, ctx)
		human_player = _human.controlled
		human_player.intent = _assist_human(human_player, intent, attacking, delta)
		_touch.set_defense_layout(not attacking)
	for team in ctx.teams:
		team.brain.update(delta, ctx, human_player)
	var playing := flow.state == MatchFlow.State.PLAYING
	for p in ctx.all_players:
		p.move(delta, ctx.court, ctx.possession.holder == p)
	PlayerCollisions.resolve(ctx.all_players, ctx.court)
	if playing:
		for team in ctx.teams:
			KeeperAI.try_save(team.keeper, ctx)
		_update_ball_handling(delta)
	var event := _ball.simulate(delta, ctx.court)
	if playing:
		_check_play(event, delta)
	else:
		_run_pending(flow.tick_stop(delta))
	_camera.follow(delta, ctx.ball.position, ctx.ball.velocity, ctx.court)
	_update_hud(human_player)


## Assists for the human's player: receive assist while a pass comes to him; PRESS and
## MATCH-UP when his side does not have the ball.
func _assist_human(player: Player, intent: PlayerIntent, attacking: bool, delta: float) -> PlayerIntent:
	if attacking:
		if _human.is_receiving(ctx):
			return ReceiveAssist.apply(player, intent, ctx)
		return intent
	if intent.press_held:
		return PressAssist.apply(player, intent, delta, ctx)
	if intent.match_up_held:
		return MatchUpAssist.apply(player, intent, ctx)
	return intent


## Fair order: the player who acts first changes every frame.
func _update_ball_handling(delta: float) -> void:
	var count := ctx.all_players.size()
	for i in range(count):
		var p := ctx.all_players[(i + _frame) % count]
		p.handling.update(delta, p, ctx)


func _check_play(event: CourtBounds.Event, delta: float) -> void:
	var goal_side := GoalDetector.check(ctx.ball, ctx.court)
	if goal_side != 0:
		var scorer: Team = ctx.teams[0] if ctx.teams[0].attack_sign == float(goal_side) else ctx.teams[1]
		flow.scores[scorer.index] += 1
		goal_scored.emit(scorer.index)
		ctx.possession.release(ctx.ball)
		_hud.show_message(tr("MSG_GOAL"))
		flow.stop(float(Config.get_value("match", "goal_message_seconds", 2.0)),
			{"type": "kickoff", "team": scorer.opponent})
		return
	if event == CourtBounds.Event.OUT:
		var plan := RestartPlacer.plan_out(ctx)
		ctx.possession.release(ctx.ball)
		_hud.show_message(tr(str(plan["key"])))
		flow.stop(float(Config.get_value("match", "restart_message_seconds", 1.5)),
			{"type": "restart", "plan": plan})
		return
	if flow.tick_clock(delta):
		ctx.possession.release(ctx.ball)
		_hud.show_message("%s  %d – %d" % [tr("MSG_FULL_TIME"), flow.scores[0], flow.scores[1]])
		flow.finish(float(Config.get_value("match", "full_time_message_seconds", 4.0)))
		full_time.emit(flow.scores[0], flow.scores[1])


func _run_pending(action: Dictionary) -> void:
	if action.is_empty():
		return
	match str(action.get("type", "")):
		"kickoff":
			_kick_off(action["team"])
		"restart":
			_hud.hide_message()
			RestartPlacer.apply_restart(ctx, action["plan"])
		"end":
			if not MatchSetup.test_mode:
				get_tree().change_scene_to_file(MENU_SCENE)


func _kick_off(kicking: Team) -> void:
	_hud.hide_message()
	RestartPlacer.kickoff(ctx, kicking)
	if _human != null:
		_human.select(RestartPlacer.most_attacking(ctx.teams[0]))


func _update_hud(human_player: Player) -> void:
	_hud.set_score(flow.scores[0], flow.scores[1])
	_hud.set_clock(flow.clock_text())
	if human_player == null:
		_hud.update_power(0.0, false, Vector2.ZERO)
		return
	var head := human_player.global_position + Vector3(0.0, POWER_BAR_HEIGHT, 0.0)
	var shown := human_player.handling.is_charging and not _camera.is_position_behind(head)
	_hud.update_power(human_player.handling.shot_charge, shown, _camera.unproject_position(head))


func _on_formation_pressed() -> void:
	var team := ctx.teams[0]
	team.set_formation(FormationData.load_formation(FormationData.next_id(team.formation.id)))
	_hud.set_formation_name(team.formation.id)


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
