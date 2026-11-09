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

# Story & Character Setup (Personalized Narrative)
var player_name: String = "Sigma-7"
var best_friend_name: String = "Vikram"
var girlfriend_name: String = "Pooja"

# Persistent Player State between floors
var player_persistent_state: Dictionary = {
	"current_health": 100.0,
	"max_health": 100.0,
	"ammo": 17,
	"reserve_ammo": 34,
	"look_multiplier": 1.0,
	"has_keycard_alpha": false,
	"has_keycard_beta": false,
}

func save_player_state(pawn: Node) -> void:
	if pawn == null:
		return
	if pawn.get("current_health") != null:
		player_persistent_state["current_health"] = pawn.current_health
	elif pawn.get("hp") != null:
		player_persistent_state["current_health"] = pawn.hp

	if pawn.get("look_multiplier") != null:
		player_persistent_state["look_multiplier"] = pawn.look_multiplier

	# Check ViewmodelRig for ammo
	var head := pawn.get_node_or_null("Head") as Node3D
	if head:
		var cam := head.get_node_or_null("Camera3D") as Camera3D
		if cam:
			var vm := cam.get_node_or_null("ViewmodelRig")
			if vm:
				if vm.get("ammo") != null:
					player_persistent_state["ammo"] = vm.ammo
				if vm.get("reserve_ammo") != null:
					player_persistent_state["reserve_ammo"] = vm.reserve_ammo

	# Floor 3 keycards are consumed upon completing Floor 3
	player_persistent_state["has_keycard_alpha"] = false
	player_persistent_state["has_keycard_beta"] = false

	print("[GameManager] Player state saved: HP=%.1f | Ammo=%d/%d | LookMult=%.2f" % [
		player_persistent_state["current_health"],
		player_persistent_state["ammo"],
		player_persistent_state["reserve_ammo"],
		player_persistent_state["look_multiplier"]
	])

func restore_player_state(pawn: Node) -> void:
	if pawn == null:
		return
	if pawn.get("current_health") != null and player_persistent_state.has("current_health"):
		pawn.current_health = player_persistent_state["current_health"]
		if pawn.has_method("_update_hud"):
			pawn._update_hud()
	elif pawn.get("hp") != null and player_persistent_state.has("current_health"):
		pawn.hp = player_persistent_state["current_health"]

	if pawn.get("look_multiplier") != null and player_persistent_state.has("look_multiplier"):
		pawn.look_multiplier = player_persistent_state["look_multiplier"]

	var head := pawn.get_node_or_null("Head") as Node3D
	if head:
		var cam := head.get_node_or_null("Camera3D") as Camera3D
		if cam:
			var vm := cam.get_node_or_null("ViewmodelRig")
			if vm:
				if vm.get("ammo") != null and player_persistent_state.has("ammo"):
					vm.ammo = player_persistent_state["ammo"]
				if vm.get("reserve_ammo") != null and player_persistent_state.has("reserve_ammo"):
					vm.reserve_ammo = player_persistent_state["reserve_ammo"]
				if vm.has_signal("ammo_changed"):
					vm.ammo_changed.emit(vm.ammo, vm.get("max_ammo") if vm.get("max_ammo") != null else 17)

	print("[GameManager] Player state restored on pawn: HP=%.1f | LookMult=%.2f" % [
		pawn.get("current_health") if pawn.get("current_health") != null else (pawn.get("hp") if pawn.get("hp") != null else 100.0),
		pawn.get("look_multiplier") if pawn.get("look_multiplier") != null else 1.0
	])

func set_story_names(p_name: String, bf_name: String, gf_name: String) -> void:
	player_name = p_name.strip_edges() if p_name.strip_edges() != "" else "Sigma-7"
	best_friend_name = bf_name.strip_edges() if bf_name.strip_edges() != "" else "Vikram"
	girlfriend_name = gf_name.strip_edges() if gf_name.strip_edges() != "" else "Pooja"
	print("[GameManager] Story names registered - Player: %s | Antagonist: %s | Hostage: %s" % [
		player_name, best_friend_name, girlfriend_name
	])

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
	if path.ends_with(".gd"):
		var script: Script = load(path)
		if script and script.can_instantiate():
			var node := script.new() as Node
			var current := get_tree().current_scene
			if current:
				current.queue_free()
			get_tree().root.add_child(node)
			get_tree().current_scene = node
			_state = State.CORRIDOR
			state_changed.emit(_state)
			print("[GameManager] Loaded script scene directly: ", path)
			return
	var err: Error = get_tree().change_scene_to_file(path)
	if err != Error.OK:
		push_error("GameManager: failed to change scene: ", err)
	else:
		_state = State.CORRIDOR
		state_changed.emit(_state)

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
