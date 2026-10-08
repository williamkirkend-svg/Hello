# Movement system design (v1, 8 Oct 2026)

Replaces section 5 of `BUILD-PROMPT.md` (the old sprint and dodge kit). Owner's brief: fluid, fun, versatile, complex and dynamic; nothing stiff; feel truly fast; match the five reference clips. Owner's choices: own look on a standard R15 body, camera always over the shoulder, slide and dash (no standing crouch), speed that builds as you keep moving. Owner's correction after seeing the reel: not as extreme as the references; it is still a PvP game in an arena. So every value below is the toned-down arena version: the references set the feel (smooth, weighty, readable), not the scale (speed, height, flips).

## 1. What the references do

Studied frame by frame (sheets in `research/movement-frames/`, slowed reel in `research/movement-reference-reel.mp4`).

| Clip | What matters |
|---|---|
| Ref 1, "Advanced Movement System" | Separate landing animation with a deep squat and arms out, recovering over about half a second. Slide is a long low glide. Dash is a short burst with a blurred afterimage. Run leans forward hard. |
| Ref 2, sliding pose | Lead leg straight out in front, back leg folded under, torso leaned back, one hand trailing near the ground, other arm up for balance. |
| Ref 3, wall run animation | Fast high-knee run cycle, body tilted with the feet toward the wall and the head away, the arm nearest the wall reaching forward and up, the other arm out behind for balance. |
| Ref 4, parkour reel | The feel target. Camera trails low behind and slightly to one side, wide field of view, stays steady through wall runs. White wind streaks pass the player at speed. A white-pink flash and ring burst on every wall kick. Grey swirling dust on the wall during a wall run. A pink streak trail on dashes. Tumbles and flips in the air. Wall to wall chains down corridors. |
| Ref 5, dev log | Procedural acceleration: speed climbs while you keep running (they show a velocity bar). "Natural" wall run: you just run along a wall at an angle and it engages, with height slowly dropping. A white dust burst on landing. |

## 2. Feel rules

0. **Arena first.** The court is 70 by 50 with 9-stud pillars and 8-stud pit walls. Movement must stay readable for the thrower: a target can be hard to hit, never impossible to follow. Top speed stays well under a quick throw (60), air time stays short, and nothing flips or spins for longer than a third of a second.

1. **Input is instant, the body is not.** A key press changes what you do on the same frame. The body follows on springs so nothing snaps.
2. **Momentum is kept, not given.** Speed is earned by sprinting and chaining moves, and lost by stopping, turning hard or hitting walls.
3. **Every move has an entry, a hold and an exit pose.** No move starts from or ends in a T-pose.
4. **Speed is shown three ways:** field of view, wind and lean.
5. **The camera barely moves.** It never swings around on its own. Wall runs change its shoulder and add about 2.5 degrees of roll, nothing more.

## 3. Characters

- Every player is spawned as R15 by the server, whatever the place's avatar setting.
- Each player keeps their own clothing, skin colours, face and accessories.
- Body parts are forced to the default R15 parts, and all scales are fixed (height, width, depth and head at 1; body type and proportion at 0), so every body is identical.
- Accessories are massless with no collision, no touch and no query, so they never change physics or hit tests.
- Gameplay hit tests keep using the root part with a fixed radius, which is the same for everyone.
- The default Animate script is removed. All animation is procedural (section 7).

## 4. Moves and numbers

All values live in `MovementConfig.lua`. Speeds are in studs per second.

### Ground speed and momentum

| Item | Value |
|---|---|
| Jog (no sprint) | 16 |
| Sprint target | ramps from 16 to 23 in about 0.6 s (12 studs/s²) |
| Overspeed from boosts | above the sprint target, decays at 5/s² on the ground, 2/s² in the air, 0 during a wall run |
| Hard cap | 28 |
| Ground acceleration | 90/s², deceleration with no input 70/s² |
| Hard turn (over 110 degrees) | keeps 60 percent of speed |
| Air control | 35/s² of steering; input cannot add speed beyond what you carried in |
| Boosts | slide entry +3, wall jump +2, wall run entry +1, roll landing keeps speed |
| Stamina | sprint and wall run drain it in 4 s, refill in 3 s after a 0.4 s pause; dash costs a quarter |

### Jumping

| Item | Value |
|---|---|
| Jump | standard, about 7 studs high |
| Variable height | releasing Space early cuts the rise |
| Fall gravity | 1.3 times normal while falling, so jumps feel snappy, not floaty |
| Coyote time | 0.12 s after leaving a ledge you can still jump |
| Jump buffer | Space pressed up to 0.12 s before landing still jumps |
| Double jump | one per airtime, 80 percent of a normal jump, refreshed by landing, wall running or a wall jump. A quick knee tuck (no flip), a small air ring under the feet. |

### Wall run (natural)

- **Engages automatically** when all of these hold:
  - you are airborne;
  - you are moving at least 14 studs/s;
  - a wall at least 6 studs tall is within 2.5 studs on your left or right;
  - you are travelling within 60 degrees of parallel to it;
  - you are holding forward.
- **Speed:** keeps your speed plus a 2-stud boost.
- **Arc:** you start with a small lift, then sink slowly at 15 percent gravity, so you run in a gentle arc.
- **Length:** up to 1.0 s, after which you slide off. On the court that is most of a pit wall's short side; on a 4-stud pillar face it is a quick wall kick.
- **Drop off:** stop holding forward or press slide.
- **Repeat:** the same wall cannot be grabbed again for 0.35 s, so a wall jump to the opposite wall chains wall runs down a corridor.

### Wall jump

- Space during a wall run.
- Launches you away from the wall at 22, up at 40, and keeps 75 percent of your speed along the wall.
- Adds 2 to momentum and refreshes the double jump.
- VFX: a white-pink flash and ring burst.

### Slide

- Press C or Left Ctrl while sprinting on the ground at 18 or faster.
- Adds 3 to speed (up to the cap), then friction slows you at 12/s² for up to 0.9 s.
- Your body drops about 1.1 studs, so you can slide under a chest-height throw.
- Jump out of a slide for a long jump that keeps your speed.
- VFX: dust and sparks trail from the feet.

### Dash (the existing dodge)

- Q: 8 studs in the stick direction over 0.2 s, costs a quarter of stamina, 0.8 s cooldown.
- One use in the air per jump.
- No invulnerability.
- VFX: a pink streak trail, two fading afterimages, and a field-of-view pop.

### Landing

| Fall speed on landing | What happens |
|---|---|
| Under 35 | Light: quick knee dip, 0.12 s |
| 35 to 60 | Medium: deeper crouch with arms out, 0.22 s, small dust puff |
| Over 60 while moving faster than 14 | Roll: quick forward roll, keeps your speed, 0.4 s |
| Over 60 standing or slow | Heavy: hero landing with one hand down, 0.35 s at half speed, dust ring and a tiny camera bump |

On this court a heavy landing comes from a rail or pillar top plus a double jump; ordinary jumps are light or medium.

### Mantle

- A ledge up to 3.5 studs high is vaulted automatically when you run into it.
- One hand goes down on the ledge and the legs swing over, in 0.3 s.

## 5. Facing

- **While moving,** the character turns to face its direction of travel, smoothed at up to 720 degrees per second, with a lean into the turn.
- **While holding a ball, charging a throw or standing still,** it turns to face where the camera looks, so throws read correctly.

## 6. Camera (always over the shoulder)

| Item | Value |
|---|---|
| Shoulder | camera offset 1.75 studs to the right and 0.6 up. During a wall run with the wall on your right, it eases to the left shoulder over 0.3 s so the wall never blocks the view, and back after. |
| Zoom | between 8 and 14 studs while you are on the court |
| Mouse | locked to the centre while you are Live on PC, so the mouse turns the camera. Released in menus and the stands. |
| Field of view | 70 at jog, rising smoothly to 78 at the hard cap. Short kicks: dash +4, wall jump +3, double jump +2, each settling over about 0.3 s. |
| Wall-run roll | 2.5 degrees toward the wall |
| Heavy landing | a 0.3-stud downward bump, nothing else |

## 7. Animation (procedural)

**Why procedural.** Animations are generated in code from the character's speed and state every frame, instead of playing uploaded keyframe files. This gives three things:
- The run's stride, lean and arm pump scale continuously with speed, which is what makes the references feel alive.
- Every move blends smoothly into every other move.
- No animation asset uploads are needed before you can test.

**How it works.** Each client animates every character from replicated state. The owner of a character sends its move state to the server about 15 times a second; the server checks it and shares it with everyone. Joints are driven through the R15 Motor6D transforms with per-joint springs.

| State | Pose |
|---|---|
| Idle | soft knees, slow breathing, slight weight shift |
| Run and sprint | stride frequency 1.4 to 2.6 cycles per second and stride length scale with speed; forward lean from 3 to 15 degrees plus extra while accelerating; arms pump harder and elbows bend more at speed; knees kick higher at speed; vertical bob; pelvis and chest counter-rotate; head stays level; banks into turns |
| Jump rise | lead knee up, trail leg back, arms up and forward |
| Apex | legs gather |
| Fall | arms out for balance, legs reaching down; long falls stretch further |
| Double jump | a quick knee tuck, 0.3 s |
| Wall run | fast high-knee cycle, body rolled with feet toward the wall, wall-side arm reaching forward and up, outer arm back |
| Wall jump | push-off with both legs, then an arched body with arms flung out, then the air poses |
| Slide | the reference 2 pose: lead leg out, back leg folded, torso back, trailing hand low, other arm up |
| Dash | dive lean into the dash direction, legs trailing |
| Landings | the four kinds in section 4 |
| Mantle | hand down, legs swing over |

**Preview.** A preview renderer draws the actual pose code as R15 boxes into short videos, so the motion can be judged before it is in Studio.

## 8. Speed VFX ("wind coming past")

| Effect | Who sees it | Trigger |
|---|---|---|
| Screen speed lines (thin white streaks at the screen edges, faint) | local player | fade in above 21 studs/s, at most 35 percent opacity at the cap |
| World wind streaks (short white beams flying past the camera) | local player | above 19 studs/s, rate grows with speed |
| Limb trails (thin white ribbons from hands and feet) | everyone | above 22 studs/s |
| Wind sound | local player | volume and pitch follow speed |
| Dash streak and afterimages | everyone | dash |
| Wall-run dust and swirl at the wall | everyone | wall run |
| Wall-kick flash and ring (small, 0.2 s) | everyone | wall jump |
| Air ring | everyone | double jump |
| Landing dust and shockwave | everyone | medium and heavy landings, rolls |
| Slide dust and sparks | everyone | slide |

All textures are Roblox built-ins, and the streaks are untextured Beams and Frames, so nothing needs uploading.

## 9. Controls

| Action | PC | Gamepad | Phone |
|---|---|---|---|
| Sprint | hold Shift | L3 | automatic when the stick is pushed fully |
| Jump, double jump, wall jump | Space | A | Jump button |
| Dash | Q | X | DASH button |
| Slide | C or Left Ctrl | B | SLIDE button |

## 10. Files

| File | Job |
|---|---|
| `ReplicatedStorage/CursedDodgeball/Movement/MovementConfig.lua` | every number above |
| `.../Movement/MoveMath.lua` (pure, tested) | momentum, acceleration, wall run checks, wall jump, landing kinds, stamina, field of view and camera targets |
| `.../Movement/Poses.lua` (pure, tested) | every pose as joint angles, plus blending and springs |
| `.../Movement/Animator.lua` | drives R15 joints for every character from state |
| `.../Movement/VFX.lua` | all effects |
| `ServerScriptService/CursedDodgeball/Characters.server.lua` | R15 spawning, standard body, accessories, respawn, move-state relay, speed sanity check |
| `StarterPlayerScripts/CursedDodgeball/Movement.client.lua` (replaces the old one) | input, state machine, physics, camera |
| `StarterCharacterScripts/Animate.client.lua` | empty stub that stops the default animations |
| `tools/pose_preview.py` | renders pose videos from the Luau pose code |
