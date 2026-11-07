extends Control
## PlayerSetup - character setup / mode select entry screen.
## Presents protagonist identity and entry parameters, then hands control back
## to GameManager for level ingress.

signal setup_completed()
signal setup_cancelled()

const ROOFTOP_SCENE := "res://addons/snss_core/scenes/Rooftop.tscn"
const MODE_SCENE := "res://addons/snss_core/scenes/GameModeSelect.tscn"

const STORY_TEXT := "You are the night partner, dropped onto the industrial facility rooftop.\nYour hostage girlfriend is held by the ghost boss Bhoot-Teri-Maki.\nEnter the rooftop service elevator, select Floor 3, and begin the mission."

func _ready() -> void:
	_build_screen()

func _build_screen() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.07, 0.06, 0.08, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "CHARACTER SETUP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	vbox.add_child(title)

	var story := Label.new()
	story.text = STORY_TEXT
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.autowrap_mode = TextServer.AUTOWRAP_WORD
	story.add_theme_font_size_override("font_size", 20)
	vbox.add_child(story)

	_add_row(vbox, "CALLSIGN:", _make_line_edit("SIGMA-7", Vector2(300.0, 32.0)))

	var sens := SpinBox.new()
	sens.min_value = 0.1
	sens.max_value = 10.0
	sens.value = 1.0
	sens.custom_minimum_size = Vector2(160.0, 32.0)
	_add_row(vbox, "BASE LOOK SENSITIVITY (HARDWARE):", sens)

	var fov := SpinBox.new()
	fov.min_value = 60.0
	fov.max_value = 110.0
	fov.value = 90.0
	fov.custom_minimum_size = Vector2(160.0, 32.0)
	_add_row(vbox, "FOV:", fov)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 48)
	vbox.add_child(buttons)

	var ok := Button.new()
	ok.text = "BREACH ROOFTOP"
	ok.custom_minimum_size = Vector2(260.0, 44.0)
	ok.pressed.connect(_on_enter)
	buttons.add_child(ok)

	var cancel := Button.new()
	cancel.text = "BACK TO MODE SELECT"
	cancel.custom_minimum_size = Vector2(260.0, 44.0)
	cancel.pressed.connect(_on_cancel)
	buttons.add_child(cancel)

func _make_line_edit(text: String, min_size: Vector2) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.custom_minimum_size = min_size
	return e

func _add_row(parent: VBoxContainer, label_text: String, field: Control) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	var l := Label.new()
	l.text = label_text
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	row.add_child(field)
	parent.add_child(row)

func _on_enter() -> void:
	if GameManager:
		GameManager.transition(GameManager.State.ROOFTOP)
	setup_completed.emit()
	_goto(ROOFTOP_SCENE)

func _on_cancel() -> void:
	setup_cancelled.emit()
	_goto(MODE_SCENE)

func _goto(path: String) -> void:
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("PlayerSetup: failed to open %s (error %s)" % [path, err])