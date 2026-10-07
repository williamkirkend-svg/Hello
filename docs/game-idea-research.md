# Backyard game + twist: idea research

Date: 7 Oct 2026. Goal: a second game that is simpler than Farm Lasso, aimed at a different (younger, competitive, clip-driven) audience, built on a backyard game everyone already knows, with one twist that makes it chaotic and fun.

## 1. What the two reference games actually do

**Huss Valley** (sharks and minnows). About 106k active players, 33M visits, tagged "battlegrounds". Rules take five seconds to explain. Rounds are short, the crowd is big, and abilities turn a crossing into a dash-dodge-fake brawl. The name became a meme ("hussing" = frantic running), which is marketing nobody paid for.

**Illegal Soccer** (Repotted, launched 12 May 2026). About 61k to 69k concurrent, 51M visits, roughly $400k revenue in five months. Eight-player servers, one timer, normal soccer controls, then revolvers, grappling hooks, jetpacks and oil dropped mid-match. Key insight from the guides: guns are not the game. Goals win. The items are tools for stealing the ball or stealing time. One good possession swings the match.

The shared formula:

1. **Zero tutorial.** The player already knows the rules from real life.
2. **Short rounds, small or crowded servers.** 60 to 120 seconds, 8 to 16 players, no downtime.
3. **The twist breaks the rules, not the goal.** The win condition stays sacred. Abilities only change how you get there.
4. **One built-in swing moment.** Catch a ball to revive a teammate, kick the can to free the jail, one possession to win. The chaos must have a scoreboard consequence.
5. **Clip-able physics.** Ragdolls, launches, things flying. The game markets itself on TikTok.
6. **Mobile first.** One or two buttons plus a joystick.
7. **A name that becomes a verb.**

## 2. Where the space is already taken (avoid)

| Backyard game | Roblox state | Verdict |
|---|---|---|
| Hide and seek | Paint and Seek hit 100k concurrent in June 2026, plus a dozen variants | Saturated |
| Freeze tag | Huss Rooms (same creator as Huss Valley) runs freeze tag | Saturated, and it is their lane |
| Musical chairs | Infinity Forge version, 487M visits | Saturated |
| Red light green light | Every Squid Game clone | Saturated |
| Sharks and minnows | Huss Valley | Taken |
| Soccer | Illegal Soccer | Taken |
| Capture the flag | Two Roblox versions, both at zero players | Open, but CTF is really a shooter mode and not "simpler" |

## 3. The ideas, ranked

### #1 Dodgeball with cursed balls (recommended)

**Base game:** classic dodgeball. Two teams, centre line, hit someone and they are out, catch a ball and the thrower is out plus one of your teammates comes back in.

**Twist:** every ball that spawns is a different cursed ball. The catch rule is the swing moment and it stays exactly as it is in real life, which is what makes the chaos matter.

Ball ideas (each is one line of logic plus one effect):
- Homing ball: curves gently toward the nearest enemy.
- Giant ball: slow, huge hitbox, can be caught by two people together.
- Swap ball: hit someone and you trade places with them.
- Sticky ball: sticks to the target and drags them across the centre line.
- Fuse ball: hot potato. Explodes 4 seconds after the first touch, out-ing whoever holds it.
- Boomerang ball: comes back to the thrower, can hit on the way back.
- Ghost ball: invisible in flight, visible only by its shadow.
- Clone ball: splits into three on throw, only one is real.
- Black hole ball: pulls every other ball on the court toward where it lands.
- Reverse ball: whoever gets hit is NOT out, the thrower is.

**Shape:** 4v4 or 5v5, 90-second rounds, best of 3. Court is a gym, parking lot or backyard with a fence, which fits the Farm Lasso art pipeline for cheap props. Jail bench on the sideline so eliminated players stay visible and cheer or heckle (emotes), and come back on a catch, so nobody sits out long.

**Why it is the pick:** universally known, including outside the US. No dodgeball game appears anywhere in the Roblox top charts, so the lane is open. The catch-to-revive rule gives constant comebacks. Balls flying and ragdolls are pure clip bait. Mobile controls are one joystick, one throw button with aim assist, one catch button.

**Risks:** hit registration must feel fair (server-authoritative balls, generous catch window). The "Illegal" naming belongs to Repotted, so pick your own brand. Name ideas: Cursed Dodgeball, Dodgeball Deathmatch, Ballistic Dodgeball.

### #2 Hot Potato / Spud with powers

**Base game:** Spud. One player throws the ball up and calls a name, everyone else scatters, the named player grabs the ball, shouts "spud", everyone freezes, and the holder takes three steps and throws. Hit someone and they get a letter (S-P-U-D). Four letters and you are out.

**Twist:** fold in hot potato. The ball is a bomb on a fuse. Holding it ticks your fuse, tagging someone passes it. Powers: throw range, teleport the potato to the furthest player, decoy potatoes, a magnet that pulls the potato to you (so you can pass it on), a freeze that locks one player's feet.

**Shape:** free-for-all, 10 to 16 players, 20 to 30 second rounds, letters accumulate across rounds, last player standing wins. This is the simplest possible loop on the list and the fastest to build.

**Why:** the freeze-on-"spud" rule is a built-in red light moment that is already funny. FFA with letters means a player is never fully out early. Tiny scope.

**Risks:** FFA bomb tag exists as a minigame in many hubs. It needs the letters-and-freeze structure and the powers to feel like its own game, not a minigame.

### #3 Marco Polo with abilities

**Base game:** pool tag. The seeker is blind. They shout "Marco" and everyone must answer "Polo", which reveals where they are.

**Twist:** the blindness is real. The seeker's screen is dark fog and sees only a sonar ping when they call Marco. Hiders are forced to reply, which lights them up for a second. Abilities: hold breath (skip one reply, costs stamina), echo decoy (throw a fake "Polo" to another spot), splash (blinds the seeker's sonar for a moment), dive (vanish under water for three seconds), fish out of water (seeker can catch anyone who leaves the pool).

**Shape:** 8 to 12 players, one or two seekers, 60-second rounds in a backyard pool, water park or lake.

**Why:** nothing like it on Roblox that I can find, the forced-reply rule is a mechanic no other tag game has, and the pool setting is summery and distinct from the dark-hallway hide-and-seek games. Pairs with a proximity voice gimmick later.

**Risks:** a blind seeker can be frustrating, so the sonar must be readable and the seeker must get a satisfying lunge. Harder to make work on mobile than #1 or #2.

### #4 Red Rover: Breakthrough

Two lines, a runner charges a chosen link, breaks through or gets absorbed. Twist: defenders pick a link ability (anchor, shield wall, bounce pad, trampoline) and the runner picks a charge ability (bulldoze, slide, pole vault, fake-out). The chant is part of the UI. To fix the downtime problem of real Red Rover, both teams send a runner at the same time, or three runners at once. Physics breakthrough is a huge clip moment. Risk: less known outside North America and the "holding hands" rule needs a visual translation (a glowing chain).

### #5 Kick the Can: Jailbreak

Hide and seek with a jail and one objective. The seeker guards the can and jails anyone they spot. Any hider who reaches and kicks the can frees the whole jail. Twist: seeker gets a sonar ping and traps, hiders get a decoy, smoke and a dash. The can is the swing moment. Risk: it sits close to the saturated hide-and-seek lane and would need a very loud identity to escape the comparison.

### #6 Four Square: king of the court

Four players, four squares, a bouncing ball, the king serves. Twist: the ball carries a power on every hit (curve, slam, freeze bounce, double bounce, invisible). Many courts per server with a promotion ladder, so losing drops you one court and winning sends you up. Satisfying and skill-based, but ball physics on mobile is the whole game and hard to get right, and the chaos ceiling is lower than the others.

### #7 Butts Up / Wall Ball

Throw a ball at a wall, catch it, mess up and you are "it". The classic punishment is standing against the wall while everyone throws at you. Twist: the penalty wall with powers. Extremely meme-able name and punishment. Risk: regional, less known outside the US, and the penalty could read as bullying to moderation.

## 4. Scoring

Scores are 1 to 5. "Open lane" is how little competition exists on Roblox today.

| Idea | Known everywhere | Open lane | Swing moment | Clip-ability | Mobile | Build size | Total |
|---|---|---|---|---|---|---|---|
| Cursed Dodgeball | 5 | 5 | 5 | 5 | 4 | 3 | 27 |
| Hot Potato / Spud | 4 | 3 | 3 | 4 | 5 | 5 | 24 |
| Marco Polo | 4 | 5 | 3 | 4 | 3 | 3 | 22 |
| Red Rover | 3 | 5 | 4 | 5 | 4 | 3 | 24 |
| Kick the Can | 3 | 3 | 5 | 3 | 4 | 3 | 21 |
| Four Square | 4 | 4 | 2 | 3 | 2 | 3 | 18 |
| Butts Up | 2 | 5 | 2 | 5 | 4 | 4 | 22 |

Red Rover ties Hot Potato on points but loses on "does a kid in Brazil or India know it", which matters for Roblox's audience.

## 5. Whatever you pick, apply this checklist

- Explain the rules in one sentence on the loading screen. If it needs two, the base game is wrong.
- Keep the real win condition untouched. Abilities change the path, never the goal.
- One rule from the real game is the comeback (catch, can kick, letters). Make it loud: slow-mo, a shout, a camera punch.
- 60 to 120 second rounds. Nobody waits more than 20 seconds for the next one.
- Eliminated players stay in the scene (bench, jail, bleachers) with emotes.
- Cosmetics only for monetization. Abilities are earned per round or rolled, not bought, so the game stays fair and clips stay funny.
- Pick a name that can be shouted and turned into a verb.

## Sources

- Huss Valley stats: https://www.rolimons.com/game/107535308163741
- Huss Valley meme context: https://escapehussvalley.com/en/guide/what-is-huss-valley
- Illegal Soccer stats: https://rowatcher.com/games/10155360168/illegal-soccer and https://profitable.app/roblox/games/illegal-soccer
- Illegal Soccer guide (items, controls): https://allthings.how/roblox-illegal-soccer-guide-best-items-and-how-to-score/
- Hide and seek saturation: https://rowatcher.com/games/9977954973/paint-and-seek
- Musical Chairs: https://rowatcher.com/games/10067540823/musical-chairs-testing
- Huss Rooms freeze tag: https://www.roblox.com/games/94610770420769/Clark-Huss-rooms
- Capture the Flag (dead): https://rowatcher.com/games/7457539177/capture-the-flag
- Backyard game rules: https://www.todaysparent.com/family/activities/fun-old-fashioned-games-and-rules/ and https://geekdad.com/2009/08/simpleoutdoorplay/
- Roblox trends 2026: https://www.creation.dev/learn/what-roblox-game-mechanics-are-trending-2026
