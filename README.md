# The Last Light

A first-person horror/puzzle game built for the Game Off: *"the game is a lie."*

You awaken in a forgotten house. Your only companion is an unreliable flashlight. Comic panels reveal fragments of a truth you were meant to forget. Something else wants the dark back.

## What it is

- **Light is information.** Spray-painted comic frames are unreadable until the beam lands on them. The runic lock only becomes solvable by reading the panel that reveals its sequence.
- **Noise draws it.** Running, bumping into objects, and opening doors make enough noise to pull the creature toward you. Crouch, move slowly, and use cover.
- **Hiding is safety.** Closets and the under-stair recess can conceal you. Leave cover to act — you can't interact freely from behind a shut panel.
- **The cycle.** This isn't a clean escape. The answer keeps rewriting itself. Push through once to learn, push through again to *understand*.

## Running (desktop)

1. Install [Godot Engine 4.7.2](https://godotengine.org/download/4.7.2/).
2. Open this project in Godot: `project.godot`.
3. Press `F5` to run.

## Web export

A build already lives in `build/web/`. To build fresh:

```bash
godot --headless --export-release "Web" build/web/index.html
```

The export preset uses `gl_compatibility` so it runs well in browsers on machines that can't do Forward+.

## Controls

| Action | Key/Mouse |
|---|---|
| Move | WASD / Arrow keys |
| Look | Mouse |
| Sprint | Shift |
| Crouch | Ctrl |
| Jump | Space |
| Interact | E |
| Toggle torch | F (or the on-screen key) |
| Journal | J |
| Pause | Escape |

## Puzzle notes

- **Front door:** Chained. It was never meant to be an exit. Stop wasting your charge on it.
- **Back door:** The basement key sets `has_back_key` and unbolts it. It won't open without it.
- **Rune lock & hatch:** Read the storage clue while the beam covers it. Three dials cycle glyphs; the lever checks your guess. Get it right and the cellar hatch swings open.
- **The chair:** A room of its own. Sit down. The game will show you what it wants to show you.


## Quick completion hint

1. **Get light:** Pick up the torch on the nightstand in the bedroom. Press `F` to turn it on.
2. **Follow clues:** Read the comic panels by pointing your torch at them. The top-left objective tells you what to do.
3. **Into the basement:** In the storage room, read the rune panel with your torch. Set the three dials to **EYE**, **MOON**, **WAVE**, then pull the lever to open the hatch.
4. **Find the key:** Head down into the basement and search for the key.
5. **Unlock the way:** The key opens the **boarded back door** in the exit hall (the front door is chained and cannot be opened).
6. **Finish:** Go back upstairs through the back door and sit in the **chair** in the final room.

Tip: Enable **Kid Mode** from `Pause` (Esc) if you want bigger text, arrow-key looking, slower battery drain, and the objective to spell out every step.
### Stuck in the bedroom?

You spawn near the middle of the bedroom. The exit to the hallway is on the **east wall** (toward larger X), around **x=9, z ~4.7–5.7**. Just pick up the torch, face east, and walk through the open doorway. No key is needed.

### Getting to the basement

1. Go from bedroom → hallway → storage room (east end of hallway).
2. Shine your torch at the rune panel on the east wall to reveal the clue.
3. Set dials: **1=EYE, 2=MOON, 3=WAVE**, then pull the lever (opens the hatch in the storage room floor).
4. Walk to the open hatch and take the stairs down to the basement.

### Where are the stairs?

The basement stairs are through the **hatch in the storage room floor**. After opening it (solve the rune lock with EYE, MOON, WAVE), look for a large open rectangle in the floor near the **south side** of the storage room (around x ~19–21, z ~2–6). Walk to the edge and go down the stairs into the basement.

## Technical

- Code-first: everything is generated at runtime (shapes, textures, comics, SFX, UI). No art or audio binaries to lose.
- Autoloads: `GameState`, `Story`, `Sfx`, `ComicArt`, `NavGraph`.
- Rendering: GL Compatibility (WebGL2) — no Forward+-only features.
- Node budget: intentionally lean (< 4k nodes) for web.
- Leak-free-at-exit semantics are in mind, but the fun bit is the story, not the allocations.

## Kid mode

The game can be played by younger players without losing the design. Turn **Kid mode** on or off from the **Pause** menu (`Escape`) — it is off by default.

- **Simpler controls:** Arrow keys can look around in addition to the mouse. No separate look-only keys were removed.
- **Bigger UI:** Objectives, notices and menus scale up for easier reading.
- **Easier puzzles:** The objective list spells out the next step in plain language, including the exact rune sequence. The lock shows the answer when kid mode is on and keeps the torch drain much slower.
- **Moody but visible:** The house has soft ambient moonlight and a small practical light in every room, so you can always find your way even if you briefly switch the torch off. Uncollected items glow softly to help you spot them.

## Attributions

Built for Game Off. A love letter to the kind of short, cheap-to-play horror that lives in your head for longer than it had any right to.