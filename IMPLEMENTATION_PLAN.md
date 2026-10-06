# THE LAST LIGHT — Implementation Plan

**Engine:** Godot 4.7.2 · **Renderer:** GL Compatibility (WebGL2) · **Target:** HTML5 / Web + Desktop
**Genre:** First-person horror / puzzle / escape · **Playtime:** 10–15 min · **Themes:** Light · Comic · Twist

---

## 1. Key Technical Decisions

### 1.1 GL Compatibility renderer (mandatory)
Godot's HTML5 export **cannot** run Forward+ (Vulkan). The project is pinned to
`gl_compatibility`, so all visuals must be authored for OpenGL ES 3.0:
no SDFGI, no volumetric fog, no SSAO/SSR. Atmosphere comes from
`BG_COLOR=black` + near-zero ambient + a fake-volumetric light-cone mesh
+ distance fog. Glow **is** supported in Compatibility and is used for
emissive props (exit sign, creature eyes, revealed glyphs).

### 1.2 Code-driven project (almost no `.tscn`)
Hand-authoring hundreds of `.tscn` nodes is the #1 source of merge conflicts and
broken node paths in a jam. Instead:

| File | Count | Role |
|---|---|---|
| `scenes/main.tscn` | 1 | Root `Node3D` + `main.gd`. Builds everything at runtime. |
| `src/**/*.gd` | ~22 | All behaviour, all content. |

The house, its props, and every interactable are generated from **plain GDScript
data tables** (`level_data.gd`, `story.gd`). Designers tweak dictionaries, not
node trees. This also means zero `.tscn` merge conflicts for a 5-person team.

### 1.3 Zero binary assets — everything procedural
No `.glb`, no `.wav`, no `.png` in the repo.
- **Meshes** — `BoxMesh`/`CylinderMesh`/`QuadMesh` primitives + `StandardMaterial3D`.
- **Comic art** — `ComicArt` autoload rasterises panel images at runtime with
  `Image` (paper grain, ink borders, halftone dots, speed lines, blood stains),
  then overlays crisp `Label3D` lettering. Comic + Light merge into one asset.
- **Audio** — `Sfx` autoload synthesises every sound as `AudioStreamWAV`
  (noise bursts, filtered envelopes, FM growls, a looping sub-drone).
  Nothing to license, nothing to download, tiny web payload.

### 1.4 Waypoint graph, not a navmesh
`NavigationMeshGenerator3D` needs runtime baking (async, heavy, and the most
fragile part of a web export). A small hand-placed **waypoint graph** with A* is
deterministic, ~80 lines, exports perfectly, and gives designers direct control
over creature patrol routes. Links auto-connect by distance + forced pairs for
the basement stairs.

---

## 2. Architecture

```
main.gd ────────── builds world, player, creature, UI; owns game flow
│
├── GameState (autoload)  flags · items · attempt · chapter · objectives · signals
├── Story     (autoload)  ALL text: panels, notes, dialogue, per-chapter stingers
├── Sfx       (autoload)  procedural audio synth + pooled one-shot players + drone
├── ComicArt  (autoload)  procedural comic panel rasteriser
├── NavGraph  (autoload)  waypoint graph + A* pathfinding
│
├── player/    player.gd · flashlight.gd · interactor.gd
├── creature/  creature.gd (FSM + senses)
├── world/     level_data.gd · level_builder.gd · interactable.gd · door.gd
│              hiding_spot.gd · comic_panel.gd · pickup.gd · rune_lock.gd
│              note.gd · zone_trigger.gd
└── ui/        hud.gd · main_menu.gd · pause_menu.gd · death_screen.gd
               final_sequence.gd
```

### Signals
`GameState` is the single hub — everything else only emits/receives:
`flag_changed(key)`, `item_added(id)`, `objective_changed(text)`,
`notice(text, dur)`, `chapter_changed(name)`, `attempt_started(n)`,
`player_caught`, `game_completed`.

---

## 3. The Three Theme Systems

### 💡 LIGHT — `flashlight.gd`
- `SpotLight3D` on the camera; toggle `F`; soft spring-lag so it feels handheld.
- Battery drains **only while lit** (1.6 %/s). Spare cells scattered as pickups (+35 %).
- `< 20 %` → flicker + colour shift to red. `0 %` → hard off, panel hints at the dark.
- Fake-volumetric cone mesh (additive) so the beam reads in Compatibility mode.
- Central API used by every other system:
  - `is_lighting(point_global) -> bool` — cone + range test
  - `illuminates(target_global) -> float` — 0..1 for creature detection
  - `signal toggled(on)`

### 📖 COMIC — `comic_panel.gd` + `ComicArt`
- A panel is a `QuadMesh` on a wall with a runtime-generated ink-border texture
  plus `Label3D` dialogue / narration / SFX lettering (`BANG!`, `RUN!`).
- **Reveal rule:** alpha rises only while `flashlight.is_lighting(panel)` is true.
  Move away or switch off → it fades out over 0.6 s. *(Proposal §3, Theme 2.)*
- First reveal plays a paper-rustle SFX and writes the text into the **Journal**
  (`Tab`) — the transient panel forces memory, the journal keeps the game fair.
- One-shot flags: `panel_<id>` so the story never replays itself.

### 🔀 TWIST — `story.gd` + `final_sequence.gd`
- Environmental records are found in sequence: **ATTEMPT #01** (living room),
  **#17** (living room), **#32** (basement lair), **#46** (final room).
- Reaching the Final Room plays a full-screen panel sequence ending on
  **`"YOU HAVE BEEN HERE BEFORE."`**
- Then the game **actually loops**: fade to black → wake in the bedroom again,
  `attempt` counter now **#47**, memory wiped, creature ~6 % faster, and a new
  bedroom panel reading `ATTEMPT #47`. Clearing the loop a second time triggers
  the **TRUE ENDING** (`"THE LIGHT IS YOU."` + credits). Bounded scope, real payoff.

---

## 4. The Creature — `creature.gd`

### 4.1 FSM
```
DORMANT ──► PATROL ──► INVESTIGATE ──► HUNT ──► SEARCH ──► RETURN
                                        │
                                        └──► CATCH ──► death screen
```

### 4.2 Perception (`awareness` 0→1, integrates over time)
| Factor | Effect |
|---|---|
| Distance falloff to `view_range` (16 m) | linear 1.0 → 0 |
| Inside creature view cone (100°) | ×1.0, outside ×0.35 |
| **Player's beam lands on creature** | **+0.65** ← core risk/reward |
| **Creature looking at a lit player** | **+0.45** |
| Player sprinting | ×1.5 |
| Player crouched | ×0.55 |
| Player hidden (wardrobe/under bed) | 0.0 |
| Basement | gain ×1.4, speed ×1.15 |
| Hearing (sprint 10 m / walk 4 m) | adds regardless of line of sight |

At `awareness ≥ 1.0` → `HUNT`. Lose sight for 4 s → `SEARCH` around last known
position → `RETURN` to patrol. Reach within 1.2 m while not hidden → caught.

Movement is `CharacterBody3D.move_and_slide()` + a wall-avoidance ray pair, so it
never clips geometry. Stale-position nudge handles corner cases.

---

## 5. Level — `level_data.gd`

7 areas per proposal §5. Ground floor at `y=0`, basement at `y=-3.6`.

```
      x=0        9      15      24
 z=0  +---------+-------+--------+
      | BEDROOM | HALL  | STORAGE|      hatch → BASEMENT (under storage)
 z=8  +---------+-------+--------+
      |        LIVING ROOM      |        z=17 wall has the FINAL ROOM door
 z=17 +---------------------+---+
      |      FINAL ROOM     |    front door on foyer east wall = the false exit
 z=24 +---------------------+
```

| # | Room | Content |
|---|---|---|
| 1 | Bedroom | Wake-up, **flashlight**, wall message *"DON'T LET THE LIGHT DIE."* |
| 2 | Hallway | Light tutorial panel, **first creature sighting**, hiding spot |
| 3 | Storage | **Rune Lock puzzle** → Iron Key + battery cell |
| 4 | Living Room | ATTEMPT **#01** & **#17** records, more panels, Front Door Key |
| 5 | Basement | Darkest, aggressive creature, lair: ATTEMPT **#32** & **#46** |
| 6 | Exit Area | Front door looks like freedom — it is chained from outside |
| 7 | Final Room | Panel sequence → **twist** → loop |

Walls are generated from `Rect2` room bounds minus doorway gaps, so the floor
plan is a readable data table. Props are placed with a compact
`Prop(name, type, pos, rot, size)` list.

### Rune Lock (Storage) — the light puzzle
Three brass dials, each cycling 4 glyphs. The correct order exists **only** on a
comic panel that is invisible until lit. Player reads it in the beam, sets the
dials, pulls the lever → Iron Key + battery. Puzzle is unsolvable in the dark,
which is the thesis of the game in one interaction.

---

## 6. Game Flow

```
main menu ─► fade in ─► WAKE UP ─► flashlight ─► explore/panels ─► rune lock
    ▲                                        │
    │                                     basement ─► lair reveal
    │                                        │
    │                          front door (chained) ─► FINAL ROOM
    │                                        │
    └── ATTEMPT #47 ◄── "YOU HAVE BEEN HERE BEFORE." ◄┘
              │
              └── second clear ─► TRUE ENDING + credits
```

Death → attempt restarts in the bedroom with the flashlight and collected keys
kept (jam-friendly), creature reset, panels already read stay read.

---

## 7. Build Steps

1. `project.godot` — Compatibility renderer, autoloads, 3D physics layers.
   **Input map is registered at runtime** in `GameState._init()` (`InputMap.add_action`)
   instead of hand-serialized `InputEventKey` blobs — readable and diff-safe.
   Keyboard **and** gamepad bindings (web gamepads work).
2. Autoloads: `GameState` → `Story` → `Sfx` → `ComicArt` → `NavGraph`.
3. World build: environment, room shells, doorway gaps, props, nav points.
4. Player: movement, look, crouch/sprint, headbob, flashlight, interactor, hiding.
5. Systems: panels, interactables, doors, pickups, rune lock, zone triggers.
6. Creature: graph pathing, FSM, senses, SFX cues, glowing eyes.
7. UI: HUD (battery, crosshair, prompt, objective, toasts), Journal, menus, death, finale.
8. Story pass: wire every panel/note/objective; then the loop + true ending.
9. **Verify:** `godot --headless --import`, then `--headless` smoke run of the
   main scene with a scripted bot that walks the critical path, asserting zero
   script errors.
10. **Export:** `Web` preset (single-thread, no Vulkan) → `build/web/`.
    Serve and smoke-test the exported `index.html`.

---

## 8. Performance Budget (WebGL2)

| Item | Budget |
|---|---|
| Draw calls | < 250 |
| Real-time lights | 1 shadowed spot (flashlight) + ≤ 10 unshadowed omnis |
| Shadow atlas | 2048, single spot |
| Triangle count | < 40 k (primitives only) |
| Dynamic nodes | < 400 |
| Target | 60 fps desktop, 30+ fps mid mobile |

Enemy AI ticks at 10 Hz (interleaved), not every frame. Panels only run their
reveal test within 10 m. Procedural textures are generated **once** and cached.

---

## 9. File Map

```
project.godot            export_presets.cfg     icon.svg
scenes/main.tscn
src/autoload/  game_state.gd  story.gd  sfx.gd  comic_art.gd  nav_graph.gd
src/player/    player.gd  flashlight.gd  interactor.gd
src/creature/  creature.gd
src/world/     level_data.gd  level_builder.gd  interactable.gd  door.gd
               hiding_spot.gd  comic_panel.gd  pickup.gd  rune_lock.gd
               note.gd  zone_trigger.gd  props.gd
src/ui/        hud.gd  main_menu.gd  pause_menu.gd  death_screen.gd
               final_sequence.gd
```