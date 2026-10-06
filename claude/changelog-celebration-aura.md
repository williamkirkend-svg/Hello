# Changelog: celebration aura upgrade (Oct 6 2026)

## What changed (player-visible)

Every one of the 12 special celebrations has a new show with "aura": one hot white core, the theme colours in the
middle and a dark rim; things that come OUT of the effect and leave the frame; a two-act structure with a silhouette
change; authored meshes and painted textures instead of plain parts; rings stacked at the floor, the chest and the
sky. Each show has a body moment for the catcher (a client-side double does the acting, so gameplay, physics and the
camera are untouched), a signature "thing that comes out", and one way it touches the world (the herd reacts, props
flash, the ground cracks, loose cobbles lift, time slows). The player stays visible: nothing persistent sits within two
studs of the torso, effects live on the floor, behind the back plane, on a four-stud orbit shell or above the head.

| Celebration | What comes out | Touches the world | Body |
|---|---|---|---|
| Starfall Halo | stars fall in a double helix down a streak-cage pillar from a crystal halo; a star seeks each nearby player | stars ride the herd; the halo drops over the player like a ring toss and lands as the floor sigil | lifted in the pillar |
| Thunder Stampede | ground arcs race out on eight tracks, a ring of bolts stands like fence posts, lightning bulls charge out of the craters | chain lightning to fence posts and lanterns, the herd flinches | wide stance, lifted into a ball-lightning cage that bursts |
| Golden Tornado | cut-rune rings stack into a funnel, coins spiral up and rain down, the beam fires the rings out as nine shock rings | hay and grass orbit the funnel, the herd is blown sideways | lifted spinning in the funnel, X pose at the slam, superhero landing |
| Galaxy Lasso | a rope of stars whirled overhead and thrown; it lifts an animal in a glowing ring; a second loop pulls a constellation out of the disc | stars over everything inside the loop, rim stars into the grass | the real whirl and throw |
| Blossom Burst | a cherry tree grows behind the player; petal fans, petal rain, plasma orbs that seek the herd | flower crowns on the animals, flowers ring the canopy | lifted on an opening lotus, the body explodes into the blossom |
| Event Horizon | nothing until the supernova: everything goes IN, then a white comet comes out | cobbles and grass stretch into the hole, the herd dangles by its leads, lights go dark red | hung upside down under the disc, swallowed, ejected into a crater |
| Spirit Stampede | the player's own herd as ghosts galloping a rising spiral out of a portal; a giant spirit bison leaps the player | hoofprints, the real herd rears and joins | rides the lead ghost for a loop |
| Prism Supernova | a white star explodes in three shells; seven coloured rays sweep like a lighthouse; glass shards; a crown of seven gems | time stops, the world desaturates, every animal is painted a colour | frozen with a stutter, shattered, re-formed hovering |
| Stormbreaker | a barn-sized storm cloud, a spiked thunder crown, a braided bolt into the raised fist, two physical shockwaves, an ice-spike ring | grass flattens, props flash, the herd is pushed | fist up, lifted, the punch into the ground |
| Phoenix Rebirth | the body chars, explodes, is reborn with flame wings, flies a rising spiral leaving a fire helix, bursts into golden embers | scorch rings, the herd ducks, every light goes white at the sun dive | the explode, the flight, the silhouette against the sun disc, the kneel |
| Astral Ascension | constellation wings, a stair of light steps, the caught animal drawn as a star map in the sky | the herd is tied into the map with beams, lanterns go blue-white | walks up the stair, arms out at the top, a feather-slow landing |
| Chrono Rift | the sigil's numerals orbit, freeze, reverse and shatter into a standing rift; eleven ghosts hunt nearby players; the plaza rewinds | the world slows to a tenth and goes sepia, cobbles lift, the herd freezes then startles all at once | the stutter, the hover with past echoes, the drop and the glass shatter |

Sets are unchanged: Set 1 (Common to Rare, rainbow throws only) is a 2.6 s accent with no camera move and no screen
hits; Set 2 (Epic, Legendary) is about 5 s with the double; Set 3 (Mythic, Secret) is 7 to 8.2 s plus a 1 s charge-up
(the inhale: the double crouches, a dark sigil irises open, dust is sucked in, lights dim, FOV narrows; no colour before
t = 0). Other players see the same shows reduced (no camera, Lighting or time effects; fewer particles by distance).

## Rules and numbers

- Grammar: build (0 to 15 percent), detonate, new silhouette, signature moment at 60 to 70 percent, settle.
- Visibility zones: FLOOR, BACK PLANE (1.5 studs behind the torso), ORBIT SHELL (4 studs or more), CROWN (1.5 studs
  above the head). Anything within 2 studs of the torso is at least 40 percent transparent. Full-screen flashes are at
  most 3 frames and throttled (ctx:Flash).
- Counts scale by ctx.Quality (1 own, .7 within 120 studs, .4 beyond) and by .55 on touch devices (AuraKit.Mobile).
- Seekers target other players within 40 studs first, then herd animals within 30, then free orbit points.
- The double (AuraKit.Performer) hides the real character with LocalTransparencyModifier and poses on Motor6D C0;
  no PlatformStand, no HumanoidRootPart moves, nothing replicates.
- Time scaling, light painting and the camera FOV only run for the celebrant's own show (ctx.Local).

## Scripts

New ModuleScripts under `ReplicatedStorage.FarmLasso.CelebrationFX`:
- `AuraKit` (the shared toolkit: Performer, Fly, Float, Shatter, Wings, Seek, Echo, Herd, Cracks, Debris, TimeScale,
  LightPaint, Chain, Stamp, Skin, Sheets, Sweeps, Cage, Monument, ChargeUp, Title, Rewind, Window, Mesh/Place, Hit,
  Starburst, PetalFan, ShockRing).
- `AuraMeshData` (pivot offsets and stand-in sizes, generated from `blender/aura_pack_pivots.json`).
- `AuraTextures` (asset ids for the painted texture pack; empty strings fall back to engine textures).
- `Shows` plus 12 children `Shows.<Id>` ({Pre, Set1, Set2, Set3}).

Patched: `CelebrationFX` (only `Play`: when `Shows[id]` exists it is used for the requested set, its `Pre` replaces
Tiers.Pre, and Spectacle.Augment, Tiers.Overdrive and AuraAccents are skipped so nothing stacks on the show; ids without
a show keep the old path). Untouched: `Celebrations`, `CelebrationClient`, `Free`, `Premium`, `Spectacle`, `Tiers`,
`AuraAccents`, `Cinematic`, the server.

Assets: `blender/Aura_Pack.glb` (54 meshes, `VFX2_*`, built by `blender/build_aura_pack.py`), imported to
`CelebrationFX.AuraMeshes`; `textures/*.png` (12 painted alpha textures and two flipbooks, `textures/paint_textures.py`).
The v1 pack (`ClaudeCelebrationPreview.VFXMeshes`) stays: GalaxyArm, GalaxyCore, GodRay and the rings are still used.

Backup location: `ServerStorage.CelebrationAuraBackup_20261006` (copy `CelebrationFX` with children there as
`CelebrationFX_old` before patching; see docs/celebration-aura-install.md).

## How to test

LOADOUT > a celebration > TRY plays Set 3 with the preview camera. For a real throw set workspace attribute
`LassoTestMult = 4` and catch an animal (the animal's rarity picks the set). Watch Output for `[CelebrationFX]` and
`[AuraKit]` lines: `mesh ... not imported` warnings mean the GLB import is incomplete (the show still plays with plain
parts). Check with a second player nearby that seekers (Chrono ghosts, Starfall stars, Blossom orbs) fly to them and
that their reduced view keeps the body, wings and sky pieces.

## Review

An independent adversarial review of the kit and all 12 shows (Roblox API misuse, nil indexing, timelines past LEN,
per-frame allocations, emitter budgets) found no crash-class issue; its eleven visible-bug findings were fixed (debris
drop timing, stamp fades, trails streaking from the mesh parking spot, the mirrored wing flash, the Phoenix spiral
entry, the Set 2 float snap, the K.Skin emitter leak, seekers running through Chrono's rewind, the standing tear
ring, double impact frames, title timing) and the lightning strike stacks were budgeted down. Spirit Stampede's calls
into the live `Voxel` module are pcall-guarded with a silhouette fallback because that module is not in the export;
check it once in Studio.

## Still open

- Upload the 12 textures and paste the ids into `AuraTextures` (engine fallbacks until then).
- Fountain interactions from the pitch (water recolour, feeding the black hole) are not built: there is no fountain
  query in the kit.
- Playtest every show at all three sets and tune `LEN`, `Pre` and the per-show counts; the showcase camera already
  allows 12 s. Nothing here was playtested (no Studio in the cloud session): the first run in Studio is the test.
- Skill update: `CelebrationFX` now has the children `AuraKit`, `AuraMeshData`, `AuraTextures`, `Shows` (+12); the
  old `Free` / `Premium` / `Spectacle` / `Tiers` / `AuraAccents` only run for ids without a show.
