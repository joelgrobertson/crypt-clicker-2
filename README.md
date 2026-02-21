# Crypt Clicker V5

**Stage-based necromancer defense roguelike** — Defend your crypt as a disembodied necromancer hand in a PS1-style 3D dungeon.

*"Defend Your Castle × Risk of Rain, but you're a necromancer's hand in a PS1-style 3D dungeon."*

## Setup

1. Open this project in **Godot 4.x** (tested with 4.2+)
2. The main scene is `scenes/main.tscn`
3. Press F5 to run

## Controls

| Input | Action |
|-------|--------|
| Left Click | Smite (damage nearest enemy) |
| Left Hold | Channel augments |
| Right Click | Grab enemy/unit |
| Right Release | Throw grabbed entity |
| WASD | Pan camera |
| Scroll Wheel | Zoom in/out |

## Project Structure

```
CryptClickerV5/
├── scenes/           # .tscn scene files
│   ├── main.tscn     # Root scene (camera, hand, lighting, post-process)
│   ├── stages/       # Dungeon stages (Antechamber, etc.)
│   ├── entities/     # Enemy and summon scenes
│   └── ui/           # UI scenes
├── scripts/          # GDScript files
│   ├── core/         # Main game logic, hand controller
│   ├── entities/     # Enemy/summon behavior
│   ├── systems/      # Wave spawner, XP, picks
│   └── ui/           # UI controllers
├── shaders/          # PS1/PSX shaders
│   ├── psx_lit.gdshader       # Vertex jitter + affine mapping (for world objects)
│   ├── psx_unlit.gdshader     # Unlit version (for hand, effects)
│   └── psx_postprocess.gdshader # Color depth + dithering overlay
└── assets/           # Textures, models, sounds, fonts
```

## Art Direction

- **PS1/PSX low-poly aesthetic**: ~300-500 triangle models, 64×64 textures, vertex lighting
- **Render resolution**: 640×480 upscaled to window size (nearest-neighbor filtering)
- **Shaders**: Vertex snapping (jitter), affine texture mapping, 5-bit color depth with ordered dithering

## V5 Design Overview

- Stage-based: Each stage is a dungeon level (Antechamber → Hall of Statues → Laboratory → Bone Pits → Lich's Vault)
- "Losing is progressing": Heroes will eventually overwhelm you and push to the next stage
- Hold tension: Hold longer = more XP/power, but enemies scale with a global timer
- Final stand at Lich's Vault: Must have built a strong enough loadout to win
