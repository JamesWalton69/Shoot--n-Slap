# Shoot-'n-Slap — Architecture & Systems Documentation

**Engine:** Godot 4.7 (GDScript, Forward Plus / D3D12, Jolt Physics)
**Build status:** Private / non-public test build (TOS-gated)

---

## 1. High-Level Architecture

```
Project root (godot/)
├── addons/snss_core/            # Self-contained, loadable addon
│   ├── autoload/                # 5 application-wide singletons (Project > Autoload)
│   │   ├── GameManager.gd       # State machine / scene orchestration
│   │   ├── InputMapper.gd       # Input abstraction + sensitivity multiplier layer
│   │   ├── CalibrationTimer.gd  # Glitch calibration randomizer
│   │   ├── AudioEnvironmentManager.gd  # Audio bus snapshot controller
│   │   └── EnvironmentController.gd        # Lighting + flashlight gating
│   ├── modescene/               # Pre-level screens
│   │   ├── GameModeSelect.gd
│   │   └── PlayerSetup.gd
│   ├── player/
│   │   ├── PlayerPawn.gd        # Protagonist controller
│   │   └── Elevator.gd          # Service elevator with clearance gating
│   ├── scenes/
│   │   ├── TOS.tscn
│   │   ├── GameModeSelect.tscn
│   │   ├── PlayerSetup.tscn
│   │   └── Part1Corridor.tscn   # Part 1 corridor (load target)
│   ├── testing/
│   │   ├── CorridorPrototype.tscn
│   │   └── CalibrationTest.gd
│   ├── inputmap.tres            # Input definitions
│   ├── input_mappings.gd        # Input registration helper
│   ├── snss_core.gd + plugin.cfg # Editor plugin registration
│   └── scenes/Main.gd           # Bootstrap layer (optional)
└── project.godot                # Autoload registration, main scene
```

## 2. Design Patterns Used

| Pattern | Location | Purpose |
|---------|----------|---------|
| Singleton (Autoload) | `GameManager`, `InputMapper`, `CalibrationTimer`, `AudioEnvironmentManager`, `EnvironmentController` | Decoupled global access without globals |
| State machine | `GameManager.State` (7 states) | Opaque application flow, guards against invalid transitions |
| Observer / signals | All managers | Loose coupling; e.g. `GameManager.state_changed` → scene load |
| Composition | `PlayerPawn` (`Head`/`Camera3D`/flashlights as children) | Behavior added via sub-nodes, never inheritance chains |
| Multiplier layer | `InputMapper.look_sensitivity_multiplier`, `PlayerPawn.look_multiplier` | Look input = raw × multiplier; hardware baseline never written |
| Snapshot controller | `AudioEnvironmentManager` | Mode changes apply pre-baked bus volumes rather than runtime faders |

## 3. System Specs

### GameManager
- States: `TOS_GATE` → `MODE_SELECT` → `PLAYER_SETUP` → `LEVEL_INGRESS` → `CORRIDOR` → `ELEVATOR_TRANSITION` → `FADED`.
- `transition(to)`: blocks if already `FADED`.
- `load_scene(path)`: `ResourceLoader.exists` guard + `change_scene_to_file`.
- `fade_out(duration, after)`: full-black crossfade via `ColorRect.modulate:a` tween.

### TOS Gatekeeper
- Blocking UI: warning text (exact wording per spec), 4 clauses as labels, two buttons.
- `Accept & Enter` → emits `tos_accepted`, proceeds. `Decline` → `OS.terminate(0)`.
- UI built programmatically (no external art assets required).

### Game Mode Selection
- Option A **Normal Mode**: post exposure 1.0, music bus live, 1.0x audio.
- Option B **70% Dark Mode**: exposure clamp, scene lights dimmed, flashlights disabled, audio locked via `AudioEnvironmentManager` (ambient −inf dB, SFX +3.52 dB / 1.5x linear), AI hearing radius untouched.

### Calibration Timer (Glitch Calibration)
- Cycle: `randf_range(300.0, 540.0)` seconds; `_process` accumulation (`_elapsed`).
- Warning: at timeout → `Phase.WARNING`, 4 s warning, `warning_started()` emitted.
- Apply: `randf_range(0.3, 0.8)` → written to `look_multiplier` on the player; `calibration_applied()` emitted; phase auto-resets with a new interval.
- Guard rails: phase checks prevent re-entrancy; `calibration_skipped` reports why.

### InputMapper / PlayerPawn sensitivity
- `look_sensitivity_multiplier` clamped to [0.3, 0.8]; setter emits `sensitivity_multiplied`.
- Player rotation: `rot = raw_delta × base_look_sensitivity × look_multiplier × fov × constant`.
- No OS-level sensitivity writes; base remains the hardware baseline.

### EnvironmentController
- Discovers all `DirectionalLight3D` nodes in the scene graph at boot.
- Normal: exposure 1.0, ambient 1.0, lights at 1.0.
- Dark 70%: exposure 0.5, ambient_light_energy 0.25, lights at 0.3, fog enabled with dark tint.
- `mode_applied` emitted for consumers.

### PlayerPawn
- Procedural `Head`/`Camera3D` creation if absent (fallback for test scenes).
- Dual SpotLights (left/right) on head; `flashlight_toggle` (F / gamepad Y).
- Dark 70% → `_disable_flashlights()` on ready.
- Movement: raw direction → `Jolt` space move (collision-avoiding) + `move_and_slide` fallback.
- HUD: base × multiplier × effective label shown in-world.
- Elevator: traverses children for `is_hostile()` / terminal presence before descent.

### Elevator
- `Area3D` with clearance states: `ALLOW` / `TERMINAL_REQUIRED` / `HOSTILE_NEARBY` / `LOCKED`.
- `descent_delay` timer → on complete: `get_tree().paused = true`, `GameManager.fade_out()` → transition boundary to Part 2.

## 4. Testing / Prototype Setup

1. Install the SnssCore addon (`addons/snss_core/`), enable it in **Project → Project Settings → Plugins**.
2. Run `res://addons/snss_core/scenes/TOS.tscn` (or set as `run/main_scene` in `project.godot`).
3. Accept TOS → choose mode → character setup → corridor.
4. Rapid calibration test: open `res://addons/snss_core/testing/CalibrationTest.gd` as a separate scene; click **FORCE CALIBRATION (TEST)** to trigger an immediate cycle (uses a 10 s test interval).
5. Corridor prototype: `res://addons/snss_core/testing/CorridorPrototype.tscn`.
6. To verify Dark 70% audio: open **Denoiser/Audio Bus** editor; Ambient bus should read −80 dB, SFX bus +3.52 dB.

### Input Map (default)

| Action | Bindings |
|--------|----------|
| move_forward | W / Up |
| move_back | S / Down |
| move_left | A / Left |
| move_right | D / Right |
| jump | Space / Gamepad Button 0 |
| flashlight_toggle | F / Gamepad Button 7 |
| look_right / look_down | Mouse delta (absolute axes kept in InputMap for display) |

### Corridor Design Notes
- Industrial zig-zag with 90° doglegs and narrow choke points.
- Hallways 3.5–4.0 m wide — movement remains feasible at 0.3x look multiplier.
- Top-floor rooftop hatch ingress (lore): protagonist descends to rescue hostage girlfriend from "Bhoot-Teri-Maki".
- Exit: fortified service elevator with hostile clearance / terminal check; descent = Part 1 → Part 2 boundary.

## 5. Known Limitations / Next Steps (Part 2 scope)
- Audio buses must exist in the project's actual `AudioBuses.tres`; managers read/write by name ("Ambient", "SFX").
- `CalibrationTimer` expects any `Node3D` with a `set_look_multiplier()` method on the scene root to be the calibration target.
- Physics movement uses Jolt direct space on the Pawn; `move_and_slide` is the fallback.
- PlayerPawn `_physics_process` runs `is_multiplayer_authority()` check — for a local single-player build, remove or bypass it.
- Lighting post-process values are camera-environment specific; fine-tune exposure targets per final art.
- Elevator `descent_delay` is 6 s by default; adjust in inspector.
- Part 2 (entity AI, hearing system, hostage mechanics) is a separate build phase.
