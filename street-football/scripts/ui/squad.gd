extends MenuScreen
## My Crew: your signed players, starters and bench. Tap two players to swap them; INFO opens the
## player card; the level button upgrades a player with coins (+attributes for every level).

var _player_card: PlayerCard
var _info: Label
var _warning: Label
var _starters_box: VBoxContainer
var _bench_box: VBoxContainer
var _selected: String = ""


func _ready() -> void:
	build_frame("MENU_MY_CREW")
	_player_card = PlayerCard.new()
	_info = UiBuild.label("", "body", "accent_2")
	_info.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	content.add_child(_info)
	var columns := UiBuild.hbox(40)
	columns.size_flags_vertical = SIZE_EXPAND_FILL
	_starters_box = _column(columns, "LABEL_STARTERS")
	_bench_box = _column(columns, "LABEL_BENCH")
	content.add_child(columns)
	_warning = UiBuild.label("SQUAD_NO_KEEPER", "small", "bad")
	content.add_child(_warning)
	content.add_child(UiBuild.label("SQUAD_SWAP_HINT", "small", "text_dim"))
	add_footer_button("BTN_BACK", go_back)
	add_child(_player_card)
	_refresh()


func go_back() -> void:
	Screens.go("main_menu")


func _column(parent: Container, title_key: String) -> VBoxContainer:
	var card := UiBuild.card()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
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
	var r := SaveGame.record
	_info.text = "%s     %s" % [tr("COINS_FMT") % SaveGame.coins, tr("RECORD_FMT") % [int(r.get("played", 0)),
		int(r.get("wins", 0)), int(r.get("draws", 0)), int(r.get("losses", 0))]]
	_warning.visible = not SaveGame.has_keeper_starting()
	_fill(_starters_box, SaveGame.starters)
	_fill(_bench_box, SaveGame.bench())


func _fill(box: VBoxContainer, ids: Array[String]) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	for player_id in ids:
		box.add_child(_row(player_id))


func _row(player_id: String) -> HBoxContainer:
	var profile: PlayerProfile = Roster.player(player_id)
	var row := UiBuild.hbox(10)
	var main := UiBuild.button("", "ChipButton", 0.0)
	main.name = "Player_" + player_id
	main.toggle_mode = true
	main.button_pressed = player_id == _selected
	main.size_flags_horizontal = SIZE_EXPAND_FILL
	main.alignment = HORIZONTAL_ALIGNMENT_LEFT
	main.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	main.add_theme_font_size_override("font_size", UiTheme.font_size("small"))
	main.text = "%s   %s   %d   %s" % [profile.short_name, UiBuild.position_name(str(profile.positions[0])),
		Ratings.best_overall(profile), tr("LABEL_LEVEL") % SaveGame.level_of(player_id)]
	main.pressed.connect(_on_player_pressed.bind(player_id))
	row.add_child(main)
	var info := UiBuild.button("BTN_INFO", "", 150.0)
	info.add_theme_font_size_override("font_size", UiTheme.font_size("small"))
	info.pressed.connect(func() -> void: _player_card.show_player(profile, 0))
	row.add_child(info)
	var cost := SaveGame.upgrade_cost(player_id)
	var upgrade := UiBuild.button("", "AccentButton", 300.0)
	upgrade.name = "Upgrade_" + player_id
	upgrade.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	upgrade.add_theme_font_size_override("font_size", UiTheme.font_size("small"))
	if cost < 0:
		upgrade.text = tr("LABEL_MAX_LEVEL")
		upgrade.disabled = true
	else:
		upgrade.text = tr("BTN_UPGRADE") % [SaveGame.level_of(player_id) + 1, cost]
		upgrade.disabled = SaveGame.coins < cost
	upgrade.pressed.connect(func() -> void:
		SaveGame.upgrade(player_id)
		_refresh())
	row.add_child(upgrade)
	return row


## First tap selects a player, a second tap on another player swaps them.
func _on_player_pressed(player_id: String) -> void:
	if _selected.is_empty():
		_selected = player_id
	elif _selected == player_id:
		_selected = ""
	else:
		SaveGame.swap(_selected, player_id)
		_selected = ""
	_refresh()
