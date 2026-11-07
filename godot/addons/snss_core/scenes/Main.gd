extends Node3D
## Main - application bootstrap. Loads TOS, then routes through mode select,
## player setup, and into the Part 1 corridor. Managers communicate via signals.

const TOS_SCENE := "res://addons/snss_core/scenes/TOS.tscn"
const MODE_SELECT := "res://addons/snss_core/modescene/GameModeSelect"
const PLAYER_SETUP := "res://addons/snss_core/modescene/PlayerSetup"
const CORRIDOR := "res://addons/snss_core/scenes/Part1Corridor"

func _ready() -> void:
	_connect_managers()
	_load_tos()

func _connect_managers() -> void:
	GameManager.state_changed.connect(_on_game_manager_state_changed)
	GameManager.game_mode_selected.connect(_on_game_mode_selected)
	AudioEnvironmentManager.mode_changed.connect(_on_audio_mode_changed)

func _load_tos() -> void:
	GameManager.transition(GameManager.State.TOS_GATE)

func _on_game_manager_state_changed(new_state: GameManager.State) -> void:
	match new_state:
		GameManager.State.TOS_GATE:
			GameManager.load_scene(TOS_SCENE)
		GameManager.State.MODE_SELECT:
			_show_mode_select()
		GameManager.State.PLAYER_SETUP:
			_show_player_setup()
		GameManager.State.LEVEL_INGRESS:
			_load_corridor()

func _on_game_mode_selected(mode: GameManager.GameMode) -> void:
	GameManager.game_mode = mode
	match mode:
		GameManager.GameMode.NORMAL:
			AudioEnvironmentManager.set_mode(AudioEnvironmentManager.AudioMode.NORMAL)
			EnvironmentController.set_mode(EnvironmentController.Mode.NORMAL)
		GameManager.GameMode.DARK_70:
			AudioEnvironmentManager.set_mode(AudioEnvironmentManager.AudioMode.DARK_70)
			EnvironmentController.set_mode(EnvironmentController.Mode.DARK_70)
	GameManager.transition(GameManager.State.PLAYER_SETUP)

func _show_mode_select() -> void:
	GameManager.load_scene(MODE_SELECT)

func _show_player_setup() -> void:
	GameManager.load_scene(PLAYER_SETUP)

func _on_audio_mode_changed(mode: AudioEnvironmentManager.AudioMode) -> void:
	pass

func _load_corridor() -> void:
	GameManager.load_scene(CORRIDOR)
	GameManager.transition(GameManager.State.CORRIDOR)
