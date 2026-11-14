extends Node
## Headless walk through the menus, run by CI:
##   godot --headless --path street-football res://tests/ui_flow_test.tscn
## Opens each screen, presses its buttons and checks where they lead (Screens.test_mode records the
## requested screen instead of changing scene) and that the choices are stored. Also checks that
## every translation key has an English and a French text.
## Prints "TEST PASS"/"TEST FAIL" lines, then "UI TESTS DONE: N failure(s)".

var _failures := 0


func _ready() -> void:
	Screens.test_mode = true
	MatchSetup.test_mode = false
	_test_translations_complete()
	_test_main_menu()
	_test_team_select()
	_test_formation_select()
	_test_court_select()
	_test_results()
	_test_squad_player_card()
	_test_settings()
	print("UI TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(test_name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("TEST PASS ", test_name)
	else:
		_failures += 1
		print("TEST FAIL ", test_name, " ", detail)


func _open(screen_id: String) -> Node:
	var screens: Dictionary = Config.get_value("ui", "screens", {})
	var scene: PackedScene = load(str(screens[screen_id]))
	var screen := scene.instantiate()
	add_child(screen)
	return screen


func _close(screen: Node) -> void:
	remove_child(screen)
	screen.free()


## Presses the button whose text (translation key) or node name matches.
func _press(root: Node, text_or_name: String) -> bool:
	var button := _find_button(root, text_or_name)
	if button == null:
		_check("button '%s' exists" % text_or_name, false)
		return false
	if button.toggle_mode:
		button.button_pressed = true
	button.pressed.emit()
	return true


func _find_button(node: Node, text_or_name: String) -> Button:
	if node is Button and ((node as Button).text == text_or_name or node.name == text_or_name):
		return node
	for child in node.get_children():
		var found := _find_button(child, text_or_name)
		if found != null:
			return found
	return null


func _test_translations_complete() -> void:
	var file := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	var header := file.get_csv_line()
	var missing: Array[String] = []
	var keys := {}
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < 2 or (line.size() == 1 and line[0].is_empty()):
			continue
		if line.size() < header.size():
			missing.append(line[0])
			continue
		for i in range(1, header.size()):
			if line[i].strip_edges().is_empty():
				missing.append("%s (%s)" % [line[0], header[i]])
		if keys.has(line[0]):
			missing.append("duplicate " + line[0])
		keys[line[0]] = true
	_check("translations: every key has English and French", missing.is_empty(), str(missing))
	var needed: Array[String] = ["MENU_QUICK_MATCH", "BTN_BACK", "TITLE_COURT", "RESULT_WIN", "ATTR_GK_KICKING",
		"POS_WING", "SETTING_CONTROLS_SIZE", "BTN_PRESS", "MSG_FULL_TIME", "STAT_POSSESSION"]
	var absent: Array[String] = []
	for key in needed:
		if not keys.has(key):
			absent.append(key)
	_check("translations: menu keys present", absent.is_empty(), str(absent))


func _test_main_menu() -> void:
	var menu := _open("main_menu")
	_press(menu, "MENU_QUICK_MATCH")
	_check("main menu: quick match opens the crew choice", Screens.last_requested == "team_select")
	_press(menu, "MENU_MY_CREW")
	_check("main menu: my crew", Screens.last_requested == "squad")
	_press(menu, "MENU_SETTINGS")
	_check("main menu: settings", Screens.last_requested == "settings")
	_close(menu)


func _test_team_select() -> void:
	MatchSetup.home_team_id = ""
	MatchSetup.away_team_id = ""
	var screen := _open("team_select")
	var away_before := MatchSetup.get_away_team_id()
	_press(screen, "AwayNext")
	_check("crews: > changes the opponent", MatchSetup.get_away_team_id() != away_before)
	var always_different := true
	for i in range(7):
		_press(screen, "HomeNext")
		always_different = always_different and MatchSetup.get_home_team_id() != MatchSetup.get_away_team_id()
		_press(screen, "AwayPrev")
		always_different = always_different and MatchSetup.get_home_team_id() != MatchSetup.get_away_team_id()
	_check("crews: your crew and the opponent are never the same", always_different)
	_press(screen, "BTN_NEXT")
	_check("crews: NEXT opens the formation", Screens.last_requested == "formation_select")
	_press(screen, "BTN_BACK")
	_check("crews: BACK returns to the main menu", Screens.last_requested == "main_menu")
	_close(screen)


func _test_formation_select() -> void:
	var screen := _open("formation_select")
	_press(screen, "Formation_2-2")
	_check("formation: choice stored", MatchSetup.get_formation_id() == "2-2", MatchSetup.get_formation_id())
	_press(screen, "BTN_NEXT")
	_check("formation: NEXT opens the court", Screens.last_requested == "court_select")
	_close(screen)


func _test_court_select() -> void:
	var screen := _open("court_select")
	_press(screen, "Court_open_lot")
	_check("court: choice stored", MatchSetup.get_court_id() == "open_lot")
	_press(screen, "Diff_hard")
	_check("court: difficulty stored", MatchSetup.get_difficulty() == "hard")
	_press(screen, "Minutes_5")
	_check("court: match length stored", is_equal_approx(MatchSetup.get_match_seconds(), 300.0),
		str(MatchSetup.get_match_seconds()))
	_press(screen, "BTN_PLAY")
	_check("court: PLAY starts the match", Screens.last_requested == "match")
	_close(screen)


func _test_results() -> void:
	MatchSetup.last_result = {
		"home_id": "concrete_kings", "away_id": "rooftop_rebels", "home_score": 3, "away_score": 2,
		"goals": [{"team": 0, "scorer": "T. Varmanetti", "own_goal": false, "time": "1:05"},
			{"team": 1, "scorer": "B. Lemoreau", "own_goal": false, "time": "2:40"}],
		"stats": {"shots": [9, 7], "saves": [3, 4], "passes_completed": [20, 15], "balls_won": [11, 9],
			"possession": [55, 45]},
	}
	var screen := _open("results")
	_check("results: shows the win", _has_label(screen, "RESULT_WIN"))
	_check("results: shows the score", _has_label(screen, "3 – 2"))
	_press(screen, "BTN_REMATCH")
	_check("results: REMATCH plays again", Screens.last_requested == "match")
	_press(screen, "BTN_MAIN_MENU")
	_check("results: MAIN MENU", Screens.last_requested == "main_menu")
	_close(screen)


func _test_squad_player_card() -> void:
	var screen := _open("squad")
	var card := _find_type(screen, "PlayerCard") as Control
	var row := _first_player_row(screen)
	_check("squad: player rows are listed", row != null)
	if row != null:
		row.pressed.emit()
	_check("squad: tapping a player opens his card", card != null and card.visible)
	_press(screen, "BTN_BACK")
	_check("squad: BACK", Screens.last_requested == "main_menu")
	_close(screen)


func _test_settings() -> void:
	var screen := _open("settings")
	_press(screen, "Lang_fr")
	_check("settings: French", TranslationServer.get_locale().begins_with("fr"))
	_press(screen, "Lang_en")
	_check("settings: English", TranslationServer.get_locale().begins_with("en"))
	_press(screen, "Fps_on")
	_check("settings: FPS on", Settings.show_fps)
	_press(screen, "Fps_off")
	_press(screen, "Sound_off")
	_check("settings: sound off", not Settings.sound_on)
	_press(screen, "Sound_on")
	_press(screen, "Music_off")
	_check("settings: music off", not Settings.music_on)
	_press(screen, "Music_on")
	_check("settings: sound and music back on", Settings.sound_on and Settings.music_on)
	_press(screen, "Size_large")
	_check("settings: large buttons", Settings.controls_size == "large" and Settings.controls_scale() > 1.0)
	_press(screen, "Size_normal")
	_close(screen)


func _has_label(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _has_label(child, text):
			return true
	return false


func _find_type(node: Node, script_class: String) -> Node:
	var script: Script = node.get_script()
	if script != null and script.get_global_name() == script_class:
		return node
	for child in node.get_children():
		var found := _find_type(child, script_class)
		if found != null:
			return found
	return null


func _first_player_row(node: Node) -> Button:
	if node is Button and (node as Button).theme_type_variation == "ChipButton" and node.get_parent() != null \
			and node.get_parent().get_parent() is TeamCard:
		return node
	for child in node.get_children():
		var found := _first_player_row(child)
		if found != null:
			return found
	return null
