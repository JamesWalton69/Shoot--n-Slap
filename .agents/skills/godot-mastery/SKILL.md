---
name: godot-mastery
description: Comprehensive expert guidelines for Godot 4.7+ GDScript 2.0, 3D physics, scene composition, and audio/environment orchestration.
---

# Godot 4.7+ Game Development Skill

## 1. GDScript 2.0 Core Rules
- **Strict Static Typing**: Always type variables, method signatures, and return values (`var speed: float = 6.0`, `func move(delta: float) -> void:`).
- **Modern Annotations**: Use `@export`, `@onready`, `@tool`, `@icon`. Never use Godot 3 `export var` or `onready var`.
- **Node Lifecycle**:
  - `_ready()`: Node and children initialized. Safe for child node queries.
  - `_physics_process(delta: float)`: Dedicated to kinematic movement, collision handling, and physics ticks.
  - `_process(delta: float)`: UI updates, smooth camera interpolations, rendering visual passes.
- **Asynchronous Flow**: Use `await signal_or_coroutine` instead of Godot 3 `yield`.

## 2. 3D Scene Architecture & Composition
- **Level Root Principle**: Levels must have a `Node3D` root. Actors (`CharacterBody3D`), static geometry (`StaticBody3D` / CSG), areas (`Area3D`), lighting (`DirectionalLight3D`, `SpotLight3D`), and post-processing (`WorldEnvironment`) must be siblings under the world, NEVER parented under the player pawn.
- **First-Person Rig Hierarchy**:
  ```
  Player (CharacterBody3D)
  ├── CollisionShape3D (CapsuleShape3D)
  ├── Head (Node3D) [Y = 1.7m]
  │   ├── Camera3D
  │   └── Flashlight / SpotLight3D
  └── HUD / CanvasLayer
  ```
- **Camera-Relative Movement**:
  - Rotate pawn body on Y-axis (Yaw) via mouse horizontal delta.
  - Rotate Head on X-axis (Pitch) via mouse vertical delta, clamped to `[-1.55, 1.55]` radians.
  - Project WASD input through horizontal facing transform:
    ```gdscript
    var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
    velocity.x = direction.x * MOVEMENT_SPEED
    velocity.z = direction.z * MOVEMENT_SPEED
    ```

## 3. Lighting & Environment
- **SpotLight3D / OmniLight3D**: Property is `.visible = true / false`, NOT `.enabled`.
- **WorldEnvironment**: Tonemap ACES, Volumetric Fog for industrial ambiance.
- **Triplanar Mapping**: For CSG geometry, use `StandardMaterial3D` with `uv1_triplanar = true` for seamless PBR materials without UV unwrapping.
