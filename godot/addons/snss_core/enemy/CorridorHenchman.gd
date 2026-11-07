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

var current_health: float = 100.0
var current_state: State = State.PATROL

var _visual_rig: Node3D
var _head: Node3D
var _visor_light: OmniLight3D
var _visor_mesh: MeshInstance3D
var _dizzy_stars: CPUParticles3D
var _audio_player: AudioStreamPlayer3D
var _anim_player: AnimationPlayer

var _default_head_rot: Vector3
var _spawn_pos: Vector3
var _patrol_dir: float = 1.0
var _slap_count: int = 0
var _stagger_timer: float = 0.0

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
	var dist := global_position.distance_to(_spawn_pos)
	if dist > patrol_distance:
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
	# Try to acquire player
	var player := _find_player()
	if player:
		var dir := (player.global_position - global_position)
		dir.y = 0.0
		if dir.length_squared() > 1.5:
			dir = dir.normalized()
			velocity.x = dir.x * run_speed
			velocity.z = dir.z * run_speed
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 8.0 * delta)
			_play_animation("walk", 0.15)
			if _anim_player:
				_anim_player.speed_scale = 1.35
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			_play_animation("idle", 0.2)
			if _anim_player:
				_anim_player.speed_scale = 1.0
	else:
		current_state = State.PATROL
		if _anim_player:
			_anim_player.speed_scale = 1.0

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

	# Dramatic backward fall tween
	if _visual_rig:
		var fall_tween := create_tween().set_parallel(true)
		fall_tween.tween_property(_visual_rig, "rotation:x", deg_to_rad(-90.0), 0.45)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fall_tween.tween_property(_visual_rig, "position:y", -0.75, 0.45)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
