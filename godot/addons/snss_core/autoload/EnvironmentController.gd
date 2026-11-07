extends Node
## EnvironmentController - game-mode lighting/post-processing + flashlight gating.
## Mode NORMAL: standard ambient lighting, post exposure, music bus live.
## Mode DARK_70: ambient exposure clamped for 70% darkness, scene directional
## lights dimmed, player flashlights disabled, audio handled by AudioEnvironmentManager.

signal mode_applied(mode: Mode)

enum Mode { NORMAL, DARK_70 }

var _mode: Mode = Mode.NORMAL
var _fog_color: Color = Color(0.1, 0.1, 0.15, 1.0)
var _all_directional_lights: Array[DirectionalLight3D] = []

var current_mode: Mode:
	get:
		return _mode

func _ready() -> void:
	apply_environment_settings(_mode)

func set_mode(mode: Mode) -> void:
	_mode = mode
	apply_environment_settings(mode)

func apply_environment_settings(mode: Mode) -> void:
	# Rescan here: autoload _ready runs before the scene tree exists.
	_all_directional_lights.clear()
	_find_all_directional_lights(get_tree().get_root())
	match mode:
		Mode.NORMAL:
			_apply_normal()
		Mode.DARK_70:
			_apply_dark_70()
	mode_applied.emit(mode)

func _get_environment() -> Environment:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var we := scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
	return we.environment if we != null else null

func _apply_normal() -> void:
	var env := _get_environment()
	if env:
		env.fog_enabled = false
		env.ambient_light_energy = 1.0
		env.tonemap_exposure = 1.0
		env.background_energy_multiplier = 1.0
	for light in _all_directional_lights:
		if light:
			light.light_energy = 1.0

func _apply_dark_70() -> void:
	var env := _get_environment()
	if env:
		env.fog_enabled = true
		env.fog_light_color = _fog_color
		env.ambient_light_color = _fog_color
		env.ambient_light_energy = 0.25
		env.tonemap_exposure = 0.5
		env.background_energy_multiplier = 0.3
	for light in _all_directional_lights:
		if light:
			light.light_energy = 0.3

func _find_all_directional_lights(root: Node) -> void:
	var stack := [root]
	while stack.size() > 0:
		var node = stack.pop_back()
		if node is DirectionalLight3D:
			_all_directional_lights.append(node)
		for child in node.get_children():
			stack.append(child)