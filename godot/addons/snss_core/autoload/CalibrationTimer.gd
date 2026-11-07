extends Node
## CalibrationTimer - Glitch Calibration randomizer system.
## Triggers every 5-9 minutes (300-540s), emits a 4s warning tone,
## rolls a random multiplier in [0.3, 0.8], and applies it to the player pawn.

signal warning_started()
signal calibration_applied(multiplier: float, elapsed: float)
signal calibration_skipped(reason: String)

const WARNING_SECONDS := 4.0
const INTERVAL_MIN_SECONDS := 300.0
const INTERVAL_MAX_SECONDS := 540.0
const CALIBRATION_BASE := 0.3
const CALIBRATION_MAX := 0.8

enum Phase { IDLE, WARNING, CALIBRATION }

var _timer: Timer
var _warning_timer: Timer
var _elapsed: float = 0.0
var _interval: float = 0.0
var _phase: Phase = Phase.IDLE
var _next_roll: float = 1.0
var _last_applied: float = 1.0
var enabled := true

func _init() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_calibration_timer_timeout)

	_warning_timer = Timer.new()
	_warning_timer.one_shot = true
	_warning_timer.timeout.connect(_on_warning_timer_timeout)

func _ready() -> void:
	if not _timer.is_inside_tree():
		add_child(_timer)
	if not _warning_timer.is_inside_tree():
		add_child(_warning_timer)
	new_calibration_cycle()

func new_calibration_cycle() -> void:
	_elapsed = 0.0
	_phase = Phase.IDLE
	_interval = randf_range(INTERVAL_MIN_SECONDS, INTERVAL_MAX_SECONDS)
	_next_roll = randf_range(CALIBRATION_BASE, CALIBRATION_MAX)
	if is_instance_valid(_timer) and _timer.is_inside_tree():
		_timer.start(_interval)

func _process(delta: float) -> void:
	if not enabled:
		return
	_elapsed += delta

func reset_calibrations() -> void:
	_next_roll = 1.0
	_elapsed = 0.0
	var player := _get_player()
	if player and player.has_method("set_look_multiplier"):
		player.set_look_multiplier(1.0)
	new_calibration_cycle()

func start_test_cycle(duration: float = 10.0) -> void:
	_elapsed = 0.0
	_phase = Phase.IDLE
	_interval = duration
	_next_roll = randf_range(CALIBRATION_BASE, CALIBRATION_MAX)
	if is_instance_valid(_timer) and _timer.is_inside_tree():
		_timer.start(duration)
	print("[CalibrationTimer] Force starting test cycle with duration: ", duration)

func _on_calibration_timer_timeout() -> void:
	if _phase != Phase.IDLE:
		calibration_skipped.emit("calibration_already_running")
		return
	_phase = Phase.WARNING
	_warning_timer.wait_time = WARNING_SECONDS
	if _warning_timer.is_inside_tree():
		_warning_timer.start()
	warning_started.emit()
	print("[CalibrationTimer] Phase: WARNING - 4-second audio hint active")

func _on_warning_timer_timeout() -> void:
	if _phase != Phase.WARNING:
		calibration_skipped.emit("calibration_already_ran")
		return
	_phase = Phase.CALIBRATION
	var player := _get_player()
	if not player:
		calibration_skipped.emit("no_player_found")
		_phase = Phase.IDLE
		new_calibration_cycle()
		return
	if player.has_method("set_look_multiplier"):
		player.set_look_multiplier(_next_roll)
	elif "look_multiplier" in player:
		player.look_multiplier = _next_roll
	_calibration_applied(_next_roll, _elapsed)
	new_calibration_cycle()

func _get_player() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var current_scene := tree.current_scene
	if current_scene:
		if current_scene.has_method("set_look_multiplier"):
			return current_scene
		var player := current_scene.find_child("Player", true, false)
		if player and player.has_method("set_look_multiplier"):
			return player
	var stack: Array[Node] = [tree.root]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		if node != self and node.has_method("set_look_multiplier"):
			return node
		for child in node.get_children():
			stack.append(child)
	return null

func _calibration_applied(multiplier: float, elapsed: float) -> void:
	_last_applied = multiplier
	_elapsed = roundf(elapsed)
	_phase = Phase.IDLE
	calibration_applied.emit(multiplier, elapsed)
	print("[CalibrationTimer] Calibration applied: %.2f (cycle duration: %.0fs)" % [multiplier, elapsed])
