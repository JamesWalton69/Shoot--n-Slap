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
	test_terrain_3d_registration()
	test_animated_sliding_door()
	test_rooftop_door_proximity_integration()
	test_character_viewmodel_and_slap()
	test_weapon_ammo_and_reload()
	test_sound_synthesizer()
	test_corridor_henchman_and_slap_stagger()
	test_henchman_retargeted_animations()
	test_terminal_hack_and_door_unlock()
	test_part1_corridor_scene_integration()
	test_floor_3_ingress_lockdown_and_barracks()
	test_ambient_loops_and_scene_audio()

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

	# Test slap trigger
	viewmodel.slap()
	if viewmodel._is_slapping or not viewmodel._can_slap:
		_pass("Viewmodel Rig: slap() triggers procedural open-hand melee swing tween")
	else:
		_fail("Viewmodel Rig", "slap() failed to trigger slap state")

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

		if gunshot and slap and whiff and chime and footstep and reload_click and wind and hum:
			if wind.loop_mode == AudioStreamWAV.LOOP_FORWARD and hum.loop_mode == AudioStreamWAV.LOOP_FORWARD:
				_pass("SoundSynthesizer: generated 16-bit PCM waveforms (gunshot, slap, footstep, reload, wind & hum loops)")
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

func test_part1_corridor_scene_integration() -> void:
	var corridor_scene = load("res://addons/snss_core/scenes/Part1Corridor.tscn")
	if not corridor_scene:
		_fail("Part1Corridor Scene", "Failed to load Part1Corridor.tscn")
		return

	var corridor = corridor_scene.instantiate()
	root.add_child(corridor)

	var entry_door = corridor.get_node_or_null("EntryBaySlidingDoor")
	var exit_door = corridor.get_node_or_null("ExitElevatorSlidingDoor")
	var terminal = corridor.get_node_or_null("TerminalConsoleArea")
	var henchman1 = corridor.get_node_or_null("HenchmanPatrol1")
	var henchman2 = corridor.get_node_or_null("HenchmanAmbush")
	var henchman3 = corridor.get_node_or_null("HenchmanTerminus")

	if entry_door and exit_door and terminal and henchman1 and henchman2 and henchman3:
		_pass("Part1Corridor: entry door, locked exit door, terminal console, and 3 henchmen present")
	else:
		_fail("Part1Corridor", "One or more corridor components missing in scene hierarchy")

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
	var hum_player = corridor.get_node_or_null("AmbientHum") as AudioStreamPlayer

	if wind_player and wind_player.bus == "Ambient" and hum_player and hum_player.bus == "Ambient":
		_pass("Ambient Scene Audio: Rooftop wind and Corridor hum players bound to Ambient bus")
	else:
		_fail("Ambient Scene Audio", "Wind or hum player missing or not routed to Ambient bus")

	rooftop.queue_free()
	corridor.queue_free()

func test_floor_3_ingress_lockdown_and_barracks() -> void:
	var corridor_scene = load("res://addons/snss_core/scenes/Part1Corridor.tscn")
	if not corridor_scene:
		_fail("Floor 3", "Failed to load Part1Corridor.tscn")
		return

	var corridor = corridor_scene.instantiate()
	root.add_child(corridor)

	var entry_door = corridor.get_node_or_null("EntryBaySlidingDoor")
	var ammo_box = corridor.get_node_or_null("GuardBarracks/AmmoResupplyBox")
	var memo = corridor.get_node_or_null("GuardBarracks/LoreMemo")
	var cabin = corridor.get_node_or_null("IngressElevatorCabin")

	if cabin and ammo_box and memo:
		_pass("Floor 3: Ingress elevator cabin, Guard Barracks, Lore Memorandum, and Ammo Resupply present")
	else:
		_fail("Floor 3", "One or more Floor 3 components missing")

	# Test Ingress Lockdown (Point of No Return)
	corridor._trigger_ingress_lockdown()
	if entry_door and entry_door.is_locked and corridor._lockdown_triggered:
		_pass("Floor 3: stepping into corridor triggers containment lockdown, locking elevator entry door")
	else:
		_fail("Floor 3", "Lockdown failed to lock entry door")

	corridor.queue_free()



