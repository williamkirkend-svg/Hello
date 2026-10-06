# Farm Lasso: the Aura upgrade pitch

Pitch for upgrading all 12 special celebrations (Celebrations.lua catalog, Oct 6 2026 export). Scope: keep every celebration's theme, name, colours and 3-set structure; replace or add layers so each one has aura, a signature "thing that comes out", one way it touches the world, and a body moment for the player. The previous Claude pack (generic layered aura with float, orbit camera, 20 white meshes) is scrapped as a product and mined for parts.

## 1. What the reference clips do that we do not yet

Nine clips, 400 sampled frames. Five habits show up in every one of them:

1. **One hot core, a coloured middle, a dark rim.** White centre, saturated mid, soot or ink outer edge (the blue aura, the pink shards, the magenta burst). Our current look is mostly mid colour. The dark rim is what makes glow read in daylight.
2. **Things leave.** Arc trails peel off the body and fly out of frame. Shards burst, hang, then scatter. Ghosts and stars travel to somewhere. Nothing stays inside a 6-stud bubble.
3. **Two acts with a silhouette change.** A build (ring, charge, suck-in) then a hard cut to a new shape: orbital ring to vertical streak cage, burst to shard field, sigil to rift. Each act gets 3 to 8 frames of pure change, then a hold.
4. **Authored shapes, not spheres.** Flat petal fans, crystal spikes, torn flame sheets, crescent sweeps, magic circles with real glyph geometry, a sun disc with rays cut into it. These are meshes or painted alpha textures, never plain particles.
5. **Stacked rings at different heights and tilts.** Floor ring, chest ring, sky ring 10 to 15 studs up, tilted 20 degrees. The sky ring is what turns an effect into an event.

Everything below is built from that grammar: build, detonate, new silhouette, settle.

## 2. The shared Aura Kit (built once, used by all 12)

A new ModuleScript `FarmLasso.CelebrationFX.AuraKit` next to the existing builders. The builders in Free, Premium, Tiers and Spectacle call it. Nothing in the current toolkit (Ctx:Ring, Emitter, Beam, Bolt, Streak, Flare, Burst, Ripple, Flash, ImpactFrame, Grade, Shake, Title) is removed.

| Capability | What it does | Who uses it |
|---|---|---|
| Seeker | One mesh flies to a target on a sine or Bezier path with a Trail and a PointLight, circles it once, phases through, dissolves. Targets: nearest other players within 40 studs, then herd animals on leads, then free orbit points. | Chrono Rift ghosts, Starfall stars, Spirit Stampede herd, Astral stars, Thunder horses |
| Ghost echo | Local clones of the character's parts in ForceField material replaying recorded Motor6D poses with a delay. | Chrono Rift, Prism Supernova, Permafrost-style statues |
| Shatter and reform | Clone limbs as fakes, hide the real ones with LocalTransparencyModifier, fling the fakes with Trails, play their paths back in reverse, reveal the body chest-first. Never touches real Motor6Ds. | Phoenix Rebirth, Event Horizon, Prism Supernova |
| Wings | Three-segment wing chains (upper, fore, primaries) per side, flap with an asymmetric curve (snap down 0.25 s, ease up 0.38 s), leading-edge Beam, tip Trails, feather shedding. | Phoenix, Astral Ascension |
| Flight path | PlatformStand plus HRP CFrame per frame along an authored crescent or spiral, body bank and torso pitch driven by path curvature. | Phoenix, Golden Tornado, Spirit Stampede |
| Herd reaction | Every herd animal within a radius does a 0.3 s crouch-then-rear with head tracking, plus a flavour: flinch, bolt, freeze, bounce, fur-up. Local only. | all 12 |
| Ground cracks | 8 pre-modelled crack meshes placed radially by raycast, scaled along their length with staggered starts, retinted per theme. | Thunder, Stormbreaker, Chrono, Event Horizon, Phoenix |
| Debris lift | Fake loose props (cobble, grass clump, hay, feather) spawned on the ground surface, lifted and orbited, dropped with physics at the end. | Golden Tornado, Event Horizon, Chrono Rift |
| Time scale | ParticleEmitter.TimeScale and animal animation speed within 30 studs, local only. | Chrono Rift, Prism Supernova |
| Light painting | Every PointLight in range swings to the theme colour and parts within radius get a 0.3 s Highlight outline. | Phoenix sun dive, Starfall, Stormbreaker, Prism |
| Sky monument | One big mesh 10 to 16 studs up, camera-facing or tilted 20 degrees. | Sun disc, clock ring, cloud, accretion disc, halo, prism |
| Rewind buffer | Ring buffer of CFrames per spawned object, played back in reverse at 3x. | Chrono Rift only |
| Chest window guard | Keeps a 3 by 4 stud window on the torso clear of persistent effects; orbiters may cross it in 0.15 s or less. | all 12 |

### Mesh pack v2 (Blender, white Neon-ready, 1 unit = 1 stud)

Kept from v1: GalaxyArm, GalaxyCore, AccretionRing, ShockRing, HaloRing, RuneRing, Sigil, ShardA/B/C, Slash, StarShard, GodRay, BeamColumn, Swirl, SpikeHalo.

New hero meshes (about 30): WingUpper, WingFore, WingPrimaries (left and right), Feather, FirePetal fan (16-petal single mesh plus single petal), SunDisc with 24 cut rays, ScorchRing with cracked inner lip, BodyShard x6 chunks, RiftLipL/R, RiftVoid gear panel, GhostWisp, ClockRing with numerals, ClockHands, TickSigil, GlassShard x4, Cobble, GrassClump, CrackA-H, CumulonimbusCloud x3 lobes, LightningHorse (flat galloping silhouette), TornadoFunnel segments, Coin, LassoLoopStar, PlanetRing, CherryTrunk, Canopy, Lotus platform, FlowerCrown, PrismCrystal, Gem x7, StarPoint, LightStep, StalactiteCrystal.

### Textures to paint (512 px PNG alpha, white on transparent, uploaded once)

Soft radial glow, hard ring, tall flame sheet, horizontal streak, 4-point star, petal shard, lightning 4x4 flipbook (1024), smoke 8x8 flipbook, quarter-arc sweep for Beams and Trails, ground crack, magic circle 1024, tileable nebula noise. Until they are uploaded the kit falls back to the engine textures already in use (sparkles, fire, shockwave, core, vortex, glow).

## 3. Keeping the player visible

Four zones only: FLOOR (rings, sigils, cracks), BACK PLANE (1.5 studs behind the torso: wings, rifts, sun disc, god rays), ORBIT SHELL (radius 4 studs or more at chest height), CROWN (1.5 studs above the head: halos, sky rings, title). Skin effects (Highlight, limb Beams, a shoulder mantle) are the only things at the body's own volume. Anything within 2 studs of the torso is at least 40 percent transparent. Full-screen flashes last at most 3 frames. One hero element at a time: wings OR sun disc OR shatter; the previous one fades to half as the next arrives. Camera distance scales with the effect's outer radius so the player stays at 25 to 35 percent of frame height. Reduced mode (other players) keeps the character-attached things and the seekers (they fly toward the viewer), drops time scaling, light painting, debris and the camera.

## 4. Set structure (unchanged)

Set 1 (Common to Rare, rainbow throws only): 2 to 3 s accent, no camera move. Set 2 (Epic, Legendary): 4 to 6 s, close camera swing. Set 3 (Mythic, Secret): 6 to 9 s full show with the 1 s charge-up and the showcase orbit. Meshes never change between sets; only count, scale, which hero elements appear, and whether the body moment happens.

## 5. The 12 celebrations

Format: hook, what comes out, how it touches the world, the body, sets, peak frame. Every Set 3 shares one charge-up shape before t=0: the player crouches, the floor sigil irises open dark, ambient particles are sucked inward to the chest, lights dim, FOV minus 4. No colour in the charge-up; t=0 is the detonation.

### 1. Starfall Halo (pale cyan, sky blue, pink)
Hook: the halo is a 14-stud crystal ring 12 studs up with twelve hanging crystal stalactites, tilted 20 degrees. The pillar of starlight is a vertical streak cage with a slow nebula scroll inside.
Comes out: falling stars. 4-point star meshes detach from the halo's inner edge and fall in a slow double helix down the pillar, each with a pale-cyan Trail. A star that lands skips once and leaves a pink star-print. One star per nearby player seeks them and hovers over their head.
World: stars that land near a herd animal bounce up onto its back and ride there glowing; the pillar's floor ring frosts the grass white-blue; the fountain water goes pale cyan and sparkles if within 10 studs.
Body: lifted inside the pillar (3 studs Set 2, 6 studs Set 3), arms out, palms up, one slow turn, accessories drifting upward.
Sets: 1 a 6-stud halo and a dozen stars at the feet, cheer with a hop. 2 the 14-stud halo, pillar, float, star-prints, stars riding animals. 3 a second larger halo above the first, the double helix, seekers to other players, and the first halo tilts and drops over the player like a ring toss, landing around their feet as the floor sigil.
Peak: the player as a silhouette halfway up the pillar, two stacked halos above, pink stars spiralling past, then the halo landing around the feet with a white flash.

### 2. Thunder Stampede (ice white, electric blue, indigo)
Hook: the blue aura clip, exactly. Plasma skin (Highlight plus crawling limb Beams and a lightning flipbook on the torso), three tall flame sheets, arc trails peeling off and flying out of frame, a floor pool with a sharp ring edge.
Comes out: the stampede. Crawling ground arcs race outward along eight radial tracks like bulls; each track ends in a bolt slamming down from 25 studs (white core, indigo halo, 3 frames) that leaves a scorched crater ring. From each crater a flat lightning bull silhouette charges outward through the fences and vanishes in a spark burst.
World: the ground arcs run along the fence line and every post flashes white as the arc passes; chain lightning jumps to lanterns and the fountain within 15 studs; herd animals rear when a bolt lands within 6 studs and their lead ropes carry a crawling arc for 0.4 s.
Body: wide stance, fists down, hair standing. At the peak the player is lifted 3 studs into a ball-lightning cage (vertical streak cage) that bursts and drops them.
Sets: 1 plasma skin, three ground arcs, one bolt behind the player. 2 six tracks, six bolts in a ring with 0.12 s stagger, post flashes, craters, three bulls. 3 arcs crawl inward in the charge-up; eight tracks, the bolt ring, eight bulls, the cage lift, a final mega-bolt on the player that detonates a 20-stud ice-white shock ring, ropes lit.
Peak: the player small and dark at the centre, eight white bolts standing around them like fence posts, blue arcs webbing the ground between, bulls leaving.

### 3. Golden Tornado (cream, gold, coral)
Hook: the rune rings get real cut-out rune glyphs so light shows through, and stack upward in a widening cone, each ring rotating against the one below, tilting into a tornado. A cream wind-sheet (twisted ribbon mesh) spirals up through them.
Comes out: coins and the beam. A fountain of gold coin meshes spirals up the funnel and rains back down with physics, settling on the ground for the hold. The beam is a 2-stud cream column from the sky that skewers every ring at once; on impact the rings fire outward as nine flat shock rings at nine heights.
World: tall grass within 10 studs lays flat outward; hay, straw and feathers lift and orbit the funnel; herd animals lean into the wind with ears and tails pulled toward it; the fountain's water sheet is dragged sideways.
Body: lifted inside the cone with the top ring, arms down and tense, spinning slowly to 7 studs; at the beam slam the pose snaps to an arms-up X, then a superhero landing.
Sets: 1 three rings and a coin puff. 2 six rings, grass flat, straw lift, lift to 3 studs, beam slam with FOV punch. 3 a gold sigil scribing itself rune by rune in the charge-up; nine rings, hay bales orbiting, animals leaning, the slam firing the rings outward, coin rain over the plaza, the landing.
Peak: the cream beam skewering nine spinning gold rings with the player a dark X at the centre, coins and straw frozen mid-spin.

### 4. Galaxy Lasso (pale cyan, periwinkle, violet)
Hook: the galaxy at the feet stays (the v1 arm meshes). The new thing is the lasso: one spiral arm detaches and rises as a rope of forty star meshes joined by a thin cyan Beam, and the player's real arm whirls it overhead and throws it.
Comes out: the star loop. It lassos the nearest herd animal and lifts it 2 studs inside a glowing ring for a second, then sets it down; with no animal near it lassos the fountain top or a fence post and tugs it. In Set 3 a second lasso pulls a constellation of the caught species out of the disc and hangs it in the sky. A ringed planet orbits at knee height and a shooting star crosses behind the title.
World: every animal and player inside the loop gets a small star over them for the hold; stars shoot from the disc rim into the tall grass and glow there; the fountain glitters.
Body: the whirl on the right shoulder Motor6D (one turn per 0.5 s), torso twisting, feet planted, then the throw. In Set 3 the player floats 2 studs on the galaxy hub.
Sets: 1 the disc, four orbiting stars, a star sigil overhead, cheer. 2 the whirl, the throw, an animal lifted, arms spinning faster. 3 the disc forms from stars sucked in from 15 studs in the charge-up; two lassos, one grabs an animal, the other pulls the constellation, rim stars into the grass.
Peak: the player mid-whirl with a rope of cyan stars looped around a floating glowing sheep, a violet galaxy spinning at their feet.

### 5. Blossom Burst (blush, pink, lavender)
Hook: a cherry tree. A 16-stud trunk grows behind the player in 0.5 s with a bending overshoot, the canopy pops as three blossoms, and the god-rays shine through it.
Comes out: petals, thousands: a flat 16-petal fan burst at the peak (the anime petal pop), two further petal waves at different tilts, then a slow petal rain. Five plasma orbs (Glass over a Neon pink core, lavender Trails) leave on lazy arcs and home on the herd.
World: each orb pops over an animal as a small blossom and leaves a flower crown mesh on its head for the hold; orbs with no animal land in the tall grass and bloom there; flowers pop up in a ring under the canopy; petals pile on the fountain's water and spin in the basin.
Body: lifted on a lotus platform that opens petal by petal under the feet, arms out, a gentle spin. In Set 3 the body explodes into the blossom for four frames and re-forms a stud higher with petals peeling off the skin.
Sets: 1 one blossom pop behind the back plane, three star flares, four god rays, a petal puff. 2 the petal burst, eight god rays, orbs to animals, flower crowns, the platform. 3 a lavender bud closes around the player in the charge-up and glows from inside; the bud bursts, the tree grows, body explode and re-form, three petal waves, petal rain, and the sigil becomes a 12-stud bloom that closes at the end with the player at its centre.
Peak: the canopy popping with the ten-stud petal fan edge-on behind the player, five lavender orbs leaving toward the line of animals.

### 6. Event Horizon (cream, orange, dark red; Robux)
Hook: the accretion disc from the TON-618 clip, modelled, tilted, with a lensing Glass sphere so the plaza bends around it, 8 studs above the player.
Comes out: nothing, until the supernova. Before that everything goes in: cobbles, straw, petals, feathers stretch into orange streaks toward the sphere. The disc flips vertical, collapses to a point, one frame of total black, then the supernova: a cream shell to 30 studs, an orange-red shock ring, a radial starburst with an impact frame, and a slow rain of glowing dark-red ash.
World: tall grass stretches upward toward the hole; the fountain's water bends up into an orange stream feeding the disc; the herd animals are lifted a stud by their leads and dangle, legs kicking, until the collapse drops them; nearby players' cameras get a 3-degree lens pull.
Body: pulled up feet-first, hanging upside down 4 studs under the disc with arms dangling; swallowed for 0.3 s; ejected downward as a white comet into a glowing crater.
Sets: 1 a coin-sized void at chest height with a thin orange ring and the lensing sphere, dust streaks, a small pop. 2 the disc, debris streams, grass stretching, the player hung upside down, a 15-stud supernova. 3 the plaza's lights go dark red in the charge-up; animals dangling, the fountain feeding the disc, the flip, the black frame, the 30-stud shell, the comet, the ash rain, the crater.
Peak: the player hanging upside down beneath the tilted orange disc, three animals dangling by their leads, the fountain bending up into it.

### 7. Spirit Stampede (lilac, purple, gold; Robux)
Hook: the ghost herd is the player's own herd. A 7-stud standing portal (gold rune rim, navy void, ForceField interior) opens behind the player and out gallop ForceField clones of the voxel rigs in the player's lead line, lilac at 60 percent transparency, gold eyes, long lilac Trails, running the game's real gait.
Comes out: the herd, on a rising spiral around the player, hooves stamping gold sparks and glowing hoofprints, passing through nearby players (Highlight flicker). Last out is a giant spirit bison that leaps clean over the player, and in Set 3 a spirit bull stops, faces the camera and bellows before fading.
World: the real herd turns to follow the ghosts, then rears, and translucent copies of them join the lap for a second; ghosts through the fence leave a lilac glow on the rails; ghost hooves splash the fountain.
Body: arms wide, then scooped onto the lead ghost's back for one loop at 5 studs in a rodeo pose, one hand up, then set down.
Sets: 1 a 3-stud portal, three ghosts doing a half-lap, gold sparks. 2 the full portal, eight ghosts in a lap, hoofprints, the real herd following and rearing, ghosts leaping into the sky. 3 gold runes orbit inward and the ground thuds in the charge-up; sixteen ghosts in two counter-rotating laps, the bison leap, the ride, the bellow, the herd ascending as a constellation line.
Peak: the bison leaping over the player, silhouetted against the portal, a lilac spiral of ghosts rising around them.

### 8. Prism Supernova (white, magenta, cyan; Robux)
Hook: time freezes properly: emitters and animals within 30 studs stop, the world desaturates, and the player is the only saturated thing in the frame. A prism crystal forms over the head.
Comes out: colour. A white star condenses at the chest, time snaps back, and it explodes in three stacked shells: white sphere, magenta petal fan, cyan ribbon arcs flying off-screen. One white beam enters the prism and splits into seven coloured rays that sweep the plaza like a lighthouse, with a lens-flare billboard when a ray crosses the camera. Glass prism shards scatter with rainbow Trails. The crown is a ring of seven gems that stays orbiting the head.
World: whatever a ray crosses is recoloured for a beat (fountain water, grass, each animal a different colour), so the plaza is painted band by band; at the snap every animal restarts at once.
Body: frozen mid-cheer with three stutter ticks, shards for three frames, re-formed hovering 2 studs with palms out, the crown landing as the player lands.
Sets: 1 a 0.2 s freeze, a triple flash behind the back plane, four ribbon arcs, a small crown. 2 a 0.4 s world freeze, the triple shell, seven rays sweeping once, the plaza painted, the crown. 3 colour drains from the whole scene over the charge-up; the freeze, the explosion with an FOV punch and impact frame, rays sweeping two full rotations, the shard scatter, the animals each left a colour, the rainbow title.
Peak: a grey world, a white-hot player at the centre of magenta petals, cyan arcs leaving the frame, seven rays painting the fountain.

### 9. Stormbreaker (ice, cyan, indigo)
Hook: a barn-sized cumulonimbus sky monument forms 14 studs up with lightning inside it; the plaza darkens under it and the player stands in the one shaft of light. The thunder crown is a spiked halo with bolts arcing between its spikes.
Comes out: braided lightning. Three Beams twist around each other from the crown down to the player's raised fist; the braid tightens, goes white, and the fist comes down into the ground. The shockwave that leaves the fist is physical: a low cyan ring with crawling arcs on its edge, 25 studs wide, and where the second ring stops an ice-spike ring erupts.
World: the ring flattens the tall grass as it travels, flings loose props, lights every fence rail cyan post by post, blows the fountain into a flat sheet, and gives the herd a 4-stud push and a stumble.
Body: feet planted, one fist raised catching the braid, torso leaning 15 degrees into the strain, lifted 4 studs by the bolt, then the punch into the ground.
Sets: 1 one bolt to the fist, a small ring, crawling floor arcs. 2 the crown, a braid of three, the fist slam, a 15-stud ring, grass and animals pushed. 3 the sky darkens and ice crystals hang in the air in the charge-up; the crown splits in two, a braid of five, the slam, two rings 0.4 s apart, props flung, the ice-spike ring, impact frame, and the braid lingering as a column the player stands in.
Peak: the player punching the ground, a white braid still connecting the fist to the spiked crown in the sky, a cyan ring flattening the grass outward.

### 10. Phoenix Rebirth (pale gold, orange, crimson)
Hook: the player burns up, explodes, is reborn with wings, flies a spiral, and explodes again into golden embers.
Timeline for Set 3 (about 8 s with the charge-up):
- Char (charge-up): knees bend, head drops, a soot-black Highlight wipes up the body, ember veins crawl up the limbs as thin Beams, a dark scorch ring opens underfoot, grass within 5 studs wilts, ash rises off the shoulders.
- Explode (0.0 to 0.2): three frames of black silhouette, then the body is replaced by six white-hot chunks and 24 shards with Trails flung on a half-sphere. A 16-petal flame fan pops to 9 studs with overshoot. Three shock rings: white, orange, soot. A 12-stud fire column for 0.15 s.
- Rebirth (0.2 to 0.8): the shards reverse along their own paths to a point 5 studs up; the body is revealed chest-first in six frames under a white Highlight. The scorch ring ignites. Wings unfold in sequence (upper, fore, primaries) to a 14-stud span with leading-edge Beams and tip Trails.
- Spiral flight (0.8 to 4.6): two rising laps, radius 8 to 4 studs, altitude 2.5 to 9, flap at 1.6 Hz with the snap-down curve, body banking 25 degrees, torso pitching with the climb. Each downstroke pushes an ember ring down and bends the grass out. The path leaves a fire ribbon that holds as a standing helix for a second after the player leaves it. Tail-feather Trails, a fire ribbon Beam between the wingtips, arc trails peeling off the tips on the fast section, feathers shed every 0.2 s, herd animals duck as the player passes over, hay bales catch a small flame.
- Sun dive (4.6 to 5.1): pull vertical to 11 studs, two frames of black silhouette against a 16-stud sun disc with 24 cut rays that irises in behind; every light in the plaza snaps white. One hard camera cut to a low angle looking up.
- Golden embers (5.1 to 5.5): at the apex the body shatters a second time into 40 gold ember shards that rain down; the wings fold forward and dissolve into rising embers.
- Landing (5.5 to 6.0): the body re-forms on the ground in a kneel with one fist down, a ring of flame petals opens flat, grass tufts fly up, the scorch ring turns gold.
- Settle: ember rain; the title letters gather from embers.
Sets: 1 the flame-up (soot wipe, shoulder mantle, two fire arcs orbiting, a wing silhouette flash behind the player for 0.4 s, a few feathers). 2 explode and rebirth, wings deploy, a hover at 3.5 studs with one 180-degree turn and flapping, a 9-stud sun disc, landing petals. 3 the full timeline.
Peak: the black-winged silhouette spread against the pale-gold sun disc, a crimson fire helix below.

### 11. Astral Ascension (ice, sky blue, violet)
Hook: the celestial wings are constellations: seven star points per wing joined by thin ice-blue Beams with a translucent violet fill behind. They do not flap; they open wider as the player rises. The player climbs a stair of light steps that appear under each footfall.
Comes out: a constellation. Stars orbit the body in three tilted rings (knee, chest, crown); as the player rises they lock into a star map of the caught animal species 14 studs up, drawn point by point and line by line. A star descends to each herd animal and hangs over its head, with Beams tying the animal-stars up into the map, so the whole herd is strung into the sky. The map stays in the sky for 10 s after the hold ends.
World: each light step stamps a glowing print; every lantern in range turns blue-white; a flat star-map reflection appears on the fountain's water.
Body: a code-driven walk up the stair, eight steps to 7 studs, then arms out and head back at the top as the wings reach 20 studs and the halo descends through the rings; a feather-slow landing.
Sets: 1 one ring of stars, a small halo, a brief wing outline behind the back plane. 2 three rings, the constellation wings, a four-step stair, the map locking and staying. 3 stars drawn in from 20 studs along thin Beams in the charge-up; the full climb, wings to 20 studs, the halo descending, the herd strung into the map, a shooting star crossing, seekers to other players.
Peak: the player at the top of the stair with 20-stud star-outline wings, three tilted rings, the animal constellation above tied down to a line of animals.

### 12. Chrono Rift (mint, spring green, navy)
Hook: time breaks. The giant time sigil lifts its numerals as orbiting shards, freezes them, reverses them, and shatters into a rift. Ghosts come out of the tear and go looking for everyone else. Then everything rewinds.
Timeline for Set 3 (about 8 s):
- Tick (charge-up): the plaza goes sepia and every emitter and animal within 30 studs slows to a tenth over a second. A 12-stud sigil (spring-green numerals on navy) scribes itself underfoot with one hand jumping per tick.
- Freeze (0.0 to 0.5): the player freezes mid-cheer and stutters, snapping pose every 0.1 s with a tick. The twelve numerals lift off the sigil and orbit at chest height, then freeze mid-orbit. A hairline of mint light stands 3 studs behind the player with a Glass sliver in front so the plaza bends.
- Tear (0.5 to 0.8): the numerals reverse their orbit, accelerate, and slam inward; the sigil shatters into the hairline, which rips to 5 studs with elastic overshoot. The player is jerked backward with arms flung forward. A gear-relief void stands behind the lips. Fourteen cobbles and eight grass clumps lift and hang orbiting the opening. An hourglass sand stream pours from 10 studs up.
- The dead come out (0.8 to 5.2): the player lifts to 3 studs, arms spread, slowly rotating backward, dragging three past-echoes of themselves. A 12-stud clock ring fades in at 7 studs, tilted, hands sweeping backward. Eleven ghost wisps squeeze out of the void one every 0.3 s, each picking a target: nearest other player within 40 studs, then herd animals, then orbit points. They circle the target's head once, phase through (mint Highlight flicker, a tick ring over the head, animals bolt 3 studs), turn to dust, and streak back as a reversed Trail. Frost footprints under their paths.
- Rewind (5.2 to 5.8): everything that came out retraces its path at 3x from the ring buffer. The clock hands spin back to twelve. The lips slam shut to the hairline. Then 0.2 s of total stillness, every emitter at zero.
- Snap (5.8 to 6.3): the player drops and lands wide, a hand on the floor. Time resumes in one frame and every animal startles at once. The hairline shatters into 40 Glass shards fired in a vertical fan with Trails, white flash two frames, shards embedding in the ground tilted and dissolving.
- Settle: the title letters appear out of order and slot in, one glitching twice.
Sets: 1 the sigil with its ticking hand, three stutter ticks, one ghost circling the player's own head, six shards. 2 numerals orbit and freeze, the rift to 3.5 studs, three ghosts seeking players then animals, two echoes, a ghost-only rewind, 16 shards, hover at 2 studs. 3 the full timeline.
Peak: the world stopped in sepia, a mint rift standing behind the player, a line of ghosts strung between the rift and three other players, twelve green numerals hanging frozen mid-orbit.

## 6. Build plan

1. Mesh pack v2 in Blender (procedural bpy script extended from build_vfx_pack.py), exported as one GLB, imported to ReplicatedStorage.CelebrationAssets alongside the existing Ring, RingThin, RingFat and Arc.
2. Textures painted procedurally (12 PNGs) for upload; IDs pasted into one table.
3. AuraKit module (seeker, echo, shatter, wings, flight path, herd reaction, cracks, debris, time scale, light painting, monument, rewind, chest guard).
4. Patch each builder in Free, Premium and Tiers, one celebration at a time, Phoenix and Chrono first since they define the kit.
5. Backups to ServerStorage.CelebrationAuraBackup_20261006 before any patch; changelog claude/changelog-celebration-aura.md.

## 7. What I need from you

1. The child modules under CelebrationFX that the export did not include: Free, Premium, Spectacle, Tiers, AuraAccents. They hold the actual per-celebration builders I would be editing.
2. The contents of ReplicatedStorage.CelebrationAssets (names of the meshes already there) and the ClaudeCelebrationPreview.VFXMeshes folder if the v1 meshes are to stay.
3. Set 3 length: is 8 to 9 s with the charge-up acceptable for the two flagship ones (Phoenix, Chrono)? The showcase camera already allows 12.
4. Spirit Stampede: are the herd animals' voxel rigs cloneable on the client (Archivable), so the ghost herd can be the player's real herd?
5. Texture uploads: are you happy to upload 12 PNGs and paste the IDs, or should everything stay on the engine textures?

Codex note: the OpenAI Codex CLI is not installed in the cloud container, so the ideation was done with two Claude agents (concept design and Roblox technique research) instead.
