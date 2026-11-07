extends Node3D
## AnimatedSlidingDoor - automatic pneumatic industrial sliding door.
## Detects the player pawn via Area3D proximity and smoothly slides open / closed.

signal door_opened()
signal door_closed()

@export var open_distance: float = 1.05
@export var open_duration: float = 0.65
@export var close_duration: float = 0.75
@export var auto_close: bool = true
@export var close_delay_seconds: float = 1.6
@export var is_locked: bool = false

var _is_open: bool = false
var _bodies_in_zone: Array[Node3D] = []
var _door_left: Node3D
var _door_right: Node3D
var _status_light: OmniLight3D
var _indicator_mesh: MeshInstance3D
var _left_closed_x: float = -0.525
var _right_closed_x: float = 0.525
var _tween: Tween
var _close_timer: Timer

const MAT_ACTIVE = preload("res://addons/snss_core/materials/mat_button_active.tres")
const MAT_LOCKED = preload("res://addons/snss_core/materials/mat_button_locked.tres")
const MAT_STANDBY = preload("res://addons/snss_core/materials/mat_button_standby.tres")

func _init() -> void:
	_close_timer = Timer.new()
	_close_timer.name = "CloseTimer"
	_close_timer.one_shot = true
	_close_timer.timeout.connect(_on_close_timer_timeout)

func _ready() -> void:
	_ensure_references()

	var detector := get_node_or_null("ProximityDetector") as Area3D
	if detector:
		if not detector.body_entered.is_connected(_on_proximity_entered):
			detector.body_entered.connect(_on_proximity_entered)
		if not detector.body_exited.is_connected(_on_proximity_exited):
			detector.body_exited.connect(_on_proximity_exited)

	if _close_timer and not _close_timer.is_inside_tree():
		add_child(_close_timer)

	_update_indicator()
	call_deferred("_check_initial_overlap")

func _ensure_references() -> void:
	if _door_left == null:
		_door_left = get_node_or_null("DoorLeft") as Node3D
		if _door_left:
			_left_closed_x = _door_left.position.x
	if _door_right == null:
		_door_right = get_node_or_null("DoorRight") as Node3D
		if _door_right:
			_right_closed_x = _door_right.position.x
	if _status_light == null:
		_status_light = get_node_or_null("StatusLight") as OmniLight3D
	if _indicator_mesh == null:
		_indicator_mesh = get_node_or_null("Frame/StatusIndicatorMesh") as MeshInstance3D

func _check_initial_overlap() -> void:
	await get_tree().physics_frame
	var detector := get_node_or_null("ProximityDetector") as Area3D
	if detector:
		for body in detector.get_overlapping_bodies():
			_on_proximity_entered(body)

func _is_target_actor(body: Node3D) -> bool:
	if body == null or body == self or body == _door_left or body == _door_right:
		return false
	if body is CharacterBody3D:
		return true
	if body.is_in_group("player") or body.is_in_group("actors"):
		return true
	if "player" in body.name.to_lower():
		return true
	return false

func _on_proximity_entered(body: Node3D) -> void:
	if not _is_target_actor(body):
		return

	if not _bodies_in_zone.has(body):
		_bodies_in_zone.append(body)

	if _close_timer:
		_close_timer.stop()

	if is_locked:
		print("[AnimatedDoor] Target entered proximity zone, but door is LOCKED")
		return

	if not _is_open:
		open_door()

func _on_proximity_exited(body: Node3D) -> void:
	_bodies_in_zone.erase(body)

	if auto_close and _bodies_in_zone.is_empty() and _is_open:
		if _close_timer and _close_timer.is_inside_tree():
			_close_timer.start(close_delay_seconds)
		elif not is_inside_tree():
			# Fallback for headless unit test outside active scene loop
			close_door()

func _on_close_timer_timeout() -> void:
	if _bodies_in_zone.is_empty() and _is_open:
		close_door()

func open_door() -> void:
	if _is_open:
		return
	_ensure_references()
	_is_open = true

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween().set_parallel(true).set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	if _door_left:
		_tween.tween_property(_door_left, "position:x", _left_closed_x - open_distance, open_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _door_right:
		_tween.tween_property(_door_right, "position:x", _right_closed_x + open_distance, open_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_update_indicator()
	door_opened.emit()
	print("[AnimatedDoor] Opening - proximity detected (%d actors in zone)" % _bodies_in_zone.size())

func close_door() -> void:
	if not _is_open:
		return
	_ensure_references()
	_is_open = false

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween().set_parallel(true).set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	if _door_left:
		_tween.tween_property(_door_left, "position:x", _left_closed_x, close_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _door_right:
		_tween.tween_property(_door_right, "position:x", _right_closed_x, close_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_update_indicator()
	door_closed.emit()
	print("[AnimatedDoor] Closing - area clear")

func set_locked(locked: bool) -> void:
	is_locked = locked
	_update_indicator()
	if is_locked and _is_open:
		close_door()

func lock_door() -> void:
	set_locked(true)

func unlock_door() -> void:
	set_locked(false)

func _update_indicator() -> void:
	_ensure_references()
	var target_color: Color
	var target_mat: Material

	if is_locked:
		target_color = Color(1.0, 0.15, 0.15, 1.0)
		target_mat = MAT_LOCKED
	elif _is_open:
		target_color = Color(0.2, 1.0, 0.4, 1.0)
		target_mat = MAT_ACTIVE
	else:
		target_color = Color(1.0, 0.65, 0.1, 1.0)
		target_mat = MAT_STANDBY

	if _status_light:
		_status_light.light_color = target_color
	if _indicator_mesh and target_mat:
		_indicator_mesh.set_surface_override_material(0, target_mat)
