extends Node
## InputMapper - decoupled input abstraction with a sensitivity multiplier layer.
## The hardware baseline is NEVER overwritten; look input is scaled by a runtime
## multiplier set by CalibrationTimer only. Exposed axes are consumed via get_axis().

signal axes_updated()
signal sensitivity_multiplied(new_multiplier: float)

const MULTIPLIER_MIN := 0.3
const MULTIPLIER_MAX := 0.8

var look_sensitivity_multiplier: float = 1.0:
	set(value):
		if value < MULTIPLIER_MIN or value > MULTIPLIER_MAX:
			push_warning("InputMapper: clamping look multiplier %s to [%s, %s]" % [value, MULTIPLIER_MIN, MULTIPLIER_MAX])
			value = clampf(value, MULTIPLIER_MIN, MULTIPLIER_MAX)
		look_sensitivity_multiplier = value
		sensitivity_multiplied.emit(value)

var deadzone: float = 0.15

func _input(event: InputEvent) -> void:
	# Only process mouse movement while the game has no GUI focus.
	if event is InputEventMouseMotion and get_viewport().gui_get_focus_owner() == null:
		apply_look(event)

func apply_look(event: InputEventMouseMotion) -> void:
	# Not used — PlayerPawn handles head rotation directly from raw delta.
	pass

func get_look_vector() -> Vector2:
	# Consumes input axes and applies the multiplier layer.
	var v := Vector2.ZERO
	if InputMap.has_action("look_right"):
		v.x += Input.get_axis("look_right_neg", "look_right")
	if InputMap.has_action("look_down"):
		v.y += Input.get_axis("look_down_neg", "look_down")
	v *= look_sensitivity_multiplier
	v = v.normalized() if v.length() > 0.0 else v
	return v

func _ready() -> void:
	sensitivity_multiplied.connect(_on_multiplier_changed)

func _on_multiplier_changed(new_multiplier: float) -> void:
	axes_updated.emit()
