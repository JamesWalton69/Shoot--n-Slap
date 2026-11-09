class_name WeaponPickup
extends Area3D
## WeaponPickup - in-world weapon grants and ammo resupply crates.
## Same floating pickup style as KeycardPickup; requires [E] (interact) while
## the collector stands within pickup_radius. Ammo crates replenish the
## carried weapon's reserve pool; weapon drops grant ownership + auto-switch.

const SoundSynthesizer = preload("res://addons/snss_core/audio/SoundSynthesizer.gd")
const ViewmodelRigScript = preload("res://addons/snss_core/player/ViewmodelRig.gd")

signal picked_up(item_name: String)

enum Kind { AMMO, WEAPON }

@export var pickup_kind: int = Kind.AMMO
@export var pickup_radius: float = 1.5
@export var rotate_speed: float = 2.2
@export var bob_amplitude: float = 0.07
@export var bob_frequency: float = 3.0
@export var ammo_refill: int = 30

var _collect_prompt: Label3D
var _glow_light: OmniLight3D
var _body_in_range: CharacterBody3D = null
var _is_collected: bool = false
var _time_passed: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player layer

	_build_visuals()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func item_display_name() -> String:
	return "AR-15 RIFLE" if pickup_kind == Kind.WEAPON else "AMMO CRATE"

func _build_visuals() -> void:
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null:
		col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var sphere := SphereShape3D.new()
		sphere.radius = pickup_radius
		col.shape = sphere
		add_child(col)

	# Crate body: green resupply crate for ammo, gun metal crate for weapons
	var mesh := MeshInstance3D.new()
	mesh.name = "CrateMesh"
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.25, 0.25)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	if pickup_kind == Kind.WEAPON:
		mat.albedo_color = Color(0.35, 0.35, 0.4)
		mat.emission_enabled = true
		mat.emission = Color(0.9, 0.55, 0.05)
	else:
		mat.albedo_color = Color(0.2, 0.7, 0.3)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.6, 0.2)
	mesh.material_override = mat
	add_child(mesh)

	_glow_light = get_node_or_null("GlowLight") as OmniLight3D
	if _glow_light == null:
		_glow_light = OmniLight3D.new()
		_glow_light.name = "GlowLight"
		_glow_light.omni_range = 3.0
		_glow_light.light_energy = 1.4
		_glow_light.light_color = Color(1.0, 0.8, 0.2) if pickup_kind == Kind.WEAPON else Color(0.1, 0.7, 0.2)
		add_child(_glow_light)

	_collect_prompt = Label3D.new()
	_collect_prompt.name = "CollectPrompt"
	_collect_prompt.text = "[E] COLLECT " + item_display_name()
	_collect_prompt.font_size = 34
	_collect_prompt.position = Vector3(0.0, 0.5, 0.0)
	_collect_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_collect_prompt.visible = false
	add_child(_collect_prompt)

func _process(delta: float) -> void:
	_time_passed += delta
	rotation.y += rotate_speed * delta

	if _glow_light:
		_glow_light.light_energy = 1.2 + sin(_time_passed * 4.0) * 0.4

	# E-to-collect interaction while a collector stands in the trigger zone
	if _body_in_range != null and not _is_collected:
		if _collect_prompt:
			_collect_prompt.visible = true
		if InputMap.has_action("interact") and Input.is_action_just_pressed("interact"):
			collect(_body_in_range)
	elif _collect_prompt:
		_collect_prompt.visible = false

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and not _is_collected:
		_body_in_range = body

func _on_body_exited(body: Node3D) -> void:
	if body == _body_in_range:
		_body_in_range = null

func collect(collector: CharacterBody3D) -> void:
	## Grants the pickup contents to the collector's viewmodel.
	if _is_collected or collector == null:
		return
	var vm := collector.get_node_or_null("Head/Camera3D/ViewmodelRig") as Node
	if vm == null:
		return

	if pickup_kind == Kind.WEAPON:
		if vm.has_method("grant_weapon"):
			vm.grant_weapon(ViewmodelRigScript.WeaponSlot.AR_15)
	else:
		if vm.get("reserve_ammo") != null:
			# Rifle mag crates when the AR is out; pistol rounds otherwise
			if int(vm.get("active_weapon_slot")) == ViewmodelRigScript.WeaponSlot.AR_15:
				vm.reserve_ammo += ammo_refill
			else:
				vm.reserve_ammo += 17

	_is_collected = true
	if _glow_light:
		_glow_light.light_energy = 2.5
	picked_up.emit(item_display_name())
	queue_free()
