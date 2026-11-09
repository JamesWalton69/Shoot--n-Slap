class_name LaserTripwire
extends Area3D
## LaserTripwire - security obstacle for Floor 3 Laser Room.
## Projects an active red laser beam. Crossing it triggers alarms and alerts guards.
## Can be disarmed via the security console.

signal tripped(intruder: Node3D)
signal disarmed()

@export var beam_length: float = 4.0
@export var is_active: bool = true
@export var zap_damage: float = 25.0

var _beam_mesh: MeshInstance3D
var _emitter_light: OmniLight3D
var _audio_player: AudioStreamPlayer3D

const SoundSynthesizer = preload("res://addons/snss_core/audio/SoundSynthesizer.gd")

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player layer

	_setup_visuals()
	_setup_collision()

	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "LaserAudio"
	_audio_player.bus = "SFX"
	add_child(_audio_player)

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _setup_visuals() -> void:
	# Laser Beam Mesh
	_beam_mesh = MeshInstance3D.new()
	_beam_mesh.name = "BeamMesh"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.018
	cyl.bottom_radius = 0.018
	cyl.height = beam_length
	_beam_mesh.mesh = cyl
	_beam_mesh.rotation.z = deg_to_rad(90.0)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.1, 0.1, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.1, 0.1)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mesh.material_override = mat
	add_child(_beam_mesh)

	# Emitter glowing spot
	_emitter_light = OmniLight3D.new()
	_emitter_light.name = "EmitterLight"
	_emitter_light.light_color = Color(1.0, 0.1, 0.1)
	_emitter_light.light_energy = 1.5
	_emitter_light.omni_range = 2.0
	add_child(_emitter_light)

func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "CollisionShape"
	var shape := BoxShape3D.new()
	shape.size = Vector3(beam_length, 0.15, 0.15)
	col.shape = shape
	add_child(col)

func _on_body_entered(body: Node3D) -> void:
	if not is_active:
		return
	if body is CharacterBody3D:
		print("[LaserTripwire] *** INTRUDER DETECTED! Laser beam crossed! ***")
		if body.has_method("take_damage"):
			body.take_damage(zap_damage)
			print("[LaserTripwire] Electrical zap delivered! Inflicted %.1f damage on intruder." % zap_damage)
		tripped.emit(body)
		if _audio_player and is_inside_tree():
			_audio_player.stream = SoundSynthesizer.get_laser_trip_alarm()
			_audio_player.play()

		# Flash emitter
		if _emitter_light and is_inside_tree():
			_emitter_light.light_energy = 5.0
			var tween := create_tween()
			tween.tween_property(_emitter_light, "light_energy", 1.5, 0.4)

func disarm_tripwire() -> void:
	is_active = false
	if _beam_mesh:
		_beam_mesh.visible = false
	if _emitter_light:
		_emitter_light.light_color = Color(0.2, 1.0, 0.3)
		_emitter_light.light_energy = 0.5
	disarmed.emit()
	print("[LaserTripwire] Laser beam disarmed!")
