# CURSED DODGEBALL: build prompt

Build a Roblox game called Cursed Dodgeball. Luau, Rojo-friendly, server-authoritative. Everything below is decided; do not add systems that are not listed.

## 1. Concept
Free-for-all dodgeball for 20 players in a sunken arena. Get hit by a ball, you are out. Catch a ball, the thrower is out. Three rounds cut the field to a single winner. Every ball is cursed with its own behaviour. Every player picks one ability. Only a ball can ever eliminate a player.

## 2. Server and show loop
- Server size 20. Minimum 6 to start. Below 6 the intermission timer re-arms and the jumbotron shows "NEED 6 PLAYERS (n)".
- Loop: Intermission 20 s → Round 1 → Replay 8 s → Round 2 → Replay 8 s → Final → Crowning 15 s → Intermission.
- Round caps and cuts: Round 1 90 s, ends at 8 players left. Round 2 60 s, ends at 4 left. Final 45 s, last one standing. With 6 to 11 players at show start play two rounds: cut to half (minimum 3), then the final.
- If a round hits its cap before the cut, the Flood starts: a pink band moves inward from the kerb at 2 studs/s; any live player standing in it is out. It stops when the cut is reached.
- If leavers drop the live count to or below the next round's cut during a replay, skip ahead to the next round or crown the survivor. Never start a round with too few players. A late joiner lands in the stands as a Spectator and plays from the next intermission.
- Round start: 3-2-1 countdown, then the ball hatch on the stage fires all balls in an arc, one every 0.25 s, to landing spots on a ring at 60% of the court's half-extents (mirrored, random rotation). Balls are not live in the air and are idle on landing.
- Replay: slow-motion replay of the cut elimination; balls vacuum back into the hatch; obstacles outside the next kerb sink into the floor; the next kerb lights; survivors outside it are moved to the nearest spawn inside.
- Crowning: winner teleported to the stage, celebration, top 4 on the jumbotron, MVP vote for spectators.

## 3. Roles
- Live: on the court.
- Ghost (rounds 1 and 2 only): eliminated player on the Ghost ring at the top of the pit wall. Gets exactly one throw per round, always a plain ball handed to them on arrival, quick throw only. If it hits a live player, Ghost and victim swap places (Ghost back on the court, victim to the ring with their own single throw). Ghost hits never count toward the cut. Miss or caught: Ghost goes to the stands. A player who already used their ghost throw this round and is hit again goes straight to the stands.
- Spectator: in the stands for the rest of the show.
- In the final there are no Ghosts; eliminated players go straight to the stands.

## 4. Core rules
- Hit: a live ball touching a player before it touches floor, wall or another ball puts them out (ragdoll fling, OUT stamp, teleport to ring or stands). No blocking with a held ball.
- Catch: tap Catch while a live ball is in reach. Window 0.25 s on a quick throw, 0.15 s on a charged throw. Catch = thrower out + catcher gains a Shield: one extra hit, lasts 3 s, does not stack or refresh while active.
- Hold: one ball at a time. A held ball pops out after 8 s (visible ring timer).
- Throw: tap = quick throw, 60 studs/s, wide catch window. Hold up to 0.8 s = charged throw, 110 studs/s, narrow window, glow and whine tell. Cannot sprint while charging. Server measures the charge from a "charge begin" message; the client sends no charge value.
- Aim: no free aim. The player always has one target shown as a bracket above that player's head (nearest to camera centre, within 90 studs and a 60° cone; Tab / swipe cycles). On release the ball flies in a straight line at where the target's chest is at that instant. It never steers or leads. Only the Eye Ball steers. Throws over 30 studs arc under gravity.
- Live/dead balls: a thrown ball is live until it touches floor, wall, a dead ball, or is caught. Dead balls can be picked up by walking over them (radius 3 studs). Balls outside the kerb roll back in after 2 s.
- Boundary: step over the kerb and you are out.
- Hit detection: server steps each ball with a spherecast every Heartbeat against live players' root parts (hit radius 2.5 plus ball radius). No Touched events, no physics in flight. Catch presses have a 0.5 s lockout.

## 5. Movement kit (everyone identical)
- Run 16 studs/s. Sprint 1.5x while holding Sprint; stamina lasts 4 s, refills in 3 s. Stamina shown as a bar on the HUD and a glowing strip on the player's back.
- Dodge: 8 studs in the joystick direction over 0.2 s, costs a quarter of stamina, 0.8 s cooldown, no invulnerability. One air dodge per jump, reset on landing. Horizontal only (never changes jump height).
- Wall run: while airborne, moving into a wall at least 6 studs tall and holding Jump runs along it at sprint speed for up to 1.5 s at quarter gravity, draining stamina like sprint. Jump again to kick off away and up, which resets the air dodge.
- Mantle: running into a ledge up to 3.5 studs high climbs it automatically.
- Controls PC: WASD, Shift sprint, Space jump/wall run, Q dodge, E ability, Mouse1 hold-to-charge throw, Mouse2 or F catch, Tab cycle target, C cycle spectator camera. Phone: joystick, Jump, and a right-hand cluster bottom to top Catch, Throw, Dodge, Ability, with Sprint to the left; swipe right half to cycle target.

## 6. Arena
Black-sky schoolyard blacktop venue. Court floor at Y=0, centre at origin, X along the long side.
- Courts: Round 1 70x50 studs, Round 2 48x36, Final 30x24. Kerb is a painted band with a 1-stud raised edge at the court boundary for the current round only.
- Pit: the court sits 8 studs below the stands. Pit walls are sheer, wall-runnable, footprint 78x58 (court plus a 4-stud free zone), with an 8-stud tunnel gap in the centre of each short wall.
- Ghost ring: 6-stud walkway at the top of the wall all the way round, glass rail 10 studs tall on the pit side so nobody can jump in.
- Stands: 5 rows on all four sides starting at ring height, each row 3 deep and 1.5 higher, with an 8-stud channel through the short-side rows for the tunnels. Spectators spawn in seats.
- Tunnels: ramps from ring level down through the short-wall gaps to the floor, with a deck at ring level and side rails. Gates at the floor end close (CanCollide) during rounds and open during intermission.
- Jumbotron: a screen above the +X short end showing countdown, live count and timer, ticker, Flood warning, replay, winner.
- Obstacles (all under 9 studs so the stands see over them, mirror-symmetric):
  - Stage 12x12x4 at centre with 6x4x6 wedge ramps on ±X; the ball hatch is on top.
  - 4 pillars 4x9x4 at (±20, ±14): wall-runnable, grapple anchors.
  - 4 half-walls 3 studs high: 8-long at (0, ±16) along X; 8-long at (±28, 0) along Z. Mantle over them.
  - 2 rails 40x0.6x1 at Y=7, Z=±14, from pillar to pillar: grapple anchors, walkable.
  - Round 2 keeps the stage, pillars at (+20,-14) and (-20,+14), half-walls at Z=±16. Final keeps only the stage. Obstacles outside the next kerb sink into the floor during the replay.
- Spawns: 20 points on a rectangle inset 3 studs from the current kerb, facing centre; mid-round returns use it shrunk by the Flood inset.

## 7. Balls
- 8 balls per show, drawn once at show start: 4 plain + 4 cursed (3 random, no duplicates, + 1 spectator Wildcard vote). The same 8 persist through all rounds and never despawn. Between rounds they are vacuumed into the hatch and re-fired.
- Every cursed ball has a unique shape, colour, idle animation, trail and sound. The jumbotron reveals the draw one ball per second during intermission.
- Re-arm: when a cursed ball triggers (Fuse, Black Hole, Paint, Decoy, Shadow-caught), it goes dormant: a countdown number floats above it, visible to everyone from anywhere, 6 s, during which it behaves as plain and looks dull. At zero a burst ripples across the whole ball and it is its original cursed ball again (colour, glow, animation, sound restored).
- Launch roster (12):
  1. Eye Ball (homing): curves toward the nearest live player in a 30° cone ahead, turning at most 25°/s, 80% speed. Cannot path around obstacles. Normal catch.
  2. Boomerang: flies an arc and returns to the thrower, live both ways; any surface contact starts the return early; a catch stops the return.
  3. Shadow: invisible in flight, only its floor shadow shows; visible again when it lands. A caught Shadow becomes visible for the rest of the round (then re-arms).
  4. Bouncy: stays live for 3 bounces off floor, walls, pillars, half-walls and rails at 90% speed each; can hit its own thrower.
  5. Giant: 2x size, 60% speed, slows the holder 35%, pierces players (outs everyone in its path), stopped by pillars, stage sides and chest-height half-walls. Cannot be caught by one player: two players within 4 studs both pressing Catch in the window catch it together (both get Shields). Uncatchable in the final.
  6. Glue: the hit does not put you out; it glues your feet for 3 s (you can still turn, throw, catch). Catcher is not glued.
  7. Swap: nobody goes out; thrower and target instantly trade positions with 1 s immunity each, regardless of height. Normal catch.
  8. Fuse: fuse starts on first pickup, 4 s, explodes in a 7-stud sphere (no occlusion) putting out everyone inside including the holder; a hit player is not out on contact, the ball drops at their feet still ticking; catching does not stop the fuse. Consumable (re-arms).
  9. Moon: holder has one-third gravity (triple jump, floaty); 70% speed lobbed throw; the hit launches the target 20 studs up and they are out on landing. Normal catch.
  10. Decoy: the throw splits into 3 balls fanned 15° apart; one is real, two are fakes that pass through players and pop on surfaces; catching a fake wastes the catch window. Consumable.
  11. Black Hole: where it lands opens a 3 s vortex pulling every loose ball to that spot (lifting over obstacles) and pulling players within 10 studs at walking pace (no outs). A catch cancels it. Consumable.
  12. Paint: splats a 6-stud pink circle on the surface below the impact for the rest of the round; anyone standing in paint cannot catch. A caught Paint splats under the thrower. Consumable. Never in the final draw.
- Surfaces: a live ball dies on floor, pit walls, pillars, stage sides and rails (balls roll off rails and ramps). Balls on the stage top are idle there. Balls in the Flood band stay pickable.

## 8. Abilities
- Each player picks one ability during the intermission on an 8-tile panel (also a physical board on the concourse). Locked when round 1 starts, for the whole game. Default Blink. Pick icon floats above the head during intermission only.
- One use per round, refreshed every round start. One button (E / ButtonL1 / touch). Ghosts and Spectators cannot use abilities. Every use: 0.3 s colour flash, sound, 2 s jumbotron ticker line ("Alex used BLINK"), icon pop above the head. The server validates role, phase and the once-per-round flag.
- No ability ever eliminates a player.
  1. Blink (blue): teleport 12 studs in your movement direction (facing if still), stops 1 stud short of walls, server clamps inside the live court. Keeps your ball.
  2. Grapple (orange): hook the nearest anchor (pillar top, rail, pit wall top edge) within 30 studs in camera direction and zip there at 60 studs/s. Pit wall anchors refused during the Flood and in the final.
  3. Snatch (green): the nearest idle ball within 20 studs flies into your hand in 0.3 s. Fails and is not consumed if you already hold one.
  4. Bubble (cyan): 1.5 s bubble that catches the first ball that would hit you (real catch: thrower out, Shield, you hold the ball). A Giant pops it and hits. A Decoy fake pops it harmlessly.
  5. Phase (violet): 1 s translucent; balls pass through you; not a catch; cannot throw or catch while phased.
  6. Vanish (white): 1.5 s fully invisible; target brackets drop off you and cannot re-lock; a held ball stays visible floating; throwing reveals you for 0.3 s. Balls still hit you.
  7. Slam (red): jump 6 studs and slam down; on landing players within 8 studs are pushed 6 studs away and loose balls scattered; no outs from the push itself. 0.6 s total.
  8. Smoke (grey): 10-stud cloud at your feet for 4 s; target brackets cannot lock onto anyone inside; the Eye Ball cannot acquire inside it.

## 9. Spectators
- Everyone not Live is in the stands (Ghosts on the ring). Four cameras cycled with one tap: seat view, broadcast (fixed Scriptable camera at centre, 25 studs up, pitched 30° down), follow-ball (CameraSubject = most recently thrown ball), player cam (cycle live humanoids). Reset to own humanoid when becoming Live.
- Cheer/boo wheel with crowd sound and seat emotes. A per-show hype meter that, when full, fires jumbotron fireworks and a crowd-picked trail on the next ball (cosmetic only).
- Wildcard vote during intermission: one of the 12 cursed balls joins the draw. MVP vote during crowning.

## 10. HUD
- Top centre: live count and timer ("14 LEFT 0:52"); under it round and Flood ("FLOOD ROUND 1" in pink); under that a two-line ticker of ability uses and catches.
- Top left: role (LIVE / GHOST with throws left / SPECTATOR / WAITING). Top right (spectators): camera mode.
- Bottom left: stamina bar (red below dodge cost), hold timer bar while holding.
- In world: red target bracket (grey out of range, hidden in smoke or on a vanished player); countdown number above dormant balls; "! INCOMING" 0.3 s before a ball reaches you; Ghost prompt "GHOST: 1 PLAIN THROW. HIT TO GET BACK IN."
- Toasts (2 s): OUT!, CAUGHT! SHIELD 3s, BACK IN!, CUT!, FLOOD!, "<name> WINS".
- Intermission panel: next-show timer and stands count, 8 ability tiles 4x2 with the current pick bordered, a Wildcard strip of 12 ball icons, "GET TO THE TUNNELS" at 8 s. The jumbotron never shows anything a player's own HUD lacks.

## 11. Onboarding
- Loading sentence (one of): "It's dodgeball. The balls are cursed. Your friends are worse."
- One how-to-play screen shown once per player, on their first intermission, four panels with one line each: GET HIT, YOU'RE OUT. / CATCH IT, THEY'RE OUT (3-second shield). / THE BALLS ARE CURSED. Watch the colour; a number above a ball means it's about to wake up. / PICK ONE ABILITY. One use per round. It never kills. Footer with the controls. One DISMISS button. Never shown again.

## 12. Main screen (logo intro, plays on join)
Reference image: concepts/logo-approved-reference.png. Black background. Two layered assets: DODGEBALL (big, wide, very round puffy white bubble letters, thick black outline with a thin white keyline) and CURSED (about 40% the height, tall condensed cracked-stone letters that are hollow stone borders with purple fire inside, sitting on DODGEBALL's top-left corner, overlapping the top of the first three letters, rotated 12° clockwise).
Sequence: DODGEBALL pops in letter by letter, centred (xylophone, 0.08 s apart). Hold 2 s alone. CURSED slams down from above at full speed, dark and unlit, onto the top-left corner (screen shake 0.2 s, dust and pebbles, the letters under it squash). 0.3 s later purple fire ignites inside the stone frames left to right (0.05 s apart; a looping 12-frame flipbook masked to the letter interiors) and keeps burning. Tagline and "TAP TO PLAY / PRESS ANY KEY" fade in. On input the logo shrinks to the top centre, the stands fade in, the logo hides after 2 s. Tap after the slam skips to the fire. Build with ScreenGui ImageLabels and TweenService (Back easing for the letter pops, Quart In for the slam); flames via ImageRectOffset spritesheet. Six sounds: xylophone run, twinkle, rock slam, pebble rattle, fire whoosh, fire crackle loop.

## 13. Monetization and progression
Cosmetics only: jerseys, ball trails and skins, catch and victory celebrations, out animations, emotes, seat flags, crown skins. Nothing that touches gameplay is sold. XP per show from placement, hits, catches, Ghost comebacks and MVP votes; levels unlock cosmetics. Leaderboards for wins, streaks, catches and Ghost comebacks.

## 14. Technical rules
- Only the server decides hits, catches, outs, shields, ability uses and ball states. Clients send intents only (throw with ball name and target id, catch press, charge begin, ability use, pick).
- Balls in flight are anchored parts moved by the server each Heartbeat along a server-stepped path; idle balls are anchored where they land. Same-frame hits are sorted by contact time before being applied.
- State mirrors to clients via attributes on a ReplicatedStorage State folder (Phase, Round, Rounds, Timer, Live, Flood, FloodInset, Winner) and per-player attributes (Role, GhostThrows, HeldBall, HeldSince, Ability, AbilityUsed, TargetId). Events go over a ShowEvent RemoteEvent as {type=...} tables.
- Keep everything under 9 studs inside the pit, under 500k triangles in view, 60 fps on a mid phone. Crowd NPCs are low-poly seated meshes with one shared material.
