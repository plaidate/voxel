# Voxel engine — developer guide

Voxel is a collection of ten small Playdate games sharing one thin
"Voxatron in a bottle" engine: a fixed 3D room of dither-shaded voxels in
an oblique 3/4 projection, rendered for the 400x240 1-bit screen. This
guide is the architecture of that shared layer and how to add a game to
the collection. For the day-to-day build workflow and design rules learned
along the way, see [DEVELOPING.md](DEVELOPING.md); this document is the
map of the code.

## Repository shape

```
core/         the shared engine — staged into every build
games/<name>/ one game per dir (config/gamestate/game/input/draw/main.lua)
Makefile      stages core/* + games/<name>/* into build/<name>/source, runs pdc
tools/smoke.sh headless Simulator smoke-test runner
dist/         prebuilt .pdx per game (players sideload these)
```

Each game is self-contained under `games/<name>/` and owns its own
`playdate.update` loop. A build **stages** `core/*.lua` and the game's
files side by side into `build/<name>/source` (pdc wants a single source
root), writes a one-line `smokeflag.lua`, and runs `pdc`. Bundle IDs are
`com.sdwfrost.voxel.<game>`; the collection is MIT.

The repo convention is globals-as-modules: `Vox`, `VoxModel`, `VoxPhys`,
`VoxProj`, `Kit`, `Util`, `Harness` are global tables created by the core
files, and each game's `Config`, `State`, `Game`, `Input`, `Draw` are the
same. `import` (not `require`); Lua 5.4. `core/lib.lua` is the single
import that pulls the whole engine in.

## The projection

One fixed room, **96 x 64 x 16** voxels (`Vox.W/D/H`). World -> screen:

```
sx = OX + x * S            -- S  = 4 px per voxel across   (OX = 8)
sy = OY + y * TY - z * TZ  -- TY = 2 px per depth step, TZ = 4 px per height
                           -- (OY = 86)
```

- **x** runs left->right across the screen.
- **y** is depth; y=0 is the back wall, larger y is nearer and lower on
  screen.
- **z** is height; z=0 is the floor, up on screen.

Each voxel draws as a `S x TY` **top face** plus a `S x TZ` **front face**.
Materials **1..4** are dither shades (1 dark .. 4 white); the front face is
drawn one shade darker than the top for a lit-from-above look. Material 0
is black. Conventions the games follow: **1** = goo / lethal dark hazard,
**4** = white for the player, pickups and landmark caps, **2** = mid-gray
fields, **3** = high-ground caps only.

## Core modules

### `vox.lua` — the room
The voxel grid and its renderer. A flat `map[(y*W+x)*H + z+1] = material`
array plus a `colTop[]` cache (highest solid z per column) that keeps
occlusion cheap.

- `Vox.set/get(x,y,z[,m])`, `Vox.solid(x,y,z)` (out-of-room-horizontally
  and below-floor count solid), `Vox.heightAt(x,y)` (standing height = top
  of the highest solid voxel + 1).
- `Vox.buildBG()` renders the **entire static room ONCE** into a 400x240
  background image with hidden-face culling (a face is drawn only if
  nothing is above/in front of it). `Vox.drawBG()` blits it — one blit per
  frame regardless of room complexity.
- `Vox.carve(cx,cy,cz,r)` removes a **sphere** of voxels (floor z=0 is
  indestructible), repaints only the dirty column strip into the
  background image, and **returns the removed voxels** as `{x,y,z,m}` for
  debris bursts.
- `Vox.set(...)` + `Vox.repaint(x0,x1)` is the inverse: **add** terrain at
  runtime and repaint the affected strip (Crumble's rising slime, Bulwark's
  placed walls, Summit/Herd terrain).
- `Vox.drawBlock(px,py,pz,m)` draws one voxel at float coords to the
  current context (dynamic actors).
- `Vox.occlude(wx0,wx1,wy,wz0,wz1)` repaints static terrain *in front of*
  an actor (y > wy) so pillars and walls correctly cover it. The `colTop`
  cache + z-pruning skips flat floor, so it costs ~nothing on open ground.

The performance model: static terrain = one blit/frame; rebuilds and strip
repaints happen **at event rate only** (a carve, a slime rise), never per
frame. Dynamic cost = actors x ~2 fills per voxel + occlusion lookups.
Measured 0.2–2 ms/frame across all games in the Simulator (33 ms budget at
30 fps). Full-room repaints (slime rise, ziggurat erosion) are single-frame
hitches — fine at event rate, never per-frame.

### `voxmodel.lua` — actors
`VoxModel.fromLayers({ {"4.4","4.4"}, {"444","444"}, ... })` builds an
actor from layer strings (one array per z, rows back->front, chars are
materials, `.` = empty). Voxels are centered on x/y and **painter-sorted at
build time**, so `VoxModel.draw(model, wx, wy, wz)` is a straight loop of
`Vox.drawBlock`.

### `voxphys.lua` — actor physics
Actors carry `x, y, z` (feet), `vz`, `hw` (footprint half-width),
`grounded`. Two families:

- **Column-top** (`groundAt`, `tryMove`, `physZ`): stand on the highest
  solid voxel under the footprint, with automatic 1-voxel step-up. No
  tunnels. Used by most games. The 1-voxel step-up limit is also a
  *design tool* — Summit's 2-voxel terrace steps gate enemies that can't
  jump.
- **Tunnel-aware** (`support`, `supportAt`, `tryMoveTun`, `physZTun`):
  stand on the surface directly beneath you, honor headroom, bump heads on
  roofs. Required for any digging/overhang game (Excavate).

### `voxproj.lua` — projectiles
`VoxProj.launch(x,y,z,az,v,elevCos,elevSin)` and `VoxProj.step(p,dt,
gravity,windX)` — a parabolic integrator returning true on impact. Games
own launch offsets and impact effects; the flight math is shared. The
package's artillery AI (Lob `solveAim`, Bulwark `solveShot`) is built on
it: simulate N candidate powers, pick the least-miss, then smear by a
decaying error term.

### `kit.lua` — game scaffolding
White HUD text, panels, cached big text, actor shadows, debris particles,
the painter-sorted draw list, and the player marker. Games built after the
first few lean on this instead of duplicating it (the polish pass collapsed
several per-game copies back into Kit):

- `Kit.title(name, lines)`, `Kit.over(reason, lines)`, `Kit.panel`,
  `Kit.text/centered/bigCentered` — chrome.
- `Kit.shadow(x,y,hw)` — actor ground shadow.
- `Kit.spawnPart/burst/updateParts/drawPart` — debris particles (feed
  `Kit.burst` the removed-voxel list from `Vox.carve`).
- `Kit.marker(wx,wy,wz,t)` — the bold black-outlined white locator chevron,
  drawn last so it survives occlusion. Every avatar game uses it (the user
  explicitly asked for strong player visibility).
- `Kit.drawSorted(list)` — sort `{y=, fn=, arg=}` back-to-front and draw.

Games that keep their **own** `spawnPart`/`updateParts` (Rubble, Crumble,
Lob, Bulwark, Herd) do so deliberately — their particle tunables differ
from Kit's (velocities, bounce friction) and the feel is intentional.

### `cutil.lua` — utilities
`Util.clamp(v,lo,hi)` and the delayed-call scheduler `Util.after(delay,fn)`
/ `Util.runPending(dt)` / `Util.clearPending()` (call `clearPending` on run
restarts so stale callbacks don't fire into a new game).

### `harness.lua` — smoke instrumentation
`smokeflag.lua` (staged by the Makefile) sets `SMOKE_BUILD`;
`Harness.enabled` mirrors it. When off, everything is a no-op and games pay
nothing. When on: pcall-wrapped update writing errors to the `err`
datastore, a 90-frame heartbeat to the `smoke` datastore (with optional
`Harness.extra` fields and `Harness.counters`), and periodic PNG
screenshots via `playdate.simulator.writeToFile`. A game routes its
per-frame update through `Harness.frame(frame, updateFn)` and sets
`Harness.autopilot` (consulted by its input module) and `Harness.shotPath`.

## Adding a game (checklist)

1. Create `games/<name>/` with `pdxinfo` (bundleID
   `com.sdwfrost.voxel.<name>`), `config.lua`, `gamestate.lua`, `game.lua`,
   `input.lua`, `draw.lua`, `main.lua`. Copy the shape from `games/marble/`
   (smallest complete game) or `games/vault/` (rooms-as-data + save). Extra
   data modules are fine (`vault/rooms.lua`).
2. Add `<name>` to `GAMES` in the Makefile.
3. `main.lua`: `import "lib"` then the game modules;
   `setRefreshRate(SMOKE_BUILD and 0 or 30)`; a `playdate.update` that
   wraps `Input.poll -> Game.update(Config.DT) -> Util.runPending ->
   Draw.frame` in `Harness.frame`; set `Harness.extra`, `Harness.autopilot`
   and `Harness.shotPath`.
4. Smoke-shorten timers: `T = SMOKE_BUILD and short or real`.
5. Autopilot drives the same code paths humans use (in `input.lua`, or in
   `game.lua` behind `Harness.enabled`). Follow the stuck-detection /
   AoE-safety / wander-burst lessons in DEVELOPING.md.
6. Verify with `tools/smoke.sh <name>` until both endings are exercised;
   look at the screenshots. **Do not** launch the Simulator by hand — it's
   single-instance.
7. Package: screenshot -> `games/<name>/screenshot.png`, write the game's
   `README.md`, add a row to the root README table and a MANUAL.md section,
   `cp -r out/<Title>.pdx dist/`.

## The ten games — what each one demonstrates

| Game | Crib it for | Key core APIs |
| --- | --- | --- |
| **Rubble** | Real-time carve-combat, crank-aim twin-stick, chase AI with chew-through-cover fallback, wave loop | `Vox.carve`, `VoxPhys.tryMove/physZ`, `Vox.occlude` |
| **Crumble** | Terrain **addition** (rising slime `Vox.set`+full `repaint`), crank-wound spring meter, stood-on erosion, screen shake | `Vox.set/repaint/heightAt`, `VoxPhys` |
| **Lob** | Turn-based phase machine, ballistic-solver AI (bracket-and-smear), per-turn wind | `VoxProj.launch/step`, `Vox.carve` |
| **Bulwark** | Mixed build/siege phases, tetromino cell math + rotation, BFS flood-fill enclosure check, catapult AI | `Vox.set/repaint`, `VoxProj` solver, `Vox.carve` |
| **Herd** | Walker-AI pathing over player-carved terrain (local wall-follow, no pathfinding), crank as a rate dial | `Vox.carve/heightAt/get`, `VoxPhys.tryMove` (splat on hard landing) |
| **Excavate** | Tunnel-aware volumetric play, gravity-settle / cave-in pattern, movable multi-cell world objects (fossils) | `VoxPhys.support/tryMoveTun/physZTun`, `Vox.carve` |
| **Marble** | Heightfield gradient physics **without** VoxPhys (own slope/bounce/air off `Vox.heightAt`), build-once terrain | `Vox.heightAt/get`, `Vox.buildBG` |
| **Summit** | Knockback melee (forward-arc vs radial AoE), timed full-room terrain rebuilds, 2-voxel steps gating enemies | `VoxPhys.tryMove/physZ`, `Vox.buildBG` |
| **Vault** | Rooms-as-data, per-room persistent state, datastore save/continue, door-as-voxels, item/pot/grub tables | whole core: `Vox.*`, `VoxModel`, `VoxPhys`, `Kit`, `Util` |
| **Voxelspace** | Large-scale terrain / column-cast renderer; **does not use the Vox grid** — own value-noise heightmap + VoxelSpace raymarcher | `Kit` chrome + `Harness` only |

**Voxelspace is the exception**: it takes only `Kit.title/panel/text` and
the `Harness` loop from core and owns a self-contained pipeline — a
wrapping 256x256 multi-octave value-noise heightmap (packed height+shade
ints) and a per-column front-to-back raymarcher with a precomputed
depth/fog ladder, 17-level Bayer dither, same-shade run merging and
per-depth `tops[]` culling. Crib it when a game needs terrain at a scale
the fixed room can't hold, or as the template for a no-fail "demo" entry.

## Design rules (learned, user-confirmed)

- A game must **use height/volume** (dig, lob, climb, flood, fall) to earn
  the engine — flat 2D grid logic in voxel paint got cut (see IDEAS.md ✕).
- The projection merges tall adjacent columns into solid walls; keep
  obstacles low and sparse, give landmarks white caps.
- Palette that reads: mid-gray fields with a subtle etched grid, white
  player + pickups, dark enemies/hazards with a white eye pixel, m3 for
  high-ground caps only.
- Crank controls players liked: 1:1 aim, hold-A oscillating power meter
  with release-to-fire, crank dials (release rate, fuse), crank-wind + A
  release (spring / boost / spin).
