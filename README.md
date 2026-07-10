# Voxel

> Part of **[plAIdate](https://plaidate.github.io)** — AI-built 1-bit games, ports, and engines for the Playdate.

Original 1-bit **voxel** games for the [Playdate](https://play.date),
sharing one thin engine. Sister project to [`phosphor`](../phosphor/)
(vector beam games) and [`dither`](../dither/) (2D pixel/sprite games);
Voxel is the home for Voxatron-style rooms — a solid 3D grid in a 3/4
projection, dither-shaded, and fully destructible.

**New player?** [MANUAL.md](MANUAL.md) is the player's manual — one
section per game with controls, mechanics and tips.
**Building on the engine?** [DEVGUIDE.md](DEVGUIDE.md) covers the
architecture and how to add a game.

## Play it

Prebuilt games live in [`dist/`](dist/) (one `.pdx` per game) and as
zips on the GitHub Releases page. Sideload a `.pdx` at
<https://play.date/account/sideload/> or open it in the Playdate
Simulator — no toolchain needed.

## Games

| Game | One-liner |
| --- | --- |
| [Rubble](games/rubble/) | Wave-survival in a destructible arena: crank-aimed shots and chewing grubs carve the level to bits |
| [Crumble](games/crumble/) | Height-survival: slime floods the room level by level while the columns crumble underfoot; crank-charged spring jumps keep you above it |
| [Lob](games/lob/) | Turn-based artillery duel: crank-powered mortar lobs over a ridge, wind, craters, and an AI that brackets its aim tighter every shot |
| [Bulwark](games/bulwark/) | Rampart: wall in your keep with crank-rotated tetromino pieces, then survive sieges that blast real craters in your defenses |
| [Herd](games/herd/) | Pocket Lemmings: sheep stream toward the gate while you dig, blast and drain goo to carve their route; the crank is the release-rate dial |
| [Excavate](games/excavate/) | Voxel archaeology: sink shafts and tunnels into a stratified mound for buried fossils — unsupported rock falls, on the prize or on you |
| [Marble](games/marble/) | Marble Madness on a heightfield: gradient physics, airborne crests, goo pools, and a crank-wound boost against the clock |
| [Summit](games/summit/) | Sumo on a crumbling ziggurat: shove brutes off the terraces into the goo sea; the crank winds a radial spin attack |
| [Vault](games/vault/) | The flagship dungeon crawl: five data-defined rooms, keys, pots, grubs, a saved run — and every wall is a door if you have a bomb |
| [Voxelspace](games/voxelspace/) | Tech demo: the Comanche VoxelSpace terrain renderer in 1-bit — endless crank-steered flight over procedural mountains, lakes and haze |

## The engine

`core/` is a small fixed-room voxel engine tuned for the 400x240 1-bit
screen and Lua on device:

- `vox.lua` — the room: a 96x64x16 voxel grid, materials as dither
  shades, oblique 3/4 projection (4px per voxel across, 2px per depth
  step, 4px per height step; each voxel is a shaded top + front face).
  Static terrain renders once into a background image with hidden-face
  culling; `Vox.carve()` removes a sphere and repaints only the dirty
  column strip, so destruction is cheap. `Vox.occlude()` repaints the
  terrain in front of a dynamic object using a per-column height cache,
  so walls and pillars correctly cover actors for ~zero cost on flat
  ground. Movement helpers: `solid`, `heightAt`.
- `voxmodel.lua` — actors as tiny voxel models authored in-code as layer
  strings, painter-sorted at build time, drawn per frame with
  `Vox.drawBlock`.
- `voxphys.lua` — shared actor physics: footprint ground sampling,
  horizontal movement with automatic 1-voxel step-up, gravity/landing.
  Terrain can also be *added* at runtime (`Vox.set` + `Vox.repaint`) —
  Crumble's rising slime floods the room this way.
- `cutil.lua` — clamp + delayed-call scheduler.
- `harness.lua` — the smoke-test harness (autopilot hook, pcall'd update,
  datastore heartbeat, periodic simulator screenshots); a staged
  `smokeflag.lua` switches it on per build.

Measured cost in the Simulator: ~0.9ms per frame with a full arena brawl
(background blit + ~150 dynamic voxel faces), comfortably inside a 30fps
budget.

## Development

Requires the Playdate SDK with `pdc` on your PATH. Game names are the
lowercase dirs in `games/`. **New here? Read [DEVELOPING.md](DEVELOPING.md)**
— engine API, add-a-game checklist, smoke-test workflow, and the design
rules learned so far.

- `make <game>` — build one game to `out/<Title>.pdx`
- `make all` — build everything
- `make <game>-smoke` — instrumented build with the autopilot + telemetry
  harness
- `tools/smoke.sh <game> [seconds] [until-grep]` — build the smoke variant,
  run it headlessly in the Simulator, and report

Each game follows the `config.lua` / `gamestate.lua` / `game.lua` /
`input.lua` / `draw.lua` module convention and owns its own
`playdate.update` loop. The Makefile stages `core/` + the game into
`build/<name>/source` and runs `pdc`; bundle IDs are
`com.sdwfrost.voxel.<game>`.

## Licensing

Original work, © 2026 Simon Frost, under the MIT [LICENSE](LICENSE), staged
into every built `.pdx`.
