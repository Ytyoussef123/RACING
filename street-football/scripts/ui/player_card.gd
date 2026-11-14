class_name PlayerCard
extends Control
## Full-screen overlay with one player's card: identity, positions, playstyle, skills and all
## attributes as colored bars, grouped like eFootball. Tap CLOSE (or outside) to hide it.

const GROUPS := [
	["GROUP_ATTACK", ["finishing", "shot_power", "long_shots", "heading"]],
	["GROUP_CONTROL", ["dribbling", "ball_control", "tight_possession"]],
	["GROUP_PASSING", ["low_pass", "lofted_pass", "vision"]],
	["GROUP_PHYSICAL", ["speed", "acceleration", "stamina", "strength", "balance", "jump"]],
	["GROUP_DEFENSE", ["tackling", "interception", "marking", "aggression"]],
	["GROUP_GOALKEEPING", ["gk_reflexes", "gk_diving", "gk_handling", "gk_positioning", "gk_kicking"]],
]

var _panel: PanelContainer
var _body: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	_panel = UiBuild.card()
	_panel.grow_horizontal = GROW_DIRECTION_BOTH
	_panel.grow_vertical = GROW_DIRECTION_BOTH
	_panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1500.0, 860.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	_body = UiBuild.vbox(14)
	_body.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_body)
	visible = false


func show_player(profile: PlayerProfile, number: int) -> void:
	for child in _body.get_children():
		child.queue_free()
	var header := UiBuild.hbox(24)
	var name_label := UiBuild.label("%d  %s" % [number, profile.name], "heading", "accent_2")
	name_label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	header.add_child(name_label)
	header.add_child(UiBuild.spacer())
	header.add_child(UiBuild.label(str(Ratings.best_overall(profile)), "title", "accent"))
	var close := UiBuild.button("BTN_CLOSE", "", 240.0)
	close.pressed.connect(hide)
	header.add_child(close)
	_body.add_child(header)
	_body.add_child(_info_line(profile))
	var groups := GridContainer.new()
	groups.columns = 3
	groups.add_theme_constant_override("h_separation", 48)
	groups.add_theme_constant_override("v_separation", 18)
	for group in GROUPS:
		groups.add_child(_group(str(group[0]), group[1], profile))
	_body.add_child(groups)
	visible = true


func _info_line(profile: PlayerProfile) -> Label:
	var positions: Array[String] = []
	for pos in profile.positions:
		positions.append(UiBuild.position_name(str(pos)))
	var skills: Array[String] = []
	for skill in profile.special_skills:
		skills.append(tr("SKILL_" + str(skill).to_upper()))
	var foot := tr("CARD_FOOT_LEFT") if profile.preferred_foot == "left" else tr("CARD_FOOT_RIGHT")
	var text := "%s  ·  %s  ·  %s  ·  %s\n%s: %s  ·  %s: %s  ·  %s: %s  ·  %s: %s" % [
		profile.nationality, tr("CARD_AGE") % profile.age, tr("CARD_HEIGHT") % int(profile.height_cm), foot,
		tr("CARD_POSITIONS"), " / ".join(PackedStringArray(positions)),
		tr("CARD_PLAYSTYLE"), tr("PLAYSTYLE_" + profile.playstyle.to_upper()),
		tr("CARD_WEAK_FOOT"), "%d/4" % profile.weak_foot,
		tr("CARD_SKILL_MOVES"), "%d/5" % profile.skill_moves]
	if not skills.is_empty():
		text += "\n%s: %s" % [tr("CARD_SPECIAL_SKILLS"), ", ".join(PackedStringArray(skills))]
	var l := UiBuild.label(text, "small", "text")
	l.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _group(title_key: String, attributes: Array, profile: PlayerProfile) -> VBoxContainer:
	var box := UiBuild.vbox(6)
	box.add_child(UiBuild.label(title_key, "body", "accent_3"))
	for attr in attributes:
		var row := UiBuild.hbox(12)
		var name_label := UiBuild.label("ATTR_" + str(attr).to_upper(), "small", "text_dim")
		name_label.custom_minimum_size = Vector2(250.0, 0.0)
		row.add_child(name_label)
		var bar := StatBar.new()
		bar.value = profile.attr(str(attr))
		row.add_child(bar)
		var value_label := UiBuild.label(str(int(profile.attr(str(attr)))), "small")
		value_label.custom_minimum_size = Vector2(48.0, 0.0)
		row.add_child(value_label)
		box.add_child(row)
	return box


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		hide()
