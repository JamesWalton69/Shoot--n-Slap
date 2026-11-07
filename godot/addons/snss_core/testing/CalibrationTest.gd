extends CanvasLayer
## CalibrationTest - overlay used to test the CalibrationTimer in isolation.
## Exposes fast-forward controls so the 5-9 minute cycle can be verified quickly.

const _test_interval_seconds := 10.0

func _ready() -> void:
	_build_overlay()

func _build_overlay() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.5)
	bg.custom_minimum_size = Vector2(1920, 1080)
	add_child(bg)

	var panel = Panel.new()
	panel.position = Vector2(30, 30)
	panel.size = Vector2(580, 250)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	var status = Label.new()
	status.name = "Status"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(status)

	var lbl = Label.new()
	lbl.name = "Label"
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(lbl)

	var buttons = HBoxContainer.new()
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(buttons)

	var btn1 = Button.new()
	btn1.name = "ForceCalibration"
	btn1.text = "FORCE CALIBRATION (TEST)"
	btn1.pressed.connect(_on_force_calibration)
	buttons.add_child(btn1)

	var btn2 = Button.new()
	btn2.name = "ResetTimer"
	btn2.text = "RESET TIMER"
	btn2.pressed.connect(_on_reset)
	buttons.add_child(btn2)

	# Wire label updates from CalibrationTimer signals.
	if CalibrationTimer:
		CalibrationTimer.warning_started.connect(_on_warning_started)
		CalibrationTimer.calibration_applied.connect(_on_calibration_applied)
		CalibrationTimer.calibration_skipped.connect(_on_calibration_skipped)

func _on_force_calibration() -> void:
	# Trigger an immediate calibration cycle for testing (warning + apply in ~4s).
	CalibrationTimer.new_calibration_cycle()

func _on_reset() -> void:
	CalibrationTimer.reset_calibrations()

func _on_warning_started() -> void:
	var lbl = get_node_or_null("Panel/Label")
	if lbl:
		lbl.text = "WARNING: GLITCH CALIBRATION INCOMING"

func _on_calibration_applied(multiplier: float, elapsed: float) -> void:
	var status = get_node_or_null("Panel/Status")
	var lbl = get_node_or_null("Panel/Label")
	if status:
		status.text = "CALIBRATION APPLIED\nmultiplier: %.2f (interval elapsed: %.0fs)\nbase system sensitivity untouched" % [multiplier, elapsed]
	if lbl:
		lbl.text = "Calibration applied. Look multiplier set to %.2f." % multiplier

func _on_calibration_skipped(reason: String) -> void:
	var status = get_node_or_null("Panel/Status")
	if status:
		status.text = "CALIBRATION SKIPPED: %s" % reason
