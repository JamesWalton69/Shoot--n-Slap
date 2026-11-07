class_name Part1Corridor
extends Node3D
## Part1Corridor - Floor 3: Utility, Storage, Laser Grid & Security Wing.
## Redesigned per architectural blueprint:
## Ingress Lift -> Scare Room & Locker Room -> Central Laser Room -> Upper Guard Wing ->
## Collapsed Blockage -> Maintenance Detour -> 2nd Floor Lift.

const SoundSynthesizer = preload("res://addons/snss_core/audio/SoundSynthesizer.gd")

var entry_door: Node3D
var exit_door: Node3D
var detour_door: Node3D
var terminal: Area3D
var player: CharacterBody3D

var has_keycard_alpha: bool = false
var has_keycard_beta: bool = false
var lasers_disarmed: bool = false
var _lockdown_triggered: bool = false

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
		_audio_player.bus = "SFX"
		add_child(_audio_player)

	# Format the personalized story memo from GameManager
	_update_story_memo()

	# Ingress Lockdown Trigger Area (placed right outside the elevator door)
	var trigger := get_node_or_null("IngressLockdownTrigger") as Area3D
	if trigger and not trigger.body_entered.is_connected(_on_ingress_trigger_entered):
		trigger.body_entered.connect(_on_ingress_trigger_entered)

	# Scare Room Keycard Alpha Pickup
	var key_alpha := get_node_or_null("ScareRoom/KeycardAlphaPickup") as Area3D
	if key_alpha and not key_alpha.body_entered.is_connected(_on_keycard_alpha_pickup):
		key_alpha.body_entered.connect(_on_keycard_alpha_pickup)

	# Upper Guard Room Keycard Beta Pickup
	var key_beta := get_node_or_null("UpperGuardBarracks/KeycardBetaPickup") as Area3D
	if key_beta and not key_beta.body_entered.is_connected(_on_keycard_beta_pickup):
		key_beta.body_entered.connect(_on_keycard_beta_pickup)

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
	if terminal and terminal.has_signal("override_completed"):
		if not terminal.override_completed.is_connected(_on_terminal_override):
			terminal.override_completed.connect(_on_terminal_override)

	# Ensure EntryBaySlidingDoor starts open for arrival
	if entry_door and entry_door.has_method("open_door"):
		entry_door.call_deferred("open_door")

	# Lock Exit and Detour doors until respective keys are found
	if exit_door and exit_door.has_method("lock_door"):
		exit_door.lock_door()
	if detour_door and detour_door.has_method("lock_door"):
		detour_door.lock_door()

func _update_story_memo() -> void:
	if _story_memo_label:
		var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
		var p_name: String = str(gm.get("player_name")) if gm and gm.get("player_name") != null else "Sigma-7"
		var bf_name: String = str(gm.get("best_friend_name")) if gm and gm.get("best_friend_name") != null else "Vikram"
		var gf_name: String = str(gm.get("girlfriend_name")) if gm and gm.get("girlfriend_name") != null else "Pooja"
		_story_memo_label.text = "[RECOVERED MEMORANDUM // TOP SECRET]\nTO: %s\n\nYou thought Bhoot-Teri-Maki kidnapped %s?\nIt was me all along — %s!\n\nI won't die a virgin while you take all the glory!\nMy mercenary bodyguards will bury you right here on Floor 3.\nYou'll never reach her on Floor 2!" % [
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
		else:
			entry_door.set("is_locked", true)

	if _ingress_lockdown_label:
		_ingress_lockdown_label.text = "[SHAFT 3: LOCKDOWN ACTIVE]\nNO RETREAT AUTHORIZED"
		_ingress_lockdown_label.modulate = Color(1.0, 0.2, 0.2)

	if _ingress_siren:
		_ingress_siren.visible = true
		_ingress_siren.light_color = Color(1.0, 0.1, 0.1)

	if _audio_player and is_inside_tree():
		_audio_player.stream = SoundSynthesizer.get_terminal_beep()
		_audio_player.pitch_scale = 0.65
		_audio_player.play()

func _on_keycard_alpha_pickup(body: Node3D) -> void:
	if body is CharacterBody3D and not has_keycard_alpha:
		has_keycard_alpha = true
		print("[Floor 3] Keycard ALPHA acquired! Laser Room security door unlocked.")
		if _audio_player:
			_audio_player.stream = SoundSynthesizer.get_reload_click()
			_audio_player.play()
		var laser_door := get_node_or_null("LaserRoomDoor")
		if laser_door and laser_door.has_method("unlock_door"):
			laser_door.unlock_door()
		var key_pickup := get_node_or_null("ScareRoom/KeycardAlphaPickup")
		if key_pickup:
			key_pickup.queue_free()

func _on_keycard_beta_pickup(body: Node3D) -> void:
	if body is CharacterBody3D and not has_keycard_beta:
		has_keycard_beta = true
		print("[Floor 3] Keycard BETA acquired! Maintenance Detour around the blockage is now UNLOCKED.")
		if _audio_player:
			_audio_player.stream = SoundSynthesizer.get_reload_click()
			_audio_player.play()
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

	if exit_door and exit_door.has_method("unlock_door"):
		exit_door.unlock_door()

func _on_ammo_box_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		var head := body.get_node_or_null("Head") as Node3D
		if head:
			var cam := head.get_node_or_null("Camera3D") as Camera3D
			if cam:
				var vm := cam.get_node_or_null("ViewmodelRig")
				if vm and vm.get("ammo") != null:
					vm.ammo = vm.max_ammo
					if vm.has_signal("ammo_changed"):
						vm.ammo_changed.emit(vm.ammo, vm.max_ammo)
					print("[Floor 3] Ammo resupplied! Full 17 rounds restored.")
					if _audio_player:
						_audio_player.stream = SoundSynthesizer.get_reload_click()
						_audio_player.play()
					var box := get_node_or_null("LockerRoom/AmmoResupplyBox")
					if box:
						box.queue_free()
