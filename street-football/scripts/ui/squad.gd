extends MenuScreen
## My crew: the players of the crew you play with (chosen in Quick match). Tap one to see his card.

var _player_card: PlayerCard


func _ready() -> void:
	build_frame("MENU_MY_CREW")
	_player_card = PlayerCard.new()
	var card := TeamCard.new()
	card.size_flags_horizontal = SIZE_SHRINK_BEGIN
	card.custom_minimum_size = Vector2(1100.0, 0.0)
	card.show_team(Roster.team(MatchSetup.get_home_team_id()))
	card.player_pressed.connect(_player_card.show_player)
	content.add_child(card)
	content.add_child(UiBuild.label("SQUAD_HINT", "small", "text_dim"))
	add_footer_button("BTN_BACK", go_back)
	add_child(_player_card)


func go_back() -> void:
	Screens.go("main_menu")
