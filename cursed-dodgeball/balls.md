# The cursed balls (ball bible, v0.1)

Rules that apply to every ball unless its entry says otherwise (see DESIGN.md section 4 for the movement kit, the 3-second shield and the target picker):
- A ball is live from the throw until it touches the floor, a wall, a dead ball, or is caught.
- A hit puts the target out. A catch puts the thrower out and gives the catcher a 3-second one-hit Shield.
- Every throw goes straight at where the picked target is at the moment of release. Nothing steers except the Eye Ball.
- A cursed ball keeps its curse all round. Consumables revert to plain after they trigger.
- Every ball has a unique shape, colour, idle motion, trail and sound. The jumbotron names it on spawn.
- Complexity is a build-cost guess: S is a parameter change on the plain ball, M is one new behaviour, L is new systems.

## Launch roster (12)

### Flight family: how it moves

**1. Eye Ball** (homing)
- Look: red rubber ball with one big cartoon eye that swivels to its target. Trail: red dotted line.
- Behaviour: after the throw it curves toward the nearest live player in a 30-degree cone ahead of it, turning at most 25 degrees per second. Flies at 80 percent of normal speed.
- Catch: normal. Because it comes straight at you, it is the easiest cursed ball to catch, which is the point.
- Counter: strafe hard late, or just catch it. Hide behind another player; it takes the first body it reaches.
- Clip: a player sprinting away while the eye follows them around a corner.
- Complexity: S.

**2. Boomerang**
- Look: a bent banana shape with wind lines, yellow. Spins in flight. Trail: curved yellow streaks.
- Behaviour: flies a wide arc and returns to the thrower's hand whether it hits or misses. It is live on the way out and on the way back, so one throw can take two people out. The thrower must catch it on the return (auto-catch if they are standing still and not holding anything); otherwise it drops dead at their feet.
- Catch: normal, and a catch stops the return.
- Counter: the arc is wide and visible; duck inside it. A thrower waiting for the return is standing still and easy to hit.
- Clip: a double out on the way back.
- Complexity: M.

**3. Shadow Ball** (invisible in flight)
- Look: when idle, a translucent pale-blue glass ball that reads as "ghostly". Once thrown it disappears and only its shadow on the floor and a faint whoosh remain.
- Behaviour: normal speed, normal physics, invisible body in flight. Visible again when it lands.
- Catch: normal window, but you have to read the shadow. A caught Shadow Ball becomes fully visible for the rest of the round (the curse is used up).
- Counter: watch the floor. Stand where the lighting makes shadows pop. Throwers tend to wind up obviously.
- Clip: someone getting hit by nothing.
- Complexity: S.

**4. Bouncy**
- Look: a glossy orange super-ball with a star pattern that stretches on each bounce. Trail: short orange squiggles.
- Behaviour: stays live for three bounces off floor or walls instead of dying on the first touch. Each bounce keeps 90 percent speed. It can hit the same player who threw it.
- Catch: normal on any bounce.
- Counter: the bounce path is predictable after the first one. Do not stand near walls.
- Clip: a bank shot off the fence.
- Complexity: S.

### Impact family: what the hit does

**5. Giant**
- Look: twice the size of a plain ball, dark blue with a thick white stripe. Lands with a thud and a dust ring. Slows the holder by 35 percent.
- Behaviour: flies at 60 percent speed, passes through players instead of stopping, and puts out every live player it touches along its path. Dies on the floor or a wall.
- Catch: cannot be caught by one player. Two players within 4 studs of each other both tapping Catch inside the window catch it together; the thrower is out and both catchers get Shields. In the final (4 players) it is simply uncatchable.
- Counter: it is slow and loud. Dodge sideways. Never stand in a line.
- Clip: a triple out.
- Complexity: M.

**6. Glue**
- Look: green ball dripping glossy slime, leaves green drips where it rolls.
- Behaviour: the hit does not put you out. It glues your feet to the floor for 3 seconds with a visible slime puddle. You can still turn, throw and catch. A glued player hit by any other ball is out as normal.
- Catch: normal, and the catcher is not glued.
- Counter: it is a setup ball. The danger is the second throw. Stuck players should catch, not panic.
- Clip: a stuck player catching the follow-up and turning the tables.
- Complexity: S.

**7. Swap**
- Look: purple ball covered in swirling white arrows that spin faster the harder it is thrown.
- Behaviour: nobody goes out. On hit, the thrower and the target instantly trade positions with a puff. Both get 1 second of immunity. Whoever is now near the edge or inside a Flood has a problem.
- Catch: normal; a caught Swap puts the thrower out like any ball.
- Counter: do not throw it from a safe spot into a dangerous one; you will inherit theirs. Catch it.
- Clip: a thrower swapping someone into the pool or into the Flood paint.
- Complexity: M.

### Chaos family: timers and lies

**8. Fuse**
- Look: black cannonball with a lit fuse and a hissing spark. The fuse shortens visibly.
- Behaviour: the fuse starts on first pickup and lasts 4 seconds. It explodes wherever it is, putting out every player within 7 studs, including whoever is holding it. Throwing it passes the problem along. A Fuse that hits a player does not put them out on contact; it drops at their feet and keeps ticking.
- Catch: catching does not stop the fuse. A catch puts the thrower out and the catcher now holds a bomb.
- Counter: do not pick it up late. Throw it into a crowd, then back away. Watch the spark.
- Clip: four players running from a bomb that one of them is still holding.
- Complexity: M. Consumable.

**9. Moon**
- Look: a pale grey cratered ball that drifts slightly when idle, with a faint halo. Trail: a soft white arc.
- Behaviour: whoever holds it has a third of normal gravity: triple jump height, long floaty hang time, and air dodges carry further. The throw itself is slow (70 percent speed) and lobbed. On hit, the target is launched 20 studs straight up with a crowd gasp and is out when they land, so the whole pit watches them come down.
- Catch: normal. Catching a Moon mid-air with an air dodge is the best-looking play in the game.
- Counter: the holder floats and is an easy target while up there. The lob is slow; catch it.
- Clip: someone catching it at the top of a triple jump, or someone else being launched over the pit wall.
- Complexity: M.

**10. Decoy**
- Look: a white ball with a question mark that wobbles. When thrown it splits into three identical balls fanned 15 degrees apart.
- Behaviour: one of the three is real. The two fakes pass through players harmlessly and pop like soap bubbles on the floor. The real one is a normal hit.
- Catch: catching a fake wastes your catch window and pops it. Catching the real one is a normal catch.
- Counter: the real ball casts a shadow; the fakes do not. Dodge the whole fan if unsure.
- Clip: a player catching a bubble while the real ball hits them.
- Complexity: M. Consumable.

### Field family: changes the court

**11. Black Hole**
- Look: a dark ball with a swirling glowing vortex pattern and sparks spiralling inward.
- Behaviour: where it lands it opens a 3-second vortex that pulls every loose ball on the court toward that spot, and pulls players within 10 studs at a walking pace. Players are not put out by it. After 3 seconds all the balls are piled in one spot.
- Catch: normal. A catch cancels the vortex.
- Counter: it is a denial tool. The thrower wants all the balls on their side. Rush the pile the moment the vortex closes, or throw a Fuse into it.
- Clip: every ball on the court sliding into one corner.
- Complexity: M. Consumable.

**12. Paint**
- Look: a fat pink ball that sloshes. Leaves a drip trail.
- Behaviour: where it lands it splats a 6-stud pink circle for the rest of the round. Anyone standing in paint cannot catch; they can only dodge. Paint circles stack up and the court gets smaller.
- Catch: a caught Paint ball splats under the thrower instead.
- Counter: stay off the pink. Use it to make a corner uncatchable before throwing a plain ball at the player cornered there.
- Clip: the final two fighting on the last clean patch of floor.
- Complexity: S. Consumable. Excluded from the final.

## Roster roadmap (seasons 2 onward, two or three per season)

Each is one line; detail them when their season is planned. Sources for the borrowed ones are in `research/ball-catalog.md`.

| Ball | Behaviour | Family |
|---|---|---|
| Traitor | A disguised plain ball that puts out the thrower, not the target; chaos weekend mode only | Chaos |
| Multi | Picking it up gives you three quick throws | Chaos |
| Cage | The hit traps the target in a rolling hamster ball for 4 s; anyone can push them toward the edge; mash to escape | Impact |
| Poison | Leaves a gas cloud on impact; standing in it 2 s puts you out | Field |
| Echo | 2 s after landing it re-launches along its own path in reverse, back at where the thrower stood | Flight |
| Whisper | Invisible and silent to everyone except the thrower and its target, half speed | Flight |
| Oath | On pickup you point at one player; it only ever puts out that player and homes on them | Flight |
| Ledger | Every catch adds a stack; when it finally hits, it puts out that many players nearest the impact | Chaos |
| Rewind | The hit sends the target back to where they stood 5 s ago and they drop their ball | Impact |
| Debt | The hit puts out the target, and the thrower is also out in 8 s unless they catch something first | Chaos |
| Sniper | Needs a 1.5 s charge, then flies at 180 studs per second in a straight line | Flight |
| Snowball | Grows bigger the further it flies; big at the end means a wider hitbox | Flight |
| Magnet | Attracts the nearest loose ball into the holder's hand every 3 s | Field |
| Mirror | The hit swaps the target's controls left-right for 4 s | Impact |
| Confetti | The hit does nothing but cover the target's screen in confetti for 3 s | Chaos |
| Feather | Floats; takes 3 s to land, live the whole time, can be caught at leisure, blocks a lane | Flight |
| Mole | Travels under the floor and pops up at the aim point | Flight |
| Chicken | Polymorphs the target into a chicken for 4 s: fast, tiny hitbox, cannot throw | Impact |
| Star | The holder is immune for 3 s and glows; thrown, it is a plain ball | Chaos |
| Lasso | Hits wrap a rope round the target and the thrower can reel them 8 studs | Impact |

## Rejected or parked ideas, and why

- Relay (must be passed twice before it can hit): needs a pass system and teams. Parked for the hybrid team mode.
- Jailbreak (hit returns a teammate): needs teams. Parked for the hybrid mode where it would be strong.
- Player-as-ball (Knockout City ball-up): great but it is a player ability, and the twist lives in the balls only.
- Soccer ball: toy, no gameplay.
- Any ball that sells for Robux. Never.

## Round pools

- Round 1 pool: all 12. Server draws 3, spectators add 1 Wildcard.
- Round 2 pool: all 12, 5 drawn, no repeats of round 1 unless the pool runs out.
- Final pool: Eye, Boomerang, Shadow, Bouncy, Giant, Glue, Swap, Fuse, Moon, Decoy, Black Hole. No Paint (the court is already tiny).
