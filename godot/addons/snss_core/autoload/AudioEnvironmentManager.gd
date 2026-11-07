extends Node
## AudioEnvironmentManager - audio bus controller with a snapshot layer.
## Supports Normal vs 70% Dark mode. Dark mode locks: ambient bus to -inf dB
## (absolute silence) and SFX master to 1.5x linear gain (+3.52 dB), independent
## of any menu setting.

signal mode_changed(mode: AudioMode)
signal ambient_bus_level_changed(level_db: float)

enum AudioMode { NORMAL, DARK_70 }

const AMBIENT_BUS_NAME := "Ambient"
const SFX_BUS_NAME := "SFX"

var current_mode: AudioMode = AudioMode.NORMAL:
	set(value):
		current_mode = value
		apply_mode_snapshot()
		mode_changed.emit(value)

var ambient_bus_volume_db: float = 0.0
var sfx_bus_volume_db: float = 0.0
var sfx_linear_gain: float = 1.5
var _sfx_snapshot_volume: float = 0.0
var _ambient_snapshot_volume: float = 0.0

var _snapshots: Dictionary = {}

func _ready() -> void:
	var ambient_bus := _get_bus_index(AMBIENT_BUS_NAME)
	var sfx_bus := _get_bus_index(SFX_BUS_NAME)
	_ambient_snapshot_volume = AudioServer.get_bus_volume_db(ambient_bus)
	_sfx_snapshot_volume = AudioServer.get_bus_volume_db(sfx_bus)
	sfx_bus_volume_db = _sfx_snapshot_volume
	ambient_bus_volume_db = _ambient_snapshot_volume
	_register_snapshots()
	apply_mode_snapshot()

func _get_bus_index(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return idx
	push_warning("AudioEnvironmentManager: bus '%s' not found, creating it." % bus_name)
	AudioServer.add_bus()
	idx = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, bus_name)
	return idx

func _register_snapshots() -> void:
	_snapshots["normal"] = { ambient = 0.0, sfx = 0.0 }
	_snapshots["dark_70"] = { ambient = -80.0, sfx = sfx_bus_volume_db }

func apply_mode_snapshot() -> void:
	match current_mode:
		AudioMode.NORMAL:
			set_ambient_bus_volume_db(_snapshots["normal"].ambient)
			set_sfx_bus_volume_db(_snapshots["normal"].sfx)
		AudioMode.DARK_70:
			set_ambient_bus_volume_db(-80.0) # absolute silence clamp
			set_sfx_bus_volume_db_to_gain(sfx_linear_gain) # +3.52 dB for 1.5x linear gain

func set_ambient_bus_volume_db(level_db: float) -> void:
	ambient_bus_volume_db = level_db
	AudioServer.set_bus_volume_db(_get_bus_index(AMBIENT_BUS_NAME), level_db)
	ambient_bus_level_changed.emit(level_db)

func set_sfx_bus_volume_db(level_db: float) -> void:
	sfx_bus_volume_db = level_db
	AudioServer.set_bus_volume_db(_get_bus_index(SFX_BUS_NAME), level_db)

func set_sfx_bus_volume_db_to_gain(gain: float) -> void:
	# +3.52 dB for 1.5x linear gain (gain clamped to prevent runaway).
	sfx_bus_volume_db = clampf(linear_to_db(gain), -80.0, 6.0)
	AudioServer.set_bus_volume_db(_get_bus_index(SFX_BUS_NAME), sfx_bus_volume_db)

func set_mode(mode: AudioMode) -> void:
	current_mode = mode

func get_mode_snapshot_db(mode: AudioMode) -> Vector2:
	return Vector2(0.0, sfx_bus_volume_db)

func _physics_process(_delta: float) -> void:
	# Heartbeat for any runtime audio drift.
	pass
