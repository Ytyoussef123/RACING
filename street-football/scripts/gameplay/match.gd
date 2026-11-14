extends Node3D
## 5v5 match: builds the court and the two teams, then runs the fixed-step loop:
## input -> switching -> AI intents -> movement -> collisions -> saves -> ball handling -> ball
## -> goal / out / clock. Score and clock are in MatchFlow, restarts in RestartPlacer.

signal goal_scored(team_index: int)
signal full_time(home_score: int, away_score: int)

const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
## Height above the player's feet where the shot power bar is drawn (visual only).
const POWER_BAR_HEIGHT := 2.6
## Height above the player's head where his name tag is drawn (visual only).
const TAG_HEIGHT_OFFSET := 0.25

var ctx := MatchContext.new()
var flow := MatchFlow.new()

var _input: HumanInput
var _human: HumanControl
var _frame: int = 0
var _goals: Array[Dictionary] = []
var _pause_menu: PauseMenu

@onready var _builder: CourtBuilder = $Court
@onready var _ball: Ball = $Ball
@onready var _players_root: Node3D = $Players
@onready var _camera: MatchCamera = $Camera
@onready var _hud: MatchHud = $UI/Hud
@onready var _touch: TouchControls = $UI/TouchControls


func _ready() -> void:
	if MatchSetup.test_mode and MatchSetup.test_seed != 0:
		ctx.rng.seed = MatchSetup.test_seed
	else:
		ctx.rng.randomize()
	ctx.court = CourtData.load_court(MatchSetup.get_court_id())
	ctx.ball = _ball.physics
	_builder.build(ctx.court)
	_build_teams()
	_input = HumanInput.new(_touch)
	if not MatchSetup.test_mode:
		_human = HumanControl.new(ctx.teams[0])
	_touch.visible = _human != null
	_hud.pause_pressed.connect(_open_pause)
	_pause_menu = PAUSE_MENU_SCENE.instantiate()
	add_child(_pause_menu)
	_pause_menu.resume_pressed.connect(_close_pause)
	_pause_menu.formation_pressed.connect(_on_formation_pressed)
	_pause_menu.quit_pressed.connect(func() -> void: Screens.go("main_menu"))
	_hud.formation_pressed.connect(_on_formation_pressed)
	_hud.set_court_name(ctx.court.name_key)
	_hud.set_team_colors(ctx.teams[0].color, ctx.teams[1].color)
	_hud.set_team_names(ctx.teams[0].short_name(), ctx.teams[1].short_name())
	_hud.set_formation_name(ctx.teams[0].formation.id)
	flow.start(MatchSetup.get_match_seconds())
	_kick_off(ctx.teams[ctx.rng.randi_range(0, 1)])
	_camera.snap_to(ctx.ball.position, ctx.court)


func _build_teams() -> void:
	var home_data: TeamData = Roster.team(MatchSetup.get_home_team_id())
	var away_data: TeamData = Roster.team(MatchSetup.get_away_team_id())
	var mates_tuning := AiTuning.for_difficulty(str(Config.get_value("ai", "teammates_difficulty", "normal")))
	var opp_tuning := AiTuning.for_difficulty(MatchSetup.get_difficulty())
	var home_speed := mates_tuning.speed_factor if MatchSetup.test_mode else 1.0
	var away_alt := TeamFactory.kits_clash(home_data.color("kit", Color.WHITE), away_data.color("kit", Color.BLACK))
	var home := TeamFactory.build(_players_root, PLAYER_SCENE, 0, home_data, MatchSetup.get_formation_id(),
		false, mates_tuning, home_speed)
	var away := TeamFactory.build(_players_root, PLAYER_SCENE, 1, away_data,
		str(Config.get_value("ai", "opponent_formation", "1-2-1")), away_alt, opp_tuning, opp_tuning.speed_factor)
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
		DribbleAssist.adjust(p, ctx)
		p.move(delta, ctx.court, ctx.possession.holder == p)
	PlayerCollisions.resolve(ctx.all_players, ctx.court)
	if playing:
		for team in ctx.teams:
			KeeperAI.try_save(team.keeper, ctx)
		_update_ball_handling(delta)
	var event := _ball.simulate(delta, ctx.court)
	if playing and ctx.possession.holder != null:
		ctx.stats.possession_time[ctx.possession.holder.team.index] += delta
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
		_record_goal(scorer)
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
			MatchSetup.last_result = _build_result()
			if not MatchSetup.test_mode:
				Screens.go("results")


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
		_hud.update_player_tag("", 0.0, false, Vector2.ZERO)
		return
	var head := human_player.global_position + Vector3(0.0, POWER_BAR_HEIGHT, 0.0)
	var on_screen := not _camera.is_position_behind(head)
	_hud.update_power(human_player.handling.shot_charge, on_screen and human_player.handling.is_charging,
		_camera.unproject_position(head))
	var tag_point := human_player.global_position + Vector3(0.0, human_player.height + TAG_HEIGHT_OFFSET, 0.0)
	_hud.update_player_tag(_tag_text(human_player), human_player.energy,
		on_screen and not _camera.is_position_behind(tag_point), _camera.unproject_position(tag_point))


## "7  T. Varmanetti  86": shirt number, name, overall in the current role.
func _tag_text(player: Player) -> String:
	if player.profile == null:
		return ""
	return "%d  %s  %d" % [player.number, player.display_name, Ratings.overall(player.profile, player.role)]


func _on_formation_pressed() -> void:
	var team := ctx.teams[0]
	team.set_formation(FormationData.load_formation(FormationData.next_id(team.formation.id)))
	MatchSetup.formation_id = team.formation.id
	_hud.set_formation_name(team.formation.id)
	_pause_menu.set_formation_name(team.formation.id)


func _open_pause() -> void:
	if flow.state == MatchFlow.State.FULL_TIME:
		return
	_touch.release_all()
	get_tree().paused = true
	_pause_menu.open(ctx.teams[0].formation.id)


func _close_pause() -> void:
	_pause_menu.close()
	get_tree().paused = false


## Android back button: pause, or resume when already paused.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if get_tree().paused:
			_close_pause()
		else:
			_open_pause()


## The scorer is the last player who kicked the ball: from the scoring team, or an own goal.
func _record_goal(scorer_team: Team) -> void:
	var kicker := ctx.possession.last_kicker
	var elapsed := MatchSetup.get_match_seconds() - flow.time_left
	var seconds := int(elapsed)
	_goals.append({
		"team": scorer_team.index,
		"scorer": kicker.display_name if kicker != null else "?",
		"own_goal": kicker != null and kicker.team != scorer_team,
		"time": "%d:%02d" % [seconds / 60, seconds % 60],
	})


func _build_result() -> Dictionary:
	var stats := ctx.stats
	return {
		"home_id": ctx.teams[0].data.id if ctx.teams[0].data != null else "",
		"away_id": ctx.teams[1].data.id if ctx.teams[1].data != null else "",
		"home_score": flow.scores[0],
		"away_score": flow.scores[1],
		"goals": _goals.duplicate(),
		"stats": {
			"shots": [stats.shots[0], stats.shots[1]],
			"saves": [stats.saves[0], stats.saves[1]],
			"passes_completed": [stats.passes_completed[0], stats.passes_completed[1]],
			"balls_won": [stats.balls_won[0], stats.balls_won[1]],
			"possession": [stats.possession_percent(0), stats.possession_percent(1)],
		},
	}
