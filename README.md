# Neon Twice

Neon Twice is a fresh Godot 4 rhythm runner. The cube auto-runs through a neon obstacle course synced to the bundled Circuit Punk loop. Jump and dash on the beat, build your own course, collect stars, and solve quick multiplication gates when time slows down.

## Controls

- Space / Up / controller A / left-side touch: jump or start
- X / Shift / controller X / right-side touch: dash
- 1, 2, 3 or click/tap an answer: solve a quiz gate
- B: pause and open the beat builder
- Builder: number keys select objects, click places, right-click deletes, Enter tests, E exports JSON (downloads on Web), I imports JSON from the clipboard, R restores the default level
- Escape: pause

The current game contains no imported code, scenes, assets, or tests from the previous project. Visuals are drawn procedurally. The level is a versioned JSON-shaped data model containing blocks, spikes, catapults, timetable quiz triggers, bounce pads, moving platforms, gravity portals, laser gates, speed rings, stars, and checkpoints.

Laser gates are beat hazards: they switch between ON and OFF on a repeating beat schedule. Pass while the laser is OFF, or dash through it while it is ON.

## Run

Open this folder in Godot 4.x and run `main.tscn`. The Web export can be configured from the fresh `project.godot` file.

## Design notes

- Normal tempo: 120 BPM, one beat every 0.5 seconds.
- Quiz slow motion: world and music are reduced to 26% speed while the answer prompt is active.
- Wrong or late answers break the combo but keep the run alive.
- All runtime values live in `main.gd` until the game grows into a multi-level data resource.
