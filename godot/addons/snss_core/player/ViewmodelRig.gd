extends Node3D
## ViewmodelRig - first-person character arms, tactical hands, combat pistol, and melee slap.
## Handles procedural weapon sway, breathing bobbing, recoil, and animated slap attacks.

const SoundSynthesizer = preload("res://addons/snss_core/audio/SoundSynthesizer.gd")
const ImpactFX = preload("res://addons/snss_core/fx/ImpactFX.gd")

signal fired_weapon(hit_collider: Node3D, hit_point: Vector3, hit_normal: Vector3)
signal slap_connected(hit_collider: Node3D, hit_point: Vector3, hit_normal: Vector3)
signal ammo_changed(current_ammo: int, max_capacity: int)
signal reload_started()
signal reload_completed()
signal aim_state_changed(is_aiming: bool)

@export var max_sway_degrees: float = 4.0
@export var sway_smooth: float = 12.0
@export var idle_bob_amount: float = 0.004
@export var walk_bob_amount: float = 0.018
@export var slap_range: float = 2.4
@export var slap_cooldown: float = 0.45
@export var shoot_cooldown: float = 0.18
@export var ammo: int = 17
@export var max_ammo: int = 17
var is_reloading: bool = false
var is_aiming: bool = false

const ADS_RIGHT_ARM_POS: Vector3 = Vector3(0.0, -0.142, -0.35)
const ADS_RIGHT_ARM_ROT: Vector3 = Vector3(0.0, 0.0, 0.0)

func set_aiming(aim: bool) -> void:
	if is_aiming != aim:
		is_aiming = aim
		aim_state_changed.emit(is_aiming)

var _right_arm: Node3D
var _left_arm: Node3D
var _weapon: Node3D
var _weapon_slide: Node3D
var _muzzle_light: OmniLight3D
var _muzzle_flash_mesh: MeshInstance3D
var _wrist_comms_label: Label3D
var _audio_player: AudioStreamPlayer

var _default_pos: Vector3
var _default_rot: Vector3
var _right_arm_default_pos: Vector3
var _right_arm_default_rot: Vector3
var _left_arm_default_pos: Vector3
var _left_arm_default_rot: Vector3

var _sway_offset: Vector2 = Vector2.ZERO
var _bob_timer: float = 0.0
var _can_slap: bool = true
var _can_shoot: bool = true
var _is_slapping: bool = false
var _camera: Camera3D

func _ready() -> void:
	_default_pos = position
	_default_rot = rotation

	_right_arm = get_node_or_null("RightArm") as Node3D
	_left_arm = get_node_or_null("LeftArm") as Node3D
	_weapon = get_node_or_null("RightArm/Weapon") as Node3D
	_weapon_slide = get_node_or_null("RightArm/Weapon/Slide") as Node3D
	_muzzle_light = get_node_or_null("RightArm/Weapon/MuzzleFlashLight") as OmniLight3D
	_muzzle_flash_mesh = get_node_or_null("RightArm/Weapon/MuzzleFlashMesh") as MeshInstance3D
	_wrist_comms_label = get_node_or_null("LeftArm/WristComms/ScreenLabel") as Label3D

	if _right_arm:
		_right_arm_default_pos = _right_arm.position
		_right_arm_default_rot = _right_arm.rotation
	if _left_arm:
		_left_arm_default_pos = _left_arm.position
		_left_arm_default_rot = _left_arm.rotation
		# Keep left arm retracted off-screen so both arms do not crowd the camera view
		_left_arm.visible = false

	# Configure Glock 3D model
	var glock_hand := get_node_or_null("RightArm/Weapon/Glock17Model/Armature/Skeleton3D/Hand_Mesh") as MeshInstance3D
	if glock_hand:
		glock_hand.visible = false

	if _muzzle_light:
		_muzzle_light.visible = false
	if _muzzle_flash_mesh:
		_muzzle_flash_mesh.visible = false

	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "ViewmodelAudio"
	_audio_player.bus = "SFX"
	add_child(_audio_player)

	call_deferred("_find_camera")

func _find_camera() -> void:
	var parent := get_parent()
	if parent is Camera3D:
		_camera = parent
	else:
		_camera = get_viewport().get_camera_3d()

func update_mouse_sway(mouse_delta: Vector2) -> void:
	# Convert mouse movement to viewmodel lag
	_sway_offset.x = clampf(mouse_delta.x * 0.0018, -deg_to_rad(max_sway_degrees), deg_to_rad(max_sway_degrees))
	_sway_offset.y = clampf(mouse_delta.y * 0.0018, -deg_to_rad(max_sway_degrees), deg_to_rad(max_sway_degrees))

func update_procedural_motion(delta: float, velocity: Vector3, is_grounded: bool) -> void:
	# Recover sway back to center
	_sway_offset = _sway_offset.lerp(Vector2.ZERO, sway_smooth * delta)

	# Smooth interpolation between Hipfire and ADS
	if _right_arm:
		var target_arm_pos := ADS_RIGHT_ARM_POS if is_aiming else _right_arm_default_pos
		var target_arm_rot := ADS_RIGHT_ARM_ROT if is_aiming else _right_arm_default_rot
		var ads_speed: float = 16.0 if is_aiming else 12.0
		_right_arm.position = _right_arm.position.lerp(target_arm_pos, ads_speed * delta)
		_right_arm.rotation = _right_arm.rotation.lerp(target_arm_rot, ads_speed * delta)

	var motion_damping: float = 0.2 if is_aiming else 1.0
	var speed := Vector2(velocity.x, velocity.z).length()
	var is_moving := is_grounded and speed > 0.1

	if is_moving:
		_bob_timer += delta * (speed * 1.8)
	else:
		_bob_timer += delta * 1.8

	# Sinusoidal bobbing
	var bob_h := cos(_bob_timer * 0.5) * (walk_bob_amount if is_moving else idle_bob_amount) * 0.6 * motion_damping
	var bob_v := sin(_bob_timer) * (walk_bob_amount if is_moving else idle_bob_amount) * motion_damping

	var target_pos := _default_pos + Vector3(bob_h, bob_v, 0.0)
	var target_rot := _default_rot + Vector3(-_sway_offset.y * 0.8 * motion_damping, -_sway_offset.x * 0.8 * motion_damping, -bob_h * 2.0)

	position = position.lerp(target_pos, 10.0 * delta)
	rotation = rotation.lerp(target_rot, 10.0 * delta)

func shoot() -> void:
	if not _can_shoot or _is_slapping or is_reloading:
		return

	if ammo <= 0:
		reload()
		return

	_can_shoot = false
	ammo -= 1
	ammo_changed.emit(ammo, max_ammo)

	# Play Suppressed Gunshot Audio
	if _audio_player:
		_audio_player.stream = SoundSynthesizer.get_gunshot()
		_audio_player.play()

	# Trigger Glock 3D fire animation
	var glock_anim := get_node_or_null("RightArm/Weapon/Glock17Model/AnimationPlayer") as AnimationPlayer
	if glock_anim and glock_anim.has_animation("Armature|Armature|Fire|BaseLayer"):
		glock_anim.stop()
		glock_anim.play("Armature|Armature|Fire|BaseLayer")

	# Visual Recoil on Weapon & Arms
	if _weapon:
		var recoil_tween := create_tween().set_parallel(true)
		recoil_tween.tween_property(_weapon, "position:z", 0.04, 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		recoil_tween.tween_property(_weapon, "rotation:x", deg_to_rad(7.5), 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if _weapon_slide:
			recoil_tween.tween_property(_weapon_slide, "position:z", 0.035, 0.03).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		recoil_tween.chain().tween_property(_weapon, "position:z", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		recoil_tween.parallel().tween_property(_weapon, "rotation:x", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if _weapon_slide:
			recoil_tween.parallel().tween_property(_weapon_slide, "position:z", 0.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Muzzle Flash flash
	if _muzzle_light:
		_muzzle_light.visible = true
	if _muzzle_flash_mesh:
		_muzzle_flash_mesh.visible = true
		_muzzle_flash_mesh.rotation.z = randf() * TAU

	if is_inside_tree():
		var tree := get_tree()
		if tree:
			tree.create_timer(0.045).timeout.connect(func():
				if _muzzle_light:
					_muzzle_light.visible = false
				if _muzzle_flash_mesh:
					_muzzle_flash_mesh.visible = false
			)
			tree.create_timer(shoot_cooldown).timeout.connect(func():
				_can_shoot = true
			)
	else:
		if _muzzle_light:
			_muzzle_light.visible = false
		if _muzzle_flash_mesh:
			_muzzle_flash_mesh.visible = false

	# Perform 3D raycast shot
	_perform_shoot_raycast()

func reload() -> void:
	if is_reloading or _is_slapping or ammo >= max_ammo:
		return

	is_reloading = true
	reload_started.emit()

	# Play reload mechanical audio
	if _audio_player:
		_audio_player.stream = SoundSynthesizer.get_reload_click()
		_audio_player.play()

	# Trigger Glock 3D reload animation
	var glock_anim := get_node_or_null("RightArm/Weapon/Glock17Model/AnimationPlayer") as AnimationPlayer
	var anim_name := "Armature|Armature|ReloadEmpty|BaseLayer" if ammo == 0 else "Armature|Armature|Reload|BaseLayer"
	if glock_anim and glock_anim.has_animation(anim_name):
		glock_anim.stop()
		glock_anim.play(anim_name)

	# Tactical weapon cant & dip during reload
	if _weapon and is_inside_tree():
		var reload_tween := create_tween()
		reload_tween.set_parallel(true)
		reload_tween.tween_property(_weapon, "position:y", -0.04, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		reload_tween.tween_property(_weapon, "rotation:z", deg_to_rad(12.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		reload_tween.chain().set_parallel(true)
		reload_tween.tween_property(_weapon, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		reload_tween.parallel().tween_property(_weapon, "rotation:z", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var reload_duration := 1.05
	if is_inside_tree():
		var tree := get_tree()
		if tree:
			tree.create_timer(reload_duration).timeout.connect(complete_reload)

func complete_reload() -> void:
	ammo = max_ammo
	is_reloading = false
	ammo_changed.emit(ammo, max_ammo)
	reload_completed.emit()

func slap() -> void:
	# Slap feature is shelved for the finale per tactical Call of Duty direction
	return

func _slap_disabled_for_now() -> void:

	# Play Slap Whiff Audio
	if _audio_player:
		_audio_player.stream = SoundSynthesizer.get_slap_whiff()
		_audio_player.play()

	# Animate the Left Hand open-hand SLAP!
	if _left_arm:
		_left_arm.visible = true
		_left_arm.position = _left_arm_default_pos + Vector3(-0.15, -0.4, 0.15)
		var slap_tween := create_tween()

		# Phase 1: Wind-up (pull back from off-screen below camera and twist wrist)
		slap_tween.set_parallel(true)
		slap_tween.tween_property(_left_arm, "position", _left_arm_default_pos + Vector3(-0.16, 0.06, 0.04), 0.1)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		slap_tween.tween_property(_left_arm, "rotation", _left_arm_default_rot + Vector3(deg_to_rad(-15), deg_to_rad(45), deg_to_rad(-25)), 0.1)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		# Phase 2: Forward Whack (explosive horizontal slap across screen center!)
		slap_tween.chain().set_parallel(true)
		slap_tween.tween_property(_left_arm, "position", _left_arm_default_pos + Vector3(0.24, -0.04, -0.28), 0.09)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		slap_tween.tween_property(_left_arm, "rotation", _left_arm_default_rot + Vector3(deg_to_rad(20), deg_to_rad(-55), deg_to_rad(35)), 0.09)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

		# Check collision at apex of the slap
		slap_tween.chain().tween_callback(_perform_slap_raycast)

		# Phase 3: Smooth retraction back down off-screen
		slap_tween.chain().set_parallel(true)
		slap_tween.tween_property(_left_arm, "position", _left_arm_default_pos + Vector3(-0.15, -0.4, 0.15), 0.18)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		slap_tween.tween_property(_left_arm, "rotation", _left_arm_default_rot, 0.18)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

		slap_tween.chain().tween_callback(func():
			_left_arm.visible = false
			_left_arm.position = _left_arm_default_pos
			_is_slapping = false
		)

	# Cooldown
	if is_inside_tree():
		var tree := get_tree()
		if tree:
			tree.create_timer(slap_cooldown).timeout.connect(func():
				_can_slap = true
			)

func _perform_shoot_raycast() -> void:
	if _camera == null:
		return

	var space_state := _camera.get_world_3d().direct_space_state
	var screen_center := get_viewport().get_visible_rect().size * 0.5
	if not is_aiming:
		screen_center += Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))

	var from := _camera.project_ray_origin(screen_center)
	var to := from + _camera.project_ray_normal(screen_center) * 120.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	# Exclude self and viewmodel
	var owner_pawn := get_parent().get_parent() as CollisionObject3D
	if owner_pawn:
		query.exclude = [owner_pawn.get_rid()]

	var result := space_state.intersect_ray(query)
	if result:
		var hit_node := result.get("collider") as Node3D
		var hit_pos := result.get("position") as Vector3
		var hit_normal := result.get("normal") as Vector3
		fired_weapon.emit(hit_node, hit_pos, hit_normal)
		print("[Viewmodel] Shot hit: %s at %s" % [hit_node.name if hit_node else "World", hit_pos])
		var parent_scene: Node = get_tree().current_scene if is_inside_tree() else null
		if parent_scene == null and is_inside_tree():
			parent_scene = get_tree().root
		if parent_scene:
			ImpactFX.spawn_bullet_impact(parent_scene, hit_pos, hit_normal)

		if hit_node and hit_node.has_method("receive_bullet"):
			hit_node.receive_bullet(40.0, hit_pos, hit_normal)
	else:
		fired_weapon.emit(null, to, Vector3.UP)

func _perform_slap_raycast() -> void:
	if _camera == null:
		return

	var space_state := _camera.get_world_3d().direct_space_state
	var screen_center := get_viewport().get_visible_rect().size * 0.5
	var from := _camera.project_ray_origin(screen_center)
	var to := from + _camera.project_ray_normal(screen_center) * slap_range

	var query := PhysicsRayQueryParameters3D.create(from, to)
	var owner_pawn := get_parent().get_parent() as CollisionObject3D
	if owner_pawn:
		query.exclude = [owner_pawn.get_rid()]

	var result := space_state.intersect_ray(query)
	if result:
		var hit_node := result.get("collider") as Node3D
		var hit_pos := result.get("position") as Vector3
		var hit_normal := result.get("normal") as Vector3
		if _audio_player:
			_audio_player.stream = SoundSynthesizer.get_slap_whack()
			_audio_player.play()
		slap_connected.emit(hit_node, hit_pos, hit_normal)
		print("[Viewmodel] *** SLAP CONNECTED! *** on: %s" % (hit_node.name if hit_node else "World"))

		var parent_scene: Node = get_tree().current_scene if is_inside_tree() else null
		if parent_scene == null and is_inside_tree():
			parent_scene = get_tree().root
		if parent_scene:
			ImpactFX.spawn_slap_impact(parent_scene, hit_pos, hit_normal)

		# Apply physical impulse if rigid body
		if hit_node is RigidBody3D:
			hit_node.apply_impulse(-hit_normal * 14.0 + Vector3.UP * 4.5, hit_pos - hit_node.global_position)
		elif hit_node and hit_node.has_method("receive_slap"):
			hit_node.receive_slap(-hit_normal, 35.0)
	else:
		slap_connected.emit(null, to, Vector3.UP)
		print("[Viewmodel] Slap swung through the air (whiff)")
