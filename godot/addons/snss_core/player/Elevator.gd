extends Area3D
## Elevator - fortified service elevator at corridor terminus.
## Checks hostile clearance / terminal interaction before descent.

signal descent_started()
signal descent_aborted(reason: String)

enum Clearance {
	ALLOW,
	TERMINAL_REQUIRED,
	HOSTILE_NEARBY,
	LOCKED,
}

@export var requires_terminal := true
@export var terminal_id := "service_terminal_01"
@export var clearance_radius := 12.0
@export var descent_delay := 6.0

var _active_player: Node = null
var _terminal_reached := false
var _hostile_nearby := false
var _descend_timer: Timer

func _ready() -> void:
	_descend_timer = Timer.new()
	_descend_timer.wait_time = descent_delay
	_descend_timer.one_shot = true
	_descend_timer.timeout.connect(_on_descent_complete)
	add_child(_descend_timer)

func _physics_process(_delta: float) -> void:
	if not _active_player:
		return
	if not has_overlapping_bodies():
		_active_player = null
		return
	var player := get_overlapping_bodies()[0]
	if player.has_method("get_elevator_data"):
		_active_player = player
		_check_clearance()

func _check_clearance() -> void:
	_terminal_reached = _terminal_reached or _is_terminal_reached()
	_hostile_nearby = _is_hostile_nearby()
	var cl := _determine_clearance()
	match cl:
		Clearance.ALLOW:
			_start_descent()
		Clearance.TERMINAL_REQUIRED:
			descent_aborted.emit("terminal not reached")
		Clearance.HOSTILE_NEARBY:
			descent_aborted.emit("hostile in elevator vicinity")
		Clearance.LOCKED:
			descent_aborted.emit("elevator not available")

func _determine_clearance() -> Clearance:
	if _active_player == null:
		return Clearance.LOCKED
	if _hostile_nearby:
		return Clearance.HOSTILE_NEARBY
	if requires_terminal and not _terminal_reached:
		return Clearance.TERMINAL_REQUIRED
	return Clearance.ALLOW

func _is_terminal_reached() -> bool:
	if not requires_terminal:
		return true
	var root = get_tree().get_root()
	for child in root.get_children():
		if child.name == terminal_id:
			return true
	return false

func _is_hostile_nearby() -> bool:
	for node in get_overlapping_bodies():
		if node.has_method("is_hostile") and node.is_hostile():
			return true
	return false

func _start_descent() -> void:
	descent_started.emit()
	_descend_timer.start()

func _on_descent_complete() -> void:
	# Transition boundary to Part 2.
	get_tree().paused = true
	_active_player = null
	_terminal_reached = false
	_hostile_nearby = false
	# Hand off to GameManager for scene fade to Part 2.
	if is_inside_tree():
		var gm := get_node_or_null("/root/GameManager")
		if gm and gm.has_method("fade_out"):
			gm.fade_out()

func try_enter(player: Node) -> void:
	if not is_inside_tree():
		return
	if _active_player == null and has_overlapping_bodies():
		_active_player = get_overlapping_bodies()[0]
