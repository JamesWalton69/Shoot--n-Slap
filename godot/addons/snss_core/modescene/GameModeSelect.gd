extends Control
## GameModeSelect - single-player mode selection (Option A Normal, Option B Dark 70).

signal mode_selected(mode: EnvironmentController.Mode)

const SETUP_SCENE := "res://addons/snss_core/scenes/PlayerSetup.tscn"
const TOS_SCENE := "res://addons/snss_core/scenes/TOS.tscn"

func _ready() -> void:
	_setup()

func _setup() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.06, 0.1, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "SHOOT-'N-SLAP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "SINGLE-PLAYER ACTION-HORROR FPS"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	vbox.add_child(subtitle)

	var heading := Label.new()
	heading.text = "SELECT GAME MODE"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	vbox.add_child(heading)

	var a := _build_mode_card(
		"NORMAL MODE",
		"Standard ambient lighting and post-processing exposure.\nActive background combat/ambient music bus.\nStandard (1.0x) audio levels."
	)
	a.pressed.connect(_on_mode_selected.bind(EnvironmentController.Mode.NORMAL))
	vbox.add_child(a)

	var b := _build_mode_card(
		"DARK 70% MODE",
		"Ambient exposure clamped for 70% darkness; scene lights dimmed.\nPlayer flashlights disabled.\nAmbient/music bus muted; SFX master at 1.5x (+3.5 dB).\nAI hearing radius remains standard."
	)
	b.pressed.connect(_on_mode_selected.bind(EnvironmentController.Mode.DARK_70))
	vbox.add_child(b)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(160.0, 40.0)
	cancel.pressed.connect(_on_cancel)
	vbox.add_child(cancel)

func _build_mode_card(title: String, desc: String) -> Button:
	var b := Button.new()
	b.text = title + "\n\n" + desc
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD
	b.custom_minimum_size = Vector2(0.0, 160.0)
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return b

func _on_mode_selected(mode: EnvironmentController.Mode) -> void:
	EnvironmentController.set_mode(mode)
	var audio_mode := AudioEnvironmentManager.AudioMode.DARK_70 \
		if mode == EnvironmentController.Mode.DARK_70 \
		else AudioEnvironmentManager.AudioMode.NORMAL
	AudioEnvironmentManager.set_mode(audio_mode)
	mode_selected.emit(mode)
	_goto(SETUP_SCENE)

func _on_cancel() -> void:
	_goto(TOS_SCENE)

func _goto(path: String) -> void:
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("GameModeSelect: failed to open %s (error %s)" % [path, err])