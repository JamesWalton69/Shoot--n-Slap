extends Area3D
## RooftopElevator - handles elevator entrance, floor selection, and descent into Floor 3.
## Buttons available: 3, 2, 1, 0.
## Pressing 3 triggers descent to Floor 3 (Part 1 Corridor).

const SoundSynthesizer = preload("res://addons/snss_core/audio/SoundSynthesizer.gd")

signal floor_selected(floor_number: int)
signal descent_initiated()

@export var target_corridor_scene: String = "res://addons/snss_core/scenes/Part1Corridor.tscn"
@export var target_door: NodePath = NodePath("../PenthouseSlidingDoor")

var _player_inside: bool = false
var _descent_in_progress: bool = false
var _button_label: Label
var _interaction_prompt: Label
var _active_floor: int = -1
var _audio_player: AudioStreamPlayer

var _flicker_light: OmniLight3D
var _flicker_timer: float = 0.0
const BASE_FLICKER_ENERGY: float = 0.8

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_ui_prompts()
	_flicker_light = get_node_or_null("FlickerLight") as OmniLight3D
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "ElevatorAudio"
	_audio_player.bus = "SFX"
	add_child(_audio_player)
	set_process(true)

func _process(delta: float) -> void:
	if _flicker_light:
		_flicker_timer += delta
		if _flicker_timer > 0.05:
			_flicker_timer = 0.0
			if randf() < 0.06:
				_flicker_light.light_energy = BASE_FLICKER_ENERGY * randf_range(0.2, 0.5)
			else:
				_flicker_light.light_energy = BASE_FLICKER_ENERGY * randf_range(0.92, 1.05)

func _build_ui_prompts() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ElevatorPanelUI"
	add_child(canvas)

	var center_box := CenterContainer.new()
	center_box.set_anchors_preset(Control.PRESET_CENTER)
	center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(center_box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	center_box.add_child(vbox)

	_interaction_prompt = Label.new()
	_interaction_prompt.text = ""
	_interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_prompt.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_interaction_prompt)

	_button_label = Label.new()
	_button_label.text = ""
	_button_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_button_label)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_player_inside = true
		_update_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_player_inside = false
		_clear_prompt()

func _update_prompt() -> void:
	if _descent_in_progress:
		return
	if _interaction_prompt:
		_interaction_prompt.text = "=== FREIGHT ELEVATOR A-4 // ROOFTOP DOCK ==="
	if _button_label:
		_button_label.text = "[Press 3] - FLOOR 3: UTILITY & STORAGE [AUTHORIZED]\n[Press 2] - FLOOR 2: EXECUTIVE WING [RESTRICTED]\n[Press 1] - FLOOR 1: FACILITY RECEPTION [RESTRICTED]\n[Press 0] - GROUND FLOOR: MAIN EXIT [RESTRICTED]"

func _clear_prompt() -> void:
	if _interaction_prompt:
		_interaction_prompt.text = ""
	if _button_label:
		_button_label.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or _descent_in_progress:
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_3, KEY_KP_3:
				press_floor_button(3)
			KEY_2, KEY_KP_2:
				press_floor_button(2)
			KEY_1, KEY_KP_1:
				press_floor_button(1)
			KEY_0, KEY_KP_0:
				press_floor_button(0)

func press_floor_button(floor_num: int) -> void:
	if _descent_in_progress:
		return

	_active_floor = floor_num
	floor_selected.emit(floor_num)

	if floor_num == 3:
		_descent_in_progress = true
		_start_descent_sequence()
	else:
		_show_restricted_feedback(floor_num)

func _show_restricted_feedback(floor_num: int) -> void:
	if _audio_player:
		_audio_player.stream = SoundSynthesizer.get_terminal_beep()
		_audio_player.play()
	if _interaction_prompt:
		_interaction_prompt.text = "FLOOR %d ACCESS RESTRICTED!\nMUST CLEAR FLOOR 3 FIRST" % floor_num
	# Reset prompt after 2 seconds
	if is_inside_tree():
		var tree := get_tree()
		if tree:
			tree.create_timer(2.0).timeout.connect(func():
				if _player_inside and not _descent_in_progress:
					_update_prompt()
			)

func _start_descent_sequence() -> void:
	descent_initiated.emit()

	if _audio_player:
		_audio_player.stream = SoundSynthesizer.get_elevator_chime()
		_audio_player.play()

	if target_door and has_node(target_door):
		var door := get_node(target_door)
		if door and door.has_method("set_locked"):
			door.set_locked(true)

	if _interaction_prompt:
		_interaction_prompt.text = "FLOOR 3 CONFIRMED.\nSEALING CABIN GATES..."
	if _button_label:
		_button_label.text = "DESCENDING TO FLOOR 3..."

	if not is_inside_tree():
		return

	# Audio cue or timer before fade out
	await get_tree().create_timer(1.5).timeout

	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.transition(gm.State.ELEVATOR_DESCENT)
		gm.fade_out(1.2, func():
			gm.load_scene(target_corridor_scene)
			gm.transition(gm.State.CORRIDOR)
		)
	else:
		get_tree().change_scene_to_file(target_corridor_scene)
