class_name PauseMenu
extends CanvasLayer
## In-match pause: RESUME, FORMATION (changes your formation) and QUIT MATCH.
## Works while the game is paused (process mode Always in the scene).

signal resume_pressed
signal formation_pressed
signal quit_pressed

var _formation_button: Button


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var card := UiBuild.card()
	center.add_child(card)
	var box := UiBuild.vbox(20)
	card.add_child(box)
	box.add_child(UiBuild.label("TITLE_PAUSE", "heading", "accent_2", HORIZONTAL_ALIGNMENT_CENTER))
	var resume := UiBuild.button("BTN_RESUME", "AccentButton", 620.0)
	resume.pressed.connect(func() -> void: resume_pressed.emit())
	box.add_child(resume)
	_formation_button = UiBuild.button("", "", 620.0)
	_formation_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_formation_button.pressed.connect(func() -> void: formation_pressed.emit())
	box.add_child(_formation_button)
	var quit := UiBuild.button("BTN_QUIT_MATCH", "", 620.0)
	quit.pressed.connect(func() -> void: quit_pressed.emit())
	box.add_child(quit)
	visible = false


func open(formation_id: String) -> void:
	set_formation_name(formation_id)
	visible = true


func close() -> void:
	visible = false


func set_formation_name(formation_id: String) -> void:
	_formation_button.text = "%s: %s" % [tr("TITLE_FORMATION"), formation_id]
