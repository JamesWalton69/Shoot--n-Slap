extends Node
## GameManager - singleton application state manager.
## Orchestrates application state flow and scene transitions.

signal state_changed(new_state: State)
signal game_mode_selected(mode: GameMode)

enum State {
	TOS_GATE,
	MODE_SELECT,
	PLAYER_SETUP,
	ROOFTOP,
	ELEVATOR_DESCENT,
	CORRIDOR,
	ELEVATOR_TRANSITION,
	FADED,
}

enum GameMode {
	NORMAL,
	DARK_70,
}

var _state: State = State.TOS_GATE
var game_mode: GameMode = GameMode.NORMAL

func _ready() -> void:
	Engine.max_fps = 144
	SnssInput.register_inputs()
	print("GameManager ready. State: ", State.keys()[_state])

func get_state() -> State:
	return _state

func transition(to: State) -> void:
	if _state == State.FADED and to != State.TOS_GATE:
		push_warning("GameManager: transition rejected; game is faded.")
		return
	_state = to
	state_changed.emit(_state)

func load_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("GameManager: scene not found: ", path)
		return
	var err: Error = get_tree().change_scene_to_file(path)
	if err != Error.OK:
		push_error("GameManager: failed to change scene: ", err)

func fade_out(duration: float = 1.2, after: Callable = Callable()) -> void:
	_state = State.FADED
	var canvas := CanvasLayer.new()
	canvas.layer = 128
	var rect := ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate.a = 0.0
	canvas.add_child(rect)
	get_tree().root.add_child(canvas)

	var tween := canvas.create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished

	if after.is_valid():
		after.call()

	# Clean up layer
	if is_instance_valid(canvas):
		canvas.queue_free()
