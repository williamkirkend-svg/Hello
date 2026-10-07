# Cursed Dodgeball: design document (v0.3, 7 Oct 2026)

Name confirmed by the owner.

This is a design-only document. No code exists yet. It pulls from three research passes in `research/` and the concept images listed in `concept-images.md`. Decisions already made with the owner: balls carry the eliminations and every player shares one movement kit, plus one chosen ability that can be used once per round and never eliminates anyone; cosmetics-only monetization; chunky cartoon backyard and schoolyard art; everyone plays at once in a pure free-for-all with no teams, and rounds cut the field down to a single winner; the court is sunk below the stands so you feel down in a pit with the crowd above you; 20 players at launch.

## 1. The pitch in one breath

Dodgeball, but everyone is on the court at once, every ball that rolls out is cursed in its own way, and the rounds keep cutting the crowd down until one kid is left standing while everyone else screams from the bleachers.

Rules you already know: get hit, you are out. Catch it, the thrower is out. Last one standing wins.

## 2. Design pillars

1. **Zero tutorial.** The loading screen says one sentence and that is the whole rulebook. Everything else is learned by getting hit by it.
2. **The catch is sacred, and only a ball gets you out.** Every cursed ball changes how a ball flies or what a hit does. None of them change what a catch means. Abilities move you, move balls, or hide you. No ability ever eliminates a player.
3. **Nobody waits in silence.** Eliminated players become Ghosts with a throwing ring and a vote, then spectators with a camera and a hype meter. The stands are part of the show.
4. **Five-minute shows.** A full show from first rush to crowned winner is about five minutes. A player who goes out in the first 30 seconds is back on the court in under five.
5. **Clip first.** Every cursed ball has a moment that makes sense in a two-second vertical clip with no sound. Ragdolls, launches, swaps, explosions.
6. **Skill wins.** Sprint, dodge in any direction including mid-air, wall run, mantle, and a 3-second shield for a catch. The only help is a target picker that never tracks. No ability purchases, no ball purchases, ever.
7. **Everyone is there for their own reason.** No teams, no squads on the court. Alliances are whatever two kids decide for ten seconds.

## 3. The show (match format)

A server runs an endless loop of Shows. A Show is three rounds on one court with the whole server playing.

| Phase | Length | What happens |
|---|---|---|
| Intermission | 20 s | Everyone in the stands. The ball machine reveals this show's cursed balls one by one on the jumbotron. Spectators vote one Wildcard ball into round 1. Players walk down onto the court through the tunnels. |
| Round 1: The Rush | up to 90 s | All 20 players on court, free-for-all. Balls on the centre circle. Round ends when the field is down to 8, or at the buzzer. |
| Replay | 8 s | Cinematic replay of the last elimination. Court shrinks for round 2 during the replay. |
| Round 2: The Cut | up to 60 s | 8 survivors, smaller court, more cursed balls. Ends at 4 left or the buzzer. |
| Replay | 8 s | Same. Court shrinks again. |
| Round 3: The Final | up to 45 s | 4 players, tiny court, every ball cursed, no Ghost re-entry. Last one standing wins. |
| Crowning | 15 s | Winner's celebration on the centre circle (the Aura kit from Farm Lasso can be reused here), podium for top 4, XP and placement rewards. Next intermission starts. |

Total: about 4 to 5 minutes. The server never has a lobby wait longer than 20 seconds.

**Server size.** Launch at 20 players. The owner wants the biggest crowd possible, so 24 is the stretch target once the court and phone performance prove out. Minimum to start a show is 6. Rounds come from the starting count: 12 or more plays the full three rounds (cut to 8, cut to 4, final); 6 to 11 plays two rounds (cut to half, then the final), so a small server never gets a round that ends on the first hit. A player joining mid-show lands in the stands with the round timer on screen and plays from the next intermission.

**The buzzer.** If a round hits its timer before the cut, the Flood starts: paint pours in from the court edges at 2 studs per second and anyone standing in it is out. It stops the moment the cut is reached. This keeps rounds from stalling and gives the crowd something to scream at.

**Why not a bracket.** Research in `research/match-formats-and-spectating.md`: brackets break the moment a kid leaves mid-match, which is why the big mobile games use shrinking shows or loss-capped ladders instead. A shrinking show with everyone in from the start has no matchmaking problem at all, and the audience grows as the show goes on, which is the spectating feature for free.

**Why three rounds and not one.** A single 16-player free-for-all ends with a long, cagey 1v1 while 14 people wait. Cutting the court between rounds forces the end game, gives three distinct ball mixes per show, and gives three replay beats for the crowd.

**No teams, ever, in the main show.** The owner's call: everyone is on the court for their own reason. A team-start hybrid is parked as a possible weekend mode and nothing in the core design depends on it.

## 4. Core rules (the dodgeball base)

- **Hit.** A live ball that touches you before it touches the floor, a wall, or another ball puts you out. No head-shot special case. A ball you are holding does not protect you (no blocking in v1).
- **Catch.** Tap Catch while a live ball is within reach. Window is 0.25 s on a quick throw, 0.15 s on a charged throw. A catch puts the thrower out and gives the catcher a Shield: one extra hit, shown as a glowing ring around the feet, lasting 3 seconds and then gone. It does not stack and does not refresh while active. The catch is the reward; the shield is a short window to press the advantage, not a buffer to hide behind.
- **Out.** The player ragdolls and is flung toward the nearest edge of the pit with an OUT stamp, then stands up as a Ghost on the ring (section 6).
- **Holding.** You can hold one ball. A held ball pops out of your hands after 8 seconds (visible ring timer) so nobody turtles.
- **Throw.** Tap Throw for a quick throw (60 studs per second, wide catch window). Hold up to 0.8 s for a charged throw (110 studs per second, narrow window, glow and whine tell). Sprinting while charging is not allowed; the charge roots you to a walk.
- **Aiming.** There is no free aim on any platform. The player always has one target: a bracket indicator above the head of the player they have picked. On release the ball flies in a straight line at the spot where that player's chest is at that instant. It does not steer, it does not lead the target, and the ball keeps going to that spot if the target dodges. Only the Eye Ball steers. Target picking: the default target is the live player nearest the centre of the camera; swipe on the right half of the screen (or tap the indicator) to cycle to the next nearest on mobile; mouse movement or Tab on PC. The indicator turns red when the target is inside throw range and grey when out of range. This makes aim a question of timing and reading dodges, not twitch accuracy, which keeps phones and PCs equal.
- **Live and dead balls.** A thrown ball is live until it touches the floor, a wall, a dead ball, or is caught. A dead ball can be picked up by anyone. Balls that leave the court roll back in from the nearest edge after 2 seconds.
- **Boundary.** The court edge is a painted band with a raised kerb. Step over it and you are out. The edge shrinks between rounds and during the Flood.
- **Pickup.** Walk over a dead ball to pick it up. Only one ball at a time.

### Movement kit (shared by everyone, Huss Valley style)

- **Run.** Base speed 16 studs per second.
- **Sprint.** Hold Sprint for 1.5x speed. Drains a stamina bar that lasts 4 seconds of sprinting and refills fully in 3 seconds of not sprinting. You can sprint while holding a ball. You cannot charge a throw while sprinting.
- **Dodge.** Tap Dodge to dash 8 studs in whatever direction the joystick points, including backward and sideways, over 0.2 seconds. Costs a quarter of the stamina bar. Cooldown 0.8 s. The dodge has no invulnerability frames: if a ball reaches your body mid-dash you are out. The dodge is about where you end up, not about being untouchable, so a good thrower who reads it still wins.
- **Air dodge.** Dodge works once per jump while airborne, in any direction, with the same cost. Landing resets it. Chaining jump, air dodge and a charged throw on landing is the high-skill play the game is built around.
- **Jump.** Standard height. Jumping over a low ball is a legitimate dodge.
- **Wall run.** While airborne, moving into a wall at least 6 studs tall and holding Jump runs you along it at sprint speed for up to 1.5 seconds with gravity at a quarter. Costs stamina like sprinting. Press Jump again to kick off, away from the wall and upward, which resets the air dodge. The pit walls, pillars and tall obstacles are all runnable. Wall runs are how you cross the court without touching the floor and how you reach the rails.
- **Mantle.** Running into a ledge up to 3.5 studs high climbs it automatically. Low walls are cover you vault over, not fences.
- **Stamina readability.** The bar is on the player's back as a small glowing strip, so throwers can see when someone is empty and spectators can see it from the stands.

### Abilities (one per player, chosen between games, used once per round)

The twist used to live only in the balls. It now lives in the balls plus one ability per player, under one hard rule: an ability can never put anyone out. Abilities get you a ball, get you out of the way, or make the thrower wrong. The ball still does the eliminating, so the catch stays sacred and spectators always know why someone went out.

- **Pick.** During the intermission (between games) every player picks one ability from the roster on the ability board in the stands. The pick is locked for the whole game: round 1, round 2, the final. Your pick shows as an icon above your head during the intermission so opponents can read the field.
- **Use.** One use per round. It refreshes at the start of every round, so a player who survives all three rounds uses it three times. One button (E, ButtonL1, or a touch button). A loud colour flash and a jumbotron ticker line ("Alex used BLINK") make every use readable from the stands.
- **Ghosts** on the ring cannot use abilities.
- **Launch roster, eight abilities.**

| Ability | What it does | Counter | Why it is in |
|---|---|---|---|
| Blink | Teleport 12 studs in your movement direction, stopped by walls. Keeps your ball. | Throw where they will be, not where they were. | The simplest escape; teaches dodging to new players. |
| Grapple | Fire a hook at any pillar, rail or wall within 30 studs and zip to it. | They arrive predictable; the zip is a straight line. | Rewards the parkour arena; the clip ability. |
| Snatch | The nearest loose ball within 20 studs flies into your hand. | Hold your ball; Snatch only takes loose balls. | Fixes the "no balls near me" problem without a Black Hole. |
| Bubble | A 1.5-second bubble that catches the first ball that would hit you. Counts as a real catch: thrower out, shield gained. | Do not throw into a bubble; wait it out or throw a Giant (uncatchable). | The defensive read; punishes impatience. |
| Phase | 1 second of translucency; balls pass through you. Not a catch, no shield. | Throw after it ends; it is loud and short. | The emergency button for a cornered player. |
| Decoy | A clone of you sprints straight ahead for 3 seconds. A ball that hits it pops it and dies. | Decoys never dodge; the real one does. | Wastes an enemy throw, sells a fake. |
| Slam | Jump then slam down: a shockwave pushes players within 8 studs back 6 studs and scatters loose balls. Nobody is put out by the push; the Flood or the kerb can finish it. | Do not stand on the edge near a Slam player. | The only ability that touches other players, kept to a shove. |
| Smoke | A 10-stud smoke cloud for 4 seconds. Target brackets cannot lock onto anyone inside it. | Throw blind at where you last saw them. | Breaks the target picker, which is the only aim help in the game. |

- **Roadmap abilities:** Quickdraw (next throw is fully charged instantly), Shrink (half size for 3 s), Magnet (loose balls within 15 studs roll to you over 2 s), Swap Places (trade spots with your target), Spring (a bounce pad under your feet for 6 s), Rewind (return to where you stood 3 s ago).
- **Balance rule of thumb:** every ability is 1 to 3 seconds long, visible from the stands, and answerable by the simplest counter: wait.

## 5. The cursed balls

Full catalog with behaviours, counters, catch rules, art and sound notes is in `balls.md`. Summary here.

**How many.** Launch with 12 cursed balls plus the plain ball, grouped in four families of three. Twelve is enough that any show feels different (round 1 draws 4 of 12, round 2 draws 5, round 3 draws 6) and few enough that a player has met every ball within an hour. Grow to 20 to 24 over the first year, two or three per season, so the roster stays a reason to come back.

| Family | What it changes | Launch balls |
|---|---|---|
| Flight | How the ball moves in the air | Eye Ball (homing), Boomerang, Shadow Ball (invisible, shadow only), Bouncy |
| Impact | What happens when it hits | Giant, Glue, Swap |
| Chaos | Timers and lies | Fuse, Decoy (three balls, one real), Moon (holder jumps high, hit launches the target) |
| Field | Changes the court itself | Black Hole, Paint |

**Ball mix.** One draw per show, at show start: 8 balls on the centre circle, 4 plain and 4 cursed (3 drawn by the server, 1 Wildcard voted by spectators). The same eight carry through every round. The court shrinks around them; the ball count does not.

**Persistence.** Balls never despawn during a show. The roster is drawn once at show start (randomised, 8 balls: 4 plain and 4 cursed, one of them the spectator Wildcard) and the same balls are reused by the players through all three rounds. Between rounds the ball machine gathers every ball back to the centre circle. A ball that leaves the court rolls back in. There is no replacement machine fire: what is on the court is what there is, so every ball is a resource worth tracking.

**Re-arm.** A cursed ball that triggers its curse (a Fuse that blew, a Black Hole that opened, a Paint that splatted, a Decoy that split, a Shadow that was caught) does not become plain for good. It goes dormant: a countdown number floats above the ball and counts down from 6 seconds, during which the ball behaves as a plain ball and reads dull. At zero a burst ripples across the whole face of the ball, like a charge replenishing, and the ball lights back up in its own colour with its idle animation restored. The countdown is a BillboardGui readable from the stands, so a spectator can see the Fuse is about to be live again before the players notice.

**Reveal.** Every cursed ball has a unique silhouette, colour, idle animation, and sound so it reads from the stands and from a phone. Nothing is a recolour.

**Why this twelve.** The owner asked for the most engaging set. Each ball was kept only if it creates a decision for the target, not just for the thrower, and if it produces a clip. Traitor was cut from launch: it is funny for the crowd but it punishes the thrower for something they could not see, which is the opposite of the skill pillar. It moves to a chaos weekend mode. Moon takes its slot because it rewards the new air-dodge kit and gives the stands the biggest launch in the game.

## 6. Ghosts, spectators and the stands

Eliminated players never leave the venue.

**Ghost ring (rounds 1 and 2).** The walkway at the top of the pit wall, between the kerb drop and the first row of seats, behind a waist-high glass rail. Ghosts stand here looking down at the court. Each Ghost gets exactly one throw per round, and it is always a plain ball handed to them by the ring's ball boy slot the moment they arrive. If that throw hits a live player, the Ghost and the victim swap places: the Ghost drops back down into the pit, the victim is flung up to the ring. If it misses or is caught, that Ghost is done for the round and walks up into the stands. One throw, a plain ball, from above, at a moving target who can dodge in any direction: getting back in is possible and it is hard, which is the owner's intent. Ghost hits do not count toward the cut, so a Ghost cannot end a round. A Ghost's victim gets their own single throw as a new Ghost, so a chain of swaps can happen but every link costs someone their only shot.

**Stands (round 3, and anyone who gives up the ring).** Rows of bleachers around the whole court. From the stands you can:
- Cycle four cameras with one tap: seat view, broadcast (fixed, elevated mid-court), follow-ball (tracks the most recently thrown ball), and player cam.
- Use the cheer and boo wheel. Crowd sound reacts. Emotes play in your seat.
- Fill a hype meter. When it fills, the jumbotron fireworks go off and the next ball out of the machine gets a crowd-picked trail. Cosmetic only, never a gameplay effect.
- Vote the Wildcard ball for the next round of the next show.
- Vote MVP during the crowning. The MVP gets a podium spot and a title for the next show.

**Why the ring plus stands split.** Research shows pure spectating loses players after one round, and giving eliminated players real influence on the live match felt petty in playtests of other games. The ring gives early-outs a skill path back in during the open rounds. The stands give late-outs stakes without power over the final.

## 7. The venue

One stadium shape, three skins at launch. The defining feature is that the court is a pit: the floor sits 8 studs below the Ghost ring and the first row of seats, so a player on the court looks up at a wall of faces and a spectator looks down into an arena. Dimensions below are the round 1 court; the kerb moves inward for rounds 2 and 3.

**Court.** A rounded rectangle, 70 by 50 studs in round 1, 48 by 36 in round 2, 30 by 24 in round 3. A centre circle of 10 studs where balls spawn from a hatch (the ball machine). No centre line in free-for-all. The floor is one bright flat colour with the boundary band in the team-neutral accent, lit brighter than everything around it.

**Obstacles (the parkour layer).** The court is no longer flat. Everything is mirror-symmetric across both axes so no spawn is favoured, and nothing is taller than 9 studs so the stands, which start at 8 studs above the floor, always see over it. Players should find it a little confusing from inside; spectators should always be able to tell what is going on from above.
- Four **pillars**, 4 by 4 by 9 studs, at the quarter points. Wall-runnable on every face. Grapple anchors.
- Four **half-walls**, 8 studs long and 3 studs high, staggered between the pillars. Cover from one side, mantle over in one motion. Balls fly over them; crouching behind one is a real defence.
- One **stage** in the centre, 12 by 12 studs, 4 studs high, with a ramp on each short side. The centre circle and ball hatch sit on top. The high ground is also the most exposed ground.
- Two **rails**, 1 stud wide, 7 studs up, running from pillar to pillar along each long side. Reached by wall run or Grapple. A player on a rail is hard to hit from below and easy to knock off with a Slam.
- The **pit walls** are wall-runnable all the way round for escapes along the edge.
- When the court shrinks between rounds, obstacles outside the new kerb sink into the floor during the replay. Round 2 keeps the stage, two pillars and two half-walls. The final keeps only the stage.

**Pit wall, kerb and ring.** A 1-stud painted kerb marks out of bounds at the floor. Behind it the pit wall rises 8 studs, sheer, with team-neutral stripes and the players-remaining count painted big on each face so the crowd reads it. At the top of the wall is the 6-stud Ghost ring with a glass rail on the court side so Ghosts throw over it and cannot fall in. Behind the ring the stands begin. Out players are flung up and over the wall onto the ring, which is the physical version of being sent off. Entry for the next show is down the two tunnels, which ramp from the stands to the floor at the short ends and close with a gate when the round starts.

**Stands.** Five rows on all four sides starting at ring height, each row 1.5 studs higher than the last so every seat sees the far edge of the floor 8 studs below. Two tunnels on the short ends where players walk down from the stands onto the court during intermission. One jumbotron on a pole at a short end, visible from the court and the stands, showing the ball reveal, replays, timer, and the players-remaining count.

**Three skins at launch.**

| Venue | Look | Hazard |
|---|---|---|
| Blacktop (default, used for ranked later) | Schoolyard asphalt, chalk lines, chain-link fence, metal bleachers, afternoon light. Concept image 1. | None. The clean one. |
| Backyard BBQ | Lawn inside a wooden fence, deck as the main stand, pool at one end, trampoline at the other, sprinklers in the corners, a dog. Concept image 2. | Sprinklers sweep arcs that slow players. The trampoline is a high-jump catch spot. The pool is out of bounds with a splash. The dog carries the ball that has sat still longest to a random spot. |
| Gym Class | Varnished wood floor, pull-out bleachers, retro scoreboard, climbing ropes, banners. Concept image 3. | The bleachers slide in during the Flood instead of paint. |

Later venues from research: cul-de-sac with an ice-cream truck lapping the loop, rooftop with vent updrafts, beach with a creeping tide, barnyard, parking lot after dark, trampoline park, drive-in with swapping sets.

**Lobby.** There is no separate lobby place. The stands are the lobby. Behind the top row there is a concourse with a practice wall (painted target, free plain balls), the cosmetic vending machine, the leaderboard board, and the daily challenge board. Concept image 7.

## 8. Readability and feel

- Chunky cartoon, toy proportions, saturated flat colours, thick outlines on balls.
- Each player gets a random bright jersey colour per show so the crowd can follow individuals. No teams in free-for-all, so colour is identity.
- Hit: 3-frame white flash on the victim, ragdoll fling toward the nearest edge, OUT stamp, crowd gasp. Elimination that triggers a cut gets the 8-second replay.
- Catch: time slows to 0.3x for 0.4 s, a radial burst, the thrower's shocked face emote fires automatically, Shield ring appears. Concept image 5.
- Throw: charged throws glow and whine so the tell is readable from the stands.
- Ball spawn: the hatch pops, the ball bounces once, and the jumbotron names it.
- Winner: a 6 to 9 second celebration using the Farm Lasso Aura kit (sky monument, seekers flying to the stands, debris lift), then podium.

## 9. Progression and monetization

- XP per show from placement, hits, catches, Ghost re-entries and MVP votes. Levels unlock cosmetics only.
- Cosmetics: jerseys, ball trails and skins (apply to whatever ball you are holding, the curse keeps its own silhouette), catch celebrations, out animations (ragdoll styles), crown skins for winners, emotes, seat flags for the stands.
- Daily challenges ("catch 3 Boomerangs", "win a show from the Ghost ring").
- Leaderboards: wins, win streaks, catches, Ghost comebacks.
- Nothing that touches gameplay is ever sold. No ball unlocks, no Shield purchases, no XP boosts that touch matchmaking.
- Later: ranked shows with placement matches and a pre-show ball ban vote, and Clubs.

## 10. Technical direction (for when building starts)

Summarised from `research/arena-and-spectators.md`. No code yet.
- Single place. Server-authoritative round manager. 16-player servers.
- Thrown balls are not physics objects in flight. The server steps a spherecast along the path each frame; clients render the ball locally. Idle balls are physics with network ownership handed to the nearest player.
- Client sends throw origin, direction, charge and timestamp. Server re-simulates with speed caps and cooldowns and rewinds the target hitbox to the client timestamp before confirming a hit. Only the server applies outs and curse effects.
- Spectator cameras are client-side CameraSubject swaps on a filtered list of live players, reset on round end.
- Crowd is low-poly seated meshes with one shared material, animated by a single client-side wave.
- Performance budget: under 500k triangles in view, under 500 draw calls, under 1.3 GB client memory, 60 fps on a mid phone.

## 11. Build order (phases, not tasks)

1. Done: grey-box court and stands, plain ball throw and catch, out and Ghost ring, the three-round show loop with the Flood, replays and crowning.
2. Movement and arena: wall run, mantle, obstacles that sink between rounds. Persistent balls with re-arm countdown.
3. Abilities: the pick board, the once-per-round use, the eight launch abilities.
4. First six cursed balls (Eye, Boomerang, Giant, Glue, Fuse, Bouncy) with re-arm.
5. Stands: cameras, cheer wheel, hype meter, Wildcard vote, ability ticker.
6. Remaining six balls. Blacktop art pass.
7. Cosmetics, XP, challenges, leaderboards.
8. Backyard and Gym venues.

## 12. Decisions log

Resolved 7 Oct 2026 with the owner:
1. Name: Cursed Dodgeball.
2. Pure free-for-all. No teams, everyone is there for their own reason.
3. Ghost swap-back stays, limited to one throw per round with a plain ball. Hard but possible.
4. Ball roster: the designer picks the most engaging twelve. Traitor moved out of launch, Moon in.
5. Launch at 20 players, more if performance allows.
6. Catch gives a one-hit shield that lasts 3 seconds. Skill-based movement added: sprint, omnidirectional dodge, air dodge. Auto-aim is a target picker that throws at where the target is at release and never tracks; only the Eye Ball tracks.
7. The court is sunk below the stands so it feels like an arena pit with the crowd above.

8. More PvP (v0.3): wall run and mantle added to the shared movement kit; one chosen ability per player, picked between games, one use per round, never eliminates; balls are drawn once per show, never despawn, re-arm after a 6-second countdown with a burst across the ball; the court gains pillars, half-walls, a centre stage and rails, all under 9 studs so the stands see over them.

Open:
- The owner's description of the re-arm effect was cut off after "and then make it look like its". Assumed: the ball lights back up in its own colour. Confirm.
- Stamina numbers (4 s sprint, quarter-bar dodge, wall run 1.5 s) are first guesses for the grey-box playtest.
- Whether the Ghost's one plain throw should be a quick throw only or allow a charge. Current draft: quick only, to keep it catchable.
