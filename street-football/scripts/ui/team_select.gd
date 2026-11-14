extends MenuScreen
## Quick match, step 1: your crew and the opponent crew, each changed with < and >.
## Tap a player to see his card.

var _home_card: TeamCard
var _away_card: TeamCard
var _player_card: PlayerCard


func _ready() -> void:
	build_frame("TITLE_TEAM_SELECT")
	_player_card = PlayerCard.new()
	var row := UiBuild.hbox(40)
	row.size_flags_vertical = SIZE_EXPAND_FILL
	_home_card = TeamCard.new()
	_away_card = TeamCard.new()
	row.add_child(_side("LABEL_YOUR_CREW", "Home", _home_card))
	row.add_child(_side("LABEL_OPPONENT", "Away", _away_card))
	content.add_child(row)
	add_footer_button("BTN_BACK", go_back)
	add_footer_button("BTN_NEXT", func() -> void: Screens.go("formation_select"), true)
	add_child(_player_card)
	_refresh()


func go_back() -> void:
	Screens.go("main_menu")


func _side(title_key: String, prefix: String, card: TeamCard) -> VBoxContainer:
	var box := UiBuild.vbox(12)
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	var top := UiBuild.hbox(16)
	var prev := UiBuild.button("<", "", 120.0)
	prev.name = prefix + "Prev"
	prev.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	prev.pressed.connect(_cycle.bind(prefix == "Home", -1))
	var next := UiBuild.button(">", "", 120.0)
	next.name = prefix + "Next"
	next.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	next.pressed.connect(_cycle.bind(prefix == "Home", 1))
	var title := UiBuild.label(title_key, "body", "accent_3", HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(prev)
	top.add_child(title)
	top.add_child(next)
	box.add_child(top)
	card.size_flags_vertical = SIZE_EXPAND_FILL
	card.player_pressed.connect(_player_card.show_player)
	box.add_child(card)
	return box


func _cycle(home: bool, step: int) -> void:
	if home:
		MatchSetup.home_team_id = MatchSetup.cycle_team(MatchSetup.get_home_team_id(), step, "")
		if MatchSetup.get_away_team_id() == MatchSetup.home_team_id:
			MatchSetup.away_team_id = MatchSetup.cycle_team(MatchSetup.home_team_id, 1, "")
	else:
		MatchSetup.away_team_id = MatchSetup.cycle_team(MatchSetup.get_away_team_id(), step, MatchSetup.get_home_team_id())
	_refresh()


func _refresh() -> void:
	_home_card.show_team(Roster.team(MatchSetup.get_home_team_id()))
	_away_card.show_team(Roster.team(MatchSetup.get_away_team_id()))
