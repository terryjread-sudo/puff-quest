# Neon Twice course-generation contract

Campaign courses are deterministic and built from eight-beat chunks. Each chunk has one primary lesson: teach, combine, escalate, recover, quiz, checkpoint, gravity, camera transition, or boss. The same seed must always produce the same course.

## Difficulty

- Easy: one main hazard per chunk, at least 2.25 beats of reaction time, generous collectibles, four shields, and 15-second quizzes.
- Normal: up to two interacting hazards per chunk, at least 1.75 beats of reaction time, three shields, and 12-second quizzes.
- Hard: up to three hazards per chunk, at least 1.35 beats of reaction time, tighter telegraphs, two shields, and 10-second quizzes.

Difficulty may change density, timing, safe-route width, and rewards. It must never remove the only safe route, place a hazard in a boss runway, fill all three behind-camera lanes, or create an unavoidable floor-hazard chain.

## Placement algorithm

1. Select the level seed and divide the timeline into eight-beat chunks.
2. Assign a role and camera mode to every section.
3. Place checkpoints and quizzes first, then reserve two-beat transition zones around them.
4. Reserve boss warning, launch, dodge, and recovery windows.
5. Place required movement objects such as gravity portals, runway platforms, and camera switches.
6. Place hazards using the difficulty budget and minimum reaction time.
7. Place collectibles along the intended safe route so they also teach the solution.
8. Run the playability validator. Shift generated conflicts to the nearest safe quarter-beat; report imported builder conflicts without rewriting them.

## Gravity contract

Every gravity portal must create a real ceiling route. During the inverted window there must be at least one ceiling platform, one ceiling hazard, a readable collectible line, and a clear landing window before gravity returns. The HUD counts down remaining anti-gravity beats and becomes urgent for the final two beats.

## Behind-camera contract

Behind-camera sections use three lanes (`-1`, `0`, `1`). Each obstacle row must leave at least one open lane. Jump and dash checks need a minimum three-beat telegraph because depth is harder to judge. Camera transitions reserve two beats without immediate collision checks.

## Level map

| Level | Sections | Key lesson |
|---|---|---|
| 1 Bone Carnival | teach → combine → escalate → skeleton boss | Rhythm basics and split routes |
| 2 Metrorail Mayhem | teach → combine → gravity → ghost boss | Moving routes and inversion |
| 3 Zombie Village Run | teach → combine → escalate → zombie boss | Jump-runway preparation; shockwaves only spare airborne players |
| 4 Digital Arcade Core | side 0–48 → behind 48–104 → gravity side 104–160 → behind boss 160–224 | Perspective switching and three-lane reading |

Level 4 checkpoints are near beats 44, 100, 156, and 200; quizzes are near beats 28, 88, 140, and 188. Its Core Sentinel rows always preserve an escape lane and use long telegraphs.
