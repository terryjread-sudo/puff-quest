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
- Every run starts with a six-second hazard-free mobile tutorial; the cube stays at the start line and the level clock restarts cleanly so the first obstacles approach normally afterward.
- Level 1 then changes tempo and starts a giant kawaii skeleton chase halfway through; the giant slams its knife into the ground every eight beats to bounce the visible world.
- Level 1 uses a local transparent sprite sheet of the supplied detailed running-skeleton reference, with twelve beat-synchronised poses for the giant leader and slam pose.
- Level 2 starts a ghost-train pursuit immediately after its opening tutorial. Around the midpoint, the ghost moves to the right side facing left and sends a travelling wave from right to left; the player and visible objects bounce as the wave reaches them. Near the finish, DASH THE GHOST triggers its supplied death animation.
- The supplied ghost animations are rasterized into transparent left/right-facing local sprite sheets, and missing/empty source frames are held on the nearest valid pose to prevent flashing.
- Catapult launches now accelerate the cube forward over their beat duration instead of teleporting it.
- Stars award diamonds, correct times-table answers award bonus diamonds, and the title-screen shop persists owned/equipped cube skins in browser local storage.
- Each skin also changes the cube's trail, dash flare, landing burst, and shield colour; Prism Pulse adds animated orbiting accents.
- Level completion now gives a clear reward breakdown: diamonds earned, perfect beats, on-beat accuracy, missed opportunities, quizzes solved, best combo, and dashes.
- Quiz recovery explicitly restores the music playback position and restarts the stream if the browser audio element unexpectedly stops.
- All runtime values live in `main.gd` until the game grows into a multi-level data resource.

## Music attribution

- Cyberpunk Menu Music — OpenGameArt.org source supplied for this project.
- Murder on the Metrorail — joeBaxterWebb, ISAo, and SRG774; CC-BY 4.0 / OGA-BY 3.0 components.
- Boss Fight — AiTechEye; OGA-BY 4.0.
- Air Woosh Move — Almitory; CC0, used for the level 2 ghost wave attack.

## Visual reference

- Running skeleton reference supplied for this project: [Fabled Frame skeleton walk](https://cdnb.artstation.com/p/assets/images/images/033/489/979/original/fabled-frame-skeleton-walk.gif?1609769783).
