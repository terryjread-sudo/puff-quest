# Neon Twice

Neon Twice is a fresh Godot 4 rhythm runner. The cube auto-runs through a neon obstacle course at 120 BPM. Jump and dash on the beat, collect stars, and solve quick 2× multiplication gates when time slows down.

## Controls

- Space / Up / controller A / left-side touch: jump or start
- X / Shift / controller X / right-side touch: dash
- 1, 2, 3 or click/tap an answer: solve a quiz gate
- Escape: pause

The current game contains no imported code, scenes, assets, or tests from the previous project. Visuals are drawn procedurally and the soundtrack is an original procedural synth loop locked to the same beat clock.

## Run

Open this folder in Godot 4.x and run `main.tscn`. The Web export can be configured from the fresh `project.godot` file.

## Design notes

- Normal tempo: 120 BPM, one beat every 0.5 seconds.
- Quiz slow motion: world and music are reduced to 26% speed while the answer prompt is active.
- Wrong or late answers break the combo but keep the run alive.
- All runtime values live in `main.gd` until the game grows into a multi-level data resource.

