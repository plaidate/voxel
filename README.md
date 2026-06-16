# Voxel

Original 1-bit **3D** games for the [Playdate](https://play.date), sharing
one thin core library. Sister project to [`phosphor`](../phosphor/) (vector
beam games) and [`dither`](../dither/) (2D pixel/sprite games); Voxel is the
home for games with real 3D — projection, depth, solid shaded forms on the
1-bit screen.

**No games yet.** This package is scaffolding: the shared `core/`, the
`tools/smoke.sh` harness runner, and a `Makefile` ready for the first 3D
game. Add a lowercase dir under `games/` and list it in the Makefile's
`GAMES`.

## Development

Requires the Playdate SDK with `pdc` on your PATH. Game names are the
lowercase dirs in `games/`.

- `make <game>` — build one game to `out/<Title>.pdx`
- `make all` — build everything
- `make <game>-smoke` — instrumented build with the autopilot + telemetry
  harness
- `tools/smoke.sh <game> [seconds] [until-grep]` — build the smoke variant,
  run it headlessly in the Simulator, and report

### Layout

- `core/` — the shared modules: `cutil.lua` (clamp + delayed-call
  scheduler) and `harness.lua` (the smoke-test harness; a staged
  `smokeflag.lua` switches it on per build). The same thin core as
  `dither/` and `classics/`: each game owns its own `playdate.update`
  loop and the `config.lua` / `gamestate.lua` / `game.lua` / `input.lua`
  / `draw.lua` module convention.
- `games/<name>/` — each game's modules plus its assets.
- The Makefile stages `core/` + the game into `build/<name>/source` and
  runs `pdc`; `dist/` holds committed release builds. Bundle IDs are
  `com.sdwfrost.voxel.<game>`.

## Licensing

Original work, © 2026 sdwfrost, under the MIT [LICENSE](LICENSE), staged
into every built `.pdx`.
