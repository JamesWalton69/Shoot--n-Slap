extends Area3D
## Elevator - fortified service elevator at corridor terminus.
## Checks hostile clearance / terminal interaction before descent into Floor 2.

const SoundSynthesizer = preload("res://addons/snss_core/audio/SoundSynthesizer.gd")

signal descent_started()
signal descent_aborted(reason: String)

enum Clearance {
	ALLOW,
	TERMINAL_REQUIRED,
	HOSTILE_NEARBY,
	LOCKED,
}

@export var requires_terminal: bool = true
@export var terminal_id: String = "service_terminal_01"
@export var clearance_radius: float = 12.0
@export var descent_delay: float = 5.0

var _active_player: CharacterBody3D = null
var _terminal_reached: bool = false
var _hostile_nearby: bool = false
var _descend_timer: Timer
var _audio_player: AudioStreamPlayer3D
var _status_sign: Label3D

func _ensure_timer() -> void:
	if _descend_timer == null:
		_descend_timer = Timer.new()
		_descend_timer.name = "DescentTimer"
		_descend_timer.wait_time = descent_delay
		_descend_timer.one_shot = true
		_descend_timer.timeout.connect(_on_descent_complete)
		add_child(_descend_timer)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player layer

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	_ensure_timer()

	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "ElevatorAudio"
	_audio_player.bus = &"SFX"
	add_child(_audio_player)

	_status_sign = get_node_or_null("../ExitSign") as Label3D

func _physics_process(_delta: float) -> void:
	if _active_player == null:
		return
	if _descend_timer and not _descend_timer.is_stopped():
		return # Already counting down
	_check_clearance()

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_active_player = body
		_check_clearance()

func _on_body_exited(body: Node3D) -> void:
	if body == _active_player:
		_active_player = null
		if _descend_timer and not _descend_timer.is_stopped():
			_descend_timer.stop()
			descent_aborted.emit("player exited elevator")
			_update_sign("[ELEVATOR S-2 // DESCENT ABORTED]\nSTEP INSIDE TO RESUME DESCENT", Color(1.0, 0.6, 0.2))

func _check_clearance() -> void:
	_terminal_reached = _terminal_reached or _is_terminal_reached()
	_hostile_nearby = _is_hostile_nearby()
	var cl := _determine_clearance()
	match cl:
		Clearance.ALLOW:
			_start_descent()
		Clearance.TERMINAL_REQUIRED:
			descent_aborted.emit("terminal not reached")
			_update_sign("[ELEVATOR S-2: LOCKDOWN ACTIVE]\nDISARM LASER GRID AT SECURITY CONSOLE", Color(1.0, 0.2, 0.2))
		Clearance.HOSTILE_NEARBY:
			descent_aborted.emit("hostile in elevator vicinity")
			_update_sign("[ELEVATOR S-2: HOSTILE THREAT NEARBY]\nELIMINATE AREA MERCENARIES FIRST", Color(1.0, 0.2, 0.2))
		Clearance.LOCKED:
			descent_aborted.emit("elevator not available")
			_update_sign("[ELEVATOR S-2: OFFLINE]", Color(0.6, 0.6, 0.6))

func _determine_clearance() -> Clearance:
	if _active_player == null:
		return Clearance.LOCKED
	if _is_hostile_nearby():
		return Clearance.HOSTILE_NEARBY
	if requires_terminal and not _is_terminal_reached():
		return Clearance.TERMINAL_REQUIRED
	return Clearance.ALLOW

func _is_terminal_reached() -> bool:
	if not requires_terminal or _terminal_reached:
		return true

	# Check ancestor corridor for lasers_disarmed state
	var p: Node = get_parent()
	while p:
		if "lasers_disarmed" in p and p.lasers_disarmed:
			_terminal_reached = true
			return true
		p = p.get_parent()

	# Check group "terminal"
	if is_inside_tree():
		var tree := get_tree()
		if tree:
			var terminal := tree.get_first_node_in_group("terminal")
			if terminal and terminal.get("is_hacked") == true:
				_terminal_reached = true
				return true
	return false

func _is_hostile_nearby() -> bool:
	var enemies: Array = []
	if is_inside_tree():
		var tree := get_tree()
		if tree:
			enemies = tree.get_nodes_in_group("enemy")
	else:
		# Standalone / headless fallback: inspect current floor hierarchy
		var level: Node = self
		while level.get_parent() and not (level is Part1Corridor):
			level = level.get_parent()
		if level:
			for child in level.find_children("", "CharacterBody3D", true, false):
				if child.is_in_group("enemy") or child.has_method("die"):
					enemies.append(child)

	for enemy in enemies:
		if enemy is Node3D and is_instance_valid(enemy):
			if enemy.has_method("is_dead") and enemy.is_dead():
				continue
			# In tree: use accurate global_position
			if is_inside_tree() and enemy.is_inside_tree():
				if global_position.distance_to(enemy.global_position) <= clearance_radius:
					return true
			else:
				# Standalone mock: any live bodyguard in level triggers nearby hostile
				return true
	return false

func set_terminal_reached(reached: bool = true) -> void:
	_terminal_reached = reached
	if _active_player:
		_check_clearance()

func _start_descent() -> void:
	_ensure_timer()
	if not is_inside_tree():
		descent_started.emit()
		return
	if not _descend_timer.is_stopped():
		return

	print("[Elevator S-2] Clearance verified. Descent initiated!")
	descent_started.emit()
	_descend_timer.start()

	# Save player persistent state to GameManager before transit
	if _active_player:
		var gm := get_node_or_null("/root/GameManager")
		if gm and gm.has_method("save_player_state"):
			gm.save_player_state(_active_player)
		_start_cabin_rumble()

	if _audio_player:
		_audio_player.stream = SoundSynthesizer.get_elevator_chime()
		_audio_player.play()

	_update_sign("[ELEVATOR S-2 // DESCENT IN PROGRESS]\nTRANSIT TO FLOOR 2 WARZONE...", Color(0.2, 1.0, 0.4))

func _start_cabin_rumble() -> void:
	if _active_player == null or not is_inside_tree():
		return
	var head := _active_player.get_node_or_null("Head") as Node3D
	if head:
		var cam := head.get_node_or_null("Camera3D") as Camera3D
		if cam:
			var base_pos := cam.position
			var tween := create_tween()
			for i in range(10):
				var shake := Vector3(randf_range(-0.02, 0.02), randf_range(-0.015, 0.015), 0.0)
				tween.tween_property(cam, "position", base_pos + shake, 0.08)
				tween.tween_property(cam, "position", base_pos, 0.08)

func _on_descent_complete() -> void:
	print("[Elevator S-2] Descent complete. Transitioning to Floor 2...")
	_active_player = null

	if is_inside_tree():
		var gm := get_node_or_null("/root/GameManager")
		if gm and gm.has_method("fade_out"):
			gm.fade_out(1.2, Callable(self, "_on_fade_finished"))
		else:
			_on_fade_finished()

func _on_fade_finished() -> void:
	if not is_inside_tree():
		return
	var gm := get_node_or_null("/root/GameManager")
	var target_scene := "res://addons/snss_core/scenes/Part2Warzone.tscn"
	var target_script := "res://addons/snss_core/scenes/Part2Warzone.gd"
	if ResourceLoader.exists(target_scene) and gm and gm.has_method("load_scene"):
		gm.load_scene(target_scene)
	elif ResourceLoader.exists(target_script) and gm and gm.has_method("load_scene"):
		gm.load_scene(target_script)
	else:
		print("[Elevator S-2] Floor 2 scene standby - ready for Part2Warzone integration.")

func try_enter(player: Node) -> void:
	if not is_inside_tree():
		return
	if player is CharacterBody3D:
		_active_player = player
	_check_clearance()

func _update_sign(msg: String, color: Color) -> void:
	if _status_sign:
		_status_sign.text = msg
		_status_sign.modulate = color
