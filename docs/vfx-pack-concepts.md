# Farm Lasso: VFX pack concepts (draft for critique)

Date: 2026-10-06. Status: concepts only, nothing built. Critique freely, then hand the surviving concepts to the Blender chat.

## Assumptions (correct these first)

1. "VFX packs" means **mesh-based effect assets built in Blender** and imported into Roblox Studio, then animated in code. Blender makes the shapes; Roblox code (TweenService, RenderStepped) makes them move. Sparkle and dust layers stay as Roblox ParticleEmitters, Beams and Trails, since those don't need Blender.
2. The packs serve the existing game loop: throw -> luck reveal -> tug-of-war -> catch -> herd -> sell -> shop. Nothing here adds a new system.
3. Art direction is chunky, low-poly, flat-shaded or two-tone, matching the voxel animal rigs and the painted UI icons. No photoreal textures.
4. Per the project rules: no night-time effects, animation is code not uploaded assets, and all effects play client-side off existing events (Throw, Fight, Sold, HerdSold) with no new per-frame network traffic.

## Shared pack format (applies to every pack)

- **Naming:** `VFX_<Pack>_<Element>_<Variant>`, e.g. `VFX_Reveal_Ring_Gold`. One mesh per file.
- **Pivot:** at the mesh's logical anchor (base of a burst, centre of a ring, tail end of a ribbon) so code can scale from the right point.
- **Scale:** author at final stud size. Reveal and sell effects sit around a 5-stud-tall character; keep elements in the 0.5 to 12 stud range.
- **Budget:** under 500 triangles per element, under 150 for anything spawned in handfuls (coins, shards, dust).
- **Colour:** one material slot, flat vertex colour or a tiny palette texture, so code can retint by tier (copper / silver / gold / rainbow) and by meter zone (aqua / hot pink / electric lime) without new assets.
- **Variants:** where a tier ladder exists, ship one base mesh and let code handle colour and scale. Ship separate meshes only when the silhouette itself changes (silver vs rainbow).
- **Delivery:** each pack is a folder of FBX files plus a one-page `README` listing element, intended stud size, pivot, and which game event triggers it.

---

## Pack 1: Throw & Rope

**Where:** from release to the moment the loop lands. Replaces or dresses the plain lasso loop in flight.

| Element | Shape | How code uses it |
|---|---|---|
| Loop ring (3 LODs) | Twisted rope torus, visible braid | Swapped by distance; spins on its axis during flight |
| Whip-crack arc | Flat ribbon mesh in a quarter-circle | Flashes at release for 0.15 s, scaled by meter multiplier |
| Comet head | Teardrop shell | Leads the loop at x2 and x4 only; tinted by meter zone colour |
| Release ring | Thin flat ring | Pops at the hand on release, grows and fades |

**Tier ladder:** x1 nothing extra. x1.5 aqua release ring. x2 adds comet head in hot pink. x4 adds the whip-crack arc in electric lime plus a second, larger release ring.

**Critique question:** is the meter-zone colouring on the throw worth it, or does it fight with the celebration tier colours that follow 1 second later?

---

## Pack 2: Luck Reveal Celebration Ladder

**Where:** the reveal hold (2.6 / 3.3 / 3.8 / 4.2 s by tier). This is the showpiece pack.

| Element | Copper | Silver | Gold | Rainbow |
|---|---|---|---|---|
| Ground ring | 1 thin ring | 2 rings, offset | 3 rings + inner glow disc | 3 rings + rotating prism disc |
| Burst | 6 short star shards | 10 shards | 16 shards, 2 lengths | 24 shards + 6 long "god rays" |
| Multiplier pedestal | none | low plinth | plinth + beam column | plinth + beam + arch |
| Overhead | none | none | sun-ray fan behind the number | full rainbow arch, 14 studs wide |
| Confetti | none | 8 flat squares | 16 squares + 4 curls | 30 mixed + 6 stars |

**Meshes needed:** ring, glow disc, prism disc, star shard (2 lengths), god ray wedge, plinth, beam column, sun-ray fan, rainbow arch, confetti square, confetti curl, confetti star. 12 meshes total; tiers are composed in code.

**Motion notes:** rings expand from the loop's landing point with overshoot (back-out easing). Shards scale from zero along their own axis. The rainbow arch rises from the ground over 0.5 s with a slight bounce, then holds. Save the screen shake and FOV punch for gold and rainbow, per the project rule.

**Critique question:** is a 14-stud rainbow arch too big for the fountain plaza sightlines, or exactly the "everyone saw that" moment you want?

---

## Pack 3: Tug-of-War Struggle

**Where:** the tap-to-catch fight. Intensity Level 1 to 4 follows `s.Tier`.

| Element | Shape | Behaviour |
|---|---|---|
| Dust puff cluster | 3 to 5 merged rounded blobs | Spawns at animal's feet on each pull; count scales with level |
| Dirt clod | Small irregular chunk | Flung backward from hooves at level 3 and 4 |
| Skid mark | Flat tapered wedge | Laid on the ground behind the animal, fades over 2 s |
| Rope strain spark | Tiny 4-point star | Appears along the taut rope at level 3 and 4 |
| Heel-dig wedge | Small ground wedge | Appears under the player's feet during the hold phase |
| Sweat drop | Teardrop | Pops off the player's head near timeout, all levels |

**Motion notes:** taps are 0.1 s shoves that fade, so dust and sparks should ride a smoothed intensity value rather than spawning per tap. Avoid high-frequency jitter.

**Critique question:** should the animal get its own species-flavoured struggle element (feathers for chick, mud for pig, snow-breath for bison) or is one generic set enough for 13+ species?

---

## Pack 4: Catch & Herd Join

**Where:** fight won, animal joins the lead.

| Element | Shape | Behaviour |
|---|---|---|
| Cinch ring | Rope ring that snaps tight | Shrinks around the animal's neck in 0.2 s, then becomes the lead collar |
| Bow knot | Chunky ribbon bow | Pops onto the collar for 0.6 s then shrinks away |
| Heart / star puff | Two small shapes | 3 to 5 float up from the animal, rarity picks heart vs star |
| Species stamp | Flat silhouette plaque | Rises above the herd counter when the "xN" count increases |
| Lead stretch flash | Short ribbon | Runs from player hand to animal once on join |

**Critique question:** should the catch moment be quiet (the reveal already shouted) or does the join deserve its own small beat?

---

## Pack 5: Sell & Coin Burst

**Where:** Animal Market sell, the `Sold` and `HerdSold` events.

| Element | Shape | Behaviour |
|---|---|---|
| Coin (3 sizes) | Thick disc with rim and a stamped lasso emblem | Fountain from the market counter, bounce once, vacuum to the HUD coin icon |
| Coin sack | Tied bag | Appears for sales over a threshold, splits into coins |
| Register star | 8-point flat star | Flashes once on the counter at "ding" |
| SOLD plank | Wooden sign board | Swings down over the counter for 1 s |
| Coin fountain spout | Short flared cylinder | Hidden emitter origin on the counter |

**Scale ladder by total:** small sale = 6 coins. Medium = 14 coins + sack. Large = 24 coins + sack + plank swing + register star twice.

**Critique question:** does the coin vacuum-to-HUD read well on mobile, or should the coins pour into a 3D box on the counter and only the number fly?

---

## Pack 6: Special Lasso Signatures

Three packs, one per special lasso. Each has a basic set (x1 / x1.5) and an advanced set (x2 / x4, including the ultimate).

**Unicorn Starmane**
- Basic: star shards (3 sizes), mane ribbon (long flat wave).
- Advanced: prism crystal, shooting-star streak body, star-ring halo.
- Ultimate: constellation frame (connected star points) that draws itself above the target.

**Thunderhoof**
- Basic: jagged bolt mesh (2 lengths), hoofprint crater disc.
- Advanced: storm puff cluster, chain-lightning fork, charged hoof ring.
- Ultimate: ground-crack fan (radial fissure plates) plus a sky bolt column.

**Crop Circle**
- Basic: flattened-wheat ring plates (2 radii), wheat stalk tufts.
- Advanced: tractor-beam cone, hover disc, grain swirl ribbon.
- Ultimate: mothership disc with underside lights and a wide beam cone (for the "Mothership" throw).

**Rule carried over:** every throw path must start at the hand, end exactly on the target, and have no frame-to-frame jumps. Signature meshes decorate the path, they never replace it.

**Critique question:** build all three now, or prove the format on one (Thunderhoof reads best from a distance) and template the rest?

---

## Pack 7: Shop & Equip

**Where:** 3D Lasso Shop and the Index.

| Element | Shape | Behaviour |
|---|---|---|
| Pedestal ring | Thin glowing ring | Slow spin under the hovered lasso |
| Unbox burst | 8 wedge petals | Opens outward on purchase, then fades |
| Equip sweep | Thin crescent | Sweeps across the player once on equip |
| Price tag | Hanging tag | Swings on hover for unaffordable items (grey Need state) |
| Lock shackle | Padlock | Sits on locked quest lassos in the Index, shakes when clicked |

Keep colours aligned with the UIStyle pill colours: gold equipped, blue equip, green buy, grey need.

---

## Pack 8: Quest Collectibles & Guild

**Where:** the 6 guild quests and their per-player collectibles.

| Element | Shape | Behaviour |
|---|---|---|
| Swarm bug (bee, butterfly) | Two tiny bodies with wing planes | Flock around the player; wings flap in code |
| Horseshoe (3 variants) | Classic, worn, gilded | Spins slowly on the ground; pops with a small ring on pickup |
| Firefly lantern | Small jar with a glowing core | Hovers and bobs; stays bright in daylight (no night cycle) |
| Quest banner | Hanging cloth with a guild crest slot | Drops in over the HUD on quest complete |
| Crest coins (6) | Flat medals, one per guild | Used in the banner and in the quest UI |

**Critique question:** are the 6 guilds distinct enough visually to justify 6 crests, or should the banner be one shape with a colour swap?

---

## Suggested build order

1. Pack 2 (Reveal ladder). Highest visible payoff, defines the colour and shape language for everything else.
2. Pack 5 (Sell). Second-most-frequent moment, and coins are reusable across the store.
3. Pack 3 (Struggle). Makes the fight feel physical.
4. Pack 6 (Thunderhoof only), then template Starmane and Crop Circle.
5. Packs 1, 4, 7, 8 as polish.

## Open questions for your critique

- Is the mesh-in-Blender assumption right, or were the packs meant to be particle sprite sheets, or both?
- Which moments feel flat to you today? That should override my build order.
- Any hard limits on asset count? Each pack above is 5 to 12 meshes.
- Should any of this be gated behind the Robux store (for example, premium reveal styles)?
- Mobile first or desktop first for scale and density?

## Hand-off note for the next chat

Paste this file and say which packs survived critique. The Blender chat should produce the FBX files plus the README per pack; the Studio session then imports them, writes the code-driven animation per pack, backs up scripts first, and ends with a changelog as the project rules require.
