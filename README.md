# Neon Twice

Neon Twice is a fresh Godot 4 rhythm runner. The cube auto-runs through a neon obstacle course synced to selectable bundled music. Jump and dash on the beat, build your own course, collect stars, and solve quick multiplication gates when time slows down.

## Controls

- Space / Up / controller A / left-side touch: jump or start
- X / Shift / controller X / right-side touch: dash
- 1, 2, 3 or click/tap an answer: solve a quiz gate
- B: pause and open the beat builder
- Builder: number keys select objects, click places, drag empty space to pan, drag objects to move, right-click deletes, Ctrl-Z/Ctrl-Y undo/redo, Ctrl-C/Ctrl-V copy/paste, Enter tests, E exports JSON (downloads on Web), I imports JSON from the clipboard, R restores the default level
- M on the title screen, or the music button, cycles the available tracks
- Escape: pause

The current game contains no imported code, scenes, assets, or tests from the previous project. Visuals are drawn procedurally. The level is a versioned JSON-shaped data model containing red hazards, green interactive objects, timetable quiz triggers, stars, and checkpoints.

Colour language is simple: red objects are dangerous, green objects help or change the run, and gold stars are collectibles. Crashes show a short, readable impact moment before respawning at the latest checkpoint; Space or tap skips the moment for an instant retry. While airborne, a mint dotted trajectory and landing crosshair preview where the cube is expected to touch down, helping the player decide whether to dash.

## Run

Open this folder in Godot 4.x and run `main.tscn`. The Web export can be configured from the fresh `project.godot` file.

## Design notes

- Normal tempo: 120 BPM, one beat every 0.5 seconds.
- Quiz slow motion: world and music are reduced to 26% speed while the answer prompt is active.
- The run starts with a three-hit shield. Wrong or late answers consume one shield hit; correct answers grant two seconds of invulnerability.
- Catapult launches now accelerate the cube forward over their beat duration instead of teleporting it.
- All runtime values live in `main.gd` until the game grows into a multi-level data resource.
