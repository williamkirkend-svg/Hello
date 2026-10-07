# Ball versus arena rules (v0.3)

How every ball behaves against the obstacles in `arena.md`. These are designer calls; nothing here needs a new system beyond what the ball already does.

## Surfaces

| Surface | What a live ball does on contact | Notes |
|---|---|---|
| Floor | Dies, becomes idle where it stops | The default |
| Pit wall | Dies, drops at the base | Wall-runnable for players, a dead end for balls |
| Pillar (any face) | Dies, drops at the base | Pillars are the cover. Breaking line of sight behind one is the main defence against a charged throw |
| Half-wall | Dies if it hits the wall; passes over if the throw is high enough | A half-wall is 3 studs; a thrown ball at chest height (about 3) clips it. Crouching behind one (just standing close) is real cover against quick throws; lobs go over |
| Stage side | Dies, drops at the base | The stage is a 4-stud wall from the floor |
| Stage top | Idle on the stage | Balls on the high ground are the prize |
| Rail | Dies on contact but cannot rest: rolls off to the floor below | Rails are 1 stud wide; a dead ball never sits on one |
| Ramp | Dies, rolls down the ramp to the floor | Ramps are slopes; idle balls on a ramp roll |
| Flood band | Balls are never flooded. An idle ball inside the pink band is still a ball | Stepping in to grab it is the bait. A ball thrown from inside the band by a player who is not yet out (the band checks each frame) is legal |
| Kerb | A ball outside the kerb rolls back inside after 2 seconds | Unchanged |

## Per ball

| Ball | Against obstacles | Against the rail and stage | In the Flood | Dormant state looks like |
|---|---|---|---|---|
| Plain | Dies on any surface | Idle on the stage, rolls off rails | Pickable | n/a |
| Eye | Steers toward the nearest player but cannot path around anything: a pillar between it and its target kills it. Breaking line of sight is the counter | Can climb to hit a player on a rail (it steers up) | Pickable | Grey, eye closed, no swivel |
| Boomerang | Any surface contact starts the return leg early along the mirrored arc. The return leg also dies on surfaces, so a Boomerang thrown into a pillar comes back only if the way is clear | Can go out over a half-wall and return over it | Pickable | Grey, no spin |
| Shadow | Invisible body, shadow on whatever surface is below it: floor, stage top, or the floor under a rail | Shadow on the stage top is the tell for a stage fight | Pickable | Fully visible and dull |
| Bouncy | Bounces off pillars, half-walls, stage sides, pit walls and the floor, three bounces, 90 percent speed each. Rails count as a bounce too | The signature bank shot is pillar to player | Pickable | Grey, no stretch |
| Giant | Pierces players, not surfaces. A pillar or stage side stops it. A half-wall stops a Giant thrown at chest height, so half-walls are the Giant counter | Too big to land on a rail; drops | Pickable, and slow to carry out of the band | Grey, no dust ring |
| Glue | Hitting a surface leaves the puddle at its base. Hitting a player glues them where they stand, including on a rail or the stage edge, where a glued player is a sitting target | Glued on a rail means no dodge off it | Glued in the Flood band means out when the band reaches you | Dull green, no drip |
| Swap | Swaps positions regardless of height: floor for rail, stage for Flood band. Swapping yourself into the band is your problem | The rail-to-floor swap is the clip | A Swap can put someone in the band on purpose | Dull purple, arrows still |
| Fuse | Blast is a pure 7-stud sphere, no occlusion. Half-walls and pillars do not protect from it | Dropping a Fuse on the stage clears the stage | A Fuse left in the band ticks and blows there | Grey, fuse unlit, countdown above |
| Moon | A launched player sails over everything, passes through rails, and is out on landing | Launching someone off a rail is the best use | n/a | Dull grey, no drift |
| Decoy | Fakes die on surfaces exactly like the real one, so the surface does not give the real one away | Same | Pickable | Dull white, no wobble |
| Black Hole | Pulled balls lift over obstacles in a straight line to the vortex. Players are pulled only if nothing is between them and the vortex | On the stage top it drags every ball up to the high ground | Balls pulled out of the band are freed | Dull, vortex still, countdown above |
| Paint | Splat lands on the surface below the impact: floor, stage top, or the floor under a rail. A splat never sits on a rail | Painting the stage top makes the high ground a no-catch zone | A splat inside the band is pointless; the band already outs | Dull pink, countdown above |

## Dormant balls and sinking obstacles

- A dormant cursed ball (countdown above it) is a plain ball in every rule above until the burst.
- When an obstacle sinks between rounds, any ball resting on it drops to the floor and stays idle there.
- Between rounds every ball is vacuumed back into the hatch during the replay (a 1-second pull with trails), and the hatch refires them at the next round start. Dormant balls finish their countdown in the hatch and come out re-armed.
