class_name Part2Warzone
extends Node3D
## Part2Warzone - Floor 2: Warzone Warehouse & Security Complex.
## Fully procedural scene generator. Entry: Shaft S-2 (south bay).
## Objective: hack the Central Security Mainframe, eliminate the Garrison
## Commander in Warehouse B, then extract through Service Shaft S-1 (north).
## Pooja is NOT on this floor; she is held in the Sub-Basement Vault.
## This script must be the root script of the loaded scene so the henchman AI
## (which resolves current_scene/Player) can find the player.

const HENCHMAN_SCENE := preload("res://addons/snss_core/enemy/CorridorHenchman.tscn")
const DOOR_SCENE := preload("res://addons/snss_core/scenes/AnimatedSlidingDoor.tscn")
const PLAYER_SCRIPT := preload("res://addons/snss_core/player/PlayerPawn.gd")

const MAT_FLOOR := preload("res://addons/snss_core/materials/mat_concrete_floor.tres")
const MAT_WALL := preload("res://addons/snss_core/materials/mat_industrial_wall.tres")
const MAT_RUST := preload("res://addons/snss_core/materials/mat_rusted_metal.tres")
const MAT_CEILING := preload("res://addons/snss_core/materials/mat_ceiling_steel.tres")
const MAT_CABIN := preload("res://addons/snss_core/materials/mat_elevator_cabin.tres")
const MAT_HAZARD := preload("res://addons/snss_core/materials/mat_hazard_trim.tres")
const MAT_SCREEN := preload("res://addons/snss_core/materials/mat_terminal_screen.tres")
const MAT_DIAMOND := preload("res://addons/snss_core/materials/mat_diamond_plate.tres")
const MAT_CRATE := preload("res://addons/snss_core/materials/mat_cargo_crate.tres")
const MAT_PALLET := preload("res://addons/snss_core/materials/mat_wooden_pallet.tres")
const MAT_TUBE := preload("res://addons/snss_core/materials/mat_fluorescent_tube.tres")
const MAT_GUNMETAL := preload("res://addons/snss_core/materials/mat_gun_metal.tres")
const MAT_CAGED := preload("res://addons/snss_core/materials/mat_caged_housing.tres")
const MAT_READOUT := preload("res://addons/snss_core/materials/mat_digital_readout.tres")
const MAT_ARMOR := preload("res://addons/snss_core/materials/mat_armor_plate.tres")

const HACK_SECONDS := 12.0
const BOSS_MAX_HEALTH := 600.0
const WAREHOUSE_HEIGHT := 9.0

var player
var mainframe_hacked := false
var commander_dead := false
var exit_unlocked := false

var _geometry: CSGCombiner3D
var _entry_door: Node3D
var _bunker_south_door: Node3D
var _bunker_north_door: Node3D
var _exit_door: Node3D
var _exit_sign: Label3D
var _entry_sign: Label3D
var _mainframe_screen: CSGBox3D
var _mainframe_label: Label3D
var _commander
var _commander_label: Label3D
var _cameras: Array[Dictionary] = []
var _alarm_lights: Array[OmniLight3D] = []

var _hud_layer: CanvasLayer
var _objective_label: Label
var _prompt_label: Label
var _warning_label: Label
var _hack_bar: ProgressBar
var _boss_bar: ProgressBar
var _end_layer: CanvasLayer
var _end_fade: ColorRect
var _end_title: Label
var _end_subtitle: Label

var _mainframe_in_range := false
var _exit_panel_in_range := false
var _entry_locked := false
var _hack_started := false
var _wave2_spawned := false
var _alarm_active := false
var _boss_active := false
var _boss_phase := 1
var _boss_slam_cooldown := 4.0
var _floor_finished := false
var _hack_progress := 0.0
var _time := 0.0
var _cam_scan_timer := 0.0
var _warning_timer := 0.0
var _last_player_health := 100.0
var _camera_wave_spawned := false

func _ready() -> void:
	print("[Floor 2] Building Warzone Warehouse & Security Complex...")
	_geometry = CSGCombiner3D.new()
	_geometry.name = "Geometry"
	_geometry.use_collision = true
	add_child(_geometry)

	_build_environment()
	_build_shell()
	_build_south_bay()
	_build_warehouse_a()
	_build_bunker()
	_build_warehouse_b()
	_build_north_bay()
	_build_lights()
	_build_player()
	_build_doors()
	_build_triggers()
	_build_mainframe()
	_build_exit_panel()
	_build_cameras()
	_build_hud()
	_update_objective("HACK THE CENTRAL MAINFRAME // ELIMINATE THE GARRISON COMMANDER")
	# Wait for the generated CSG collision before enemies can scan for line of sight.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_spawn_garrison()
	_spawn_resupply(Vector3(-7, 0, 12))
	_spawn_resupply(Vector3(8, 0, -6.5))
	_warn("FLOOR 2 // WARZONE WAREHOUSE", 4.0)
	_self_check()

func _self_check() -> void:
	assert(_entry_door != null, "S-2 entry door missing")
	assert(_exit_door != null and bool(_exit_door.get("is_locked")), "S-1 must start locked")
	assert(_bunker_south_door != null and _bunker_north_door != null, "bunker doors missing")
	assert(player != null and player.position.z > 17.0, "player must spawn in the S-2 bay")
	assert(_mainframe_screen != null and _commander != null, "objective props missing")
	assert(HACK_SECONDS >= 10.0 and BOSS_MAX_HEALTH > 100.0, "combat tuning invalid")

# ---------------------------------------------------------------- utilities

func _box(node_name: String, size: Vector3, pos: Vector3, mat: Material, collision := true) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.name = node_name
	b.size = size
	b.position = pos
	b.material = mat
	b.use_collision = collision
	_geometry.add_child(b)
	return b

func _cyl(node_name: String, radius: float, height: float, pos: Vector3, mat: Material, collision := true) -> CSGCylinder3D:
	var c := CSGCylinder3D.new()
	c.name = node_name
	c.radius = radius
	c.height = height
	c.position = pos
	c.material = mat
	c.use_collision = collision
	_geometry.add_child(c)
	return c

func _light(pos: Vector3, energy := 1.4, light_range := 16.0, color := Color(1.0, 0.92, 0.78), shadows := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_energy = energy
	l.omni_range = light_range
	l.light_color = color
	l.shadow_enabled = shadows
	add_child(l)
	return l

func _label(text: String, pos: Vector3, size := 32, color := Color(0.75, 0.95, 1.0), billboard := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = size
	l.modulate = color
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	add_child(l)
	return l

func _emissive(color: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

# ---------------------------------------------------------------- environment

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.01, 0.016)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.36, 0.45)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(-58, -35, 0)
	fill.light_energy = 0.22
	fill.light_color = Color(0.6, 0.7, 0.9)
	add_child(fill)

func _build_shell() -> void:
	_box("Floor_Main", Vector3(52, 0.2, 44), Vector3(0, -0.1, 0), MAT_FLOOR)
	_box("Ceiling_Main", Vector3(52, 0.2, 44), Vector3(0, WAREHOUSE_HEIGHT + 0.1, 0), MAT_CEILING)
	_box("Wall_South", Vector3(52, WAREHOUSE_HEIGHT, 0.5), Vector3(0, WAREHOUSE_HEIGHT * 0.5, 22), MAT_WALL)
	_box("Wall_North", Vector3(52, WAREHOUSE_HEIGHT, 0.5), Vector3(0, WAREHOUSE_HEIGHT * 0.5, -22), MAT_WALL)
	_box("Wall_East", Vector3(0.5, WAREHOUSE_HEIGHT, 44), Vector3(26, WAREHOUSE_HEIGHT * 0.5, 0), MAT_WALL)
	_box("Wall_West", Vector3(0.5, WAREHOUSE_HEIGHT, 44), Vector3(-26, WAREHOUSE_HEIGHT * 0.5, 0), MAT_WALL)

	for x in [-18.0, 18.0]:
		for z in [-13.0, -7.0, 7.0, 13.0]:
			_box("Pillar_%d_%d" % [int(x), int(z)], Vector3(1.1, WAREHOUSE_HEIGHT, 1.1), Vector3(x, WAREHOUSE_HEIGHT * 0.5, z), MAT_WALL)
			_box("PillarTrim_%d_%d" % [int(x), int(z)], Vector3(1.35, 0.5, 1.35), Vector3(x, 1.3, z), MAT_HAZARD, false)

# ---------------------------------------------------------------- south bay / S-2

func _build_south_bay() -> void:
	# Bay side walls
	_box("S2_BayWall_West", Vector3(0.4, WAREHOUSE_HEIGHT, 5.2), Vector3(-6, WAREHOUSE_HEIGHT * 0.5, 19.4), MAT_WALL)
	_box("S2_BayWall_East", Vector3(0.4, WAREHOUSE_HEIGHT, 5.2), Vector3(6, WAREHOUSE_HEIGHT * 0.5, 19.4), MAT_WALL)
	# Front wall with a 2.5 m doorway at x = 0
	_box("S2_FrontWall_West", Vector3(4.75, WAREHOUSE_HEIGHT, 0.4), Vector3(-3.625, WAREHOUSE_HEIGHT * 0.5, 17), MAT_WALL)
	_box("S2_FrontWall_East", Vector3(4.75, WAREHOUSE_HEIGHT, 0.4), Vector3(3.625, WAREHOUSE_HEIGHT * 0.5, 17), MAT_WALL)
	_box("S2_FrontLintel", Vector3(2.5, 6.5, 0.4), Vector3(0, 5.75, 17), MAT_WALL)
	# Elevator cabin shell
	_box("S2_CabinWall_West", Vector3(0.25, 4.0, 4.8), Vector3(-3, 2.0, 19.6), MAT_CABIN)
	_box("S2_CabinWall_East", Vector3(0.25, 4.0, 4.8), Vector3(3, 2.0, 19.6), MAT_CABIN)
	_box("S2_CabinCeiling", Vector3(6, 0.3, 5), Vector3(0, 4.05, 19.5), MAT_CABIN)
	_box("S2_CabinFloor", Vector3(6, 0.02, 5), Vector3(0, 0.01, 19.5), MAT_DIAMOND, false)
	_box("S2_CabinBack", Vector3(6, 4, 0.3), Vector3(0, 2, 21.8), MAT_CABIN)
	# Cab interior dressing
	_box("S2_Bench", Vector3(4.4, 0.45, 0.6), Vector3(0, 0.5, 21.4), MAT_GUNMETAL)
	_box("S2_CabinTrim", Vector3(6.2, 0.12, 5.2), Vector3(0, 4.2, 19.5), MAT_HAZARD, false)
	_entry_sign = _label("SHAFT S-2 // INGRESS\nFLOOR 2: WARZONE WAREHOUSE", Vector3(0, 3.4, 17.3), 30, Color(0.5, 0.95, 1.0))
	_label("NO RETREAT AUTHORIZED", Vector3(0, 2.9, 21.55), 22, Color(1.0, 0.35, 0.3))
	# Crate clutter just outside the cabin
	_box("S2_Crate_A", Vector3(1.4, 1.2, 1.1), Vector3(-4.7, 0.6, 18.6), MAT_CRATE)
	_box("S2_Crate_B", Vector3(1.0, 0.9, 1.0), Vector3(4.6, 0.45, 18.9), MAT_CRATE)
	_box("S2_Crate_C", Vector3(1.1, 0.8, 1.1), Vector3(-4.5, 0.4, 16.5), MAT_CRATE)

# ---------------------------------------------------------------- warehouse A

func _build_warehouse_a() -> void:
	_container(Vector3(-16, 0, 11), 0.0, 0)
	_container(Vector3(-16.1, 0, 11), 0.12, 1)
	_container(Vector3(15, 0, 12), 0.0, 0)
	_container(Vector3(15, 0, 12), 0.0, 1)
	_container(Vector3(-17, 0, 4.2), 1.57, 0)
	_container(Vector3(12, 0, 5.5), 0.35, 0)
	_container(Vector3(7, 0, 8.8), 1.57, 0)

	_pallet(Vector3(-6, 0, 14))
	_pallet(Vector3(-5.2, 0, 14.2))
	_pallet(Vector3(4, 0, 12.5))
	_barrel(Vector3(8.5, 0, 13.6))
	_barrel(Vector3(9.2, 0, 13.9))
	_barrel(Vector3(-10, 0, 7.5))
	_barrel(Vector3(-9.3, 0, 7.2))

	# Damaged forklift silhouette
	_box("Forklift_Body", Vector3(2.2, 1.1, 1.4), Vector3(-3, 0.55, 6.4), MAT_HAZARD)
	_box("Forklift_Mast", Vector3(0.25, 2.6, 0.3), Vector3(-2.0, 1.3, 6.4), MAT_RUST)
	_box("Forklift_Forks", Vector3(0.18, 0.12, 2.0), Vector3(-2.0, 0.25, 7.4), MAT_RUST)
	_cyl("Forklift_Wheel_L", 0.45, 0.3, Vector3(-3.7, 0.45, 5.8), MAT_GUNMETAL)
	_cyl("Forklift_Wheel_R", 0.45, 0.3, Vector3(-2.3, 0.45, 5.8), MAT_GUNMETAL)

	_catwalk()
	# Wall signage
	_label("WAREHOUSE A\nCARGO STAGING", Vector3(-25.6, 6.2, 9), 40, Color(0.95, 0.75, 0.35), false)
	_label("AUTHORIZED PERSONNEL ONLY", Vector3(25.6, 6.2, 9), 26, Color(1.0, 0.45, 0.3), false)

func _container(pos: Vector3, rot_y: float, level: int) -> void:
	var y := 1.295 + level * 2.6
	var c := _box("Container_%d_%d_%d" % [int(pos.x), int(pos.z), level], Vector3(6.06, 2.59, 2.44), Vector3(pos.x, y, pos.z), MAT_CRATE)
	c.rotation.y = rot_y
	var trim := _box("ContainerTrim_%d_%d_%d" % [int(pos.x), int(pos.z), level], Vector3(6.1, 0.16, 2.5), Vector3(pos.x, y + 1.12, pos.z), MAT_HAZARD, false)
	trim.rotation.y = rot_y

func _pallet(pos: Vector3) -> void:
	_box("Pallet", Vector3(1.3, 0.16, 1.0), Vector3(pos.x, 0.08, pos.z), MAT_PALLET)
	_box("PalletCargo", Vector3(1.1, 0.7, 0.85), Vector3(pos.x, 0.5, pos.z), MAT_CRATE)

func _barrel(pos: Vector3) -> void:
	_cyl("Barrel", 0.38, 0.92, Vector3(pos.x, 0.46, pos.z), MAT_RUST)
	_cyl("BarrelBand", 0.4, 0.1, Vector3(pos.x, 0.68, pos.z), MAT_HAZARD, false)

func _catwalk() -> void:
	# East-wall elevated walkway in Warehouse A.
	_box("Catwalk_Deck", Vector3(2.8, 0.25, 5.9), Vector3(23.6, 5.4, 5.45), MAT_DIAMOND)
	_box("Catwalk_KickPlate", Vector3(0.08, 0.3, 5.9), Vector3(22.2, 5.6, 5.45), MAT_HAZARD, false)
	var rail := _box("Catwalk_Rail", Vector3(0.09, 1.0, 5.2), Vector3(22.2, 6.0, 5.0), MAT_RUST)
	rail.use_collision = true
	var i := 0
	var z := 2.6
	while z < 7.4:
		_box("Catwalk_Post_%d" % i, Vector3(0.09, 1.1, 0.09), Vector3(22.2, 6.0, z), MAT_RUST, false)
		z += 2.4
		i += 1
	# Support pillars
	for sz in [3.5, 7.5]:
		_box("Catwalk_Support_%d" % int(sz), Vector3(0.6, 5.4, 0.6), Vector3(24.7, 2.7, sz), MAT_WALL)
	# Walkable access ramp down to the warehouse floor (south end).
	var ramp := _box("Catwalk_Ramp", Vector3(2.8, 0.25, 9.2), Vector3(23.6, 2.7, 11.95), MAT_DIAMOND)
	ramp.rotation.x = 0.65
	var ramp_rail := _box("Catwalk_RampRail", Vector3(0.09, 1.0, 9.2), Vector3(22.3, 3.7, 11.95), MAT_RUST)
	ramp_rail.rotation.x = 0.65

# ---------------------------------------------------------------- bunker

func _build_bunker() -> void:
	# 16 x 6 m hardened room between the two warehouse halls (ceiling 3.6 m).
	_box("Bunker_Wall_West", Vector3(0.4, 3.6, 6), Vector3(-8, 1.8, -1), MAT_WALL)
	_box("Bunker_Wall_East", Vector3(0.4, 3.6, 6), Vector3(8, 1.8, -1), MAT_WALL)
	_box("Bunker_Wall_South_W", Vector3(6.75, 3.6, 0.4), Vector3(-4.625, 1.8, 2), MAT_WALL)
	_box("Bunker_Wall_South_E", Vector3(6.75, 3.6, 0.4), Vector3(4.625, 1.8, 2), MAT_WALL)
	_box("Bunker_Wall_North_W", Vector3(6.75, 3.6, 0.4), Vector3(-4.625, 1.8, -4), MAT_WALL)
	_box("Bunker_Wall_North_E", Vector3(6.75, 3.6, 0.4), Vector3(4.625, 1.8, -4), MAT_WALL)
	_box("Bunker_Lintel_S", Vector3(2.5, 1.1, 0.4), Vector3(0, 3.05, 2), MAT_WALL)
	_box("Bunker_Lintel_N", Vector3(2.5, 1.1, 0.4), Vector3(0, 3.05, -4), MAT_WALL)
	_box("Bunker_Ceiling", Vector3(16, 0.2, 6), Vector3(0, 3.7, -1), MAT_CEILING)
	_box("Bunker_FloorPlate", Vector3(16, 0.02, 6), Vector3(0, 0.01, -1), MAT_DIAMOND, false)
	# Full-width bulkheads force the player through the security bunker.
	_box("Bulkhead_A_West", Vector3(18, WAREHOUSE_HEIGHT, 0.5), Vector3(-17, WAREHOUSE_HEIGHT * 0.5, 2), MAT_WALL)
	_box("Bulkhead_A_East", Vector3(18, WAREHOUSE_HEIGHT, 0.5), Vector3(17, WAREHOUSE_HEIGHT * 0.5, 2), MAT_WALL)
	_box("Bulkhead_B_West", Vector3(18, WAREHOUSE_HEIGHT, 0.5), Vector3(-17, WAREHOUSE_HEIGHT * 0.5, -4), MAT_WALL)
	_box("Bulkhead_B_East", Vector3(18, WAREHOUSE_HEIGHT, 0.5), Vector3(17, WAREHOUSE_HEIGHT * 0.5, -4), MAT_WALL)

	# Server racks along both flanks.
	for sx in [-6.6, 6.6]:
		for rz in [-2.7, -0.9, 0.9]:
			_box("ServerRack", Vector3(1.2, 2.35, 1.5), Vector3(sx, 1.18, rz), MAT_CAGED)
			for row in range(4):
				_box("RackLED", Vector3(0.06, 0.06, 0.5), Vector3(sx - 0.63, 0.5 + row * 0.45, rz), MAT_READOUT, false)

	# Mainframe console against the north-west wall.
	_box("MainframeDesk", Vector3(2.8, 1.0, 0.9), Vector3(-4.6, 0.5, -3.35), MAT_GUNMETAL)
	_box("MainframeHousing", Vector3(1.9, 1.55, 0.6), Vector3(-4.6, 1.35, -3.55), MAT_ARMOR)
	_box("MainframeTrim", Vector3(2.0, 0.12, 0.72), Vector3(-4.6, 2.12, -3.55), MAT_HAZARD, false)
	_box("BunkerPipe_A", Vector3(15.4, 0.22, 0.22), Vector3(0, 3.35, -3.6), MAT_RUST, false)
	_box("BunkerPipe_B", Vector3(15.4, 0.16, 0.16), Vector3(0, 3.05, -3.6), MAT_RUST, false)
	_light(Vector3(0, 3.35, -1), 1.0, 9.0, Color(0.7, 0.85, 1.0))
	_label("SECURITY BUNKER // CENTRAL MAINFRAME", Vector3(0, 3.0, 1.72), 22, Color(0.55, 0.9, 1.0))
	var detainee := "POOJA"
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.get("girlfriend_name") != null:
		detainee = str(gm.get("girlfriend_name")).to_upper()
	_label("PRISONER TRANSFER LOG\nDETAINEE: %s\nHOLDING: SUB-BASEMENT VAULT B-1\nSTATUS: AWAITING FLOOR 2 CLEARANCE" % detainee, Vector3(5.4, 2.2, -3.72), 18, Color(1.0, 0.55, 0.45), false)

# ---------------------------------------------------------------- warehouse B / boss arena

func _build_warehouse_b() -> void:
	_container(Vector3(-17, 0, -6.4), 0.0, 0)
	_container(Vector3(17, 0, -6.4), 0.0, 0)
	_container(Vector3(-16.5, 0, -13.6), 0.3, 0)
	_container(Vector3(16.5, 0, -13.4), -0.25, 0)
	_container(Vector3(8.5, 0, -8.2), 1.57, 0)
	_container(Vector3(-9, 0, -8.0), 1.57, 0)

	# Hazard-striped kill zone and approach lane.
	_box("Boss_HazardLine_S", Vector3(16, 0.02, 0.55), Vector3(0, 0.02, -6.2), MAT_HAZARD, false)
	_box("Boss_HazardLine_N", Vector3(16, 0.02, 0.55), Vector3(0, 0.02, -14.2), MAT_HAZARD, false)
	_box("Boss_HazardLine_W", Vector3(0.55, 0.02, 8.0), Vector3(-8, 0.02, -10.2), MAT_HAZARD, false)
	_box("Boss_HazardLine_E", Vector3(0.55, 0.02, 8.0), Vector3(8, 0.02, -10.2), MAT_HAZARD, false)
	_box("Boss_Platform", Vector3(8, 0.02, 8), Vector3(0, 0.01, -10.2), MAT_DIAMOND, false)

	# Barricades and ammo crates around the arena rim.
	_barrel(Vector3(-12, 0, -15))
	_barrel(Vector3(-11.2, 0, -15.2))
	_barrel(Vector3(12, 0, -6))
	_barrel(Vector3(12.8, 0, -6.3))
	_box("ArenaCrate_A", Vector3(2.0, 1.2, 1.4), Vector3(-6, 0.6, -15.2), MAT_CRATE)
	_box("ArenaCrate_B", Vector3(1.6, 1.0, 1.2), Vector3(6, 0.5, -5.6), MAT_CRATE)

	# Emergency lighting (off until the alarm).
	for x in [-24.0, 24.0]:
		for z in [-5.6, -9.5, -14.0]:
			var siren := _light(Vector3(x, 7.0, z), 0.0, 12.0, Color(1.0, 0.12, 0.08))
			siren.visible = false
			_alarm_lights.append(siren)
	for x in [-24.0, 24.0]:
		for z in [4.0, 10.0]:
			var siren_a := _light(Vector3(x, 7.0, z), 0.0, 12.0, Color(1.0, 0.12, 0.08))
			siren_a.visible = false
			_alarm_lights.append(siren_a)

	_label("WAREHOUSE B // GARRISON COMMAND", Vector3(-25.6, 6.4, -10), 36, Color(1.0, 0.35, 0.25), false)
	_label("KILL ZONE", Vector3(25.6, 6.4, -10), 30, Color(1.0, 0.2, 0.15), false)

# ---------------------------------------------------------------- north bay / S-1

func _build_north_bay() -> void:
	_box("S1_BayWall_West", Vector3(0.4, WAREHOUSE_HEIGHT, 5.2), Vector3(-6, WAREHOUSE_HEIGHT * 0.5, -19.4), MAT_WALL)
	_box("S1_BayWall_East", Vector3(0.4, WAREHOUSE_HEIGHT, 5.2), Vector3(6, WAREHOUSE_HEIGHT * 0.5, -19.4), MAT_WALL)
	_box("S1_FrontWall_West", Vector3(4.75, WAREHOUSE_HEIGHT, 0.4), Vector3(-3.625, WAREHOUSE_HEIGHT * 0.5, -16), MAT_WALL)
	_box("S1_FrontWall_East", Vector3(4.75, WAREHOUSE_HEIGHT, 0.4), Vector3(3.625, WAREHOUSE_HEIGHT * 0.5, -16), MAT_WALL)
	_box("S1_FrontLintel", Vector3(2.5, 6.5, 0.4), Vector3(0, 5.75, -16), MAT_WALL)
	_box("S1_CabinWall_West", Vector3(0.25, 4.0, 4.8), Vector3(-3, 2.0, -18.6), MAT_CABIN)
	_box("S1_CabinWall_East", Vector3(0.25, 4.0, 4.8), Vector3(3, 2.0, -18.6), MAT_CABIN)
	_box("S1_CabinCeiling", Vector3(6, 0.3, 5), Vector3(0, 4.05, -18.5), MAT_CABIN)
	_box("S1_CabinFloor", Vector3(6, 0.02, 5), Vector3(0, 0.01, -18.5), MAT_DIAMOND, false)
	_box("S1_CabinBack", Vector3(6, 4, 0.3), Vector3(0, 2, -20.8), MAT_CABIN)
	_box("S1_CabinTrim", Vector3(6.2, 0.12, 5.2), Vector3(0, 4.2, -18.5), MAT_HAZARD, false)
	_exit_sign = _label("SERVICE SHAFT S-1\nAUTHORIZATION REQUIRED", Vector3(0, 3.4, -15.72), 30, Color(1.0, 0.4, 0.3))
	_label("EXTRACTION // FLOOR 2 CLEARANCE", Vector3(0, 2.9, -20.55), 20, Color(0.6, 0.95, 1.0))

	# Exit control pedestal beside the door.
	_box("S1_PanelStand", Vector3(0.7, 1.25, 0.45), Vector3(3.25, 0.62, -15.2), MAT_GUNMETAL)
	_box("S1_PanelScreen", Vector3(0.55, 0.4, 0.06), Vector3(3.25, 1.35, -14.97), MAT_SCREEN)

# ---------------------------------------------------------------- lights

func _build_lights() -> void:
	for x in [-13.0, 0.0, 13.0]:
		for z in [14.0, 8.0, 2.5, -7.0, -13.0]:
			_box("Tube_%d_%d" % [int(x), int(z)], Vector3(3.8, 0.09, 0.42), Vector3(x, 8.72, z), MAT_TUBE, false)
			_light(Vector3(x, 8.3, z), 1.25, 17.0)
	for z in [18.8, -19.0]:
		_box("BayTube_%d" % int(z), Vector3(3.6, 0.09, 0.4), Vector3(0, 3.9, z), MAT_TUBE, false)
		_light(Vector3(0, 3.55, z), 0.9, 9.0)
	# Catwalk accent lighting.
	for z in [3.5, 6.5]:
		_light(Vector3(23.6, 6.4, z), 0.55, 7.0, Color(0.55, 0.75, 1.0))

# ---------------------------------------------------------------- player

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.collision_layer = 2
	player.collision_mask = 5
	player.position = Vector3(0, 0.2, 19.6)
	player.rotation.y = 0.0
	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	collider.position = Vector3(0, 0.9, 0)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	collider.shape = capsule
	player.add_child(collider)
	add_child(player)
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_player_health_changed)
	if player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)
	_last_player_health = player.current_health

# ---------------------------------------------------------------- doors

func _make_door(pos: Vector3, node_name: String, locked := false) -> Node3D:
	var d := DOOR_SCENE.instantiate() as Node3D
	d.name = node_name
	d.position = pos
	add_child(d)
	if locked and d.has_method("lock_door"):
		d.call("lock_door")
	return d

func _build_doors() -> void:
	_entry_door = _make_door(Vector3(0, 0, 17), "EntryBaySlidingDoor")
	_bunker_south_door = _make_door(Vector3(0, 0, 2), "BunkerSouthDoor")
	_bunker_north_door = _make_door(Vector3(0, 0, -4), "BunkerNorthDoor")
	_exit_door = _make_door(Vector3(0, 0, -16), "ServiceElevatorS1Door", true)
	if _entry_door.has_method("open_door"):
		_entry_door.call_deferred("open_door")

# ---------------------------------------------------------------- triggers

func _make_area(node_name: String, pos: Vector3, size: Vector3) -> Area3D:
	var a := Area3D.new()
	a.name = node_name
	a.position = pos
	a.collision_layer = 0
	a.collision_mask = 2
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	a.add_child(cs)
	add_child(a)
	return a

func _build_triggers() -> void:
	var entry_trigger := _make_area("EntryLockdownTrigger", Vector3(0, 1.5, 14.6), Vector3(12, 3, 1.2))
	entry_trigger.body_entered.connect(_on_entry_trigger_entered)
	var arena_trigger := _make_area("BossArenaTrigger", Vector3(0, 1.5, -5.2), Vector3(52, 3, 1.4))
	arena_trigger.body_entered.connect(_on_arena_trigger_entered)

# ---------------------------------------------------------------- mainframe & exit panel

func _build_mainframe() -> void:
	_mainframe_screen = _box("MainframeScreen", Vector3(1.7, 0.9, 0.06), Vector3(-4.6, 1.4, -3.23), MAT_SCREEN)
	_mainframe_label = _label("[CENTRAL SECURITY MAINFRAME]\n[ HOLD E ] TO BREACH", Vector3(-4.6, 2.6, -3.1), 20, Color(1.0, 0.35, 0.3))
	_mainframe_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_mainframe_label.rotation.y = 0.0
	var zone := _make_area("MainframeHackZone", Vector3(-4.6, 1.2, -1.6), Vector3(3.8, 2.6, 3.6))
	zone.body_entered.connect(_on_mainframe_body_entered)
	zone.body_exited.connect(_on_mainframe_body_exited)

func _build_exit_panel() -> void:
	var zone := _make_area("S1PanelZone", Vector3(3.25, 1.2, -14.3), Vector3(2.0, 2.4, 2.4))
	zone.body_entered.connect(_on_exit_panel_body_entered)
	zone.body_exited.connect(_on_exit_panel_body_exited)

# ---------------------------------------------------------------- cameras

func _build_cameras() -> void:
	_add_camera("Cam_WarehouseA_West", Vector3(-24.6, 7.2, 13.5), Vector3(0, 7.2, 7.0))
	_add_camera("Cam_WarehouseA_East", Vector3(24.6, 7.2, 3.8), Vector3(0, 7.2, 10.5))
	_add_camera("Cam_Bunker", Vector3(-7.0, 3.25, 1.6), Vector3(2.0, 1.3, -2.6))
	_add_camera("Cam_WarehouseB", Vector3(24.6, 7.2, -14.2), Vector3(0, 7.2, -8.0))

func _add_camera(node_name: String, pos: Vector3, target: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = pos
	add_child(pivot)
	pivot.look_at(target, Vector3.UP)

	var housing := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.55, 0.45, 0.9)
	housing.mesh = mesh
	housing.material_override = MAT_GUNMETAL
	pivot.add_child(housing)

	var lens := MeshInstance3D.new()
	var lens_mesh := CylinderMesh.new()
	lens_mesh.top_radius = 0.12
	lens_mesh.bottom_radius = 0.12
	lens_mesh.height = 0.12
	lens.mesh = lens_mesh
	lens.rotation.x = PI * 0.5
	lens.position = Vector3(0, 0, -0.5)
	lens.material_override = _emissive(Color(1.0, 0.15, 0.1), 2.5)
	pivot.add_child(lens)

	var beam := SpotLight3D.new()
	beam.position = Vector3(0, 0, -0.55)
	beam.spot_range = 20.0
	beam.spot_angle = 32.0
	beam.light_energy = 2.2
	beam.light_color = Color(0.75, 0.85, 1.0)
	pivot.add_child(beam)

	var status := OmniLight3D.new()
	status.position = Vector3(0, -0.12, -0.45)
	status.light_energy = 0.45
	status.omni_range = 1.6
	status.light_color = Color(1.0, 0.1, 0.05)
	pivot.add_child(status)

	_cameras.append({
		"node": pivot,
		"base_yaw": pivot.rotation.y,
		"phase": randf() * TAU,
		"cooldown": 0.0,
		"status": status,
	})

# ---------------------------------------------------------------- HUD

func _make_hud_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "WarzoneHUD"
	_hud_layer.layer = 10
	add_child(_hud_layer)

	var root := Control.new()
	root.name = "HUDRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_objective_label = _make_hud_label(17, Color(0.72, 0.94, 1.0))
	_objective_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_objective_label.offset_left = -760
	_objective_label.offset_right = -24
	_objective_label.offset_top = 20
	_objective_label.offset_bottom = 110
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_objective_label)

	_warning_label = _make_hud_label(21, Color(1.0, 0.5, 0.25))
	_warning_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_warning_label.offset_left = -520
	_warning_label.offset_right = 520
	_warning_label.offset_top = 24
	_warning_label.offset_bottom = 64
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_warning_label)

	_boss_bar = ProgressBar.new()
	_boss_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_bar.offset_left = -300
	_boss_bar.offset_right = 300
	_boss_bar.offset_top = 72
	_boss_bar.offset_bottom = 96
	_boss_bar.show_percentage = true
	_boss_bar.visible = false
	root.add_child(_boss_bar)

	_hack_bar = ProgressBar.new()
	_hack_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hack_bar.offset_left = -220
	_hack_bar.offset_right = 220
	_hack_bar.offset_top = -168
	_hack_bar.offset_bottom = -144
	_hack_bar.show_percentage = true
	_hack_bar.visible = false
	root.add_child(_hack_bar)

	_prompt_label = _make_hud_label(19, Color(0.92, 0.98, 1.0))
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.offset_left = -520
	_prompt_label.offset_right = 520
	_prompt_label.offset_top = -132
	_prompt_label.offset_bottom = -84
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_prompt_label)

	_end_layer = CanvasLayer.new()
	_end_layer.name = "WarzoneEndScreen"
	_end_layer.layer = 100
	add_child(_end_layer)
	_end_fade = ColorRect.new()
	_end_fade.color = Color.BLACK
	_end_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_fade.modulate.a = 0.0
	_end_layer.add_child(_end_fade)
	_end_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_end_title = _make_hud_label(42, Color(0.85, 0.95, 1.0))
	_end_title.set_anchors_preset(Control.PRESET_CENTER)
	_end_title.offset_left = -600
	_end_title.offset_right = 600
	_end_title.offset_top = -70
	_end_title.offset_bottom = 0
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.text = ""
	_end_layer.add_child(_end_title)

	_end_subtitle = _make_hud_label(20, Color(1.0, 0.55, 0.35))
	_end_subtitle.set_anchors_preset(Control.PRESET_CENTER)
	_end_subtitle.offset_left = -600
	_end_subtitle.offset_right = 600
	_end_subtitle.offset_top = 10
	_end_subtitle.offset_bottom = 80
	_end_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_subtitle.text = ""
	_end_layer.add_child(_end_subtitle)

func _update_objective(text: String) -> void:
	if _objective_label:
		_objective_label.text = "FLOOR 2 // WARZONE WAREHOUSE\nOBJECTIVE: " + text

func _warn(text: String, seconds := 4.0) -> void:
	if _warning_label:
		_warning_label.text = text
		_warning_timer = seconds

# ---------------------------------------------------------------- garrison

func _spawn_enemy(pos: Vector3, health := 100.0, alerted := false) -> Node3D:
	var e := HENCHMAN_SCENE.instantiate() as Node3D
	e.name = "Mercenary"
	e.position = pos
	e.set("max_health", health)
	e.add_to_group("enemy")
	add_child(e)
	if alerted and e.get("current_state") != null:
		e.set("current_state", 1)
	return e

func _spawn_garrison() -> void:
	_spawn_enemy(Vector3(-12, 0.2, 10))
	_spawn_enemy(Vector3(10, 0.2, 9))
	_spawn_enemy(Vector3(-6, 0.2, 5))
	_spawn_enemy(Vector3(18, 0.2, 3))
	_spawn_enemy(Vector3(5, 0.2, 10.5))
	_spawn_enemy(Vector3(-4, 0.2, -0.5))
	_spawn_enemy(Vector3(4, 0.2, -1.5))
	_spawn_enemy(Vector3(-12, 0.2, -7))
	_spawn_enemy(Vector3(13, 0.2, -9))
	_spawn_enemy(Vector3(10, 0.2, -6))
	_spawn_commander()

func _spawn_commander() -> void:
	_commander = HENCHMAN_SCENE.instantiate()
	_commander.name = "GarrisonCommander"
	_commander.position = Vector3(0, 0.2, -10.2)
	_commander.set("max_health", BOSS_MAX_HEALTH)
	_commander.set("move_speed", 2.2)
	_commander.set("run_speed", 4.4)
	_commander.set("attack_range", 30.0)
	_commander.set("bullet_damage", 9.0)
	_commander.set("patrol_distance", 0.2)
	_commander.add_to_group("enemy")
	add_child(_commander)
	_commander.enemy_defeated.connect(_on_commander_defeated)

	_commander_label = Label3D.new()
	_commander_label.text = "GARRISON COMMANDER\n100%"
	_commander_label.font_size = 28
	_commander_label.outline_size = 10
	_commander_label.outline_modulate = Color(0, 0, 0, 0.9)
	_commander_label.modulate = Color(1.0, 0.3, 0.22)
	_commander_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_commander_label.position = Vector3(0, 2.7, 0)
	_commander.add_child(_commander_label)

func _alert_garrison() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.has_method("is_dead") and not bool(e.call("is_dead")):
			e.set("current_state", 1)

# ---------------------------------------------------------------- resupply

func _spawn_resupply(pos: Vector3) -> void:
	_box("ResupplyCrate_%d_%d" % [int(pos.x), int(pos.z)], Vector3(1.4, 0.9, 1.1), Vector3(pos.x, 0.45, pos.z), MAT_CRATE)
	_box("ResupplyStrip_%d_%d" % [int(pos.x), int(pos.z)], Vector3(1.42, 0.08, 1.12), Vector3(pos.x, 0.93, pos.z), MAT_HAZARD, false)
	_label("[RESUPPLY]\nAMMO // +25 HP", Vector3(pos.x, 1.5, pos.z), 16, Color(0.5, 1.0, 0.55))
	var zone := _make_area("ResupplyZone_%d_%d" % [int(pos.x), int(pos.z)], Vector3(pos.x, 1.0, pos.z), Vector3(2.4, 2.2, 2.4))
	zone.body_entered.connect(_on_resupply_entered.bind(zone))

func _on_resupply_entered(body: Node3D, station: Area3D) -> void:
	if body != player or station.get_meta("used", false):
		return
	station.set_meta("used", true)
	var vm = player.get_node_or_null("Head/Camera3D/ViewmodelRig")
	if vm and vm.get("ammo") != null:
		vm.set("ammo", int(vm.get("max_ammo")))
		if vm.has_signal("ammo_changed"):
			vm.emit_signal("ammo_changed", int(vm.get("ammo")), int(vm.get("max_ammo")))
	player.call("heal", 25.0)
	_warn("RESUPPLY ACQUIRED — AMMO REFILLED // +25 HP", 3.0)

# ---------------------------------------------------------------- frame loop

func _process(delta: float) -> void:
	if _floor_finished:
		return
	_time += delta
	_update_alarm_lights()
	_update_hack(delta)
	_update_boss(delta)
	_process_cameras(delta)
	_update_prompt()
	if _warning_timer > 0.0:
		_warning_timer -= delta
		if _warning_timer <= 0.0 and _warning_label:
			_warning_label.text = ""

func _update_alarm_lights() -> void:
	if not _alarm_active:
		return
	var energy := 1.2 + sin(_time * 6.0) * 0.7
	for l in _alarm_lights:
		l.light_energy = energy

func _update_hack(delta: float) -> void:
	if mainframe_hacked:
		if _hack_bar:
			_hack_bar.visible = false
		return
	if _mainframe_in_range and Input.is_key_pressed(KEY_E):
		if not _hack_started:
			_start_hack()
		_hack_progress = minf(HACK_SECONDS, _hack_progress + delta)
		if _hack_progress >= HACK_SECONDS * 0.5 and not _wave2_spawned:
			_wave2_spawned = true
			_spawn_wave([Vector3(-6, 0.2, 4.5), Vector3(6, 0.2, 4.5)])
			_warn("MAINFRAME AT 50% — SECOND WAVE INBOUND", 4.0)
		if _hack_progress >= HACK_SECONDS:
			_complete_hack()
	if _hack_bar:
		_hack_bar.visible = _mainframe_in_range and _hack_progress > 0.0 and not mainframe_hacked
		_hack_bar.value = (_hack_progress / HACK_SECONDS) * 100.0

func _start_hack() -> void:
	_hack_started = true
	_alarm_active = true
	for l in _alarm_lights:
		l.visible = true
	_alert_garrison()
	_spawn_wave([Vector3(20, 0.2, 14), Vector3(-20, 0.2, 13)])
	_mainframe_label.text = "[BREACH IN PROGRESS]\nHOLD POSITION"
	_mainframe_label.modulate = Color(1.0, 0.8, 0.2)
	_warn("MAINFRAME BREACH DETECTED — GARRISON ALERTED", 5.0)
	print("[Floor 2] Mainframe breach started. Alarm active.")

func _complete_hack() -> void:
	if mainframe_hacked:
		return
	mainframe_hacked = true
	_hack_progress = HACK_SECONDS
	_mainframe_screen.material = _emissive(Color(0.1, 1.0, 0.3), 2.5)
	_mainframe_label.text = "[MAINFRAME BREACHED]\nSECURITY GRID OFFLINE"
	_mainframe_label.modulate = Color(0.3, 1.0, 0.4)
	_warn("CENTRAL MAINFRAME HACKED — S-1 GATE PARTIALLY RELEASED", 5.0)
	if commander_dead:
		_update_objective("PROCEED TO SERVICE SHAFT S-1")
	else:
		_update_objective("ELIMINATE THE GARRISON COMMANDER")
	_check_exit_unlock()

func _on_player_health_changed(current: float, _max_val: float) -> void:
	if _hack_progress > 0.0 and not mainframe_hacked and current < _last_player_health:
		_hack_progress = maxf(0.0, _hack_progress * 0.75)
		_warn("HACK INTERRUPTED — 25% PROGRESS LOST", 3.0)
	_last_player_health = current

func _on_player_died() -> void:
	_warn("SIGNAL LOST — REBOOTING FLOOR 2...", 3.0)
	if player:
		player.set_physics_process(false)
	await get_tree().create_timer(2.5).timeout
	if is_inside_tree():
		get_tree().reload_current_scene()

# ---------------------------------------------------------------- boss

func _on_arena_trigger_entered(body: Node3D) -> void:
	if body != player or _boss_active or commander_dead:
		return
	_boss_active = true
	_boss_phase = 1
	_boss_slam_cooldown = 3.0
	if _bunker_north_door:
		if _bunker_north_door.has_method("close_door"):
			_bunker_north_door.call("close_door")
		if _bunker_north_door.has_method("lock_door"):
			_bunker_north_door.call("lock_door")
	_alert_garrison()
	if _boss_bar:
		_boss_bar.visible = true
		_boss_bar.value = 100.0
	_warn("GARRISON COMMANDER — ENGAGE", 4.0)
	_update_objective("ELIMINATE THE GARRISON COMMANDER")
	print("[Floor 2] Boss arena sealed. Garrison Commander engaged.")

func _update_boss(delta: float) -> void:
	if not _boss_active or commander_dead or _commander == null or not is_instance_valid(_commander):
		return
	if _commander.has_method("is_dead") and bool(_commander.call("is_dead")):
		return
	var health: float = float(_commander.get("current_health"))
	var ratio := health / BOSS_MAX_HEALTH
	if _commander_label:
		_commander_label.text = "GARRISON COMMANDER\n%d%%" % int(ceil(ratio * 100.0))
	if _boss_bar:
		_boss_bar.value = ratio * 100.0

	if _boss_phase == 1 and ratio <= 0.66:
		_boss_phase = 2
		_commander.set("run_speed", 5.0)
		_spawn_wave([Vector3(-7, 0.2, -12), Vector3(7, 0.2, -12)])
		_warn("COMMANDER PHASE 2 — ARMOR PLATING SHATTERED", 4.0)
	elif _boss_phase == 2 and ratio <= 0.33:
		_boss_phase = 3
		_commander.set("run_speed", 5.8)
		_commander.set("bullet_damage", 12.0)
		_spawn_wave([Vector3(-9, 0.2, -14), Vector3(9, 0.2, -14)])
		_warn("COMMANDER PHASE 3 — BERSERK", 4.0)

	_boss_slam_cooldown -= delta
	if _boss_slam_cooldown <= 0.0 and player:
		var dist: float = _commander.global_position.distance_to(player.global_position)
		if dist < 4.6:
			player.call("take_damage", 16.0)
			_boss_slam_cooldown = 4.5
			_warn("COMMANDER SLAM — KEEP YOUR DISTANCE", 2.0)

func _on_commander_defeated() -> void:
	if commander_dead:
		return
	commander_dead = true
	_boss_active = false
	if _boss_bar:
		_boss_bar.visible = false
	if _commander_label:
		_commander_label.text = "GARRISON COMMANDER\nNEUTRALIZED"
	if _bunker_north_door and _bunker_north_door.has_method("unlock_door"):
		_bunker_north_door.call("unlock_door")
	_warn("GARRISON COMMANDER NEUTRALIZED", 5.0)
	if mainframe_hacked:
		_update_objective("PROCEED TO SERVICE SHAFT S-1")
	else:
		_update_objective("HACK THE CENTRAL MAINFRAME")
	_check_exit_unlock()
	print("[Floor 2] Garrison Commander eliminated.")

# ---------------------------------------------------------------- cameras

func _process_cameras(delta: float) -> void:
	_cam_scan_timer -= delta
	for cam in _cameras:
		var pivot: Node3D = cam["node"]
		pivot.rotation.y = float(cam["base_yaw"]) + sin(_time * 0.7 + float(cam["phase"])) * 0.55
		cam["cooldown"] = maxf(0.0, float(cam["cooldown"]) - delta)
	if _cam_scan_timer > 0.0:
		return
	_cam_scan_timer = 0.25
	for cam in _cameras:
		if float(cam["cooldown"]) > 0.0:
			continue
		var pivot: Node3D = cam["node"]
		if _camera_sees_player(pivot):
			cam["cooldown"] = 7.0
			_on_camera_detected()
			break

func _camera_sees_player(pivot: Node3D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var from := pivot.global_position
	var to: Vector3 = player.global_position + Vector3(0, 1.3, 0)
	var delta := to - from
	if delta.length() > 20.0:
		return false
	var flat := Vector3(delta.x, 0, delta.z)
	if flat.length_squared() < 0.01:
		return false
	var forward := -pivot.global_transform.basis.z
	forward.y = 0.0
	if forward.normalized().dot(flat.normalized()) < 0.84:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result.size() > 0 and result.get("collider") == player

func _on_camera_detected() -> void:
	_alarm_active = true
	for l in _alarm_lights:
		l.visible = true
	_alert_garrison()
	_warn("SECURITY CAMERA DETECTED YOU — GARRISON ALERTED", 4.0)
	if not _camera_wave_spawned:
		_camera_wave_spawned = true
		_spawn_wave([Vector3(-22, 0.2, 4), Vector3(22, 0.2, 2)])

# ---------------------------------------------------------------- wave / entry

func _spawn_wave(points: Array) -> void:
	for p in points:
		_spawn_enemy(p, 90.0, true)

func _on_entry_trigger_entered(body: Node3D) -> void:
	if body != player or _entry_locked:
		return
	_entry_locked = true
	if _entry_door:
		if _entry_door.has_method("close_door"):
			_entry_door.call("close_door")
		if _entry_door.has_method("lock_door"):
			_entry_door.call("lock_door")
	_entry_sign.text = "[SHAFT S-2: LOCKDOWN]\nNO RETREAT AUTHORIZED"
	_entry_sign.modulate = Color(1.0, 0.2, 0.15)
	_warn("S-2 SEALED — NO RETREAT", 3.0)

# ---------------------------------------------------------------- interaction

func _on_mainframe_body_entered(body: Node3D) -> void:
	if body == player:
		_mainframe_in_range = true

func _on_mainframe_body_exited(body: Node3D) -> void:
	if body == player:
		_mainframe_in_range = false

func _on_exit_panel_body_entered(body: Node3D) -> void:
	if body == player:
		_exit_panel_in_range = true

func _on_exit_panel_body_exited(body: Node3D) -> void:
	if body == player:
		_exit_panel_in_range = false

func _unhandled_input(event: InputEvent) -> void:
	if _floor_finished:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if _exit_panel_in_range:
			_try_exit()

func _try_exit() -> void:
	if not exit_unlocked:
		var mainframe_state := "DONE" if mainframe_hacked else "PENDING"
		var commander_state := "DONE" if commander_dead else "PENDING"
		_warn("S-1 SEALED // MAINFRAME: %s // COMMANDER: %s" % [mainframe_state, commander_state], 4.0)
		return
	_finish_floor()

func _check_exit_unlock() -> void:
	if exit_unlocked or not (mainframe_hacked and commander_dead):
		return
	exit_unlocked = true
	if _exit_door:
		if _exit_door.has_method("unlock_door"):
			_exit_door.call("unlock_door")
		if _exit_door.has_method("open_door"):
			_exit_door.call("open_door")
	_exit_sign.text = "SERVICE SHAFT S-1\nEXTRACTION READY"
	_exit_sign.modulate = Color(0.3, 1.0, 0.4)
	_update_objective("EXTRACT VIA SERVICE SHAFT S-1")
	_warn("SERVICE SHAFT S-1 UNLOCKED — PROCEED NORTH", 6.0)
	print("[Floor 2] S-1 extraction unlocked.")

func _update_prompt() -> void:
	if not _prompt_label:
		return
	if _floor_finished:
		_prompt_label.text = ""
		return
	if _exit_panel_in_range:
		if exit_unlocked:
			_prompt_label.text = "[PRESS E] CALL SERVICE ELEVATOR S-1"
		else:
			var mf := "DONE" if mainframe_hacked else "PENDING"
			var cd := "DONE" if commander_dead else "PENDING"
			_prompt_label.text = "[S-1 SEALED] MAINFRAME: %s // COMMANDER: %s" % [mf, cd]
		return
	if _mainframe_in_range and not mainframe_hacked:
		if _hack_progress > 0.0:
			_prompt_label.text = "HOLD E — BREACHING MAINFRAME %d%%" % int((_hack_progress / HACK_SECONDS) * 100.0)
		else:
			_prompt_label.text = "[HOLD E] BREACH CENTRAL MAINFRAME (12s)"
		return
	_prompt_label.text = ""

# ---------------------------------------------------------------- extraction

func _finish_floor() -> void:
	if _floor_finished:
		return
	_floor_finished = true
	if _exit_door and _exit_door.has_method("open_door"):
		_exit_door.call("open_door")
	if player:
		player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tween := create_tween()
	tween.tween_property(_end_fade, "modulate:a", 1.0, 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_show_end_titles)
	print("[Floor 2] Extraction reached. Floor complete.")

func _show_end_titles() -> void:
	_end_title.text = "FLOOR 2 CLEARED"
	_end_subtitle.text = "SERVICE SHAFT S-1 // DESCENDING TO THE SUB-BASEMENT VAULT\nTO BE CONTINUED"

