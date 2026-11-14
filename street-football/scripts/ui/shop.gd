extends MenuScreen
## Shop: sign free agents and unlock courts with coins. Signed players join My Crew's bench.

var _player_card: PlayerCard
var _coins: Label
var _players_box: VBoxContainer
var _courts_box: VBoxContainer


func _ready() -> void:
	build_frame("MENU_SHOP")
	_player_card = PlayerCard.new()
	_coins = UiBuild.label("", "body", "accent_2")
	_coins.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	content.add_child(_coins)
	var columns := UiBuild.hbox(40)
	columns.size_flags_vertical = SIZE_EXPAND_FILL
	_players_box = _section(columns, "SHOP_PLAYERS", 1.6)
	_courts_box = _section(columns, "SHOP_COURTS", 1.0)
	content.add_child(columns)
	add_footer_button("BTN_BACK", go_back)
	add_child(_player_card)
	_refresh()


func go_back() -> void:
	Screens.go("main_menu")


func _section(parent: Container, title_key: String, stretch: float) -> VBoxContainer:
	var card := UiBuild.card()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = stretch
	var box := UiBuild.vbox(8)
	card.add_child(box)
	box.add_child(UiBuild.label(title_key, "body", "accent_3"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var rows := UiBuild.vbox(8)
	rows.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(rows)
	box.add_child(scroll)
	parent.add_child(card)
	return rows


func _refresh() -> void:
	_coins.text = tr("COINS_FMT") % SaveGame.coins
	for box in [_players_box, _courts_box]:
		for child in (box as Node).get_children():
			box.remove_child(child)
			child.queue_free()
	var any_player := false
	for player_id in Roster.free_agent_ids():
		if SaveGame.owned.has(player_id):
			continue
		any_player = true
		_players_box.add_child(_player_row(player_id))
	if not any_player:
		_players_box.add_child(UiBuild.label("SHOP_EMPTY", "small", "text_dim"))
	var any_court := false
	for court_id in Config.get_value("match", "courts", []):
		var id := str(court_id)
		if SaveGame.court_unlocked(id):
			continue
		any_court = true
		_courts_box.add_child(_court_row(id))
	if not any_court:
		_courts_box.add_child(UiBuild.label("SHOP_EMPTY", "small", "text_dim"))


func _player_row(player_id: String) -> HBoxContainer:
	var profile: PlayerProfile = Roster.player(player_id)
	var row := UiBuild.hbox(10)
	var text := UiBuild.label("%s   %s   %d   %s" % [profile.short_name, UiBuild.position_name(str(profile.positions[0])),
		Ratings.best_overall(profile), tr("PLAYSTYLE_" + profile.playstyle.to_upper())], "small")
	text.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(text)
	var info := UiBuild.button("BTN_INFO", "", 150.0)
	info.add_theme_font_size_override("font_size", UiTheme.font_size("small"))
	info.pressed.connect(func() -> void: _player_card.show_player(profile, 0))
	row.add_child(info)
	var price := SaveGame.player_price(profile)
	var buy := UiBuild.button("", "AccentButton", 280.0)
	buy.name = "Buy_" + player_id
	buy.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	buy.add_theme_font_size_override("font_size", UiTheme.font_size("small"))
	buy.text = tr("BTN_BUY") % price
	buy.disabled = SaveGame.coins < price
	buy.pressed.connect(func() -> void:
		SaveGame.buy_player(player_id)
		_refresh())
	row.add_child(buy)
	return row


func _court_row(court_id: String) -> HBoxContainer:
	var court := CourtData.load_court(court_id)
	var row := UiBuild.hbox(10)
	var text := UiBuild.label(court.name_key, "small")
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(text)
	var price := SaveGame.court_price(court_id)
	var buy := UiBuild.button("", "AccentButton", 280.0)
	buy.name = "Unlock_" + court_id
	buy.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	buy.add_theme_font_size_override("font_size", UiTheme.font_size("small"))
	buy.text = tr("BTN_BUY") % price
	buy.disabled = SaveGame.coins < price
	buy.pressed.connect(func() -> void:
		SaveGame.unlock_court(court_id)
		_refresh())
	row.add_child(buy)
	return row
