# Shoot-'n-Slap — Core Framework (Part 1)

Single-player action-horror FPS, private/non-public build. Core gameplay framework, system managers, and initial testing scene built on **Godot 4.7 (GDScript)**.

## Architecture

```
addons/snss_core/
├── autoload/
│   ├── GameManager.gd        # State machine: TOS_GATE → MODE_SELECT → PLAYER_SETUP → LEVEL_INGRESS → CORRIDOR → ELEVATOR_TRANSITION
│   ├── InputMapper.gd        # Decoupled input abstraction with sensitivity multiplier layer
│   ├── CalibrationTimer.gd   # Glitch calibration randomizer (5–9 min cycles, 4s warning)
│   ├── AudioEnvironmentManager.gd  # Bus snapshot controller (Normal vs 70% Dark)
│   └── EnvironmentController.gd        # Lighting/post-process + flashlight gating
├── modescene/
│   ├── GameModeSelect.gd     # Option A Normal / Option B 70% Dark
│   └── PlayerSetup.gd        # Character setup / mode select entry
├── player/
│   ├── PlayerPawn.gd         # Protagonist controller (zig-zag corridor movement, look, flashlight)
│   └── Elevator.gd           # Fortified service elevator with clearance gating
├── scenes/
│   ├── TOS.tscn              # Blocking TOS gatekeeper
│   ├── GameModeSelect.tscn   # Mode selection
│   ├── PlayerSetup.tscn      # Character setup
│   └── Part1Corridor.tscn    # Part 1 corridor scene (load target)
├── testing/
│   ├── CorridorPrototype.tscn # 90-degree zig-zag corridor prototype
│   └── CalibrationTest.gd     # Calibration timer test overlay
├── plugin.cfg / snss_core.gd # Editor plugin registration
└── inputmap.tres             # Input definitions
```

## Mandatory TOS Gatekeeper

- Warning text: *"If you haven't read the TOS, please go and read. This TOS is not so good that you will not read and it is written by me after all so you have to read. Please go and read the TOS."*
- Four clauses (restricted/private use only; no resale/commercial use; developer legal immunity; take the game lightly).
- **Accept & Enter** → proceeds to character setup/mode select; **Decline** → `OS.terminate(0)`.

## Game Modes

- **Normal Mode** — standard ambient lighting, post exposure, music bus active, 1.0x audio.
- **70% Dark Mode** — ambient exposure clamped for 70% darkness, scene directional lights dimmed, player flashlights disabled; audio locked: ambient/music bus at −inf dB, SFX master at 1.5x linear gain (+3.5 dB), AI hearing radius standard (not scaled).

## Glitch Calibration Sensitivity Randomizer

- Timer triggers every 300–540 s (5–9 min) at a randomized float.
- 4 s escalating warning audio cue before each shift.
- Roll: random float in [0.3, 0.8] applied as axis multiplier on look input vector — **base system mouse sensitivity is never overwritten**.
- Audio click/snap confirmation, then timer auto-resets with a new 5–9 min duration.

## Level Ingress (Part 1)

- Protagonist ("sigma male" night partner) drops through a rooftop hatch to rescue his hostage girlfriend from ghost boss "Bhoot-Teri-Maki".
- Top-floor industrial corridor with 90° zig-zag doglegs, narrow choke points, 3.5–4 m wide geometry (movement remains viable at 0.3x sensitivity).
- Exit: fortified service elevator with clearance check (hostile clearance / terminal interaction) before descent — descent is the transition boundary to Part 2.

## Unit Setup / Testing

1. Open `godot/project.godot` in the Godot Editor (v4.7+).
2. Enable the **SnssCore** addon in `Project → Project Settings → Plugins`.
3. Run `addons/snss_core/scenes/TOS.tscn` as the active scene (it is already set as `run/main_scene`).
4. Accept the TOS, select a mode, then complete character setup to reach the corridor.
5. For rapid calibration testing, open `addons/snss_core/testing/CalibrationTest.tscn` as a separate scene and click **FORCE CALIBRATION (TEST)** (10 s cycle).
6. Corridor prototype: run `addons/snss_core/testing/CorridorPrototype.tscn`.

### Notes

- The corridor prototype includes an in-world sensitivity HUD (BASE x MULTIPLIER = EFFECTIVE).
- Flashlight toggle (F) works only in Normal mode; flashlights are forced off in Dark 70%.
- Input bindings are registered at boot by `SnssInput.register_inputs()` and saved to `inputmap.tres` so the editor sees them.

### Input bindings

| Action | Key |
|--------|-----|
| Move forward | W / Up |
| Move back | S / Down |
| Move left | A / Left |
| Move right | D / Right |
| Jump | Space / Gamepad A |
| Flashlight toggle | F / Gamepad Y |

### Unit testing

- Run `res://addons/snss_core/testing/UnitTest.gd` from the Godot editor (F6) or via CLI:
  `godot --headless --script addons/snss_core/testing/UnitTest.gd`
- Tests cover: input multiplier clamping/normalization, calibration roll range (0.3–0.8), interval range (300–540 s), audio bus locking (−80 dB ambient, +3.52 dB SFX), and GameManager fade gating.

### Test notes

- Default calibration window is 5–9 minutes; use `CalibrationTest` overlay to fast-forward.
- Effective look sensitivity = base system sensitivity × multiplier; multiplier is reported by the Pawn HUD.
- Dark 70% mode verified by confirming ambient/music bus at −80 dB and SFX at +3.52 dB.
