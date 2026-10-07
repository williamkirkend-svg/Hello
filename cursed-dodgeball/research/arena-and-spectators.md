# Research: court, arenas, spectators, tech (Roblox)

Scale used: 1 stud = 0.28 m, Roblox character about 5 studs. Primary pages were blocked by the proxy, so figures come from search snippets of the cited rulebooks and docs; spot-check the WDBF attack-line distance and the Roblox performance budgets before relying on them.

## 1. Official court dimensions in studs

| Ruleset | Real size | Studs | Lines | Notes |
|---|---|---|---|---|
| WDBF 2024/2026 | 18 x 9 m, 1 m free zone | 64 x 32, free zone 3.6 | Attack line 5.5 m from centre = 19.6 studs | Balls on centre line |
| NDL (US rubber) | 60 x 30 ft, 4 ft neutral zone | 65 x 33, neutral 4.4 | Attack line 10 ft = 10.9 studs from centre | 6 balls on centre line (4 blockers, 2 stingers) |
| Rec / intramural | 50 x 25 ft | 54 x 27 | Attack lines +-10.9 | 3 balls each side of centre |
| School playground | 40 x 20 yd | 131 x 65 | Centre line only | |
| British U13-U17 | 17 x 8 m | 61 x 29 | | |
| Full basketball court | 94 x 50 ft | 102 x 54 | | Gym courts are painted inside these |

Rules that shape layout: opening rush with balls on the centre line, balls must be carried behind the attack line before a legal throw, stepping over sideline or centre line is out, a catcher must land in bounds, eliminated players queue on a sideline in elimination order and return first-out-first-in, returning players touch the back wall before re-entering.

Suggested baseline: 80 x 40 studs total (40 x 40 halves), attack lines 12 studs from centre, 6 balls on the centre line, 4-stud free zone, 8 to 12 stud jail strips along each sideline. Playtest at 64 x 32 and 100 x 50 as well.

Sources: https://worlddodgeballfederation.com/wdbf-multimedia/2024/03/WDBF-Dodgeball-Rules-2024.pdf , https://www.dimensions.com/element/dodgeball-court-wdbf , https://en.wikipedia.org/wiki/National_Dodgeball_League_rules , https://www.jmu.edu/recreation/intramural-sports/_rules/dodgeball-rules.pdf , https://www.bcit.ca/files/recreation/pdf/dodgeball_rules.pdf

## 2. Knockout City map design (Velan, 2021-2023)

| Map | Gimmick |
|---|---|
| Knockout Roundabout | Cars lap a traffic circle, shove players and knock balls loose; you can ride a car |
| Rooftop Rumble | Pitfalls, rickety bridge, wind gusts that glide you across gaps |
| Back Alley Brawl | Pneumatic tubes you ride through |
| Concussion Yard | Giant swinging wrecking ball; most verticality, most praised |
| Galaxy Burger | Whole map rotates around the kitchen; trash chute pit |
| Jukebox Junction | Hover train crosses the map |
| Holowood Drive-In | Movie sets swap every minute, changing geometry |
| Lockdown Throwdown | Spotlight drones; crossing a beam triggers a cage-ball turret |
| Alien Smash Site | Ride floating saucers across pits |
| Dueling Docks | Two conveyor belts carry randomised cargo-box cover |

Ball types: Standard, Bomb (sticks to walls, fuse starts on pickup, hurts holder too), Moon (holder jumps high, targets fly), Cage (traps target in a rolling ball you can throw off edges), Sniper (long range, fast), Multi (three throws), Soda (fizz obscures), Poison, plus "ball up" where a teammate becomes the ball.

Lessons: one unique mechanic per map, built after the throw/catch/dodge core was balanced. Every main location has a ball spawn. Combat pockets use broad, never-repeated shapes and distinct landmarks. Hazards are non-interactive moving things you dodge, not things players trigger. Verticality made matches dynamic; the rotating map was the most disorienting.

Sources: https://www.dualshockers.com/knockout-city-ball-types/ , https://www.psu.com/news/knockout-city-interview-ps4-the-creation-of-a-multiplayer-success-in-2021/ , https://www.denofgeek.com/games/knockout-city-dodgeball-preview-hands-on-impressions , https://www.godisageek.com/reviews/knockout-city-review/

## 3. Roblox venues with spectators

- Illegal Soccer: 8-player servers, stylised pitches, crowd is scenery, Replays and Ranked are separate sub-places rather than a live-spectate stadium.
- Huss Valley: not a stadium game. One open valley everyone can see end to end, so caught players become in-world spectators.
- Dress to Impress: the strongest reference. Everyone teleports to a runway with seating, contestants walk one at a time with an auto camera, everyone else votes 1 to 5 stars during the walk, a lobby podium shows the top three.
- Volleyball Legends: Spectate is a menu option next to Invite and Challenge, a camera mode rather than a physical stand. Emotes and chat bubbles broke in spectate, so handle them explicitly.
- Blade Ball: late joiners land in spectate with the round timer on screen.
- Descent of Champions (Ubisoft Game Lab): hologram crowd that changes colour on spectator emotes, spectators earn currency and influence the match, and the jumbotron front-and-centre was the most iterated element so players and crowd share a reference point.
- Spotlights (Roblox): audience reacts live with applause, boos, emoji and star ratings.
- Roblox has no built-in spectate. Set Camera.CameraSubject to a Humanoid or part, or go Scriptable and drive the CFrame.

Sources: https://dungeonpath.com/posts/dress-to-impress/runway-and-voting-guide/ , https://devmesh.intel.com/projects/descent-of-champions-bf90d7 , https://devforum.roblox.com/t/how-to-make-a-spectate/606352 , https://allthings.how/roblox-blade-ball-how-to-play-full-guide/

## 4. Readability patterns

- Mirror symmetry by default. Build half, mirror it, break the mirror only with cosmetics and landmarks.
- Finding players is the number one concern. Keep the court open, differentiate halves with colour, lighting and texture.
- Out of bounds: material change plus a raised kerb or paint band 0.5 to 1 stud wide, court floor lit brighter than the free zone, and a brief outline flash when a foot crosses since there is no referee.
- Eliminated players: hockey penalty boxes are glass-fronted benches in full view. Give spectators a continued role, but eliminated players with real influence over the live match felt petty in the pattern literature.

## 5. Arena shortlist (symmetric about the centre line)

1. Gym Class Classic: retractable bleachers slide in on a timer and shrink the free zone; jail on the bottom row.
2. Cul-de-Sac Showdown: an ice-cream truck laps the loop every 30 s and shoves anyone in its lane.
3. Backyard BBQ: pool at one end mirrored by a trampoline at the other, rotating sprinklers sweep arcs that slow players, falling in the pool is out.
4. Rooftop Recess: AC vent updrafts and a wind gust that curves balls.
5. Beach Boardwalk: the tide line creeps in every minute, shrinking both halves.
6. Barnyard Brawl: hay bales as cover, a loose dog carries the stillest ball to the other side, chickens scatter as an incoming-ball tell.
7. Parking Lot After Dark: hit a car and its headlights strobe that half for 2 s, shopping-cart trains roll across the centre.
8. Trampoline Park: everyone bounces, throws are aerial, catch window is huge.
Bonus: Drive-In Night, the screen swaps sets every minute.

## 6. Spectator layout recommendations

- Court sunk 3 to 5 studs below a concourse, stands on both long sides, 3 to 5 rows rising about 1.5 studs per row, end zones open for benches, jails and the big scoreboard.
- New joiners spawn in the stands at the mid-court aisle with the round timer on screen. A warm-up cage behind each end with free balls for waiting players.
- Jail is the front row: glass-fronted bench on the team's own sideline, ordered first-out-first-in with queue numbers over heads, a catch pops the front person back through a gate on the back line.
- Interaction without griefing: cheer and boo wheel with crowd sound, a per-side hype meter from spectator cheers that grants only cosmetic or tiny effects and nothing in ranked, spectator-thrown items purely cosmetic.
- Cameras, all client-side: seat view, broadcast (fixed camera mid-court about 25 studs up looking down 30 degrees), follow-ball, player cam. Cycle with one tap. Mute spectator chat bubbles over the court.
- After each round let spectators tap an MVP and show a podium in the concourse.

## 7. Technical recommendations

- Hit detection: never rely on Touched for thrown balls. Step the ball path with raycast or spherecast each frame.
- Authority: client renders the throw instantly and sends origin, direction, timestamp and id. The server re-simulates with sanity checks (speed caps, cooldowns, distance between claimed and server position) and rewinds the target hitbox to the client timestamp before validating. Only the server applies outs and cursed-ball effects.
- Network ownership: either two balls (visual client-owned plus invisible server-owned) or no physics in flight (deterministic cast on server, visual on clients, physics only when idle or rolling with ownership handed to the nearest player).
- Mobile: Adaptive physics stepping plus any Touched connection slows server-owned moving parts near characters. Use Fixed or drop Touched.
- Budgets: 500k triangles and 500 draw calls in scene, under 50k parts loaded, under 1.3 GB client memory, single meshes 20k tris or less, props under 5k, characters under 10k.
- Map size: an arena plus stadium is a small map. Keep streaming off or set the minimum radius to cover the whole court so balls and players never stream out for spectators.
- Crowd: billboards or low-poly seated meshes with one shared material, animated by a single client-side wave, not per-seat Humanoids.

Sources: https://devforum.roblox.com/t/how-to-make-good-projectiles/1581728 , https://devforum.roblox.com/t/server-sided-hit-detection-with-lag-compensation/3322386 , https://devforum.roblox.com/t/network-ownership/898365 , https://create.roblox.com/docs/performance-optimization/design , https://create.roblox.com/docs/en-us/workspace/streaming.md
