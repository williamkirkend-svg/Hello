# Round flow (v0.3)

The show, second by second, with the parkour arena, abilities and persistent balls in place. Numbers are first guesses for the playtest unless they already live in `Config`.

## Intermission (20 s)

| Time left | What happens |
|---|---|
| 20 | Everyone is in the stands. Jumbotron: "NEXT SHOW IN 20". The pick panel opens for anyone who has not locked an ability; last pick stays by default. Spectator Wildcard vote opens (one of the 12 cursed balls). |
| 20 to 8 | The ball draw for this show is revealed on the jumbotron one ball at a time with its name and a two-word hint ("EYE: it follows you"). Eight reveals, one a second. |
| 8 | Ability picks lock. Pick icons float above heads. Tunnel gates open. "GET TO THE TUNNELS." |
| 8 to 0 | Players walk down the two tunnels onto the court. Anyone still in the stands at 0 is teleported to a spawn point. |
| 0 | Gates close. Round 1 begins with the countdown. |

## Round start (3 s countdown + 2 s fountain)

1. **Countdown.** Players stand on their spawn points, free to move within 4 studs. "3, 2, 1" on the jumbotron with a drum hit each. No balls exist on the court yet.
2. **Whistle and fountain.** At 0 the hatch on the stage fires all 8 balls in a high arc, one every 0.25 s, to 8 landing spots on a ring at 60 percent of the court's half-extents, mirrored across both axes and rotated by a random angle each round. Balls are not live in the air (they cannot hit) and are idle the moment they land. The fountain is the crowd's first cheer.
3. **The scramble.** Players sprint to the nearest landing spot. With 20 players and 8 balls, roughly 8 get a ball and 12 do not. The first throws happen around second 4. The stage stays empty for the first few seconds, which is on purpose: the high ground is a choice, not a spawn advantage.

## Round body

- Hits, catches, shields, Ghost throws and the one ability use per round as designed.
- **Dormant balls** show a countdown above them visible to everyone from anywhere. A ball about to re-arm is a race.
- **Ball economy:** 8 balls never change count. A ball outside the kerb rolls back after 2 s. A ball on a sunk obstacle drops. A ball in the Flood band stays pickable, and reaching for it is how the Flood gets people.
- **The Flood** starts at the round cap and moves the pink band inward at 2 studs per second until the cut.
- **Round 1** cap 90 s, cut at 8. **Round 2** cap 60 s, cut at 4. **Final** cap 45 s, last one standing.

## The cut (8 s replay)

| Seconds into replay | What happens |
|---|---|
| 0 to 4 | Slow-motion replay of the eliminating hit on the jumbotron and on every screen (a frozen camera from the broadcast position with a 0.3x time scale). "CUT! 8 SURVIVE." |
| 1 to 3 | Every ball is vacuumed back into the hatch with trails, including dormant ones, which finish their countdown inside and come out re-armed. |
| 3 to 6 | Obstacles outside the next kerb sink into the floor with a dust puff. The next kerb lights up. Ghosts who did not get back in are moved to the stands. |
| 6 to 8 | Survivors who are standing outside the next kerb are walked (teleported with a short fade) to the nearest spawn point inside it. Everyone else stays where they stand. |
| 8 | Next round's countdown begins. The fountain fires into the smaller court. |

The final's court is 30 by 24 with 8 balls and 4 players: more balls than hands is intended, so nobody can stall for lack of a ball.

## Crowning (15 s)

- The winner is teleported to the stage top. Their celebration plays (the Farm Lasso Aura kit, 6 to 9 s).
- The jumbotron shows the top four: winner, then the last three out in reverse order.
- MVP vote opens for spectators (3 candidates: most hits, most catches, best Ghost comeback), result shown at the next intermission.
- At 0 everyone is returned to the stands and the next intermission starts.

## Edge cases

- **Fewer than 6 at intermission end:** the timer re-arms, the jumbotron shows "NEED 6 PLAYERS (4)".
- **Six to eleven players:** two rounds (cut to half, then the final); the fountain still fires all 8 balls.
- **A player joins mid-show:** stands, spectator camera, the next-show timer, and the pick panel. They play from the next intermission.
- **A leaver during the replay** can leave too few players for the next round: the show skips ahead or crowns, never starts an empty round.
- **A round that ends in the first 3 seconds** (everyone leaves): same skip-ahead rule.
