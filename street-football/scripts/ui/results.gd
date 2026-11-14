extends MenuScreen
## After the final whistle: win / draw / loss, the score, the goals (time, scorer) and the match
## stats. REMATCH plays the same match again.

const STAT_ROWS := [
	["STAT_SHOTS", "shots"],
	["STAT_SAVES", "saves"],
	["STAT_PASSES", "passes_completed"],
	["STAT_BALLS_WON", "balls_won"],
	["STAT_POSSESSION", "possession"],
]


func _ready() -> void:
	build_frame("MSG_FULL_TIME")
	var r: Dictionary = MatchSetup.last_result
	var home: TeamData = Roster.team(str(r.get("home_id", MatchSetup.get_home_team_id())))
	var away: TeamData = Roster.team(str(r.get("away_id", MatchSetup.get_away_team_id())))
	var home_score := int(r.get("home_score", 0))
	var away_score := int(r.get("away_score", 0))
	content.add_child(_headline(home_score, away_score))
	content.add_child(_score_row(home, away, home_score, away_score))
	if r.has("coins_earned"):
		content.add_child(_plain(tr("REWARD_FMT") % [int(r["coins_earned"]), int(r.get("coins_total", 0))], "body"))
	var row := UiBuild.hbox(40)
	row.size_flags_vertical = SIZE_EXPAND_FILL
	row.add_child(_goals_card(r.get("goals", []), home, away))
	row.add_child(_stats_card(r.get("stats", {}), home, away))
	content.add_child(row)
	add_footer_button("BTN_MAIN_MENU", go_back)
	add_footer_button("BTN_REMATCH", func() -> void: Screens.go("match"), true)


func go_back() -> void:
	Screens.go("main_menu")


func _headline(home_score: int, away_score: int) -> Label:
	if home_score > away_score:
		return UiBuild.label("RESULT_WIN", "heading", "good")
	if home_score < away_score:
		return UiBuild.label("RESULT_LOSS", "heading", "bad")
	return UiBuild.label("RESULT_DRAW", "heading", "accent_2")


func _score_row(home: TeamData, away: TeamData, home_score: int, away_score: int) -> HBoxContainer:
	var row := UiBuild.hbox(24)
	row.add_child(UiBuild.color_chip(home.color("kit", Color.WHITE), Vector2(30, 90)))
	row.add_child(_plain(home.name, "heading"))
	row.add_child(_plain("%d – %d" % [home_score, away_score], "title"))
	row.add_child(_plain(away.name, "heading"))
	row.add_child(UiBuild.color_chip(away.color("kit", Color.WHITE), Vector2(30, 90)))
	return row


func _goals_card(goals: Array, home: TeamData, away: TeamData) -> PanelContainer:
	var card := UiBuild.card()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	var box := UiBuild.vbox(8)
	card.add_child(box)
	box.add_child(UiBuild.label("LABEL_GOALS", "body", "accent_3"))
	if goals.is_empty():
		box.add_child(UiBuild.label("NO_GOALS", "small", "text_dim"))
	for goal in goals:
		var g: Dictionary = goal
		var team_name := home.short_name if int(g.get("team", 0)) == 0 else away.short_name
		var scorer := str(g.get("scorer", "?"))
		if bool(g.get("own_goal", false)):
			scorer += " (%s)" % tr("LABEL_OWN_GOAL")
		box.add_child(_plain("%s   %s   %s" % [str(g.get("time", "")), team_name, scorer], "small"))
	return card


func _stats_card(stats: Dictionary, home: TeamData, away: TeamData) -> PanelContainer:
	var card := UiBuild.card()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 10)
	card.add_child(grid)
	grid.add_child(UiBuild.label("LABEL_STATS", "body", "accent_3"))
	grid.add_child(_plain(home.short_name, "body"))
	grid.add_child(_plain(away.short_name, "body"))
	for row in STAT_ROWS:
		var values: Array = stats.get(str(row[1]), [0, 0])
		var suffix := "%" if str(row[1]) == "possession" else ""
		grid.add_child(UiBuild.label(str(row[0]), "small", "text_dim"))
		grid.add_child(_plain("%d%s" % [int(values[0]), suffix], "small"))
		grid.add_child(_plain("%d%s" % [int(values[1]), suffix], "small"))
	return card


## A label with text that must not be translated (names, numbers).
func _plain(text: String, size_key: String) -> Label:
	var l := UiBuild.label(text, size_key)
	l.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	return l
