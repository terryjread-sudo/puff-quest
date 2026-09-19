# Neon Twice

Neon Twice is a fresh Godot 4 rhythm campaign. Each song is a level with its own BPM, obstacle patterns, background animation, and progression unlock. Jump and dash on the beat, build your own course, collect stars, and solve quick multiplication gates when time slows down.

## Controls

- Space / Up / controller A / left-side touch: jump or start
- X / Shift / controller X / right-side touch: dash
- 1, 2, 3 or click/tap an answer: solve a quiz gate
- B: pause and open the beat builder
- Builder: number keys select objects, click places, drag empty space to pan, drag objects to move, right-click deletes, Ctrl-Z/Ctrl-Y undo/redo, Ctrl-C/Ctrl-V copy/paste, Enter tests, E exports JSON (downloads on Web), I imports JSON from the clipboard, R restores the default level
- The title screen lists all campaign levels; complete them in order to unlock the next one
- Escape: pause

The current game contains no imported code, scenes, assets, or tests from the previous project. Visuals are drawn procedurally. The campaign levels are versioned JSON-shaped data models containing red hazards, green interactive objects, timetable quiz triggers, stars, and checkpoints.

Colour language is simple: red objects are dangerous, green objects help or change the run, and gold stars are collectibles. Crashes show a short, readable impact moment before respawning at the latest checkpoint; Space or tap skips the moment for an instant retry. While airborne, a mint dotted trajectory and landing crosshair preview where the cube is expected to touch down, helping the player decide whether to dash.

## Run

Open this folder in Godot 4.x and run `main.tscn`. The Web export can be configured from the fresh `project.godot` file.

## Design notes

- Normal tempo: 120 BPM, one beat every 0.5 seconds.
- Each campaign track has its own beat setting: Cyberpunk Menu (120 BPM), Murder on the Metrorail (116 BPM), and Boss Fight (128 BPM).
- Quiz slow motion: the world and music are reduced to 26% speed while the answer prompt is active; the exact player, camera, physics, and music position are restored after a correct answer.
- The run starts with a three-hit shield. Wrong or late answers consume one shield hit; correct answers grant two seconds of invulnerability.
- Wrong or late answers show the multiplication correction before applying the shield/checkpoint consequence.
- Jump timing is rated as PERFECT, GOOD, or normal, with bonus score for landing the jump input on the song beat.
- Level 1 changes tempo and starts a kawaii skeleton chase halfway through, with seeded thrown hazards so the surprise remains fair.
- Level 1 uses a local transparent sprite sheet of the supplied detailed running-skeleton reference, with twelve beat-synchronised poses for the parade and giant leader.
- Catapult launches now accelerate the cube forward over their beat duration instead of teleporting it.
- Progress and best scores are saved in browser local storage.
- All runtime values live in `main.gd` until the game grows into a multi-level data resource.

## Music attribution

- Cyberpunk Menu Music — OpenGameArt.org source supplied for this project.
- Murder on the Metrorail — joeBaxterWebb, ISAo, and SRG774; CC-BY 4.0 / OGA-BY 3.0 components.
- Boss Fight — AiTechEye; OGA-BY 4.0.

## Visual reference

- Running skeleton reference supplied for this project: [Fabled Frame skeleton walk](https://cdnb.artstation.com/p/assets/images/images/033/489/979/original/fabled-frame-skeleton-walk.gif?1609769783).
