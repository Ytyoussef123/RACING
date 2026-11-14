class_name TeamCard
extends PanelContainer
## A crew card: name, kit colors, team rating and the 5 players (number, name, position, overall).
## Tapping a player emits player_pressed (the screen can open his card).

signal player_pressed(profile: PlayerProfile, number: int)

var _box: VBoxContainer


func _init() -> void:
	theme_type_variation = "CardPanel"
	_box = UiBuild.vbox(10)
	add_child(_box)


func show_team(team: TeamData) -> void:
	for child in _box.get_children():
		child.queue_free()
	var header := UiBuild.hbox(14)
	header.add_child(UiBuild.color_chip(team.color("kit", Color.WHITE), Vector2(28, 56)))
	header.add_child(UiBuild.color_chip(team.color("keeper", Color.GRAY), Vector2(14, 56)))
	var name_label := UiBuild.label(team.name, "heading")
	name_label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	header.add_child(name_label)
	_box.add_child(header)
	_box.add_child(UiBuild.label(tr("LABEL_TEAM_RATING") % team_rating(team), "small", "text_dim"))
	for entry in team.players:
		var profile: PlayerProfile = Roster.player(str(entry.get("id", "")))
		if profile == null:
			continue
		_box.add_child(_player_row(profile, int(entry.get("number", 0))))


## Average of the players' best overall ratings.
static func team_rating(team: TeamData) -> int:
	var total := 0
	var count := 0
	for entry in team.players:
		var profile: PlayerProfile = Roster.player(str(entry.get("id", "")))
		if profile != null:
			total += Ratings.best_overall(profile)
			count += 1
	return roundi(float(total) / float(maxi(1, count)))


func _player_row(profile: PlayerProfile, number: int) -> Button:
	var row := Button.new()
	row.theme_type_variation = "ChipButton"
	row.custom_minimum_size = Vector2(0.0, 72.0)
	row.focus_mode = FOCUS_NONE
	row.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.text = "%2d   %s   %s   %d" % [number, profile.short_name, UiBuild.position_name(str(profile.positions[0])),
		Ratings.best_overall(profile)]
	row.add_theme_font_size_override("font_size", UiTheme.font_size("small"))
	row.pressed.connect(func() -> void: player_pressed.emit(profile, number))
	return row
