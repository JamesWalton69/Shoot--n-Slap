extends Area3D
## TerminalConsole - interactive security terminal in Terminus Arena.
## Overrides the lockdown on ExitElevatorSlidingDoor when hacked by player.

const SoundSynthesizer = preload("res://addons/snss_core/audio/SoundSynthesizer.gd")

signal terminal_hacked()

@export var exit_door_path: NodePath = NodePath("../ExitElevatorSlidingDoor")
@export var screen_mesh_path: NodePath = NodePath("../CorridorCSG/TerminalScreenMesh")

var exit_door_node: Node3D = null
var screen_mesh_node: CSGBox3D = null

var is_hacked: bool = false
var _player_in_range: bool = false
var _prompt_label: Label
var _audio_player: AudioStreamPlayer3D

var _mat_screen_active: StandardMaterial3D
var _mat_screen_unlocked: StandardMaterial3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.bus = &"SFX"
	add_child(_audio_player)

	_build_hud_prompt()

	_mat_screen_active = StandardMaterial3D.new()
	_mat_screen_active.albedo_color = Color(0.9, 0.2, 0.2)
	_mat_screen_active.emission_enabled = true
	_mat_screen_active.emission = Color(1.0, 0.15, 0.15)
	_mat_screen_active.emission_energy_multiplier = 3.0

	_mat_screen_unlocked = StandardMaterial3D.new()
	_mat_screen_unlocked.albedo_color = Color(0.2, 0.9, 0.3)
	_mat_screen_unlocked.emission_enabled = true
	_mat_screen_unlocked.emission = Color(0.2, 1.0, 0.4)
	_mat_screen_unlocked.emission_energy_multiplier = 3.5

	_update_screen_mesh()

func _build_hud_prompt() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "TerminalHUD"
	add_child(canvas)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(center)

	_prompt_label = Label.new()
	_prompt_label.text = ""
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 17)
	center.add_child(_prompt_label)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.name == "Player":
		_player_in_range = true
		_update_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D and body.name == "Player":
		_player_in_range = false
		if _prompt_label:
			_prompt_label.text = ""

func _update_prompt() -> void:
	if not _prompt_label:
		return
	if is_hacked:
		_prompt_label.text = "=== TERMINAL OVERRIDE ACTIVE ===\nSHAFT 4 ELEVATOR UNLOCKED"
	else:
		_prompt_label.text = "=== SECURITY CONSOLE T-9 ===\n[PRESS E] - OVERRIDE SHAFT 4 LOCKDOWN"

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or is_hacked:
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E:
			hack_terminal()

func hack_terminal() -> void:
	if is_hacked:
		return

	is_hacked = true
	print("[Terminal] Override sequence initiated!")

	if _audio_player:
		_audio_player.stream = SoundSynthesizer.get_terminal_beep()
		_audio_player.play()

	_update_screen_mesh()
	_update_prompt()

	# Unlock exit sliding door
	var door: Node = exit_door_node
	if door == null and exit_door_path and has_node(exit_door_path):
		door = get_node(exit_door_path)
	if door and door.has_method("set_locked"):
		door.set_locked(false)
		print("[Terminal] ExitElevatorSlidingDoor unlocked!")

	terminal_hacked.emit()

func _update_screen_mesh() -> void:
	var screen_mesh: CSGBox3D = screen_mesh_node
	if screen_mesh == null and screen_mesh_path and has_node(screen_mesh_path):
		screen_mesh = get_node(screen_mesh_path) as CSGBox3D
	if screen_mesh:
		screen_mesh.material = _mat_screen_unlocked if is_hacked else _mat_screen_active
