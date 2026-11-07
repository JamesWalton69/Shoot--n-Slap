class_name KeycardPickup
extends Area3D
## KeycardPickup - interactive tactical keycard collectible.
## Floats and rotates in 3D space with an emissive pulse for high visibility.

const SoundSynthesizer = preload("res://addons/snss_core/audio/SoundSynthesizer.gd")

signal picked_up(card_name: String)

@export var card_name: String = "ALPHA"
@export var rotate_speed: float = 2.2
@export var bob_amplitude: float = 0.07
@export var bob_frequency: float = 3.0

var _initial_y: float = 0.0
var _time_passed: float = 0.0
var _mesh_node: MeshInstance3D = null
var _glow_light: OmniLight3D = null

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player layer

	_initial_y = position.y
	_mesh_node = get_node_or_null("KeyMesh") as MeshInstance3D

	# Add glowing omnilight if not present
	_glow_light = get_node_or_null("GlowLight") as OmniLight3D
	if _glow_light == null:
		_glow_light = OmniLight3D.new()
		_glow_light.name = "GlowLight"
		_glow_light.omni_range = 3.0
		_glow_light.light_energy = 1.5
		if card_name == "ALPHA":
			_glow_light.light_color = Color(0.1, 0.7, 1.0)
		else:
			_glow_light.light_color = Color(1.0, 0.8, 0.2)
		add_child(_glow_light)

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time_passed += delta
	# Continuous smooth rotation
	rotation.y += rotate_speed * delta

	# Smooth vertical floating bob
	position.y = _initial_y + sin(_time_passed * bob_frequency) * bob_amplitude

	# Subtle pulsing light energy
	if _glow_light:
		_glow_light.light_energy = 1.2 + sin(_time_passed * 4.0) * 0.4

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		picked_up.emit(card_name)
