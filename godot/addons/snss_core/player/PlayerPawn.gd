extends CharacterBody3D
## PlayerPawn - protagonist controller for Part 1 ("Sigma-7").
## Features first-person tactical viewmodel (arms, hands, silenced combat pistol, open-hand slap),
## full-body torso/legs mesh, dynamic crosshair HUD, mouse look sensitivity scaling, and camera shake.

signal entered_elevator()
signal shot_fired(hit_node: Node3D, hit_pos: Vector3)
signal slap_hit(hit_node: Node3D, hit_pos: Vector3)

const MOVEMENT_SPEED: float = 6.0
const SPRINT_MULTIPLIER: float = 1.6
const JUMP_VELOCITY: float = 4.5
const MOUSE_SENSITIVITY_BASE: float = 0.0022

var base_look_sensitivity: float = 1.0
var look_multiplier: float = 1.0

var _flashlights: Array[SpotLight3D] = []
var _head: Node3D
var _camera: Camera3D
var _viewmodel: Node3D
var _body_mesh: Node3D

var _hud_layer: CanvasLayer
var _sensitivity_label: Label
var _weapon_status_label: Label
var _reticle_center: ColorRect
var _reticle_ticks: Array[ColorRect] = []
var _hitmarker_container: Control
var _camera_trauma: float = 0.0

const ViewmodelRigScene = preload("res://addons/snss_core/player/ViewmodelRig.tscn")
const PlayerBodyMeshScene = preload("res://addons/snss_core/player/PlayerBodyMesh.tscn")
const SoundSynthesizer = preload("res://addons/snss_core/audio/SoundSynthesizer.gd")

var _step_accumulator: float = 0.0
var _footstep_player: AudioStreamPlayer3D

## Called by CalibrationTimer to dynamically scale look input within [0.3, 0.8].
func set_look_multiplier(multiplier: float) -> void:
	look_multiplier = clampf(multiplier, 0.3, 0.8)
	_update_hud()

func _ready() -> void:
	_setup_camera_rig()
	_setup_flashlights()
	_setup_hud()
	_setup_audio()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_audio() -> void:
	_footstep_player = AudioStreamPlayer3D.new()
	_footstep_player.name = "FootstepAudio"
	_footstep_player.bus = "SFX"
	_footstep_player.stream = SoundSynthesizer.get_footstep()
	_footstep_player.max_distance = 18.0
	_footstep_player.unit_size = 2.5
	add_child(_footstep_player)

	if is_inside_tree():
		var env_ctrl := get_node_or_null("/root/EnvironmentController")
		if env_ctrl and env_ctrl.get("current_mode") == 1:
			_disable_flashlights()

func _setup_camera_rig() -> void:
	_head = get_node_or_null("Head") as Node3D
	if _head == null:
		_head = Node3D.new()
		_head.name = "Head"
		_head.position = Vector3(0.0, 1.65, 0.0)
		add_child(_head)

	_camera = _head.get_node_or_null("Camera3D") as Camera3D
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = "Camera3D"
		_camera.position = Vector3.ZERO
		_camera.fov = 90.0
		_camera.current = true
		_head.add_child(_camera)

	# First-Person Viewmodel (Hands & Weapon)
	_viewmodel = _camera.get_node_or_null("ViewmodelRig") as Node3D
	if _viewmodel == null:
		_viewmodel = ViewmodelRigScene.instantiate()
		_camera.add_child(_viewmodel)

	if _viewmodel:
		if not _viewmodel.fired_weapon.is_connected(_on_viewmodel_fired):
			_viewmodel.fired_weapon.connect(_on_viewmodel_fired)
		if not _viewmodel.slap_connected.is_connected(_on_viewmodel_slapped):
			_viewmodel.slap_connected.connect(_on_viewmodel_slapped)
		if _viewmodel.has_signal("ammo_changed") and not _viewmodel.ammo_changed.is_connected(_on_viewmodel_ammo_changed):
			_viewmodel.ammo_changed.connect(_on_viewmodel_ammo_changed)
		if _viewmodel.has_signal("reload_started") and not _viewmodel.reload_started.is_connected(_on_viewmodel_reload_started):
			_viewmodel.reload_started.connect(_on_viewmodel_reload_started)
		if _viewmodel.has_signal("reload_completed") and not _viewmodel.reload_completed.is_connected(_on_viewmodel_reload_completed):
			_viewmodel.reload_completed.connect(_on_viewmodel_reload_completed)

	# Full-Body Mesh (visible when looking down)
	_body_mesh = get_node_or_null("PlayerBodyMesh") as Node3D
	if _body_mesh == null:
		_body_mesh = PlayerBodyMeshScene.instantiate()
		add_child(_body_mesh)

func _setup_flashlights() -> void:
	_flashlights.clear()
	_flashlights.append(_create_flashlight("FlashlightLeft", Vector3(-0.25, -0.1, -0.2)))
	_flashlights.append(_create_flashlight("FlashlightRight", Vector3(0.25, -0.1, -0.2)))

func _create_flashlight(node_name: String, offset: Vector3) -> SpotLight3D:
	var light := _head.get_node_or_null(node_name) as SpotLight3D
	if light == null:
		light = SpotLight3D.new()
		light.name = node_name
		light.position = offset
		light.spot_angle = 38.0
		light.spot_attenuation = 2.0
		light.spot_range = 28.0
		light.light_energy = 1.0
		light.shadow_enabled = true
		_head.add_child(light)
	light.visible = true
	return light

func _disable_flashlights() -> void:
	for light in _flashlights:
		if is_instance_valid(light):
			light.visible = false

func _setup_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "PlayerHUD"
	add_child(_hud_layer)

	# Sensitivity HUD (Top Left)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(24.0, 24.0)
	_hud_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	_sensitivity_label = Label.new()
	_sensitivity_label.add_theme_font_size_override("font_size", 14)
	margin.add_child(_sensitivity_label)

	# Weapon & Action HUD (Bottom Right)
	var action_panel := PanelContainer.new()
	action_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action_panel.offset_left = -340.0
	action_panel.offset_top = -80.0
	action_panel.offset_right = -24.0
	action_panel.offset_bottom = -24.0
	_hud_layer.add_child(action_panel)

	var action_margin := MarginContainer.new()
	action_margin.add_theme_constant_override("margin_left", 14)
	action_margin.add_theme_constant_override("margin_top", 8)
	action_margin.add_theme_constant_override("margin_right", 14)
	action_margin.add_theme_constant_override("margin_bottom", 8)
	action_panel.add_child(action_margin)

	_weapon_status_label = Label.new()
	_weapon_status_label.text = "SIGMA-7 // GLOCK 17 [17/17]\n[L-CLICK] FIRE  |  [R-CLICK / F] SLAP"
	_weapon_status_label.add_theme_font_size_override("font_size", 13)
	action_margin.add_child(_weapon_status_label)

	# Tactical Reticle & Crosshair (Center Screen)
	_build_reticle_hud()
	_update_hud()

func _build_reticle_hud() -> void:
	var center_node := Control.new()
	center_node.set_anchors_preset(Control.PRESET_CENTER)
	center_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(center_node)

	# Center dot
	_reticle_center = ColorRect.new()
	_reticle_center.color = Color(1.0, 1.0, 1.0, 0.75)
	_reticle_center.size = Vector2(3.0, 3.0)
	_reticle_center.position = Vector2(-1.5, -1.5)
	_reticle_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_node.add_child(_reticle_center)

	# 4 Crosshair ticks: Top, Bottom, Left, Right
	var tick_offsets := [Vector2(0, -12), Vector2(0, 8), Vector2(-12, 0), Vector2(8, 0)]
	var tick_sizes := [Vector2(2, 6), Vector2(2, 6), Vector2(6, 2), Vector2(6, 2)]

	for i in range(4):
		var tick := ColorRect.new()
		tick.color = Color(1.0, 1.0, 1.0, 0.55)
		tick.size = tick_sizes[i]
		tick.position = tick_offsets[i]
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center_node.add_child(tick)
		_reticle_ticks.append(tick)

	# Hitmarker Container (Diagonal ticks for slap/hit confirmation)
	_hitmarker_container = Control.new()
	_hitmarker_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hitmarker_container.visible = false
	center_node.add_child(_hitmarker_container)

	var diag_offsets := [Vector2(-9, -9), Vector2(7, -9), Vector2(-9, 7), Vector2(7, 7)]
	for offset in diag_offsets:
		var hm := ColorRect.new()
		hm.color = Color(1.0, 0.25, 0.25, 0.9)
		hm.size = Vector2(3, 3)
		hm.position = offset
		hm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hitmarker_container.add_child(hm)

func _update_hud() -> void:
	if _sensitivity_label:
		var effective: float = base_look_sensitivity * look_multiplier
		_sensitivity_label.text = "AIM SENSITIVITY: %.2f x %.2f = %.2f (EFFECTIVE)" % [
			base_look_sensitivity,
			look_multiplier,
			effective
		]

func _on_viewmodel_fired(hit_node: Node3D, hit_pos: Vector3, _hit_normal: Vector3) -> void:
	_camera_trauma = minf(_camera_trauma + 0.25, 1.0)
	shot_fired.emit(hit_node, hit_pos)
	if hit_node:
		_show_hitmarker()

func _on_viewmodel_slapped(hit_node: Node3D, hit_pos: Vector3, _hit_normal: Vector3) -> void:
	_camera_trauma = minf(_camera_trauma + 0.45, 1.0)
	slap_hit.emit(hit_node, hit_pos)
	if hit_node:
		_show_hitmarker()

func _on_viewmodel_ammo_changed(current: int, max_capacity: int) -> void:
	if _weapon_status_label:
		if current == 0:
			_weapon_status_label.text = "SIGMA-7 // GLOCK 17 [EMPTY]\n[R] RELOAD  |  [R-CLICK / F] SLAP"
		else:
			_weapon_status_label.text = "SIGMA-7 // GLOCK 17 [%d/%d]\n[L-CLICK] FIRE  |  [R] RELOAD  |  [R-CLICK / F] SLAP" % [current, max_capacity]

func _on_viewmodel_reload_started() -> void:
	if _weapon_status_label:
		_weapon_status_label.text = "SIGMA-7 // GLOCK 17 [RELOADING...]\n[L-CLICK] BUSY  |  [R-CLICK / F] SLAP"

func _on_viewmodel_reload_completed() -> void:
	if _viewmodel and _weapon_status_label and _viewmodel.get("ammo") != null:
		_on_viewmodel_ammo_changed(_viewmodel.ammo, _viewmodel.max_ammo)

func _show_hitmarker() -> void:
	if _hitmarker_container:
		_hitmarker_container.visible = true
		var tree := get_tree()
		if tree:
			tree.create_timer(0.08).timeout.connect(func():
				if _hitmarker_container:
					_hitmarker_container.visible = false
			)
		else:
			_hitmarker_container.visible = false

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= 14.0 * delta

	# Jump
	var jump_pressed := false
	if InputMap.has_action("jump") and Input.is_action_just_pressed("jump"):
		jump_pressed = true
	elif Input.is_key_pressed(KEY_SPACE):
		jump_pressed = true

	if jump_pressed and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Sprint
	var is_sprinting := false
	if InputMap.has_action("sprint") and Input.is_action_pressed("sprint"):
		is_sprinting = true
	elif Input.is_key_pressed(KEY_SHIFT):
		is_sprinting = true

	var current_speed: float = MOVEMENT_SPEED * (SPRINT_MULTIPLIER if is_sprinting else 1.0)

	# Planar input handling with both InputMap & direct Key fallbacks
	var input_dir := Vector2.ZERO
	if (InputMap.has_action("move_forward") and Input.is_action_pressed("move_forward")) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if (InputMap.has_action("move_back") and Input.is_action_pressed("move_back")) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0
	if (InputMap.has_action("move_left") and Input.is_action_pressed("move_left")) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if (InputMap.has_action("move_right") and Input.is_action_pressed("move_right")) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0

	if input_dir.length_squared() > 0.0:
		input_dir = input_dir.normalized()

	var move_dir: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if move_dir != Vector3.ZERO:
		velocity.x = move_dir.x * current_speed
		velocity.z = move_dir.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, MOVEMENT_SPEED * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, MOVEMENT_SPEED * 10.0 * delta)

	move_and_slide()

	# Footsteps: Accumulate floor travel distance
	if is_on_floor():
		var horiz_vel := Vector2(velocity.x, velocity.z)
		var horiz_speed := horiz_vel.length()
		if horiz_speed > 0.4:
			var step_threshold: float = 1.35 if is_sprinting else 1.8
			_step_accumulator += horiz_speed * delta
			if _step_accumulator >= step_threshold:
				_step_accumulator = 0.0
				_play_footstep()
		else:
			_step_accumulator = 0.0
	else:
		_step_accumulator = 0.0

	# Update Viewmodel procedural motion (walk sway, breathing bob)
	if _viewmodel and _viewmodel.has_method("update_procedural_motion"):
		_viewmodel.update_procedural_motion(delta, velocity, is_on_floor())

	# Process Camera Shake Trauma
	if _camera_trauma > 0.0:
		_camera_trauma = maxf(0.0, _camera_trauma - delta * 3.2)
		var shake := _camera_trauma * _camera_trauma
		if _camera:
			_camera.rotation.z = randf_range(-deg_to_rad(2.0), deg_to_rad(2.0)) * shake
	elif _camera and _camera.rotation.z != 0.0:
		_camera.rotation.z = move_toward(_camera.rotation.z, 0.0, 5.0 * delta)

func _play_footstep() -> void:
	if _footstep_player:
		_footstep_player.pitch_scale = randf_range(0.92, 1.08)
		_footstep_player.play()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity_scale: float = base_look_sensitivity * look_multiplier * MOUSE_SENSITIVITY_BASE
		# Horizontal rotation on pawn body (Yaw)
		rotate_y(-event.relative.x * sensitivity_scale)
		# Vertical rotation on Head (Pitch)
		if _head:
			_head.rotate_x(-event.relative.y * sensitivity_scale)
			_head.rotation.x = clampf(_head.rotation.x, -deg_to_rad(85.0), deg_to_rad(85.0))
		# Feed mouse motion into viewmodel weapon sway
		if _viewmodel and _viewmodel.has_method("update_mouse_sway"):
			_viewmodel.update_mouse_sway(event.relative)

	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if event.button_index == MOUSE_BUTTON_LEFT:
				# Shoot weapon
				if _viewmodel and _viewmodel.has_method("shoot"):
					_viewmodel.shoot()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				# Melee open-hand SLAP!
				if _viewmodel and _viewmodel.has_method("slap"):
					_viewmodel.slap()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_F or event.keycode == KEY_V:
			# Melee open-hand SLAP key fallback
			if _viewmodel and _viewmodel.has_method("slap"):
				_viewmodel.slap()
		elif event.keycode == KEY_R:
			# Reload Glock 17
			if _viewmodel and _viewmodel.has_method("reload"):
				_viewmodel.reload()
		elif event.keycode == KEY_L:
			_toggle_flashlight()
		elif event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	elif InputMap.has_action("reload") and event.is_action_pressed("reload"):
		if _viewmodel and _viewmodel.has_method("reload"):
			_viewmodel.reload()

	elif InputMap.has_action("flashlight_toggle") and event.is_action_pressed("flashlight_toggle"):
		_toggle_flashlight()

func _toggle_flashlight() -> void:
	if is_inside_tree():
		var env_ctrl := get_node_or_null("/root/EnvironmentController")
		if env_ctrl and env_ctrl.get("current_mode") == 1:
			return
	for light in _flashlights:
		if is_instance_valid(light):
			light.visible = not light.visible
