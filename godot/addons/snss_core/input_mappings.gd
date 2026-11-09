extends RefCounted
## SnssInput - centralized input map registration for Shoot-'n-Slap.
## Called once at boot; keeps raw-input paths decoupled from core logic.

class_name SnssInput

static func register_inputs() -> void:
	# InputMap is an engine singleton; register actions directly.
	const ACTIONS := [
		"move_forward", "move_back", "move_left", "move_right", "jump",
		"look_right", "look_right_neg", "look_down", "look_down_neg",
		"flashlight_toggle", "reload", "sprint", "fire", "aim_down_sights", "interact",
	]
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	# Mouse / Trigger actions
	_mouse_btn("fire", MOUSE_BUTTON_LEFT)
	_mouse_btn("aim_down_sights", MOUSE_BUTTON_RIGHT)
	_joy("fire", JOY_BUTTON_RIGHT_SHOULDER)
	_joy("aim_down_sights", JOY_BUTTON_LEFT_SHOULDER)
	# Movement bindings
	_key("move_forward", KEY_W)
	_key("move_forward", KEY_UP)
	_key("move_back", KEY_S)
	_key("move_back", KEY_DOWN)
	_key("move_left", KEY_A)
	_key("move_left", KEY_LEFT)
	_key("move_right", KEY_D)
	_key("move_right", KEY_RIGHT)
	# Actions
	_key("jump", KEY_SPACE)
	_joy("jump", JOY_BUTTON_A)
	_key("sprint", KEY_SHIFT)
	_joy("sprint", JOY_BUTTON_LEFT_STICK)
	_key("reload", KEY_R)
	_joy("reload", JOY_BUTTON_X)
	# Utilities
	_key("flashlight_toggle", KEY_L)
	_joy("flashlight_toggle", JOY_BUTTON_RIGHT_SHOULDER)
	_key("interact", KEY_E)
	_joy("interact", JOY_BUTTON_B)

static func _mouse_btn(action: String, button_index: MouseButton) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button_index
	_add_event(action, ev)

static func _key(action: String, keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	_add_event(action, ev)

static func _joy(action: String, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	_add_event(action, ev)

static func _add_event(action: String, event: InputEvent) -> void:
	InputMap.action_add_event(action, event)
