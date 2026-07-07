# Voxel — player's manual

Ten original 1-bit games for the [Playdate](https://play.date), all built
on one destructible voxel room. Each game has its own section below. They
share a look and a control language: **d-pad** moves, **A** is the main
action, **B** is the secondary action, and the **crank** does something
different — and central — in every one. On every title screen, press **A**
to start; on every game-over screen, **A** restarts after a short lockout.

To install a game: download its `.pdx.zip` from Releases (or copy the
`.pdx` from `dist/`), then sideload at
<https://play.date/account/sideload/> or open it in the Playdate Simulator.

Jump to a game: [Rubble](#rubble) · [Crumble](#crumble) · [Lob](#lob) ·
[Bulwark](#bulwark) · [Herd](#herd) · [Excavate](#excavate) ·
[Marble](#marble) · [Summit](#summit) · [Vault](#vault) ·
[Voxelspace](#voxelspace)

---

## Rubble

**Carve the arena. Survive the grubs.**

A destructible voxel arena under siege. Waves of burrowing grubs pour in
from the four edges and converge on you; every shot you miss and every grub
gnawing at cover blasts real craters into the walls and mounds. By wave
five the arena you started in is literal rubble. The terrain is both your
ammunition and your liability.

**Controls**
- D-pad — move (normalized on diagonals).
- Crank — aim, 1:1 (crank up aims away from the viewer). If the crank is
  docked, aim follows your movement direction.
- A — fire; hold for autofire.
- B — jump (clears about one mound or step; used to hop mounds and re-cross
  craters).

**How to play.** Clear every grub in a wave to advance; each new wave has
one more grub and they move a little faster. Shots one-shot a grub on a
direct hit; a shot that hits terrain carves a crater and throws debris. The
floor is indestructible bedrock — everything above it is fair game.

**Scoring & lives.** 10 points per grub, plus a 25-point bonus for each
wave cleared (from wave 2 on). You have 3 HP (pips, top-right). A contact
hit costs 1 HP, shoves you back, and grants ~1.2 s of invincibility. Zero
HP is WRECKED.

**Enemy.** The **grub** is the only enemy: it chases you directly at a
speed that rises each wave. When terrain blocks it, it *chews* — carving a
hole through the cover in front of it every ~1.1 s. Contact at close range
damages you.

**Tips**
- Grubs are much slower than you (base ~5.5 vs your 16) — always kite, and
  shoot backward with the crank rather than trading blows.
- Speed climbs +0.4 per wave, so start thinning waves before they cluster;
  by wave 10 grubs are noticeably quicker.
- Don't camp behind a pillar — blocked grubs chew through cover in about a
  second. Cover is temporary by design.
- Fire *across* the arena, not into your own footing: your misses carve
  craters that can strand you.
- After a hit you're briefly invulnerable and flying from the knockback —
  steer that shove toward open ground, not another grub.

---

## Crumble

**Climb the crumbling columns. Outlast the rising slime.**

Height-survival on collapsing ground. Slime floods the room from the floor
up, one level at a time, swallowing the low landscape — and the columns you
stand on erode out from under your feet. Stay high, grab gems, and wind the
crank: a charged spring jump is your only way back up once the easy routes
are gone.

**Controls**
- D-pad — move (auto-walks up 1-voxel steps).
- B — plain hop.
- Crank — wind the spring (a charge meter fills in the bottom margin).
- A — release the spring jump: a fully-wound spring roughly doubles a plain
  hop's height. Press A with no charge and it's just a hop.

**How to play.** There is no win — it's an endurance run; your score and
how long you last are the metrics. The slime rises on a timer that starts
generous (first rise at ~10 s) and accelerates toward a ~4 s cadence, each
rise flooding every empty voxel below the new level (including pits you
carved). While you stand still on a column top, that block erodes every
~0.55 s and drops you.

**Scoring & lives.** 10 points per gem. 3 HP. Touching slime under your
feet costs 1 HP but *pops you upward* for an escape chance, with ~1 s of
invincibility. Zero HP is CONSUMED.

**Pickups & hazards.** **Gems** (flashing white) are the only pickup — up
to 3 at a time, always spawning at least 3 levels above the slime line, so
chasing them naturally leads you to safe high ground. **Slime** (dark) is
the rising kill-line; lethal to stand on.

**Tips**
- Never stand still — the column under you erodes every ~0.55 s and the
  slime is climbing. Keep hopping between column tops.
- Keep the crank wound *before* you need it: a full spring is the
  difference between reaching the next plateau and falling in.
- The slime clock accelerates, so bank height and gems early while rises
  are slow.
- A slime touch isn't instant death — it pops you up with i-frames. One
  heart to spare can buy a boost to a ledge you couldn't otherwise reach.
- Don't carve your own trap: holes you drop through fill with slime on the
  next rise.

---

## Lob

**Artillery duel in a crumbling voxel room.**

A turn-based artillery duel — Worms in a bottle. Two mortars sit on firing
pads at opposite ends of a rolling heightfield split by a central ridge
that blocks flat shots and forces real lobs. Every miss blasts a crater, so
the battlefield degrades into a moonscape over a match.

**Controls**
- Crank — rotate aim, 1:1 (d-pad ←/→ rotate as a docked fallback).
- Hold A — run an oscillating power meter that sweeps 0→1→0 every ~0.9 s.
- Release A — fire at the current power reading.

**How to play.** Play alternates through banner → aim → flight → resolve.
Elevation is fixed at 45°; you control only heading and power. Wind is
re-rolled every turn and bends the shell sideways in flight. First to 2
round-wins takes the match.

**Scoring & lives.** No points — you win rounds, shown as heart pips. 3
hearts per round. A blast within ~4.5 voxels costs 1 heart; a direct hit
(within 2) costs 2 — including your own short shots. A mutual kill is
awarded to you.

**Enemy AI.** The foe computes the straight-line heading to you, then
brackets its power by simulating candidate shots and picking the least
miss, then smears the result by an error term. That error **shrinks every
shot it fires** (from ~6 down toward a 1.5 floor), so it walks its aim onto
you and becomes deadly by its fourth or fifth shot.

**Tips**
- End rounds fast — the foe's aim tightens with every shot it takes.
- Read the wind gauge before committing; wind (±6) is a big deflection.
- You take splash from your own craters — don't lob short onto the ridge in
  front of you.
- A direct hit (within 2 voxels) does 2 of 3 hearts, so aim to land *on*
  the foe, not just near it.
- You can bury the foe: carving the ground out from under it drops it and
  changes its firing solution.
- For maximum range, release A at the very top of the power arc.

---

## Bulwark

**Wall in your keep. Survive the siege.**

Rampart in a voxel room. First you wall your keep inside a closed ring
using tetromino pieces; then you survive a siege as catapults on the east
edge lob crater-blasting shells at your walls and keep while you answer
with the keep-top cannon. Rebuild between sieges over cratered ground.

**Controls**
- *Build phase:* D-pad steps the cursor; crank turns the piece in 90°
  detents (B also turns); A places.
- *Siege phase:* Crank aims the cannon; hold A for the power meter; release
  A to fire.

**How to play.** Play cycles banner → build (20 s) → banner → siege (14 s).
A cell is buildable only on soil/crater ground, inside the region, and off
the east catapult strip. When build time ends, the game flood-fills from
around your keep: if the fill reaches the map edge your ring is open and you
lose. Survive 3 sieges for VICTORY. Craters from a siege can reopen your
ring, so re-check the perimeter each build.

**Scoring & lives.** The keep has 6 hearts; any shell landing within ~6
voxels of the keep centre (including your own overshoots) costs 1 → CASTLE
FELL at zero. Closing the ring pays +50; each destroyed catapult +25.
Killing every catapult ends a siege early.

**Enemy.** **Catapults** number 1 + round (2 in the first siege, up to 4).
Each re-fires every ~2.2–3.6 s and mostly targets your ring walls (about
75% of shots), sometimes the keep (15%) or a courtyard spot (10%), using
the same bracketing solver as Lob. A cannon shell landing within ~3.5
voxels destroys one.

**Tips**
- Expect the perimeter to take the most fire (75% of shots) — keep spare
  pieces ready to patch ring cells.
- Lob *past* the keep toward the catapult line; your own short shots can
  cost keep hearts.
- Going offensive is often safer than turtling — clearing all catapults
  ends the siege instantly and pays 25 each.
- After each siege, re-close any craters in your ring before the 20 s build
  clock runs out, or you lose to WALLS OPEN.
- Siege 3 throws 4 catapults — prioritize the ones aimed at gaps.
- Use B for quick 90° turns when the crank detents feel slow on the build
  clock.

---

## Herd

**Dig, blast and drain a path. Get the flock home.**

Pocket Lemmings on the voxel engine. Sheep pour from a west platform and
march east toward the gate. You can't command them — your only tools
*remove* terrain. Dig notches to turn walls into climbable stairs, blast
whole gaps through ridges, or carve the surface off a goo pool to drain a
safe path. Save the quota before the shift timer expires.

**Controls**
- D-pad — move the dig cursor (hold to auto-repeat).
- A — dig: a small carve on a short cooldown; repeats while held.
- B — blast: a big carve, but limited charges per level, and it **kills any
  sheep caught in it**.
- Crank — the release-rate dial: sets how fast sheep emerge (from ~0.3 to
  2.5 per second). A docked crank leaves the rate unchanged.

**How to play.** Each level generates ridges, goo pools and a gate. Sheep
spawn on a timer scaled by your crank rate until 12 have emerged; you carve
their route in real time. Meet the quota of saved sheep to advance; miss it
and the run ends. The quota climbs 7→8→9→10 and the terrain gets harder.

**Scoring.** +10 per sheep saved; +5 per unused blast charge at level end.
No lives — missing the quota is the fail condition.

**Sheep AI.** A sheep steps east; if blocked it sidesteps one way, then the
other, then shuffles back if fully boxed in. Goo directly ahead reads as a
wall, so sheep detour around pools — but a sheep that lands *on* goo dies,
and so does one that falls too far (a drop of more than ~3.5 voxels
splats).

**Hazards.** **Ridges** (4-tall walls, white cap) block sheep until you dig
stairs or blast a gap. **Goo pools** (dark) are lethal and read as walls.
**Long falls** splat. **Your own blast** kills nearby sheep.

**Tips**
- Digs are free and cool down fast; chaining several up a ridge face makes
  a reliable staircase. Save your 5 blasts for solid later-level ridges.
- Every unused blast is +5 at level end — treat blasts as a scored
  resource, not a default.
- Drain goo (carve its surface) *before* you funnel sheep toward it, or
  they'll pile against it as if it were a wall.
- Crank the rate down while carving a tricky route, then wind up to full
  once the path is safe — spawning caps at 12, so a late flood costs you
  nothing and beats the shift timer.
- Keep drops under ~3.5 voxels: a single dig usually turns a fatal fall
  into a survivable step.

---

## Excavate

**Dig for fossils. Mind the roof.**

Voxel archaeology. Fossils are buried in the deep strata of a great layered
mound. Sink shafts and tunnel along the dark lower layers to reach them,
and get them all out before the shift timer ends. Undermine a fossil to
drop it to your tunnel floor — but tunnel greedily and the roof caves in on
your head.

**Controls**
- D-pad — move (climbs gentle slopes, squeezes through tunnels you've
  carved).
- Crank — aim the pick (docked: aim follows your movement direction).
- A — dig: into a face it tunnels forward; on open ground it sinks a pit
  into that column. Hold to keep digging.
- B — hop (grounded only).

**How to play.** Each shift builds a mound of dark→light strata, buries
fossil clusters in the deep layers, and starts a 90 s timer. Dig to each
fossil, extract it, and clear them all for a new, richer mound. After every
dig, the area around the impact **settles**: unsupported voxels — fossils
included — drop straight down onto the next solid block. Three cave-in hits
and you're buried.

**Scoring & lives.** Intact fossil +15, cracked fossil +5, +25 per shift
cleared. 3 hearts (restored each new game, not each shift), with ~1.2 s of
invincibility after a hit.

**Hazards.** **Cave-ins** are the only damage source: a settle that drops
more than ~6 voxels near you (or that buries you) costs a heart. The
**shift timer** ending is SHIFT OVER. No enemies.

**Tips**
- Fossils sit in the *dark* deep strata, not the light surface caps — dig
  down into the shadowed layers.
- Undermine, don't over-dig: remove the *support* under a fossil so it
  drops to your floor intact (15) rather than hacking at it and cracking it
  (5).
- Keep each settle small — cave-ins only bite above ~6 falling voxels *and*
  within ~3 voxels of you, so dig from the side and step back.
- After an unavoidable collapse, dig again during the ~1.2 s invincibility
  blink — a second settle in that window is free.
- Face slightly downslope on open ground so the pick starts a shaft instead
  of skimming rock off the hill.
- Watch for sparkles — exposed fossil faces flash white, marking a cluster
  whose roof you've already thinned.

---

## Marble

**Roll downhill. Dodge the goo. Beat the clock.**

Marble Madness on a voxel heightfield. Each course is a tilted,
mogul-studded slope from a high west pad down to a flat white east pad.
Slopes accelerate the marble, steep faces bounce it back, crests throw it
airborne, and dark goo pools dissolve it. Reach the pad before the clock
dies; the courses keep coming, each bumpier and gooier.

**Controls**
- D-pad — steer (only ~30% strength while airborne).
- Crank — wind the boost meter (either direction).
- A — release the boost along your current direction of motion (due east if
  you're nearly stopped).

**How to play.** Roll west→east against a 45-second course timer. Reach the
white pad to score and start the next course. Touch goo and you lose a
marble and respawn at the start — but the clock keeps running.

**Scoring & lives.** Clearing a course pays 25 plus 2 per second left. 3
marbles per run; goo costs one.

**Physics.** On the ground you accelerate down the height-map gradient and
steer with the d-pad, up to a speed cap. A rise of more than ~1.5 voxels
bounces you; dropping off a crest of more than ~1.2 voxels puts you
airborne, and goo and the goal only trigger while you're grounded. Boost
adds to your current velocity — it's a speed extender, not a turn.

**Hazards.** **Goo pools** (dark, mid-course) are lethal to a grounded
marble. **Moguls and valleys** are terrain, not lethal. The **white east
pad** is the goal.

**Tips**
- You're airborne whenever you drop off a ledge taller than ~1.2 voxels —
  and goo can't touch you in the air. Hop crests over pools instead of
  steering around them.
- Air steering is only ~30% strength; commit to a line before you leave the
  ground.
- Boost fires along your motion vector — straighten out first, since from a
  standstill it just fires due east.
- Course clear pays 2 per second left on top of 25; on early courses a
  fast, risky line can out-score a safe one.
- Losing a marble does *not* reset the clock — after a late death, hunt the
  pad directly rather than farm a clean line.
- Gentle faces are climbable ramps if you carry speed; only rises above
  ~1.5 voxels bounce you back.

---

## Summit

**Sumo on a crumbling ziggurat.**

A sumo brawl on a four-terrace ziggurat rising out of a goo sea. Brutes
swarm the terraces; anyone whose feet land in the goo is gone. The terrace
steps are two voxels tall, so only you — with a jump — can climb them:
brutes must be shoved off, level by level. Meanwhile the lowest terrace
erodes on a timer and the arena shrinks under everyone.

**Controls**
- D-pad — move (your last direction sets your facing).
- A — shove (forward arc only).
- B — jump (grounded only — this is how you climb the 2-voxel steps).
- Crank — wind the spin meter; at full charge (blinking READY) the next A
  is a radial spin blast instead of a shove.

**How to play.** Each round rings brutes around the terraces. Shove them
downhill and into the goo. Clear all brutes to advance (+25) to a round
with more, faster brutes. Touch the goo yourself and the run ends.

**Scoring & lives.** Brute in the goo = 10; round clear = 25. Brutes per
round = 2 + round (capped at 6), getting faster each round. One life — goo
contact ends it.

**Mechanics.** Your shove has more reach and a shorter cooldown than a
brute's counter-shove. The spin is radial with bigger reach and knockback
but consumes the meter. Thrown actors *slide over* goo while still flying —
they only splash when they land grounded on it, and walkers refuse to step
onto goo on their own. Every ~9 seconds the lowest terrace erodes inward
and eventually vanishes, promoting the next level to the low one.

**Enemy.** **Brutes** (dark, white eye) walk straight at you and can't jump
terraces; within close range at similar height they shove back, but with
less reach and a longer cooldown than yours.

**Tips**
- Your shove out-ranges and out-cycles the brutes' counter-shove — poke
  first and back off; they can't trade evenly.
- The shove only hits the half-plane you face, and facing is your last
  d-pad direction — tap toward the target before pressing A.
- Brutes can't jump: hold a higher terrace and they pile against the step
  below, lined up for a downhill shove.
- Save the spin for when you're surrounded — its radial knockback can
  launch a whole crowd off an edge, and it needs less than a full crank
  turn to charge.
- Shove from high ground so thrown brutes get the airtime and speed to
  splash far out; a weak nudge at the edge may just park them beside the
  goo.
- Erosion only eats the lowest terrace every ~9 s — when the CRUMBLE timer
  is low, be anywhere but level 1.

---

## Vault

**A dungeon of voxels. Every wall is a door if you have a bomb.**

A five-room dungeon crawl where the dungeon itself is solid voxels.
Somewhere five rooms in sits the idol; between you and it are grubs, goo
moats, pots, one locked door and the key that opens it. Because every wall
is just voxels, a bomb opens anything — including the walls the designers
meant to be doors. Your run saves at every doorway.

**Controls**
- D-pad — move.
- Crank — aim the sword, 1:1 (docked: aim follows your movement).
- A — swing the sword (kills grubs, smashes pots).
- B — drop a bomb (short fuse, then a spherical blast).
- *Title screen:* A = new game, B = continue a saved run (shown only when a
  save exists).

**How to play.** Enter a room, clear or loot what you like, then find the
openings in the border walls and walk through to the next. The route runs
start → hub → west (holds the bomb pickup) → east, behind the locked door →
the idol room to the north. The hub holds the key that opens its one locked
door. Reach and touch the idol to win.

**Scoring & lives.** No score — the goal is the idol. 5 hearts (top-right).
A hit costs 1 heart, with brief invincibility and knockback. Zero hearts is
SLAIN. Cleared rooms *stay* cleared for the rest of the run.

**Mechanics.** A **locked door** is a wall of white voxel columns; stand
near it holding a key and it auto-unlocks (consuming the key). **Bombs**
carve a sphere after a short fuse — they kill grubs, smash pots, and hurt
*you* if you're too close, so drop and step away. A bomb through an outer
dungeon wall just clamps you back inside, but a bomb through a locked door
or interior wall is a legitimate shortcut. The game saves your room, HP,
keys and bombs at every room entry; the title's Continue restores it, and
winning clears the save.

**Enemies, hazards & pickups.** **Grubs** sit idle until you're near, then
walk straight at you (much slower than you run); one sword hit kills, and
they won't path into goo. **Goo** burns a heart per touch and knocks you
back; grubs avoid it. **Keys**, **bomb pickups** and **hearts** (from pots)
all bob and are grabbed on contact. **Pots** smash to sometimes drop a
heart or a bomb. The **idol** is the win.

**Tips**
- You run far faster than grubs — you can always just run past them; only
  fight when they crowd a pickup.
- The sword hits a wide arc in front of you and pots don't need a facing
  check — swing while running through pot clusters.
- Bombs carve a radius of 3 but hurt you within about 4 — drop and
  immediately move 5+ voxels away before the fuse ends.
- The intended route needs the key, but a spare bomb through the hub's
  locked door skips the key hunt entirely.
- Goo costs 1 heart per touch with i-frames — with a few hearts to spare,
  walking straight across a goo moat is often cheaper than the long way
  around.
- Clear a room's grubs once and it's safe for the rest of the run; saves
  happen at every doorway.

---

## Voxelspace

**Comanche-style heightmap flyover. Crank steers, d-pad climbs.**

A tech demo, not a game: the classic VoxelSpace/Comanche terrain renderer
running in 1-bit. Endless crank-steered flight over procedurally generated
mountains, lakes and snowcaps that fade into dithered haze. The world
wraps, so you can fly forever — no enemies, no score, no way to die.

**Controls**
- Crank — steer.
- D-pad left/right — steer without the crank.
- D-pad up/down — climb / dive.
- A (held) — boost (more than doubles your speed).
- B — regenerate the terrain with a brand-new seed.

**How to play.** You cruise forward automatically. Altitude clamps between
the terrain (the ground pushes you up over ridges — you can't crash) and a
ceiling. Press B any time you want a fresh landscape. The HUD shows
altitude, speed and heading.

**How the world is made.** Each seed builds a wrapping heightmap from
layered value noise, squared for dramatic peaks: below a threshold is flat
water, above a higher one is snow, and slopes are shaded lighter on the
lit (west) side. The renderer marches each screen column front-to-back,
drawing only what rises above what's already drawn and fading distant
terrain into fog.

**Tips**
- You can't crash — the terrain shoves you upward — so fly straight at
  mountains for the best skimming views.
- Hold Down while crossing a range: the moment you clear the ridge you'll
  dive into the valley behind it.
- Snowcapped ranges are rarer than lakes; press B to reroll until you get a
  good one.
- Boost (A) more than doubles your speed — combined with high altitude it's
  the fastest way to scan a new seed for scenery.
- Lit slopes face west: fly with the light for high-contrast terrain, into
  it for moodier silhouettes.
