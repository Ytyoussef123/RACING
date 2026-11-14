extends MenuScreen
## Quick match, step 2: your formation, with your crew placed on a mini court.

var _preview: FormationPreview


func _ready() -> void:
	build_frame("TITLE_FORMATION")
	var row := UiBuild.hbox(40)
	row.size_flags_vertical = SIZE_EXPAND_FILL
	var list := UiBuild.vbox(16)
	var group := ButtonGroup.new()
	for formation_id in FormationData.all_ids():
		var id := str(formation_id)
		var chip := UiBuild.chip(id, group, 320.0)
		chip.name = "Formation_" + id
		chip.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		chip.button_pressed = id == MatchSetup.get_formation_id()
		chip.pressed.connect(_select.bind(id))
		list.add_child(chip)
	row.add_child(list)
	_preview = FormationPreview.new()
	row.add_child(_preview)
	content.add_child(row)
	add_footer_button("BTN_BACK", go_back)
	add_footer_button("BTN_NEXT", func() -> void: Screens.go("court_select"), true)
	_refresh()


func go_back() -> void:
	Screens.go("team_select")


func _select(formation_id: String) -> void:
	MatchSetup.formation_id = formation_id
	if MatchSetup.get_home_team_id() == SaveGame.MY_CREW_ID:
		SaveGame.formation_id = formation_id
		SaveGame.save()
	_refresh()


func _refresh() -> void:
	_preview.show_formation(Roster.team(MatchSetup.get_home_team_id()),
		FormationData.load_formation(MatchSetup.get_formation_id()))
