class_name Part1Corridor
extends Node3D
## Part1Corridor - Floor 3: Utility, Storage & Security Wing.
## Manages ingress elevator arrival, containment lockdown (point of no return),
## guard room pickups, and security terminal override.

const SoundSynthesizer = preload("res://addons/snss_core/audio/SoundSynthesizer.gd")

var entry_door: Node3D
var exit_door: Node3D
var terminal: Area3D
var player: CharacterBody3D

var _lockdown_triggered: bool = false
var _ingress_lockdown_label: Label3D
var _ingress_siren: OmniLight3D
var _audio_player: AudioStreamPlayer3D

func _ensure_references() -> void:
	if entry_door == null:
		entry_door = get_node_or_null("EntryBaySlidingDoor") as Node3D
	if exit_door == null:
		exit_door = get_node_or_null("ExitElevatorSlidingDoor") as Node3D
	if terminal == null:
		terminal = get_node_or_null("TerminalConsoleArea") as Area3D
	if player == null:
		player = get_node_or_null("Player") as CharacterBody3D
	if _ingress_lockdown_label == null:
		_ingress_lockdown_label = get_node_or_null("IngressElevatorCabin/LockdownSign") as Label3D
	if _ingress_siren == null:
		_ingress_siren = get_node_or_null("IngressElevatorCabin/LockdownSiren") as OmniLight3D

func _ready() -> void:
	_ensure_references()

	if _audio_player == null:
		_audio_player = AudioStreamPlayer3D.new()
		_audio_player.name = "FloorAudio"
		_audio_player.bus = "SFX"
		add_child(_audio_player)

	# Setup Ingress Lockdown Trigger Area (placed right outside the elevator door at Z = 19.5)
	var trigger := get_node_or_null("IngressLockdownTrigger") as Area3D
	if trigger:
		if not trigger.body_entered.is_connected(_on_ingress_trigger_entered):
			trigger.body_entered.connect(_on_ingress_trigger_entered)

	# Setup Ammo Pickup Box in Guard Barracks
	var ammo_box := get_node_or_null("GuardBarracks/AmmoResupplyBox") as Area3D
	if ammo_box:
		if not ammo_box.body_entered.is_connected(_on_ammo_box_entered):
			ammo_box.body_entered.connect(_on_ammo_box_entered)

	# Ensure EntryBaySlidingDoor starts open for arrival
	if entry_door and entry_door.has_method("open_door"):
		entry_door.call_deferred("open_door")

func _on_ingress_trigger_entered(body: Node3D) -> void:
	if _lockdown_triggered:
		return
	if body is CharacterBody3D:
		_lockdown_triggered = true
		_trigger_ingress_lockdown()

func _trigger_ingress_lockdown() -> void:
	_ensure_references()
	_lockdown_triggered = true
	print("[Floor 3] Ingress door lockdown initiated! No turning back into the elevator.")
	if entry_door:
		if entry_door.has_method("close_door"):
			entry_door.close_door()
		if entry_door.has_method("lock_door"):
			entry_door.lock_door()
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
					var box := get_node_or_null("GuardBarracks/AmmoResupplyBox")
					if box:
						box.queue_free()
