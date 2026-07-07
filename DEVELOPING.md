# Developing voxel games (engine + workflow notes)

How to build a game in this repo. General Playdate conventions live in
`~/Projects/playdate/PLAYDATE-GUIDE.md`; this file is the Vox-engine
specifics. Written for a fresh session to be productive immediately.

## The engine (`core/`)

One fixed room, 96x64x16 voxels, oblique 3/4 projection:
`sx = OX + x*4`, `sy = OY + y*2 - z*4`. Each voxel draws as a 4x2 top
face + 4x4 front face; materials 1..4 are dither shades (front face uses
the next-darker pattern). Material 1 is conventionally "goo" (lethal
dark stuff) in games that need a hazard, 4 is white (player, landmarks,
pickups).

- `vox.lua` — the grid. `Vox.set/get/solid/heightAt`, `Vox.carve(x,y,z,r)`
  (sphere removal; floor z=0 indestructible; returns removed voxels for
  debris), `Vox.buildBG()/drawBG()` (static terrain renders ONCE into a
  400x240 image with hidden-face culling), `Vox.repaint(x0,x1)` (dirty
  column strip after `Vox.set` changes — this is how terrain gets ADDED),
  `Vox.drawBlock` (dynamic voxel at float coords),
  `Vox.occlude(x0,x1,y,z0,z1)` (repaint terrain in front of an actor so
  walls hide it; per-column height cache + z-pruning keeps it ~free).
- `voxmodel.lua` — actors as layer-string models, painter-sorted at
  build time. `VoxModel.fromLayers({{"4.4","4.4"},{"444","444"},...})`.
- `voxphys.lua` — actor physics. `groundAt/tryMove/physZ` stand actors on
  COLUMN TOPS (no tunnels). `support/tryMoveTun/physZTun` are the
  tunnel-aware variants (stand on the surface beneath, honor headroom,
  bump heads) — required for any digging/overhang game.
- `voxproj.lua` — parabolic shells: `VoxProj.launch(x,y,z,az,v,cos,sin)`,
  `VoxProj.step(p,dt,gravity,windX)` returns true on impact. Also the AI
  pattern: solve aim by simulating candidate powers and picking the
  least-miss (see lob/bulwark `solveShot`).
- `kit.lua` — game scaffolding: `Kit.title/over/panel/text/centered`,
  `Kit.shadow`, `Kit.spawnPart/burst/updateParts/drawPart`,
  `Kit.drawSorted` (painter list of `{y=,fn=,arg=}`), and `Kit.marker`
  (the bold player-locator chevron — every avatar game uses it; user
  explicitly asked for strong player visibility).
- `cutil.lua` — `Util.clamp`, `Util.after(delay,fn)` scheduler
  (`Util.clearPending()` on run restarts), `Util.runPending(dt)`.
- `harness.lua` — smoke instrumentation (see workflow below).

## Adding a game (checklist)

1. `games/<name>/` with `pdxinfo` (bundleID `com.sdwfrost.voxel.<name>`),
   `config.lua`, `gamestate.lua`, `game.lua`, `input.lua`, `draw.lua`,
   `main.lua`. Copy the shape from `games/marble/` (small) or
   `games/vault/` (rooms-as-data, saves). Extra data modules are fine
   (`vault/rooms.lua`).
2. Add the name to `GAMES` in the Makefile.
3. `main.lua` boilerplate: `import "lib"` then the game modules;
   `setRefreshRate(SMOKE_BUILD and 0 or 30)`; `Harness.frame` wrapping
   Input.poll → Game.update(Config.DT) → Util.runPending → Draw.frame;
   `Harness.extra` fields + `Harness.shotPath =
   ".../voxel/build/<name>-shot.png"`; updMs/drwMs rolling timings.
4. Smoke-shorten timers: `T = SMOKE_BUILD and short or real`.
5. Autopilot: either in `input.lua` (synthesizes input) or in `game.lua`
   behind `Harness.enabled` (drives the same code paths humans use).
   Follow the autopilot lessons in the master guide (goal-progress stuck
   detection, AoE safety, wander-burst escape).
6. Verify: `make <name>` then `tools/smoke.sh <name> 240 '"kills":[1-9]'`
   style runs until BOTH endings are exercised. Look at the screenshots.
7. Package: `cp build/<name>-shot.png games/<name>/screenshot.png`,
   write `games/<name>/README.md`, add a row to the root README table,
   mark the idea ● in IDEAS.md, `cp -r out/<Title>.pdx dist/`.

## Performance model

Static terrain costs one blit per frame regardless of complexity —
rebuilds (`buildBG`) and strip repaints happen at event rate only.
Dynamic cost = actors x ~2 fills per voxel + occlusion lookups; measured
0.2–2ms/frame in the Simulator across all nine games (30fps budget is
33ms; device is slower but the headroom is wide). Full-room repaints
(slime rise, ziggurat erosion) are single-frame hitches — fine at event
rate, never per-frame.

## Design rules (learned, user-confirmed)

- A game must USE height/volume (dig, lob, climb, flood, fall) to earn
  the engine — 2D grid logic in voxel paint got cut (see IDEAS.md ✕
  entries).
- The projection merges tall adjacent columns into solid walls; keep
  obstacles low/sparse, and give landmarks white caps.
- Palette that reads: mid-gray (m2) fields with subtle etched grid,
  white (m4) player + pickups, dark (m1) enemies/hazards with a white
  eye pixel, m3 for high-ground caps only.
- Controls users liked: crank = aim (1:1), hold-A oscillating power
  meter with release-to-fire, crank dials (release rate, fuse), crank
  wind + A release (spring/boost/spin).

## Current games (what to crib from)

| Game | Crib for |
| --- | --- |
| rubble | carve combat, crank aim, enemy chase, wave loop |
| crumble | terrain ADDITION (rising fill + full repaint), spring meter |
| lob | turn-based phases, ballistic solver AI, wind |
| bulwark | tetromino placement, flood-fill enclosure check, mixed phases |
| herd | walker AI (sidestep + goal-progress), release-rate dial, tools |
| excavate | tunnel physics, column-settle cave-ins, strata, chevron |
| marble | heightfield gradient physics, bounce/air, pads |
| summit | knockback sumo, terrace maps, timed erosion |
| vault | rooms-as-data, transitions, datastore save/continue, items |
| voxelspace | non-Vox heightmap renderer (VoxelSpace/Comanche), value-noise terrain |

Roadmap and per-idea engine notes: `IDEAS.md`. Everything here was
verified with `tools/smoke.sh` autopilot runs; keep that bar.
