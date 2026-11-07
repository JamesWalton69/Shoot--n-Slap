extends Area3D
## TerminalConsole - interactive security terminal in Floor 3 Central Laser Room.
## Overrides the lockdown on ExitElevatorSlidingDoor and disarms laser tripwires when hacked.

const SoundSynthesizer = preload("res://addons/snss_core/audio/SoundSynthesizer.gd")

signal terminal_hacked()
signal override_completed()

@export var exit_door_path: NodePath = NodePath("../ExitElevatorSlidingDoor")
@export var screen_mesh_path: NodePath = NodePath("../CorridorCSG/TerminalScreenMesh")

var exit_door_node: Node3D = null
var screen_mesh_node: Node3D = null

var is_hacked: bool = false
var _player_in_range: bool = false
var _prompt_label: Label
var _audio_player: AudioStreamPlayer3D
var _screen_3d_label: Label3D

var _mat_screen_active: StandardMaterial3D
var _mat_screen_unlocked: StandardMaterial3D

func _ready() -> void:
	add_to_group("terminal")
	collision_layer = 0
	collision_mask = 2 # Player layer

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "ConsoleAudio"
	_audio_player.bus = &"SFX"
	add_child(_audio_player)

	_screen_3d_label = get_node_or_null("ScreenPrompt") as Label3D

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
	_update_3d_prompt()

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
	_prompt_label.add_theme_font_size_override("font_size", 18)
	center.add_child(_prompt_label)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_player_in_range = true
		_update_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_player_in_range = false
		if _prompt_label:
			_prompt_label.text = ""

func _update_prompt() -> void:
	if not _prompt_label:
		return
	if is_hacked:
		_prompt_label.text = "=== SECURITY CONSOLE: OVERRIDDEN ===\nLASER GRID DISABLED // SHAFT 2 LIFT UNLOCKED"
	else:
		_prompt_label.text = "=== SECURITY CONSOLE T-9 ===\n[PRESS E] - OVERRIDE LASER GRID & UNLOCK SHAFT 2 LIFT"

func _update_3d_prompt() -> void:
	if _screen_3d_label:
		if is_hacked:
			_screen_3d_label.text = "[SECURITY OVERRIDE COMPLETE]\nLASER GRID DISABLED // LIFT UNLOCKED"
			_screen_3d_label.modulate = Color(0.2, 1.0, 0.4)
		else:
			_screen_3d_label.text = "[SECURITY OVERRIDE CONSOLE]\n[PRESS E] TO DISARM LASERS"
			_screen_3d_label.modulate = Color(0.2, 0.9, 1.0)

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
	_update_3d_prompt()

	# Locate and unlock exit sliding door
	var door: Node = exit_door_node
	if door == null and exit_door_path and has_node(exit_door_path):
		door = get_node(exit_door_path)
	if door == null and is_inside_tree():
		door = get_tree().root.find_child("ExitElevatorSlidingDoor", true, false)
	if door and door.has_method("unlock_door"):
		door.unlock_door()
		print("[Terminal] ExitElevatorSlidingDoor unlocked!")
	elif door and door.has_method("set_locked"):
		door.set_locked(false)
		print("[Terminal] ExitElevatorSlidingDoor unlocked!")

	# Disarm tripwires if parent corridor has not already
	var parent_corridor: Node = get_parent()
	while parent_corridor:
		if parent_corridor.has_method("_on_terminal_override"):
			parent_corridor._on_terminal_override()
			break
		parent_corridor = parent_corridor.get_parent()

	terminal_hacked.emit()
	override_completed.emit()

func _update_screen_mesh() -> void:
	var screen_mesh: Node = screen_mesh_node
	if screen_mesh == null and screen_mesh_path and has_node(screen_mesh_path):
		screen_mesh = get_node(screen_mesh_path)
	if screen_mesh == null:
		screen_mesh = get_node_or_null("ConsoleMesh")

	if screen_mesh and screen_mesh is MeshInstance3D:
		screen_mesh.set_surface_override_material(0, _mat_screen_unlocked if is_hacked else _mat_screen_active)
	elif screen_mesh and screen_mesh is CSGBox3D:
		screen_mesh.material = _mat_screen_unlocked if is_hacked else _mat_screen_active
