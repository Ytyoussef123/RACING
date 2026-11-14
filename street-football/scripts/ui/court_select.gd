extends MenuScreen
## Quick match, step 3: the court (walls or not), the difficulty and the match length, then PLAY.

const DIFFICULTY_KEYS := {"easy": "DIFF_EASY", "normal": "DIFF_NORMAL", "hard": "DIFF_HARD"}


func _ready() -> void:
	build_frame("TITLE_COURT")
	var courts := GridContainer.new()
	courts.columns = 2
	courts.add_theme_constant_override("h_separation", 24)
	courts.add_theme_constant_override("v_separation", 16)
	var court_group := ButtonGroup.new()
	for court_id in Config.get_value("match", "courts", ["cage_concrete"]):
		courts.add_child(_court_chip(str(court_id), court_group))
	content.add_child(courts)
	var diff_row := _option_row("LABEL_DIFFICULTY")
	var diff_group := ButtonGroup.new()
	for diff in Config.get_value("match", "difficulties", ["easy", "normal", "hard"]):
		var id := str(diff)
		var chip := UiBuild.chip(str(DIFFICULTY_KEYS.get(id, id)), diff_group, 260.0)
		chip.name = "Diff_" + id
		chip.button_pressed = id == MatchSetup.get_difficulty()
		chip.pressed.connect(func() -> void: MatchSetup.difficulty = id)
		diff_row.add_child(chip)
	var length_row := _option_row("LABEL_MATCH_LENGTH")
	var length_group := ButtonGroup.new()
	for minutes in Config.get_value("ui", "match_minutes", [3, 4, 5]):
		var m := int(minutes)
		var chip := UiBuild.chip(tr("MINUTES_FMT") % m, length_group, 200.0)
		chip.name = "Minutes_%d" % m
		chip.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		chip.button_pressed = m == MatchSetup.get_match_minutes()
		chip.pressed.connect(func() -> void: MatchSetup.match_minutes = m)
		length_row.add_child(chip)
	add_footer_button("BTN_BACK", go_back)
	add_footer_button("BTN_PLAY", func() -> void: Screens.go("match"), true)


func go_back() -> void:
	Screens.go("formation_select")


func _court_chip(court_id: String, group: ButtonGroup) -> Button:
	var court := CourtData.load_court(court_id)
	var rule := tr("COURT_WALLS_ON") if court.walls else tr("COURT_WALLS_OFF")
	if court.ball_friction_mult > 1.2:
		rule = "%s · %s" % [rule, tr("COURT_SAND")]
	var size_text := tr("COURT_SIZE_FMT") % [int(court.length), int(court.width)]
	var unlocked := SaveGame.court_unlocked(court_id)
	if not unlocked:
		size_text = tr("LOCKED_FMT") % SaveGame.court_price(court_id)
	var text := "%s\n%s\n%s" % [tr(court.name_key), rule, size_text]
	var chip := UiBuild.chip(text, group, 860.0)
	chip.name = "Court_" + court_id
	chip.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	chip.custom_minimum_size.y = 180.0
	chip.disabled = not unlocked
	if not unlocked and MatchSetup.get_court_id() == court_id:
		MatchSetup.court_id = ""
	chip.button_pressed = unlocked and court_id == MatchSetup.get_court_id()
	chip.pressed.connect(func() -> void: MatchSetup.court_id = court_id)
	return chip


func _option_row(title_key: String) -> HBoxContainer:
	var row := UiBuild.hbox(20)
	var title := UiBuild.label(title_key, "body", "accent_3")
	title.custom_minimum_size = Vector2(420.0, 0.0)
	row.add_child(title)
	content.add_child(row)
	return row
