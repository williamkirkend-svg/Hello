# Cursed Dodgeball: design document (v0.1, 7 Oct 2026)

Working title. Rename before launch; see section 12.

This is a design-only document. No code exists yet. It pulls from three research passes in `research/` and the concept images listed in `concept-images.md`. Decisions already made with the owner: balls carry the twist and players have no abilities; cosmetics-only monetization; chunky cartoon backyard and schoolyard art; everyone plays at once and rounds cut the field down to a single winner.

## 1. The pitch in one breath

Dodgeball, but everyone is on the court at once, every ball that rolls out is cursed in its own way, and the rounds keep cutting the crowd down until one kid is left standing while everyone else screams from the bleachers.

Rules you already know: get hit, you are out. Catch it, the thrower is out. Last one standing wins.

## 2. Design pillars

1. **Zero tutorial.** The loading screen says one sentence and that is the whole rulebook. Everything else is learned by getting hit by it.
2. **The catch is sacred.** Every cursed ball changes how a ball flies or what a hit does. None of them change what a catch means. The catch is the comeback and the skill ceiling.
3. **Nobody waits in silence.** Eliminated players become Ghosts with a throwing ring and a vote, then spectators with a camera and a hype meter. The stands are part of the show.
4. **Five-minute shows.** A full show from first rush to crowned winner is about five minutes. A player who goes out in the first 30 seconds is back on the court in under five.
5. **Clip first.** Every cursed ball has a moment that makes sense in a two-second vertical clip with no sound. Ragdolls, launches, swaps, explosions.
6. **Fair on a phone.** One joystick, two buttons, aim assist. No ability purchases, no ball purchases, ever.

## 3. The show (match format)

A server runs an endless loop of Shows. A Show is three rounds on one court with the whole server playing.

| Phase | Length | What happens |
|---|---|---|
| Intermission | 20 s | Everyone in the stands. The ball machine reveals this show's cursed balls one by one on the jumbotron. Spectators vote one Wildcard ball into round 1. Players walk down onto the court through the tunnels. |
| Round 1: The Rush | up to 90 s | All players on court, free-for-all. Balls on the centre circle. Round ends when the field is down to 8, or at the buzzer. |
| Replay | 8 s | Cinematic replay of the last elimination. Court shrinks for round 2 during the replay. |
| Round 2: The Cut | up to 60 s | 8 survivors, smaller court, more cursed balls. Ends at 4 left or the buzzer. |
| Replay | 8 s | Same. Court shrinks again. |
| Round 3: The Final | up to 45 s | 4 players, tiny court, every ball cursed, no Ghost re-entry. Last one standing wins. |
| Crowning | 15 s | Winner's celebration on the centre circle (the Aura kit from Farm Lasso can be reused here), podium for top 4, XP and placement rewards. Next intermission starts. |

Total: about 4 to 5 minutes. The server never has a lobby wait longer than 20 seconds.

**Server size.** Launch at 16 players, raise to 20 or 24 once the court and performance budget prove out. Minimum to start a show is 6; below 6 the show collapses to two rounds (cut to 3, then final). A player joining mid-show lands in the stands with the round timer on screen and plays from the next intermission.

**The buzzer.** If a round hits its timer before the cut, the Flood starts: paint pours in from the court edges at 2 studs per second and anyone standing in it is out. It stops the moment the cut is reached. This keeps rounds from stalling and gives the crowd something to scream at.

**Why not a bracket.** Research in `research/match-formats-and-spectating.md`: brackets break the moment a kid leaves mid-match, which is why the big mobile games use shrinking shows or loss-capped ladders instead. A shrinking show with everyone in from the start has no matchmaking problem at all, and the audience grows as the show goes on, which is the spectating feature for free.

**Why three rounds and not one.** A single 16-player free-for-all ends with a long, cagey 1v1 while 14 people wait. Cutting the court between rounds forces the end game, gives three distinct ball mixes per show, and gives three replay beats for the crowd.

**Hybrid option (owner's call, see section 12).** Round 1 can be played as two teams of 8 with classic sides, centre line and the catch-revive rule, and then rounds 2 and 3 go free-for-all. It feels more like real dodgeball at the start and gives teams something to cheer for in the stands. The cost is two rule sets to teach. Recommendation: launch pure free-for-all, test the hybrid as a weekend mode.

## 4. Core rules (the dodgeball base)

- **Hit.** A live ball that touches you before it touches the floor, a wall, or another ball puts you out. No head-shot special case. A ball you are holding does not protect you (no blocking in v1).
- **Catch.** Tap Catch while a live ball is within reach. Window is 0.25 s on a quick throw, 0.15 s on a charged throw. A catch puts the thrower out and gives the catcher a Shield: one extra hit, shown as a glowing ring around the feet, does not stack.
- **Out.** The player ragdolls and is flung toward their nearest sideline with an OUT stamp, then stands up as a Ghost in the Ghost ring (section 6).
- **Holding.** You can hold one ball. Holding slows you 15 percent. A held ball pops out of your hands after 8 seconds (visible ring timer) so nobody turtles.
- **Throw.** Tap Throw for a quick throw (60 studs per second, wide catch window). Hold up to 0.8 s for a charged throw (110 studs per second, narrow window, slight glow and sound tell). Aim is where your camera looks, with a soft lock on the nearest player within 10 degrees on mobile.
- **Live and dead balls.** A thrown ball is live until it touches the floor, a wall, a dead ball, or is caught. A dead ball can be picked up by anyone. Balls that leave the court roll back in from the nearest edge after 2 seconds.
- **Boundary.** The court edge is a painted band with a raised kerb. Step over it and you are out. The edge shrinks between rounds and during the Flood.
- **Pickup.** Walk over a dead ball to pick it up. Only one ball at a time.
- **Movement.** Run, jump. No dash, no abilities. All the spice is in the balls.

## 5. The cursed balls

Full catalog with behaviours, counters, catch rules, art and sound notes is in `balls.md`. Summary here.

**How many.** Launch with 12 cursed balls plus the plain ball, grouped in four families of three. Twelve is enough that any show feels different (round 1 draws 4 of 12, round 2 draws 5, round 3 draws 6) and few enough that a player has met every ball within an hour. Grow to 20 to 24 over the first year, two or three per season, so the roster stays a reason to come back.

| Family | What it changes | Launch balls |
|---|---|---|
| Flight | How the ball moves in the air | Eye Ball (homing), Boomerang, Shadow Ball (invisible, shadow only), Bouncy |
| Impact | What happens when it hits | Giant, Glue, Swap |
| Chaos | Timers and lies | Fuse, Traitor (outs the thrower), Decoy (three balls, one real) |
| Field | Changes the court itself | Black Hole, Paint |

**Ball mix per round.** Round 1: 8 balls on the centre circle, 4 plain and 4 cursed (3 drawn by the server, 1 Wildcard voted by spectators). Round 2: 6 balls, 1 plain and 5 cursed. Round 3: 4 balls, all cursed, drawn from a "finals pool" that excludes Traitor and Paint.

**Persistence.** A cursed ball keeps its curse for the whole round, so it is a resource worth fighting over, except consumables (Fuse, Black Hole, Paint, Decoy) which turn into a plain ball after they trigger. The ball machine at the centre fires a replacement cursed ball every 20 seconds in rounds 1 and 2.

**Reveal.** Every cursed ball has a unique silhouette, colour, idle animation, and sound so it reads from the stands and from a phone. Nothing is a recolour. The only exception is Traitor, which is disguised on purpose.

## 6. Ghosts, spectators and the stands

Eliminated players never leave the venue.

**Ghost ring (rounds 1 and 2).** A raised walkway between the court kerb and the first row of seats, behind a waist-high glass rail. Ghosts stand here. Dead balls that roll off the court come to them. A Ghost can throw at live players. A Ghost who hits a live player swaps places with them (the Prisonball rule): the Ghost drops back onto the court, the hit player goes to the ring. This keeps everyone playing and lets a kid who got out in the first 10 seconds get back in on their own skill. Ghost hits do not count toward the cut, so a Ghost cannot end a round. Ghost throws are always quick throws, so they are catchable, and a catch of a Ghost throw sends that Ghost to the stands for good.

**Stands (round 3, and anyone who gives up the ring).** Rows of bleachers around the whole court. From the stands you can:
- Cycle four cameras with one tap: seat view, broadcast (fixed, elevated mid-court), follow-ball (tracks the most recently thrown ball), and player cam.
- Use the cheer and boo wheel. Crowd sound reacts. Emotes play in your seat.
- Fill a hype meter. When it fills, the jumbotron fireworks go off and the next ball out of the machine gets a crowd-picked trail. Cosmetic only, never a gameplay effect.
- Vote the Wildcard ball for the next round of the next show.
- Vote MVP during the crowning. The MVP gets a podium spot and a title for the next show.

**Why the ring plus stands split.** Research shows pure spectating loses players after one round, and giving eliminated players real influence on the live match felt petty in playtests of other games. The ring gives early-outs a skill path back in during the open rounds. The stands give late-outs stakes without power over the final.

## 7. The venue

One stadium shape, three skins at launch. Dimensions below are the round 1 court; the kerb moves inward for rounds 2 and 3.

**Court.** A rounded rectangle, 70 by 50 studs in round 1, 48 by 36 in round 2, 30 by 24 in round 3. A centre circle of 10 studs where balls spawn from a hatch (the ball machine). No centre line in free-for-all. The floor is one bright flat colour with the boundary band in the team-neutral accent, lit brighter than everything around it.

**Kerb and ring.** A 1-stud raised kerb marks out of bounds. Behind it a 6-stud Ghost ring, then a glass rail, then stands.

**Stands.** Five rows on all four sides, each row 1.5 studs higher than the last so every seat sees the far edge. Two tunnels on the short ends where players walk down from the stands onto the court during intermission. One jumbotron on a pole at a short end, visible from the court and the stands, showing the ball reveal, replays, timer, and the players-remaining count.

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

1. Grey-box court and stands, plain ball throw and catch, out and Ghost ring, one round to last player. Playtest the feel of throw, catch and the 8-second hold.
2. The three-round show loop with the Flood, replays and crowning.
3. First six cursed balls (Eye, Boomerang, Giant, Glue, Fuse, Bouncy). Ball machine and reveal.
4. Stands: cameras, cheer wheel, hype meter, Wildcard vote.
5. Remaining six balls. Blacktop art pass.
6. Cosmetics, XP, challenges, leaderboards.
7. Backyard and Gym venues.

## 12. Decisions needed from the owner

1. **Name.** Working title is Cursed Dodgeball. Candidates: Cursed Dodgeball, Dodgeball Chaos, Ballistic, Last Ball Standing, Dodge or Die. Needs to be shoutable and verb-able.
2. **Pure free-for-all or the hybrid** (teams in round 1, free-for-all after)? Recommendation: pure free-for-all at launch.
3. **Ghost re-entry rule.** Keep Ghost hits as a swap (recommended), or make Ghosts pure spectators from the first out? The swap is more fun but adds one rule to teach.
4. **Traitor ball.** It is disguised and punishes the thrower. Funny, but it is the one ball that can feel unfair. Ship it, or hold it for a chaos weekend mode?
5. **Server size at launch.** 16 (safe) or 20 (bigger crowd, more risk on phones)?
6. **Catch reward.** Shield for one extra hit (recommended), or the catcher also pulls the longest-out Ghost back onto the court?
