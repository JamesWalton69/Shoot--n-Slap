extends CharacterBody3D
## CorridorHenchman - tactical security enemy for Shoot-'n-Slap.
## Features procedural ragdoll/stagger animations when slapped or shot,
## dizzy star visual FX, glowing red optical visor, and patrol/alert AI.

const SoundSynthesizer = preload("res://addons/snss_core/audio/SoundSynthesizer.gd")
const ImpactFX = preload("res://addons/snss_core/fx/ImpactFX.gd")
const HenchmanAnimationHelper = preload("res://addons/snss_core/enemy/HenchmanAnimationHelper.gd")

signal enemy_staggered(slap_count: int)
signal enemy_defeated()

enum State { PATROL, ALERT, STAGGERED, DEAD }

@export var max_health: float = 100.0
@export var patrol_distance: float = 5.0
@export var move_speed: float = 2.4
@export var run_speed: float = 4.2
@export var attack_range: float = 22.0
@export var bullet_damage: float = 16.0

var current_health: float = 100.0
var current_state: State = State.PATROL

var _visual_rig: Node3D
var _head: Node3D
var _visor_light: OmniLight3D
var _visor_mesh: MeshInstance3D
var _dizzy_stars: CPUParticles3D
var _audio_player: AudioStreamPlayer3D
var _anim_player: AnimationPlayer
var _muzzle_light: OmniLight3D

var _default_head_rot: Vector3
var _spawn_pos: Vector3
var _patrol_dir: float = 1.0
var _slap_count: int = 0
var _stagger_timer: float = 0.0
var _shoot_cooldown: float = 1.0

var _visor_mat_alert: StandardMaterial3D
var _visor_mat_stunned: StandardMaterial3D

func _ready() -> void:
	current_health = max_health
	_spawn_pos = global_position

	_visual_rig = get_node_or_null("VisualRig") as Node3D
	_head = get_node_or_null("VisualRig/Head") as Node3D
	_visor_light = get_node_or_null("VisualRig/Head/VisorLight") as OmniLight3D
	_visor_mesh = get_node_or_null("VisualRig/Head/VisorMesh") as MeshInstance3D
	_dizzy_stars = get_node_or_null("VisualRig/Head/DizzyStars") as CPUParticles3D
	_audio_player = get_node_or_null("AudioPlayer") as AudioStreamPlayer3D

	# Retarget Mixamo animation tracks onto TacticalSoldier's CC skeleton
	var anim_node := get_node_or_null("VisualRig/TacticalSoldier/AnimationPlayer") as AnimationPlayer
	if anim_node:
		_anim_player = anim_node
		var lib := HenchmanAnimationHelper.get_animation_library()
		if not _anim_player.has_animation_library("tactical"):
			_anim_player.add_animation_library("tactical", lib)
		_play_animation("idle")

	if _head:
		_default_head_rot = _head.rotation

	# Gun Muzzle Flash light
	_muzzle_light = OmniLight3D.new()
	_muzzle_light.name = "GunMuzzleFlash"
	_muzzle_light.light_color = Color(1.0, 0.7, 0.2)
	_muzzle_light.light_energy = 3.5
	_muzzle_light.omni_range = 4.5
	_muzzle_light.position = Vector3(0.2, 1.2, 0.6)
	_muzzle_light.visible = false
	if _visual_rig:
		_visual_rig.add_child(_muzzle_light)

	if _dizzy_stars:
		_dizzy_stars.emitting = false

	# Setup visor materials
	_visor_mat_alert = StandardMaterial3D.new()
	_visor_mat_alert.albedo_color = Color(0.9, 0.1, 0.1)
	_visor_mat_alert.emission_enabled = true
	_visor_mat_alert.emission = Color(1.0, 0.15, 0.15)
	_visor_mat_alert.emission_energy_multiplier = 3.0

	_visor_mat_stunned = StandardMaterial3D.new()
	_visor_mat_stunned.albedo_color = Color(1.0, 0.8, 0.1)
	_visor_mat_stunned.emission_enabled = true
	_visor_mat_stunned.emission = Color(1.0, 0.85, 0.2)
	_visor_mat_stunned.emission_energy_multiplier = 2.5

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= 12.0 * delta

	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.ALERT:
			_process_alert(delta)
		State.STAGGERED:
			_process_stagger(delta)

	move_and_slide()

func _play_animation(anim_name: String, custom_blend: float = 0.2) -> void:
	if _anim_player and _anim_player.has_animation("tactical/" + anim_name):
		if _anim_player.current_animation != "tactical/" + anim_name:
			_anim_player.play("tactical/" + anim_name, custom_blend)

func _process_patrol(delta: float) -> void:
	# Passive visual scanning for player
	var player := _find_player()
	if player:
		var dist := global_position.distance_to(player.global_position)
		if dist <= 14.0 and _has_line_of_sight(player):
			current_state = State.ALERT
			print("[Henchman] Player spotted! Switching to COMBAT ALERT.")
			return

	var dist_spawn := global_position.distance_to(_spawn_pos)
	if dist_spawn > patrol_distance:
		_patrol_dir *= -1.0

	velocity.z = _patrol_dir * move_speed
	velocity.x = 0.0

	# Face movement direction
	if absf(velocity.z) > 0.1:
		var target_yaw := 0.0 if velocity.z > 0.0 else PI
		rotation.y = lerp_angle(rotation.y, target_yaw, 5.0 * delta)
		_play_animation("walk", 0.25)
	else:
		_play_animation("idle", 0.25)

func _process_alert(delta: float) -> void:
	var player := _find_player()
	if player:
		var dir := (player.global_position - global_position)
		dir.y = 0.0
		var dist := dir.length()
		if dist > 0.1:
			var target_rot := atan2(dir.x, dir.z)
			rotation.y = lerp_angle(rotation.y, target_rot, 9.0 * delta)

		var has_los := _has_line_of_sight(player)

		# If in firing range and line of sight is clear, engage with firearms!
		if dist <= attack_range and has_los:
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
			_play_animation("idle", 0.15)
			if _anim_player:
				_anim_player.speed_scale = 1.0

			_shoot_cooldown -= delta
			if _shoot_cooldown <= 0.0:
				_shoot_cooldown = randf_range(1.1, 1.7)
				_fire_at_player(player)
		else:
			# Advance tactically to re-acquire line of sight
			if dir.length_squared() > 2.0:
				var move_dir := dir.normalized()
				velocity.x = move_dir.x * run_speed
				velocity.z = move_dir.z * run_speed
				_play_animation("walk", 0.15)
				if _anim_player:
					_anim_player.speed_scale = 1.35
			else:
				velocity.x = 0.0
				velocity.z = 0.0
				_play_animation("idle", 0.2)
	else:
		current_state = State.PATROL
		if _anim_player:
			_anim_player.speed_scale = 1.0

func _has_line_of_sight(target: Node3D) -> bool:
	if target == null or not is_inside_tree():
		return false
	var space_state := get_world_3d().direct_space_state
	var from := global_position + Vector3(0.0, 1.4, 0.0)
	var to := target.global_position + Vector3(0.0, 1.4, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var res := space_state.intersect_ray(query)
	if res:
		var hit_collider: Node = res.get("collider")
		return hit_collider == target or hit_collider.get_parent() == target
	return true

func _fire_at_player(player: CharacterBody3D) -> void:
	if current_state == State.DEAD or player == null:
		return

	# Play punchy unsuppressed rifle blast
	if _audio_player:
		_audio_player.stream = SoundSynthesizer.get_enemy_rifle_shot()
		_audio_player.pitch_scale = randf_range(0.95, 1.05)
		_audio_player.play()

	# Muzzle flash
	if _muzzle_light:
		_muzzle_light.visible = true
		var tree := get_tree()
		if tree:
			tree.create_timer(0.06).timeout.connect(func():
				if is_instance_valid(_muzzle_light):
					_muzzle_light.visible = false
			)

	# Raycast weapon fire with slight aim inaccuracy
	var from := global_position + Vector3(0.0, 1.35, 0.0)
	var aim_spread := Vector3(randf_range(-0.35, 0.35), randf_range(-0.2, 0.3), randf_range(-0.35, 0.35))
	var to := player.global_position + Vector3(0.0, 1.35, 0.0) + aim_spread

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := space_state.intersect_ray(query)
	if hit:
		var hit_node: Node = hit.get("collider")
		var hit_pos: Vector3 = hit.get("position")
		var hit_norm: Vector3 = hit.get("normal")

		var parent_scene: Node = get_tree().current_scene if is_inside_tree() else get_tree().root
		if parent_scene:
			ImpactFX.spawn_bullet_impact(parent_scene, hit_pos, hit_norm)

		if hit_node == player or (hit_node and hit_node.get_parent() == player):
			if player.has_method("take_damage"):
				player.take_damage(bullet_damage)
				print("[Henchman] Hit landed on player! Dealt %.1f damage." % bullet_damage)

func _process_stagger(delta: float) -> void:
	# Decelerate backward stumble
	velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)

	_stagger_timer -= delta
	if _stagger_timer <= 0.0:
		_recover_from_stagger()

func _find_player() -> CharacterBody3D:
	var root := get_tree().current_scene if is_inside_tree() else null
	if root:
		return root.get_node_or_null("Player") as CharacterBody3D
	return null

## Called by ViewmodelRig when the player slaps this henchman!
func receive_slap(slap_dir: Vector3, damage: float = 35.0) -> void:
	if current_state == State.DEAD:
		return

	_slap_count += 1
	current_health -= damage
	print("[Henchman] SLAPPED! Hit count: %d, HP remaining: %.1f" % [_slap_count, current_health])

	# Play visceral/stagger grunt audio
	if _audio_player:
		_audio_player.stream = SoundSynthesizer.get_henchman_stagger_grunt()
		_audio_player.play()

	if current_health <= 0.0:
		die(slap_dir * 8.0)
		return

	# Enter staggered state
	current_state = State.STAGGERED
	_stagger_timer = 1.2
	enemy_staggered.emit(_slap_count)

	if _anim_player:
		_anim_player.speed_scale = 1.0
	_play_animation("hit", 0.05)

	# Knockback impulse
	var flat_dir := Vector3(slap_dir.x, 0.0, slap_dir.z).normalized()
	velocity = flat_dir * 5.5 + Vector3.UP * 2.2

	# Comical/Visceral Head snap reaction
	if _head:
		var snap_yaw := deg_to_rad(randf_range(40.0, 65.0) * (-1.0 if randf() > 0.5 else 1.0))
		var snap_pitch := deg_to_rad(-25.0)
		var head_tween := create_tween()
		head_tween.tween_property(_head, "rotation", _default_head_rot + Vector3(snap_pitch, snap_yaw, 0.0), 0.08)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		head_tween.tween_property(_head, "rotation", _default_head_rot, 0.35)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Body flinch
	if _visual_rig:
		var body_tween := create_tween()
		body_tween.tween_property(_visual_rig, "rotation:x", deg_to_rad(-22.0), 0.08)
		body_tween.tween_property(_visual_rig, "rotation:x", 0.0, 0.4).set_trans(Tween.TRANS_BOUNCE)

	# Dizzy stars FX
	if _dizzy_stars:
		_dizzy_stars.emitting = true

	# Visor stunned color
	if _visor_mesh:
		_visor_mesh.material_override = _visor_mat_stunned
	if _visor_light:
		_visor_light.light_color = Color(1.0, 0.85, 0.2)

func _recover_from_stagger() -> void:
	if current_state == State.DEAD:
		return

	current_state = State.ALERT
	_play_animation("idle", 0.25)
	if _dizzy_stars:
		_dizzy_stars.emitting = false
	if _visor_mesh:
		_visor_mesh.material_override = _visor_mat_alert
	if _visor_light:
		_visor_light.light_color = Color(1.0, 0.15, 0.15)
	if _head:
		_head.rotation = _default_head_rot

## Called when shot by the silenced combat pistol
func receive_bullet(damage: float = 40.0, hit_pos: Vector3 = Vector3.ZERO, hit_normal: Vector3 = Vector3.UP) -> void:
	if current_state == State.DEAD:
		return

	current_health -= damage
	print("[Henchman] Shot taken! HP remaining: %.1f" % current_health)

	if current_health <= 0.0:
		die(-hit_normal * 4.0)
		return

	current_state = State.ALERT
	_play_animation("hit", 0.05)

	# Bullet flinch
	if _visual_rig:
		var tween := create_tween()
		tween.tween_property(_visual_rig, "position:z", -0.08, 0.05)
		tween.tween_property(_visual_rig, "position:z", 0.0, 0.15)

func is_dead() -> bool:
	return current_state == State.DEAD

func die(death_impulse: Vector3 = Vector3.ZERO) -> void:
	current_state = State.DEAD
	velocity = death_impulse
	enemy_defeated.emit()
	print("[Henchman] Neutralized / KO'd!")

	if _anim_player:
		_anim_player.speed_scale = 1.0
	_play_animation("death", 0.1)

	# Disable collision
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.set_deferred("disabled", true)

	if _dizzy_stars:
		_dizzy_stars.emitting = false

	if _visor_light:
		_visor_light.visible = false

	# Drop tactical ammo resupply crate at death location
	_spawn_death_drop()

	# Dramatic backward fall tween
	if _visual_rig:
		var fall_tween := create_tween().set_parallel(true)
		fall_tween.tween_property(_visual_rig, "rotation:x", deg_to_rad(-90.0), 0.45)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fall_tween.tween_property(_visual_rig, "position:y", -0.75, 0.45)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _spawn_death_drop() -> void:
	if not is_inside_tree():
		return
	var drop := Area3D.new()
	drop.name = "DroppedAmmoBox"
	drop.collision_layer = 2
	drop.collision_mask = 2
	drop.global_position = global_position + Vector3(0.0, 0.3, 0.0)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 0.8, 1.0)
	col.shape = shape
	drop.add_child(col)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.25, 0.25)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.7, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.6, 0.2)
	mesh.material_override = mat
	drop.add_child(mesh)

	drop.body_entered.connect(func(body: Node3D):
		if body is CharacterBody3D:
			var head := body.get_node_or_null("Head")
			if head:
				var cam := head.get_node_or_null("Camera3D")
				if cam:
					var vm := cam.get_node_or_null("ViewmodelRig")
					if vm and vm.get("ammo") != null:
						vm.ammo = vm.max_ammo
						if vm.has_signal("ammo_changed"):
							vm.ammo_changed.emit(vm.ammo, vm.max_ammo)
						print("[AmmoDrop] 17 rounds picked up from eliminated bodyguard!")
			drop.queue_free()
	)

	var parent := get_parent()
	if parent:
		parent.call_deferred("add_child", drop)
