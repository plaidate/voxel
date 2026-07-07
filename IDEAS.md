# Voxel — game roadmap

Ideas that fit the engine (fixed 96x64x16 room, 3/4 view, carve + add
terrain, height physics, crank). Status: ☐ idea · ◐ in progress · ● shipped.

## Shipped

- ● **Rubble** — wave-survival in a destructible arena; crank aims, shots
  and chewing grubs carve the level. (carve showcase)
- ● **Crumble** — height-survival; slime floods the room level by level,
  columns crumble underfoot, crank winds a spring jump. (add + height)

## Carve-first

- ● **Lob** — turn-based artillery duel (Worms-in-a-room). Crank winds
  shot power, d-pad sets azimuth; mortar shells fly a z-parabola with
  wind and blast craters; terrain between the duelists erodes over the
  match. AI brackets its aim tighter every turn. Parabolic projectile
  integrator lives in games/lob/game.lua — promote to core when a second
  game needs it.
- ✕ **Sapper** — CUT (July 2026): Bomberman is 2D grid logic in voxel
  paint — height added nothing, and the 3/4 projection made tall pillars
  merge into unreadable walls. Design rule learned: a game must *use*
  height/volume (dig, lob, climb, flood, fall) to earn the engine.
- ● **Herd** — pocket Lemmings: critters march on the existing step-up
  walking; your only tool is terrain surgery (dig channels, carve ramps,
  blast holes, drain goo) to route them to the gate. Crank is the
  release-rate dial. Sheep treat goo as a wall (route around) but die
  falling into it; blasts kill sheep in the radius.

## Build-first

- ● **Bulwark** — Rampart. Phase 1: crank-rotate tetromino wall pieces to
  enclose your keep (flood-fill enclosure check); phase 2: siege carves
  your walls down while the keep cannon answers. Add-vs-carve in direct
  opposition. Shells use core voxproj.lua (promoted from Lob).
- ✕ **Redoubt** — CUT (July 2026): flat creep-pathing tower defense is
  2D-in-disguise (same rule as Sapper); its wall-building appeal is
  already covered by Bulwark.

## Height & physics

- ● **Marble** — Marble Madness: steer a ball over a sculpted heightfield;
  slope acceleration from heightAt gradients, wall bounces, airborne
  crests, goo pools, timer. Crank winds a boost, A releases it.
- ● **Summit** — king-of-the-hill sumo on a ziggurat; shove enemies off
  ledges into the goo sea while outer terraces crumble away. 2-voxel
  terrace steps = only the player can jump levels; crank winds a radial
  spin. Knockback needs to fly ~11+ voxels to score ring-outs.
- ● **Excavate** — archaeology dig: tunnel into a mound for fossils;
  unsupported voxels collapse (game-side column compaction; fossils fall
  when undermined). Brought tunnel-aware physics into core
  (VoxPhys.support/tryMoveTun/physZTun) and the Kit.marker locator
  chevron. Fossils live in the deep strata (z <= 5) so undermining works.

## Flagship

- ● **Vault** — Voxatron-style room-to-room dungeon crawl: keys, smashable
  pots, grubs, goo moats, jumpable parapets, datastore saves (continue
  from title). Rooms are data (games/vault/rooms.lua). Design twist:
  no scripted secret walls — the whole dungeon is carvable, so scarce
  bombs turn any wall into a door.

## Demos

- ● **Voxelspace** — not a Vox-engine game: the classic VoxelSpace
  (Comanche) heightmap renderer as a 1-bit tech demo. Wrapping 256x256
  value-noise terrain (smoothed, 2 world units per cell), per-column ray
  march with early exit, precomputed depth ladders, run-merged fills,
  17-level Bayer shades + distance haze. Crank steers, d-pad climbs,
  A boosts, B rerolls the map. ~5ms/frame at 50fps.
