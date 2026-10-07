# Arena layout (v0.3)

Top-down map: `arena-topdown.svg` (open it in a browser or Studio's image viewer). Units are studs. X runs along the long side, Z along the short side, the court centre is the origin, the floor top is Y = 0, the Ghost ring and first row of seats are at Y = 8.

## Courts per round

| Round | Court (X by Z) | Kerb at | What stays inside |
|---|---|---|---|
| 1 | 70 by 50 | X = +-35, Z = +-25 | Stage, 4 pillars, 4 half-walls, 2 rails, ball hatch |
| 2 | 48 by 36 | X = +-24, Z = +-18 | Stage, 2 pillars (diagonal), 2 half-walls (N and S), no rails |
| 3 (final) | 30 by 24 | X = +-15, Z = +-12 | Stage only |

Obstacles that fall outside the next kerb sink into the floor during the 8-second replay (a 2-second tween, dust puff at the floor). Nothing is ever taller than 9 studs, so every seat in the stands, which start at Y = 9.5, looks over everything.

## Obstacle sheet

| Name | Size (X, Y, Z) | Centre (X, Y, Z) | Count | Wall-runnable | Mantle | Grapple anchor |
|---|---|---|---|---|---|---|
| Stage | 12, 4, 12 | 0, 2, 0 | 1 | No (4 studs, too low) | Yes, from any side | No |
| Stage ramps | 6, 4, 6 (wedge) | +-9, 2, 0 | 2 | No | n/a | No |
| Ball hatch | 3, 0.5, 3 | 0, 4.25, 0 | 1 | n/a | n/a | No |
| Pillar | 4, 9, 4 | +-20, 4.5, +-14 | 4 | Yes, all four faces | No | Yes, the top |
| Half-wall N, S | 8, 3, 1 | 0, 1.5, +-16 | 2 | No | Yes | No |
| Half-wall E, W | 1, 3, 8 | +-28, 1.5, 0 | 2 | No | Yes | No |
| Rail | 40, 0.6, 1 | 0, 7, +-14 | 2 | No | No | Yes, anywhere along it |
| Pit walls | 78, 8, 1 and 1, 8, 58 | at X = +-39, Z = +-29 | 4 | Yes, full length | No | Yes, the top edge |

Round 2 keeps the pillars at (+20, -14) and (-20, +14), the half-walls at Z = +-16, and the stage. Round 3 keeps the stage.

## Movement routes the layout is built for

- **Floor loop:** sprint the lane between the half-walls and the kerb, vault a half-wall, dodge behind a pillar. This is where most players live.
- **High route:** wall run a pillar face, kick off onto the rail, run the rail along the long side, drop onto the stage. Hard to hit from below, exposed to anyone on the far rail.
- **Edge escape:** wall run along the pit wall to get out of a corner during the Flood. The Flood band still counts if you land in it.
- **Stage fight:** the ball hatch is on the stage, so the first seconds of every round are a scramble up the ramps. The stage is the best throwing position and the worst dodging position.

## Spawn points

Twenty points on a rectangle inset 3 studs from the round's kerb (X = +-32, Z = +-22 in round 1), evenly spaced, facing the centre. All obstacles are at least 4 studs from that rectangle in every round. Mid-round returns (a Ghost swap) use the same rectangle shrunk by the Flood inset.

## Spectator readability rules

- Heights: nothing above 9 studs; stands start at 9.5.
- Colour: floor is one flat bright colour, obstacles one darker flat colour with a white top edge, kerb band white. Players are the only saturated moving colours apart from balls.
- Every ability use fires a 0.3-second colour flash on the player and a ticker line on the jumbotron.
- The broadcast camera sits 25 studs above the centre, pitched 30 degrees, and never needs to move: the whole court fits.
- The Flood is a bright pink band, the countdown above a dormant ball is a floating number, both readable from the top row.

## Why this layout and not a flat court

The owner wants more movement and a little confusion for players on the floor without losing the crowd. Pillars and half-walls break sightlines at player height (1 to 5 studs) and not at spectator height (9.5 studs and up). Rails give the wall run and the Grapple a destination. The stage puts the one objective, the balls, in the most visible spot. Shrinking obstacles with the court means the final is still a pure dodgeball showdown.
