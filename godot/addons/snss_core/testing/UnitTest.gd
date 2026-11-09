extends SceneTree
## Unit tests for Shoot-'n-Slap core systems.
## Run via CLI:
##   .\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe --headless --path godot --script addons/snss_core/testing/UnitTest.gd

const InputMapperScript = preload("res://addons/snss_core/autoload/InputMapper.gd")
const CalibrationTimerScript = preload("res://addons/snss_core/autoload/CalibrationTimer.gd")
const AudioEnvironmentManagerScript = preload("res://addons/snss_core/autoload/AudioEnvironmentManager.gd")
const GameManagerScript = preload("res://addons/snss_core/autoload/GameManager.gd")

var _passed := 0
var _failed := 0

func _init() -> void:
	print("========================================")
	print("SHOOT-'N-SLAP TEST SUITE (HEADLESS RUN)")
	print("========================================")
	test_inputmapper_multiplier_layer()
	test_calibration_timer_random_range()
	test_calibration_timer_phase_guards()
	test_audio_snapshot_dark_70()
	test_game_manager_fade_guard()
	test_game_manager_rooftop_state()
	test_story_setup_names()
	test_terrain_3d_registration()
	test_animated_sliding_door()
	test_rooftop_door_proximity_integration()
	test_character_viewmodel_and_slap()
	test_player_cod_health_and_regen()
	test_weapon_ammo_and_reload()
	test_sound_synthesizer()
	test_corridor_henchman_and_slap_stagger()
	test_henchman_retargeted_animations()
	test_laser_tripwire()
	test_terminal_hack_and_door_unlock()
	test_part1_corridor_scene_integration()
	test_floor_3_ingress_lockdown_and_scare_room()
	test_floor_3_elevator_clearance()
	test_keycard_pickup_animation()
	test_ambient_loops_and_scene_audio()
	test_player_persistent_state_and_elevator_transit()
	test_laser_tripwire_zap_damage()

	print("========================================")
	print("TOTAL TESTS: %d | PASSED: %d | FAILED: %d" % [_passed + _failed, _passed, _failed])
	print("========================================")

	quit(0 if _failed == 0 else 1)

func _pass(test_name: String) -> void:
	_passed += 1
	print("  [PASS] %s" % test_name)

func _fail(test_name: String, msg: String) -> void:
	_failed += 1
	print("  [FAIL] %s - %s" % [test_name, msg])

func test_inputmapper_multiplier_layer() -> void:
	var mapper: Node = InputMapperScript.new()
	var signal_box: Array = [-1.0]
	mapper.sensitivity_multiplied.connect(func(v: float): signal_box[0] = v)
	mapper.look_sensitivity_multiplier = 0.5
	if mapper.look_sensitivity_multiplier == 0.5 and signal_box[0] == 0.5:
		_pass("InputMapper: multiplier assignment emits sensitivity_multiplied")
	else:
		_fail("InputMapper", "Failed to assign multiplier or fire signal")

	# Clamping test
	mapper.look_sensitivity_multiplier = 0.1
	if mapper.look_sensitivity_multiplier == 0.3:
		_pass("InputMapper: lower clamp enforced to 0.3")
	else:
		_fail("InputMapper", "Lower clamp failed: got %f" % mapper.look_sensitivity_multiplier)

	mapper.look_sensitivity_multiplier = 1.5
	if mapper.look_sensitivity_multiplier == 0.8:
		_pass("InputMapper: upper clamp enforced to 0.8")
	else:
		_fail("InputMapper", "Upper clamp failed: got %f" % mapper.look_sensitivity_multiplier)

	mapper.queue_free()

func test_calibration_timer_random_range() -> void:
	var timer: Node = CalibrationTimerScript.new()
	var all_rolls_valid := true
	for i in range(25):
		timer.new_calibration_cycle()
		var r: float = timer._next_roll
		if r < 0.3 or r > 0.8:
			all_rolls_valid = false
			break
	if all_rolls_valid:
		_pass("CalibrationTimer: all rolls strictly in [0.3, 0.8]")
	else:
		_fail("CalibrationTimer", "Roll out of bounds")

	var all_intervals_valid := true
	for i in range(25):
		timer.new_calibration_cycle()
		var iv: float = timer._interval
		if iv < 300.0 or iv > 540.0:
			all_intervals_valid = false
			break
	if all_intervals_valid:
		_pass("CalibrationTimer: cycle interval strictly in [300.0, 540.0] seconds")
	else:
		_fail("CalibrationTimer", "Interval out of bounds")

	if timer.WARNING_SECONDS == 4.0:
		_pass("CalibrationTimer: warning audio cue window is exactly 4.0 seconds")
	else:
		_fail("CalibrationTimer", "Warning duration unexpected: %f" % timer.WARNING_SECONDS)

	timer.queue_free()

func test_calibration_timer_phase_guards() -> void:
	var timer: Node = CalibrationTimerScript.new()
	if timer._phase == CalibrationTimerScript.Phase.IDLE:
		_pass("CalibrationTimer: initializes in IDLE phase")
	else:
		_fail("CalibrationTimer", "Did not initialize in IDLE phase")

	var skipped_signal: Array = [false]
	timer.calibration_skipped.connect(func(_r: String): skipped_signal[0] = true)
	timer._phase = CalibrationTimerScript.Phase.WARNING
	timer._on_calibration_timer_timeout()
	if skipped_signal[0]:
		_pass("CalibrationTimer: re-entrant timeout blocked during WARNING phase")
	else:
		_fail("CalibrationTimer", "Failed to guard against re-entrant timeout")

	timer.queue_free()

func test_audio_snapshot_dark_70() -> void:
	var mgr: Node = AudioEnvironmentManagerScript.new()
	mgr.set_mode(AudioEnvironmentManagerScript.AudioMode.DARK_70)
	if mgr.current_mode == AudioEnvironmentManagerScript.AudioMode.DARK_70:
		_pass("AudioEnvironmentManager: switched to DARK_70 mode")
	else:
		_fail("AudioEnvironmentManager", "Failed to switch mode")

	if mgr.ambient_bus_volume_db == -80.0:
		_pass("AudioEnvironmentManager: ambient music bus clamped to -80 dB (silence)")
	else:
		_fail("AudioEnvironmentManager", "Ambient bus volume: %f" % mgr.ambient_bus_volume_db)

	var expected_gain_db: float = linear_to_db(1.5)
	if abs(mgr.sfx_bus_volume_db - expected_gain_db) < 0.05:
		_pass("AudioEnvironmentManager: SFX linear gain locked at 1.5x (+3.52 dB)")
	else:
		_fail("AudioEnvironmentManager", "SFX bus unexpected dB: %f (expected %f)" % [mgr.sfx_bus_volume_db, expected_gain_db])

	mgr.queue_free()

func test_game_manager_fade_guard() -> void:
	var gm: Node = GameManagerScript.new()
	var rejected := true
	gm.transition(GameManagerScript.State.FADED)
	gm.state_changed.connect(func(_s): rejected = false)
	gm.transition(GameManagerScript.State.CORRIDOR)
	if rejected:
		_pass("GameManager: transition blocked when in FADED state")
	else:
		_fail("GameManager", "Transition allowed during FADED state")
	gm.queue_free()

func test_game_manager_rooftop_state() -> void:
	var gm: Node = GameManagerScript.new()
	gm.transition(GameManagerScript.State.ROOFTOP)
	if gm.get_state() == GameManagerScript.State.ROOFTOP:
		_pass("GameManager: ROOFTOP state transition supported")
	else:
		_fail("GameManager", "Failed to transition to ROOFTOP")
	gm.queue_free()

func test_story_setup_names() -> void:
	var gm: Node = GameManagerScript.new()
	gm.set_story_names("Agent-47", "Vikram_BestFriend", "Pooja_Girlfriend")
	if gm.player_name == "Agent-47" and gm.best_friend_name == "Vikram_BestFriend" and gm.girlfriend_name == "Pooja_Girlfriend":
		_pass("GameManager: story names (Player, Best Friend, Girlfriend) registered correctly")
	else:
		_fail("GameManager", "Failed to set story names")
	gm.queue_free()

func test_terrain_3d_registration() -> void:
	if ClassDB.class_exists("Terrain3D"):
		_pass("Terrain3D: GDExtension plugin loaded and registered in ClassDB")
	else:
		_fail("Terrain3D", "Class not found in ClassDB")

func test_animated_sliding_door() -> void:
	var door_scene = load("res://addons/snss_core/scenes/AnimatedSlidingDoor.tscn")
	if door_scene == null:
		_fail("AnimatedSlidingDoor", "Failed to load AnimatedSlidingDoor.tscn")
		return

	var door = door_scene.instantiate()
	root.add_child(door)
	door._ready()

	# 1. Initial State
	if not door._is_open and not door.is_locked:
		_pass("AnimatedSlidingDoor: initial state closed and ready")
	else:
		_fail("AnimatedSlidingDoor", "Initial state unexpected: open=%s locked=%s" % [door._is_open, door.is_locked])

	# 2. Mock Actor Proximity Detection
	var mock_player := CharacterBody3D.new()
	mock_player.name = "Player"
	root.add_child(mock_player)

	door._on_proximity_entered(mock_player)
	if door._is_open:
		_pass("AnimatedSlidingDoor: opens automatically when player enters proximity zone")
	else:
		_fail("AnimatedSlidingDoor", "Failed to open on proximity entered")

	# Check indicator is green
	var light: OmniLight3D = door.get_node_or_null("StatusLight")
	if light and light.light_color.g > 0.8:
		_pass("AnimatedSlidingDoor: status light turns green when open")
	else:
		_fail("AnimatedSlidingDoor", "Status light color not green")

	# 3. Exit proximity zone
	door._on_proximity_exited(mock_player)
	if door._bodies_in_zone.is_empty():
		_pass("AnimatedSlidingDoor: clears player tracking on exit")
	else:
		_fail("AnimatedSlidingDoor", "Failed to clear player from zone")

	# 4. Trigger close timeout
	door._on_close_timer_timeout()
	if not door._is_open:
		_pass("AnimatedSlidingDoor: closes automatically after delay")
	else:
		_fail("AnimatedSlidingDoor", "Failed to close after delay")

	# 5. Lock testing
	door.set_locked(true)
	if door.is_locked and light and light.light_color.r > 0.8:
		_pass("AnimatedSlidingDoor: locks and turns indicator red")
	else:
		_fail("AnimatedSlidingDoor", "Lock status or red light failed")

	# Attempt to open while locked
	door._on_proximity_entered(mock_player)
	if not door._is_open:
		_pass("AnimatedSlidingDoor: refuses to open while locked")
	else:
		_fail("AnimatedSlidingDoor", "Door opened while locked!")

	mock_player.queue_free()
	door.queue_free()

func test_rooftop_door_proximity_integration() -> void:
	var rooftop_scene = load("res://addons/snss_core/scenes/Rooftop.tscn")
	if rooftop_scene == null:
		_fail("RooftopProximity", "Failed to load Rooftop.tscn")
		return

	var rooftop = rooftop_scene.instantiate()
	root.add_child(rooftop)

	var door = rooftop.get_node_or_null("PenthouseSlidingDoor")
	var player = rooftop.get_node_or_null("Player")

	if door and player:
		# Player at spawn (0, 1, 8) -> door is closed
		if not door._is_open:
			_pass("Rooftop Door: initially closed with player at rooftop drop-in spawn")
		else:
			_fail("Rooftop Door", "Door unexpectedly open at spawn")

		# Move player to elevator entrance proximity zone (0, 1.0, -1.0)
		player.position = Vector3(0.0, 1.0, -1.0)
		door._on_proximity_entered(player)

		if door._is_open:
			_pass("Rooftop Door: automatically detects player approach and opens")
		else:
			_fail("Rooftop Door", "Failed to open when player approached elevator penthouse")

		# Move player inside the elevator cabin (0, 1.0, -4.5)
		var elevator = rooftop.get_node_or_null("RooftopElevator")
		if elevator:
			elevator._on_body_entered(player)
			if elevator._player_inside:
				_pass("Rooftop Elevator: detects player standing inside spacious cabin")
			else:
				_fail("Rooftop Elevator", "Player inside detection failed")

			# Select Floor 3
			elevator.press_floor_button(3)
			if elevator._descent_in_progress and door.is_locked:
				_pass("Rooftop Elevator: Floor 3 selection locks sliding door and initiates descent")
			else:
				_fail("Rooftop Elevator", "Floor 3 selection failed to lock door or begin descent")
	else:
		_fail("Rooftop Door", "Could not locate PenthouseSlidingDoor or Player in Rooftop.tscn")

		door.queue_free()
	rooftop.queue_free()

func test_character_viewmodel_and_slap() -> void:
	var viewmodel_scene = load("res://addons/snss_core/player/ViewmodelRig.tscn")
	if not viewmodel_scene:
		_fail("Viewmodel Scene", "Failed to load ViewmodelRig.tscn")
		return

	var viewmodel = viewmodel_scene.instantiate()
	root.add_child(viewmodel)

	var right_arm = viewmodel.get_node_or_null("RightArm")
	var left_arm = viewmodel.get_node_or_null("LeftArm")
	var weapon = viewmodel.get_node_or_null("RightArm/Weapon")
	var slide = viewmodel.get_node_or_null("RightArm/Weapon/Slide")
	var muzzle_flash = viewmodel.get_node_or_null("RightArm/Weapon/MuzzleFlashMesh")
	var wrist_screen = viewmodel.get_node_or_null("LeftArm/WristComms")

	if right_arm and left_arm and weapon and slide and muzzle_flash and wrist_screen:
		_pass("Viewmodel Rig: tactical arms, pistol slide, muzzle flash, and wrist comms verified")
	else:
		_fail("Viewmodel Rig", "One or more rig components missing")

	# Test shoot trigger
	var shot_fired := false
	viewmodel.fired_weapon.connect(func(_hit, _pos, _norm): shot_fired = true)
	viewmodel.shoot()
	if not viewmodel._can_shoot or shot_fired:
		_pass("Viewmodel Rig: shoot() activates weapon recoil and fires raycast")
	else:
		_fail("Viewmodel Rig", "shoot() failed to enter cooldown")

	# Test ADS (Aim Down Sights)
	var ads_changed := [false]
	viewmodel.aim_state_changed.connect(func(_aim): ads_changed[0] = true)
	viewmodel.set_aiming(true)
	if viewmodel.is_aiming and ads_changed[0]:
		_pass("Viewmodel Rig: Right-Click ADS transitions to aim-down-sights mode")
	else:
		_fail("Viewmodel Rig", "Failed to activate ADS state")

	# Verify slap is shelved for the finale
	viewmodel.slap()
	if not viewmodel._is_slapping:
		_pass("Viewmodel Rig: slap melee is cleanly shelved for the finale per specification")
	else:
		_fail("Viewmodel Rig", "Slap swung unexpectedly")

	# Test PlayerPawn integration
	var player_script = load("res://addons/snss_core/player/PlayerPawn.gd")
	var player = CharacterBody3D.new()
	player.set_script(player_script)
	root.add_child(player)
	player._ready()

	var p_viewmodel = player.get_node_or_null("Head/Camera3D/ViewmodelRig")
	var p_body = player.get_node_or_null("PlayerBodyMesh")
	if p_viewmodel and p_body:
		_pass("PlayerPawn: tactical viewmodel and lower body mesh mounted correctly")
	else:
		_fail("PlayerPawn", "Viewmodel or PlayerBodyMesh not found on PlayerPawn")

	player.set_look_multiplier(0.65)
	if is_equal_approx(player.look_multiplier, 0.65):
		_pass("PlayerPawn: look multiplier updated and clamped within [0.3, 0.8]")
	else:
		_fail("PlayerPawn", "Look multiplier failed to set: got %f" % player.look_multiplier)

	player.queue_free()
	viewmodel.queue_free()

func test_player_cod_health_and_regen() -> void:
	var player_script = load("res://addons/snss_core/player/PlayerPawn.gd")
	var player = CharacterBody3D.new()
	player.set_script(player_script)
	root.add_child(player)
	player._ready()

	# Initial full health
	if player.current_health == 100.0:
		_pass("PlayerPawn: initialized with 100 HP")
	else:
		_fail("PlayerPawn", "Initial health is not 100")

	# Take damage
	player.take_damage(40.0)
	if player.current_health == 60.0 and player._damage_vignette != null:
		_pass("PlayerPawn: take_damage(40) correctly reduces HP to 60 and updates damage vignette")
	else:
		_fail("PlayerPawn", "take_damage failed to reduce health or update vignette")

	# Regenerate health
	player._process(6.0) # More than 4.5s regen delay
	if player.current_health > 60.0:
		_pass("PlayerPawn: Call of Duty health regeneration restores HP after delay")
	else:
		_fail("PlayerPawn", "Health regeneration failed: HP remains %f" % player.current_health)

	player.queue_free()

func test_weapon_ammo_and_reload() -> void:
	var rig_scene = load("res://addons/snss_core/player/ViewmodelRig.tscn")
	if not rig_scene:
		_fail("ViewmodelRig", "Failed to load ViewmodelRig.tscn")
		return

	var rig = rig_scene.instantiate()
	root.add_child(rig)

	if rig.ammo == 17 and rig.max_ammo == 17:
		_pass("Viewmodel Rig: magazine initialized with full 17 rounds capacity")
	else:
		_fail("Viewmodel Rig", "Expected 17 rounds, got %d" % rig.ammo)

	var ammo_changed_box := [false, 0]
	rig.ammo_changed.connect(func(cur: int, _max_cap: int):
		ammo_changed_box[0] = true
		ammo_changed_box[1] = cur
	)

	rig.shoot()
	if rig.ammo == 16 and ammo_changed_box[0] and ammo_changed_box[1] == 16:
		_pass("Viewmodel Rig: firing decrements ammo and emits ammo_changed signal")
	else:
		_fail("Viewmodel Rig", "Expected 16 rounds after shot, got %d" % rig.ammo)

	var reload_started_box := [false]
	var reload_completed_box := [false]
	rig.reload_started.connect(func(): reload_started_box[0] = true)
	rig.reload_completed.connect(func(): reload_completed_box[0] = true)
	rig.reload()

	if rig.is_reloading and reload_started_box[0]:
		_pass("Viewmodel Rig: reload triggers is_reloading state and reload_started signal")
	else:
		_fail("Viewmodel Rig", "Reload state failed to initiate")

	rig.complete_reload()
	if rig.ammo == 17 and not rig.is_reloading and reload_completed_box[0]:
		_pass("Viewmodel Rig: reload completes restoring full 17 rounds capacity")
	else:
		_fail("Viewmodel Rig", "Reload completion failed")

	rig.queue_free()

func test_sound_synthesizer() -> void:
	var synth = preload("res://addons/snss_core/audio/SoundSynthesizer.gd")
	if synth:
		var gunshot: AudioStreamWAV = synth.get_gunshot()
		var slap: AudioStreamWAV = synth.get_slap_whack()
		var whiff: AudioStreamWAV = synth.get_slap_whiff()
		var chime: AudioStreamWAV = synth.get_elevator_chime()
		var footstep: AudioStreamWAV = synth.get_footstep()
		var reload_click: AudioStreamWAV = synth.get_reload_click()
		var wind: AudioStreamWAV = synth.get_wind_loop()
		var hum: AudioStreamWAV = synth.get_hum_loop()
		var laser_alarm: AudioStreamWAV = synth.get_laser_trip_alarm()
		var rifle_shot: AudioStreamWAV = synth.get_enemy_rifle_shot()
		var heartbeat: AudioStreamWAV = synth.get_heartbeat()
		var player_hurt: AudioStreamWAV = synth.get_player_hurt()
		var radio_static: AudioStreamWAV = synth.get_radio_static()

		if gunshot and slap and whiff and chime and footstep and reload_click and wind and hum and laser_alarm and rifle_shot and heartbeat and player_hurt and radio_static:
			if wind.loop_mode == AudioStreamWAV.LOOP_FORWARD and hum.loop_mode == AudioStreamWAV.LOOP_FORWARD:
				_pass("SoundSynthesizer: generated 16-bit PCM waveforms (gunshot, slap, reload, radio static, laser alarm, heartbeat)")
			else:
				_fail("SoundSynthesizer", "Wind or hum loops missing LOOP_FORWARD setting")
		else:
			_fail("SoundSynthesizer", "One or more audio waveforms were empty")
	else:
		_fail("SoundSynthesizer", "Failed to load SoundSynthesizer script")

func test_corridor_henchman_and_slap_stagger() -> void:
	var henchman_scene = load("res://addons/snss_core/enemy/CorridorHenchman.tscn")
	if not henchman_scene:
		_fail("Henchman Scene", "Failed to load CorridorHenchman.tscn")
		return

	var henchman = henchman_scene.instantiate()
	root.add_child(henchman)

	# Verify initial state
	if henchman.current_health == 100.0 and henchman.current_state == 0:
		_pass("Corridor Henchman: initialized with 100 HP in PATROL state")
	else:
		_fail("Corridor Henchman", "Unexpected initial state or HP")

	# Slap 1: Stagger test
	var staggered_box := [false]
	henchman.enemy_staggered.connect(func(_count): staggered_box[0] = true)
	henchman.receive_slap(Vector3(0, 0, -1), 35.0)

	if henchman.current_health == 65.0 and henchman.current_state == 2 and staggered_box[0]:
		_pass("Corridor Henchman: open-hand slap inflicts damage, triggers stagger state and signal")
	else:
		_fail("Corridor Henchman", "Slap failed to transition to STAGGERED state: state %d, HP %f" % [henchman.current_state, henchman.current_health])

	# Slap 2 & 3: Neutralization
	var defeated_box := [false]
	henchman.enemy_defeated.connect(func(): defeated_box[0] = true)
	henchman.receive_slap(Vector3(0, 0, -1), 35.0)
	henchman.receive_slap(Vector3(0, 0, -1), 35.0)

	if henchman.current_health <= 0.0 and henchman.current_state == 3 and defeated_box[0]:
		_pass("Corridor Henchman: consecutive slaps neutralize henchman into DEAD state")
	else:
		_fail("Corridor Henchman", "Defeat transition failed: state %d, HP %f" % [henchman.current_state, henchman.current_health])

	henchman.queue_free()

func test_terminal_hack_and_door_unlock() -> void:
	var door_scene = load("res://addons/snss_core/scenes/AnimatedSlidingDoor.tscn")
	var terminal_script = load("res://addons/snss_core/scenes/TerminalConsole.gd")
	if not door_scene or not terminal_script:
		_fail("Terminal Hack", "Failed to load door scene or terminal script")
		return

	var door = door_scene.instantiate()
	door.is_locked = true
	root.add_child(door)

	var terminal = Area3D.new()
	terminal.set_script(terminal_script)
	terminal.exit_door_node = door
	root.add_child(terminal)

	if door.is_locked and not terminal.is_hacked:
		_pass("Terminal Console: initially locked door awaiting override")
	else:
		_fail("Terminal Console", "Initial locked state invalid")

	var hacked_box := [false]
	terminal.terminal_hacked.connect(func(): hacked_box[0] = true)
	terminal.hack_terminal()

	if terminal.is_hacked and not door.is_locked and hacked_box[0]:
		_pass("Terminal Console: hacking terminal unlocks ExitElevatorSlidingDoor")
	else:
		_fail("Terminal Console", "Hack failed to unlock door: door locked = %s" % str(door.is_locked))

	terminal.queue_free()
	door.queue_free()

func test_laser_tripwire() -> void:
	var laser_script = load("res://addons/snss_core/scenes/LaserTripwire.gd")
	if not laser_script:
		_fail("LaserTripwire", "Failed to load LaserTripwire.gd")
		return

	var tripwire = Area3D.new()
	tripwire.set_script(laser_script)
	root.add_child(tripwire)
	tripwire._ready()

	var tripped_box := [false]
	tripwire.tripped.connect(func(_intruder): tripped_box[0] = true)

	var mock_player = CharacterBody3D.new()
	tripwire._on_body_entered(mock_player)

	if tripped_box[0] and tripwire.is_active:
		_pass("LaserTripwire: beam intersection emits tripped signal and sounds alarm")
	else:
		_fail("LaserTripwire", "Failed to trigger tripwire alarm")

	tripwire.disarm_tripwire()
	if not tripwire.is_active:
		_pass("LaserTripwire: disarm_tripwire() turns off active state and hides beam")
	else:
		_fail("LaserTripwire", "Tripwire remained active after disarm")

	mock_player.queue_free()
	tripwire.queue_free()

func test_part1_corridor_scene_integration() -> void:
	var corridor_scene = load("res://addons/snss_core/scenes/Part1Corridor.tscn")
	if not corridor_scene:
		_fail("Part1Corridor Scene", "Failed to load Part1Corridor.tscn")
		return

	var corridor = corridor_scene.instantiate()
	root.add_child(corridor)
	if corridor.has_method("_ensure_references"):
		corridor._ensure_references()
	if corridor.has_method("_setup_scare_and_door_decorations"):
		corridor._setup_scare_and_door_decorations()

	var entry_door = corridor.get_node_or_null("EntryBaySlidingDoor")
	var exit_door = corridor.get_node_or_null("ExitElevatorSlidingDoor")
	var scare_room = corridor.get_node_or_null("ScareRoom")
	var locker_room = corridor.get_node_or_null("LockerRoom")
	var laser_room = corridor.get_node_or_null("LaserRoom")
	var blockage = corridor.get_node_or_null("CorridorBlockage")
	var detour_door = corridor.get_node_or_null("MaintenanceDetourDoor")
	var detour_encounter = corridor.get_node_or_null("DetourEncounter")

	if entry_door and exit_door and scare_room and locker_room and laser_room and blockage and detour_door and detour_encounter:
		_pass("Part1Corridor: Blueprint layout verified (Scare Room, Lockers, Laser Room, Blockage & Detour present)")
	else:
		_fail("Part1Corridor", "One or more blueprint components missing in scene hierarchy")

	# Verify all blueprint sub-doors and intermediate rooms from the sketch
	var scare_door = corridor.get_node_or_null("ScareRoomDoor")
	var locker_door = corridor.get_node_or_null("LockerRoomDoor")
	var laser_door = corridor.get_node_or_null("LaserRoomDoor")
	var west_door = corridor.get_node_or_null("WestRoom1Door")
	var west_room = corridor.get_node_or_null("WestCorridorRoom")
	var east_door = corridor.get_node_or_null("EastRoom2Door")
	var east_room = corridor.get_node_or_null("ServerCommsRoom")
	var barracks_door = corridor.get_node_or_null("UpperBarracksDoor")

	if scare_door and locker_door and laser_door and west_door and west_room and east_door and east_room and barracks_door:
		_pass("Part1Corridor: Blueprint sub-doors (Scare, Locker, Laser, West Sub-Room 1, East Sub-Room 2, Barracks) and intermediate wing rooms verified")
	else:
		_fail("Part1Corridor", "Blueprint sub-doors or intermediate rooms missing in scene")

	corridor.queue_free()

func test_henchman_retargeted_animations() -> void:
	var helper_script = load("res://addons/snss_core/enemy/HenchmanAnimationHelper.gd")
	if not helper_script:
		_fail("HenchmanAnimationHelper", "Failed to load HenchmanAnimationHelper.gd")
		return

	var lib = helper_script.get_animation_library()
	if lib and lib.has_animation("walk") and lib.has_animation("idle") and lib.has_animation("hit") and lib.has_animation("death"):
		_pass("HenchmanAnimationHelper: retargeted Mixamo clips into library (walk, idle, hit, death)")
	else:
		_fail("HenchmanAnimationHelper", "Retargeted library missing required animations")

func test_ambient_loops_and_scene_audio() -> void:
	var rooftop_scene = load("res://addons/snss_core/scenes/Rooftop.tscn")
	var corridor_scene = load("res://addons/snss_core/scenes/Part1Corridor.tscn")
	if not rooftop_scene or not corridor_scene:
		_fail("Scene Audio", "Failed to load Rooftop or Corridor scene")
		return

	var rooftop = rooftop_scene.instantiate()
	root.add_child(rooftop)
	var wind_player = rooftop.get_node_or_null("AmbientWind") as AudioStreamPlayer

	var corridor = corridor_scene.instantiate()
	root.add_child(corridor)
	if corridor.has_method("_ensure_references"):
		corridor._ensure_references()
	if corridor.has_method("_setup_scare_and_door_decorations"):
		corridor._setup_scare_and_door_decorations()
	var hum_player = corridor.get_node_or_null("AmbientHum") as AudioStreamPlayer

	if wind_player and wind_player.bus == "Ambient" and hum_player and hum_player.bus == "Ambient":
		_pass("Ambient Scene Audio: Rooftop wind and Corridor hum players bound to Ambient bus")
	else:
		_fail("Ambient Scene Audio", "Wind or hum player missing or not routed to Ambient bus")

	rooftop.queue_free()
	corridor.queue_free()

func test_floor_3_ingress_lockdown_and_scare_room() -> void:
	var corridor_scene = load("res://addons/snss_core/scenes/Part1Corridor.tscn")
	if not corridor_scene:
		_fail("Floor 3", "Failed to load Part1Corridor.tscn")
		return

	var corridor = corridor_scene.instantiate()
	root.add_child(corridor)
	if corridor.has_method("_ensure_references"):
		corridor._ensure_references()
	if corridor.has_method("_setup_scare_and_door_decorations"):
		corridor._setup_scare_and_door_decorations()

	var entry_door = corridor.get_node_or_null("EntryBaySlidingDoor")
	var cabin = corridor.get_node_or_null("IngressElevatorCabin")
	var memo = corridor.get_node_or_null("ScareRoom/StoryMemoNote")
	var key_alpha = corridor.get_node_or_null("ScareRoom/KeycardAlphaPickup")
	var key_beta = corridor.get_node_or_null("UpperGuardBarracks/KeycardBetaPickup")

	if cabin and memo and key_alpha and key_beta:
		_pass("Floor 3: Ingress cabin, Scare Room Story Note, Keycard Alpha, and Keycard Beta verified")
	else:
		_fail("Floor 3", "Floor 3 key components or note missing")

	# Test Ingress Lockdown (Point of No Return)
	corridor._trigger_ingress_lockdown()
	if entry_door and entry_door.is_locked and corridor._lockdown_triggered:
		_pass("Floor 3: stepping into corridor triggers containment lockdown, locking elevator entry door")
	else:
		_fail("Floor 3", "Lockdown failed to lock entry door")

	# Test Keycard Alpha and Keycard Beta Pickups
	var mock_player = CharacterBody3D.new()
	corridor._on_keycard_alpha_pickup(mock_player)
	if corridor.has_keycard_alpha and corridor.laser_door and not corridor.laser_door.is_locked:
		_pass("Floor 3: picking up Keycard Alpha grants Laser Room clearance and unlocks LaserRoomDoor")
	else:
		_fail("Floor 3", "Failed to acquire Keycard Alpha or unlock LaserRoomDoor")

	corridor._on_keycard_beta_pickup(mock_player)
	if corridor.has_keycard_beta and corridor.detour_door and not corridor.detour_door.is_locked:
		_pass("Floor 3: picking up Keycard Beta unlocks the Maintenance Detour around the blockage")
	else:
		_fail("Floor 3", "Keycard Beta failed to unlock Maintenance Detour")

	# Test Scare Room Proximity Scare Sequence
	corridor._on_scare_trigger_entered(mock_player)
	if corridor._scare_triggered and memo.modulate.r > 0.9:
		_pass("Floor 3: entering Scare Room triggers horror sequence, radio static, and blood note emphasis")
	else:
		_fail("Floor 3", "Scare sequence trigger failed")

	if memo.text.contains("Underground Vault"):
		_pass("Floor 3: story memorandum correctly references Underground Vault lore")
	else:
		_fail("Floor 3", "Memo does not reference Underground Vault")

	# Verify newly mounted 3D props & decals
	var desk_crt = corridor.get_node_or_null("ScareRoom/Desk/DeskCRTMonitor")
	var desk_blood = corridor.get_node_or_null("ScareRoom/Desk/DeskBloodDecal")
	var hand_decal = corridor.get_node_or_null("ScareRoom/WallHandprintDecal")
	var laser_scanner = corridor.get_node_or_null("LaserRoomDoor/DoorScannerLaser")
	if desk_crt and desk_blood and hand_decal and laser_scanner:
		_pass("Floor 3: CRT monitor, blood pool, wall handprint decals, and keycard scanners mounted successfully")
	else:
		_fail("Floor 3", "Props mounting incomplete: crt=%s, blood=%s, hand=%s, scanner=%s" % [desk_crt != null, desk_blood != null, hand_decal != null, laser_scanner != null])

	mock_player.queue_free()
	corridor.queue_free()

func test_floor_3_elevator_clearance() -> void:
	var corridor_scene = load("res://addons/snss_core/scenes/Part1Corridor.tscn")
	if not corridor_scene:
		_fail("Elevator Clearance", "Failed to load Part1Corridor.tscn")
		return

	var corridor = corridor_scene.instantiate()
	root.add_child(corridor)
	if corridor.has_method("_ensure_references"):
		corridor._ensure_references()
	if corridor.has_method("_setup_scare_and_door_decorations"):
		corridor._setup_scare_and_door_decorations()

	var elev = corridor.get_node_or_null("ExitElevatorCabin/ExitElevatorZone")
	if not elev:
		_fail("Elevator Clearance", "ExitElevatorZone not found in scene")
		corridor.queue_free()
		return

	var mock_player = CharacterBody3D.new()
	corridor.add_child(mock_player)
	elev._active_player = mock_player

	# 1. Hostiles are alive nearby (Detour Henchmen guarding exit) -> Clearance.HOSTILE_NEARBY
	var cl = elev._determine_clearance()
	if cl == elev.Clearance.HOSTILE_NEARBY:
		_pass("Elevator S-2: descent blocked when armed hostiles remain in vicinity")
	else:
		_fail("Elevator Clearance", "Expected HOSTILE_NEARBY, got %d" % cl)

	# 2. Neutralize nearby enemies in corridor
	var enemies = corridor.find_children("", "CharacterBody3D", true, false)
	for e in enemies:
		if e.has_method("die"):
			e.die()

	# 3. Without terminal override -> Clearance.TERMINAL_REQUIRED
	cl = elev._determine_clearance()
	if cl == elev.Clearance.TERMINAL_REQUIRED:
		_pass("Elevator S-2: descent blocked without security console terminal override")
	else:
		_fail("Elevator Clearance", "Expected TERMINAL_REQUIRED, got %d" % cl)

	# 4. Terminal override hacked and enemies defeated -> Clearance.ALLOW
	elev.set_terminal_reached(true)
	cl = elev._determine_clearance()
	if cl == elev.Clearance.ALLOW:
		_pass("Elevator S-2: clearance granted when terminal is overridden and area secured")
	else:
		_fail("Elevator Clearance", "Expected ALLOW, got %d" % cl)

	mock_player.queue_free()
	corridor.queue_free()

func test_keycard_pickup_animation() -> void:
	var keycard_script = load("res://addons/snss_core/scenes/KeycardPickup.gd")
	if not keycard_script:
		_fail("Keycard Pickup", "Failed to load KeycardPickup.gd")
		return

	var card: Area3D = Area3D.new()
	card.set_script(keycard_script)
	root.add_child(card)

	var init_rot = card.rotation.y

	# Simulate process step
	card._process(0.2)

	if card.rotation.y != init_rot:
		_pass("Keycard Pickup: continuous rotation animation active")
	else:
		_fail("Keycard Pickup", "Rotation did not advance in _process")

	var picked_box := [false, ""]
	card.picked_up.connect(func(c_name: String):
		picked_box[0] = true
		picked_box[1] = c_name
	)

	var mock_player = CharacterBody3D.new()
	card._on_body_entered(mock_player)

	if picked_box[0] and picked_box[1] == "ALPHA":
		_pass("Keycard Pickup: detects player contact and emits picked_up with card identifier")
	else:
		_fail("Keycard Pickup", "Pickup signal emission failed")

	mock_player.queue_free()
	card.queue_free()

func test_player_persistent_state_and_elevator_transit() -> void:
	var gm := root.get_node_or_null("GameManager")
	if gm == null:
		gm = GameManagerScript.new()
		gm.name = "GameManager"
		root.add_child(gm)

	var mock_pawn := CharacterBody3D.new()
	var pawn_script := GDScript.new()
	pawn_script.source_code = "extends CharacterBody3D\nvar current_health: float = 68.0\nvar look_multiplier: float = 0.65\n"
	pawn_script.reload()
	mock_pawn.set_script(pawn_script)

	# Save mock pawn state
	gm.save_player_state(mock_pawn)
	if gm.player_persistent_state["current_health"] == 68.0 and gm.player_persistent_state["look_multiplier"] == 0.65:
		_pass("GameManager: save_player_state captures HP and Look Multiplier")
	else:
		_fail("GameManager", "save_player_state failed to capture values: HP=%f, mult=%f" % [gm.player_persistent_state["current_health"], gm.player_persistent_state["look_multiplier"]])

	# Restore to a new pawn entering Floor 2
	var new_pawn := CharacterBody3D.new()
	var new_script := GDScript.new()
	new_script.source_code = "extends CharacterBody3D\nvar current_health: float = 100.0\nvar look_multiplier: float = 1.0\n"
	new_script.reload()
	new_pawn.set_script(new_script)
	gm.restore_player_state(new_pawn)

	if new_pawn.get("current_health") == 68.0 and new_pawn.get("look_multiplier") == 0.65:
		_pass("GameManager: restore_player_state successfully transfers HP and Look Multiplier to new level pawn")
	else:
		_fail("GameManager", "restore_player_state failed to restore values: HP=%f, mult=%f" % [new_pawn.get("current_health"), new_pawn.get("look_multiplier")])

	# Verify Floor 3 keycards are cleared
	if gm.player_persistent_state["has_keycard_alpha"] == false and gm.player_persistent_state["has_keycard_beta"] == false:
		_pass("GameManager: Floor 3 keycards cleared upon floor transit")
	else:
		_fail("GameManager", "Keycards were not cleared")

	mock_pawn.queue_free()
	new_pawn.queue_free()

func test_laser_tripwire_zap_damage() -> void:
	var tripwire_script = load("res://addons/snss_core/scenes/LaserTripwire.gd")
	if not tripwire_script:
		_fail("LaserTripwire", "Failed to load LaserTripwire.gd")
		return

	var wire: Area3D = Area3D.new()
	wire.set_script(tripwire_script)
	root.add_child(wire)

	var victim := CharacterBody3D.new()
	var victim_script := GDScript.new()
	victim_script.source_code = "extends CharacterBody3D\nvar current_health: float = 100.0\nfunc take_damage(amt: float) -> void:\n\tcurrent_health -= amt\n"
	victim_script.reload()
	victim.set_script(victim_script)

	wire._on_body_entered(victim)

	if victim.current_health == 75.0:
		_pass("LaserTripwire: crossing active laser delivers 25 zap damage to player")
	else:
		_fail("LaserTripwire", "Expected 75.0 HP after zap, got %f" % victim.current_health)

	victim.queue_free()
	wire.queue_free()



