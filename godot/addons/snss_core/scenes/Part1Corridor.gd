class_name Part1Corridor
extends Node3D
## Part1Corridor - Floor 3: Utility, Storage, Laser Grid & Security Wing.
## Built strictly according to the hand-drawn blueprint:
## Ingress Lift S-3 -> Scare Room (Alpha Key) & Locker Room (Armory) ->
## Central Laser Room (Tripwire Grid & Security Console) flanked by
## West Security Office (Sub-Room 1) and East Comms Relay (Sub-Room 2) ->
## Upper Guard Barracks (Beta Key) -> Crushed Hallway Blockage ->
## Maintenance Detour (2-Man Patrol) -> 2nd Floor Lift S-2.

const SoundSynthesizer = preload("res://addons/snss_core/audio/SoundSynthesizer.gd")

var entry_door: Node3D
var exit_door: Node3D
var detour_door: Node3D
var laser_door: Node3D
var scare_door: Node3D
var locker_door: Node3D
var west_room1_door: Node3D
var east_room2_door: Node3D
var barracks_door: Node3D

var terminal: Area3D
var player: CharacterBody3D

var has_keycard_alpha: bool = false
var has_keycard_beta: bool = false
var lasers_disarmed: bool = false
var _lockdown_triggered: bool = false
var _scare_triggered: bool = false

var _ingress_lockdown_label: Label3D
var _ingress_siren: OmniLight3D
var _audio_player: AudioStreamPlayer3D
var _story_memo_label: Label3D

func _ensure_references() -> void:
	if entry_door == null:
		entry_door = get_node_or_null("EntryBaySlidingDoor") as Node3D
	if exit_door == null:
		exit_door = get_node_or_null("ExitElevatorSlidingDoor") as Node3D
	if detour_door == null:
		detour_door = get_node_or_null("MaintenanceDetourDoor") as Node3D
	if laser_door == null:
		laser_door = get_node_or_null("LaserRoomDoor") as Node3D
	if scare_door == null:
		scare_door = get_node_or_null("ScareRoomDoor") as Node3D
	if locker_door == null:
		locker_door = get_node_or_null("LockerRoomDoor") as Node3D
	if west_room1_door == null:
		west_room1_door = get_node_or_null("WestRoom1Door") as Node3D
	if east_room2_door == null:
		east_room2_door = get_node_or_null("EastRoom2Door") as Node3D
	if barracks_door == null:
		barracks_door = get_node_or_null("UpperBarracksDoor") as Node3D
	if terminal == null:
		terminal = get_node_or_null("LaserRoom/TerminalConsoleArea") as Area3D
		if terminal == null:
			terminal = get_node_or_null("TerminalConsoleArea") as Area3D
	if player == null:
		player = get_node_or_null("Player") as CharacterBody3D
	if _ingress_lockdown_label == null:
		_ingress_lockdown_label = get_node_or_null("IngressElevatorCabin/LockdownSign") as Label3D
	if _ingress_siren == null:
		_ingress_siren = get_node_or_null("IngressElevatorCabin/LockdownSiren") as OmniLight3D
	if _story_memo_label == null:
		_story_memo_label = get_node_or_null("ScareRoom/StoryMemoNote") as Label3D

func _ready() -> void:
	_ensure_references()

	if _audio_player == null:
		_audio_player = AudioStreamPlayer3D.new()
		_audio_player.name = "FloorAudio"
		_audio_player.bus = &"SFX"
		add_child(_audio_player)

	# Format the personalized story memo from GameManager
	_update_story_memo()

	# Ingress Lockdown Trigger Area (placed right outside the elevator door)
	var trigger := get_node_or_null("IngressLockdownTrigger") as Area3D
	if trigger and not trigger.body_entered.is_connected(_on_ingress_trigger_entered):
		trigger.body_entered.connect(_on_ingress_trigger_entered)

	# Scare Room Trigger (approaching desk/memo note)
	var scare_trig := get_node_or_null("ScareRoom/ScareTrigger") as Area3D
	if scare_trig and not scare_trig.body_entered.is_connected(_on_scare_trigger_entered):
		scare_trig.body_entered.connect(_on_scare_trigger_entered)

	# Scare Room Keycard Alpha Pickup
	var key_alpha := get_node_or_null("ScareRoom/KeycardAlphaPickup") as Area3D
	if key_alpha:
		if not key_alpha.body_entered.is_connected(_on_keycard_alpha_pickup):
			key_alpha.body_entered.connect(_on_keycard_alpha_pickup)
		if key_alpha.has_signal("picked_up") and not key_alpha.is_connected("picked_up", _on_keycard_alpha_pickup):
			key_alpha.connect("picked_up", _on_keycard_alpha_pickup)

	# Upper Guard Room Keycard Beta Pickup
	var key_beta := get_node_or_null("UpperGuardBarracks/KeycardBetaPickup") as Area3D
	if key_beta:
		if not key_beta.body_entered.is_connected(_on_keycard_beta_pickup):
			key_beta.body_entered.connect(_on_keycard_beta_pickup)
		if key_beta.has_signal("picked_up") and not key_beta.is_connected("picked_up", _on_keycard_beta_pickup):
			key_beta.connect("picked_up", _on_keycard_beta_pickup)

	# Ammo Resupply Crate in Locker Room
	var locker_ammo := get_node_or_null("LockerRoom/AmmoResupplyBox") as Area3D
	if locker_ammo and not locker_ammo.body_entered.is_connected(_on_ammo_box_entered):
		locker_ammo.body_entered.connect(_on_ammo_box_entered)

	# Wire Laser Tripwires in Laser Room
	var tripwire_container := get_node_or_null("LaserRoom/Tripwires")
	if tripwire_container:
		for child in tripwire_container.get_children():
			if child.has_signal("tripped") and not child.tripped.is_connected(_on_laser_beam_tripped):
				child.tripped.connect(_on_laser_beam_tripped)

	# Wire Terminal Console
	if terminal:
		if terminal.has_signal("override_completed") and not terminal.override_completed.is_connected(_on_terminal_override):
			terminal.override_completed.connect(_on_terminal_override)
		elif terminal.has_signal("terminal_hacked") and not terminal.terminal_hacked.is_connected(_on_terminal_override):
			terminal.terminal_hacked.connect(_on_terminal_override)

	# Ensure EntryBaySlidingDoor starts open for arrival
	if entry_door and entry_door.has_method("open_door"):
		entry_door.call_deferred("open_door")

	# Lock doors that require keycards or terminal hacks
	if laser_door and laser_door.has_method("lock_door"):
		laser_door.lock_door()
	if detour_door and detour_door.has_method("lock_door"):
		detour_door.lock_door()
	if exit_door and exit_door.has_method("lock_door"):
		exit_door.lock_door()

func _update_story_memo() -> void:
	if _story_memo_label:
		var gm: Node = get_node_or_null("/root/GameManager") if is_inside_tree() else null
		var p_name: String = str(gm.get("player_name")) if gm and gm.get("player_name") != null else "Sigma-7"
		var bf_name: String = str(gm.get("best_friend_name")) if gm and gm.get("best_friend_name") != null else "Vikram"
		var gf_name: String = str(gm.get("girlfriend_name")) if gm and gm.get("girlfriend_name") != null else "Pooja"
		_story_memo_label.text = "[RECOVERED MEMORANDUM // TOP SECRET]\nTO: %s\n\nYou thought Bhoot-Teri-Maki kidnapped %s?\nIt was me all along — %s!\n\nI won't die a virgin while you take all the glory!\nMy mercenary bodyguards will bury you right here on Floor 3.\nShe is locked deep in the Underground Vault!\nMy Garrison Commander on Floor 2 will execute you before you ever reach the lower elevators!" % [
			p_name.to_upper(), gf_name, bf_name.to_upper()
		]

func _on_ingress_trigger_entered(body: Node3D) -> void:
	if _lockdown_triggered:
		return
	if body is CharacterBody3D:
		_lockdown_triggered = true
		_trigger_ingress_lockdown()

func _trigger_ingress_lockdown() -> void:
	_ensure_references()
	_lockdown_triggered = true
	print("[Floor 3] Ingress door lockdown initiated! No retreat into Shaft 3.")
	if entry_door:
		if entry_door.has_method("close_door"):
			entry_door.close_door()
		if entry_door.has_method("set_locked"):
			entry_door.set_locked(true)
		elif entry_door.has_method("lock_door"):
			entry_door.lock_door()
		else:
			entry_door.set("is_locked", true)

	if _ingress_lockdown_label:
		_ingress_lockdown_label.text = "[SHAFT 3: LOCKDOWN ACTIVE]\nNO RETREAT AUTHORIZED"
		_ingress_lockdown_label.modulate = Color(1.0, 0.2, 0.2)

	if _ingress_siren:
		_ingress_siren.visible = true
		_ingress_siren.light_color = Color(1.0, 0.1, 0.1)

	# Audio muted per user request
	# if _audio_player and is_inside_tree():
	# 	_audio_player.stream = SoundSynthesizer.get_terminal_beep()
	# 	_audio_player.pitch_scale = 0.65
	# 	_audio_player.play()

func _on_scare_trigger_entered(body: Node3D) -> void:
	if _scare_triggered:
		return
	if body is CharacterBody3D:
		_scare_triggered = true
		_play_scare_sequence()

func _play_scare_sequence() -> void:
	print("[Floor 3 Scare] Comm frequency intercepted: 'You will never leave Floor 3 alive...'")
	var red_light := get_node_or_null("ScareRoom/RedEmergencyLight") as OmniLight3D
	if red_light and is_inside_tree():
		var tween := create_tween()
		tween.tween_property(red_light, "light_energy", 0.1, 0.08)
		tween.tween_property(red_light, "light_energy", 4.0, 0.06)
		tween.tween_property(red_light, "light_energy", 0.2, 0.08)
		tween.tween_property(red_light, "light_energy", 2.2, 0.14)

	if _story_memo_label:
		_story_memo_label.modulate = Color(1.0, 0.15, 0.15, 1.0)

	_show_radio_interception_popup()

func _show_radio_interception_popup() -> void:
	if not is_inside_tree():
		return
	var gm: Node = get_node_or_null("/root/GameManager")
	var bf_name: String = str(gm.get("best_friend_name")) if gm and gm.get("best_friend_name") != null else "Vikram"
	var canvas := CanvasLayer.new()
	canvas.layer = 120
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_top = 40.0
	panel.offset_bottom = 110.0
	panel.offset_left = 60.0
	panel.offset_right = -60.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.88)
	style.border_color = Color(1.0, 0.2, 0.2, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = "[RADIO INTERCEPT // ENCRYPTED COMMS - %s]\n'You'll never leave Floor 3 alive! She's locked deep in the Vault, and Floor 2 is a warzone!'" % bf_name.to_upper()
	label.modulate = Color(1.0, 0.35, 0.35)
	panel.add_child(label)
	canvas.add_child(panel)
	get_tree().root.add_child(canvas)

	# Auto fade-out after 5 seconds
	var tree := get_tree()
	if tree:
		tree.create_timer(5.0).timeout.connect(func():
			if is_instance_valid(canvas):
				var tween := canvas.create_tween()
				tween.tween_property(panel, "modulate:a", 0.0, 0.8)
				tween.tween_callback(canvas.queue_free)
		)

func _on_keycard_alpha_pickup(body_or_card: Variant = null) -> void:
	if has_keycard_alpha:
		return
	if body_or_card is CharacterBody3D or body_or_card is String or body_or_card == null:
		has_keycard_alpha = true
		print("[Floor 3] Keycard ALPHA acquired! Laser Room security door unlocked.")
		# Audio muted per user request
		# if _audio_player and is_inside_tree():
		# 	_audio_player.stream = SoundSynthesizer.get_reload_click()
		# 	_audio_player.play()
		_ensure_references()
		if laser_door and laser_door.has_method("unlock_door"):
			laser_door.unlock_door()
		var key_pickup := get_node_or_null("ScareRoom/KeycardAlphaPickup")
		if key_pickup:
			key_pickup.queue_free()

func _on_keycard_beta_pickup(body_or_card: Variant = null) -> void:
	if has_keycard_beta:
		return
	if body_or_card is CharacterBody3D or body_or_card is String or body_or_card == null:
		has_keycard_beta = true
		print("[Floor 3] Keycard BETA acquired! Maintenance Detour around the blockage is now UNLOCKED.")
		# Audio muted per user request
		# if _audio_player and is_inside_tree():
		# 	_audio_player.stream = SoundSynthesizer.get_reload_click()
		# 	_audio_player.play()
		_ensure_references()
		if detour_door and detour_door.has_method("unlock_door"):
			detour_door.unlock_door()
		var key_pickup := get_node_or_null("UpperGuardBarracks/KeycardBetaPickup")
		if key_pickup:
			key_pickup.queue_free()

func _on_laser_beam_tripped(_intruder: Node3D) -> void:
	print("[Floor 3] LASER GRID COMPROMISED! Alerting all floor bodyguards.")
	# Flash room siren
	var siren := get_node_or_null("LaserRoom/LaserAlarmSiren") as OmniLight3D
	if siren:
		siren.visible = true
	# Put all bodyguards in ALERT combat mode
	var guards := get_tree().get_nodes_in_group("enemy") if is_inside_tree() else []
	for g in guards:
		if g.get("current_state") != null:
			g.current_state = 1 # State.ALERT

func _on_terminal_override() -> void:
	lasers_disarmed = true
	print("[Floor 3] Security Console hacked! Laser grid disarmed and Exit elevator unlocked.")
	var tripwire_container := get_node_or_null("LaserRoom/Tripwires")
	if tripwire_container:
		for tripwire in tripwire_container.get_children():
			if tripwire.has_method("disarm_tripwire"):
				tripwire.disarm_tripwire()

	_ensure_references()
	if exit_door and exit_door.has_method("unlock_door"):
		exit_door.unlock_door()

	var exit_elev := get_node_or_null("ExitElevatorCabin/ExitElevatorZone")
	if exit_elev and exit_elev.has_method("set_terminal_reached"):
		exit_elev.set_terminal_reached(true)

func _on_ammo_box_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		if body.has_method("heal"):
			body.heal(50.0)
		elif body.get("current_health") != null:
			body.current_health = minf(100.0, body.current_health + 50.0)
			if body.has_method("_update_hud"):
				body._update_hud()

		var head := body.get_node_or_null("Head") as Node3D
		if head:
			var cam := head.get_node_or_null("Camera3D") as Camera3D
			if cam:
				var vm := cam.get_node_or_null("ViewmodelRig")
				if vm and vm.get("ammo") != null:
					vm.ammo = vm.max_ammo
					if vm.get("reserve_ammo") != null:
						vm.reserve_ammo = max(vm.reserve_ammo, 34)
					if vm.has_signal("ammo_changed"):
						vm.ammo_changed.emit(vm.ammo, vm.max_ammo)
					print("[Floor 3] Armory supply gathered! Health reinforced and full 17 rounds restored.")
					var box := get_node_or_null("LockerRoom/AmmoResupplyBox")
					if box:
						box.queue_free()
