extends Node
## TOSGatekeeper - blocking Terms of Service screen.
## Application is locked until the user explicitly accepts. Decline terminates
## the build.

signal tos_accepted()
signal tos_declined()

enum Phase { DISPLAY, ACCEPTED, DECLINED }

const TOS_SCENE := "res://addons/snss_core/scenes/GameModeSelect.tscn"

const TOS_WARNING_TEXT := "If you haven't read the TOS, please go and read. This TOS is not so good that you will not read and it is written by me after all so you have to read. Please go and read the TOS."

const TOS_CLAUSES := [
	"Restricted category / non-public build for private testing only.",
	"Strict prohibition on selling, redistributing, or commercial use under penalty of heavy fines.",
	"Absolute developer legal immunity for any issues, damages, or disputes arising from gameplay.",
	"Explicit notice to take the game lightly and not as a serious matter.",
]

var _phase: Phase = Phase.DISPLAY

func _ready() -> void:
	_phase = Phase.DISPLAY
	_build_screen()

func _build_screen() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.08, 0.08, 1.0)
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
	title.text = "TERMS OF SERVICE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	var warning_panel := PanelContainer.new()
	warning_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(warning_panel)

	var warning_label := Label.new()
	warning_label.text = TOS_WARNING_TEXT
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	warning_label.add_theme_font_size_override("font_size", 20)
	warning_panel.add_child(warning_label)

	for i in range(TOS_CLAUSES.size()):
		var clause := Label.new()
		clause.text = "%s. %s" % [i + 1, TOS_CLAUSES[i]]
		clause.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(clause)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 48)
	vbox.add_child(buttons)

	_make_button(buttons, "Accept & Enter")
	_make_button(buttons, "Decline")

func _make_button(parent: Node, text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(240.0, 48.0)
	btn.pressed.connect(_on_button_pressed.bind(text))
	parent.add_child(btn)
	return btn

func _on_button_pressed(text: String) -> void:
	if text == "Accept & Enter":
		_phase = Phase.ACCEPTED
		tos_accepted.emit()
		_goto(TOS_SCENE)
	else:
		_phase = Phase.DECLINED
		tos_declined.emit()
		get_tree().quit()

func _goto(path: String) -> void:
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("TOSGatekeeper: failed to open %s (error %s)" % [path, err])

func check_acceptance() -> bool:
	return _phase == Phase.ACCEPTED