# Cursed Dodgeball Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A playable grey-box of Cursed Dodgeball: sunken pit arena, plain-ball throw and catch, outs and the Ghost ring, the three-round show loop, the movement kit and the target picker.

**Architecture:** All game rules live in pure Luau modules with zero Roblox requires (ShowState, Balls, BallFlight, Targeting) so they run headless under the `luau` CLI. Thin Roblox layers (server show driver, server ball driver, client movement, client throwing, client spectate, HUD) call the pure modules and own Instances, remotes and cameras. The arena is built procedurally from `Config` so no meshes are needed for Phase 1.

**Tech Stack:** Roblox Luau, Rojo project layout (also installable by copy-paste like Farm Lasso), `luau` CLI for tests, `luau-analyze` via `scripts/luau-check.sh`.

**Spec:** `cursed-dodgeball/DESIGN.md` (sections 3, 4, 6, 7, 10) and `cursed-dodgeball/balls.md`.

## Global Constraints

- Pure modules under `cursed-dodgeball/src/ReplicatedStorage/CursedDodgeball/Pure/` must not reference `game`, `script`, `workspace`, `Instance`, `Vector3` or `task`. Vectors are `{x,y,z}` tables there.
- Every number from the spec is in `Config.lua` and nowhere else: 20 players, min 6, round caps 90/60/45 s, cuts to 8 then 4, intermission 20 s, replay 8 s, crowning 15 s, court 70x50 / 48x36 / 30x24 studs, pit depth 8, ring width 6, five rows at 1.5 studs, quick throw 60, charged 110, charge time 0.8 s, catch windows 0.25/0.15 s, shield 3 s, hold limit 8 s, run 16, sprint 1.5x, stamina 4 s drain / 3 s refill, dodge 8 studs in 0.2 s costing 0.25 bar with 0.8 s cooldown, flood 2 studs/s, ball roll-back 2 s, Ghost one plain throw per round, round 1 balls 8 (4 plain), round 2 balls 6 (1 plain), final 4 balls all cursed.
- Only the server decides hits, catches, outs and shields.
- No code comments with model names. No team concepts anywhere.

## Review Focus

1. A player leaves mid-round: the field count must drop and a cut or win must still fire (ShowState test in Task 3).
2. Fewer than 6 players at intermission end: the show must not start, the timer re-arms (Task 3).
3. Two balls hit the same player in one frame: exactly one elimination and one Ghost entry (Task 3 and Task 8).
4. A throw arrives from a client claiming an origin far from the server's position for that player: rejected (Task 4 `validateThrow` test, Task 8 uses it).
5. The last two players both get hit in the same frame: the round ends with a winner chosen by the earlier timestamp, never with zero players (Task 3).

---

### Task 1: Project skeleton, test runner, Config

**Files:**
- Create: `cursed-dodgeball/default.project.json`
- Create: `cursed-dodgeball/src/ReplicatedStorage/CursedDodgeball/Config.lua`
- Create: `cursed-dodgeball/tests/run.luau`
- Create: `cursed-dodgeball/tests/Config.test.luau`
- Create: `cursed-dodgeball/scripts/test.sh`

**Interfaces:**
- Produces: `Config` table with fields `Players`, `Show`, `Court`, `Throw`, `Catch`, `Movement`, `Balls` holding the Global Constraints values. `tests/run.luau` requires every `*.test.luau` in `tests/` listed in its `TESTS` array and prints `N passed, M failed`, exiting non-zero on failure. Test files export `function(t)` where `t.eq(a, b, msg)` and `t.ok(cond, msg)` assert.

- [ ] Write `tests/Config.test.luau` asserting `Config.Players.Max == 20`, `Config.Show.Rounds[1].Cap == 90`, `Config.Court.Rounds[3].Width == 30`.
- [ ] Run `bash cursed-dodgeball/scripts/test.sh`; expect failure (Config missing).
- [ ] Write `Config.lua` with every Global Constraints value; write `run.luau` and `test.sh` (`luau tests/run.luau` from the project folder, `LUAU` env override for the binary path).
- [ ] Run the tests; expect `1 passed, 0 failed`.
- [ ] Commit.

### Task 2: Balls catalog and round draw (pure)

**Files:**
- Create: `.../CursedDodgeball/Pure/Balls.lua`
- Test: `cursed-dodgeball/tests/Balls.test.luau`

**Interfaces:**
- Produces: `Balls.Defs: {[id]: {id, name, family, consumable, finalPool, speedMul, colour}}` for `Plain` plus the 12 launch balls from `balls.md`; `Balls.draw(roundIndex: number, rng: () -> number, exclude: {string}?) -> {string}` returning ball ids for the round (round 1: 4 Plain + 3 cursed, round 2: 1 Plain + 5 cursed, round 3: 4 cursed from the final pool), no duplicate cursed ids, excluding ids in `exclude`.

- [ ] Write tests: 12 cursed defs; round 1 draw has 7 entries with 4 `Plain` and 3 distinct cursed; round 2 has 6 with 1 Plain; round 3 has 4, none Plain, none `Paint`; `exclude` removes ids; a seeded rng gives a deterministic draw.
- [ ] Run; expect failure.
- [ ] Implement.
- [ ] Run; expect pass.
- [ ] Commit.

### Task 3: ShowState machine (pure)

**Files:**
- Create: `.../CursedDodgeball/Pure/ShowState.lua`
- Test: `cursed-dodgeball/tests/ShowState.test.luau`

**Interfaces:**
- Produces: `ShowState.new(config, rng) -> state`; `state:addPlayer(id)`, `state:removePlayer(id)`; `state:step(dt) -> events` where events is an array of `{type=..., ...}` with types `PhaseChanged {phase, round}`, `Eliminated {id, by}`, `GhostReturned {ghost, victim}`, `Cut {round, survivors}`, `Winner {id}`, `ShieldGained {id}`, `ShieldExpired {id}`, `FloodStarted {round}`, `BallsDrawn {round, ids}`; `state:hit(victimId, throwerId, nowStamp)`; `state:catch(catcherId, throwerId)`; `state:ghostThrowHit(ghostId, victimId)`; `state:ghostThrowSpent(ghostId)`; `state.phase` in `"Intermission" | "Round" | "Replay" | "Crowning"`; `state.round` 1..3; `state:roleOf(id)` in `"Live" | "Ghost" | "Spectator" | "Waiting"`; `state:liveCount()`; `state.timer` seconds left in the phase; `state.flood` boolean.
- Rules: Intermission needs `>= Config.Players.Min` to start, else the timer re-arms. Round ends at the cut (8, then 4) or when one live player remains in the final; at the cap the flood flag turns on and stays until the cut. With fewer than 6 players at show start, rounds are 2 (cut to 3, then final). Hit on a shielded player removes the shield, no elimination. Shield expires after `Config.Catch.ShieldSeconds`. A hit on a player who is not Live is ignored. Ghosts get `throwsLeft = 1` on entering the ring; `ghostThrowHit` swaps roles when `throwsLeft == 1` and the victim is Live, then sets `throwsLeft = 0` for the new Ghost's victim-turned-Ghost to 1 and the returning player to Live; `ghostThrowSpent` moves the Ghost to Spectator. Ghost swaps never trigger a cut. In the final, Ghosts are Spectators immediately. Two hits in one frame on the last two players: the one with the smaller `nowStamp` is eliminated first and the other is the winner.

- [ ] Write tests covering: intermission re-arm below 6; 20 players, round 1 runs until 8 remain then `Cut`; cap reached sets flood and `FloodStarted`; round 2 to 4; final to winner with `Winner` and `Crowning`; player removal mid-round counts toward the cut; shield blocks one hit and expires at 3 s; ghost one throw swap, second throw ignored, miss sends to Spectator; ghost hit never cuts; final has no ghosts; 5-player show collapses to two rounds; double hit on last two.
- [ ] Run; expect failure.
- [ ] Implement.
- [ ] Run; expect pass.
- [ ] Commit.

### Task 4: BallFlight math (pure)

**Files:**
- Create: `.../CursedDodgeball/Pure/BallFlight.lua`
- Test: `cursed-dodgeball/tests/BallFlight.test.luau`

**Interfaces:**
- Produces: `BallFlight.aim(origin, targetChest, charge01, config) -> {dir={x,y,z}, speed}` (straight line, speed lerps quick to charged by charge01, no lead); `BallFlight.step(pos, dir, speed, dt, gravity) -> newPos` (gravity is 0 for quick throws under 30 studs and `config.Throw.Gravity` otherwise, decided by caller); `BallFlight.segmentHitsSphere(p0, p1, centre, radius) -> boolean`; `BallFlight.catchWindow(charge01, config) -> seconds`; `BallFlight.validateThrow(claimedOrigin, serverPos, maxDist) -> boolean`.

- [ ] Write tests: aim returns unit dir toward target and speed 60 at charge 0, 110 at charge 1; step moves `speed*dt`; segment-sphere true when passing through, false when missing by more than radius; catch window 0.25 at 0 and 0.15 at 1; validateThrow false beyond maxDist.
- [ ] Run; expect failure.
- [ ] Implement.
- [ ] Run; expect pass.
- [ ] Commit.

### Task 5: Targeting (pure)

**Files:**
- Create: `.../CursedDodgeball/Pure/Targeting.lua`
- Test: `cursed-dodgeball/tests/Targeting.test.luau`

**Interfaces:**
- Produces: `Targeting.pick(cameraPos, cameraDir, candidates: {{id, pos}}, maxRange) -> id?` choosing the candidate with the smallest angle from `cameraDir` within `maxRange`; `Targeting.cycle(currentId, orderedIds) -> id` returning the next id with wraparound; `Targeting.order(cameraPos, cameraDir, candidates) -> {id}` sorted by angle.

- [ ] Write tests: pick chooses the centred candidate over a nearer off-axis one; out of range excluded; cycle wraps; order sorts by angle.
- [ ] Run; expect failure. Implement. Run; expect pass. Commit.

### Task 6: Remotes and ArenaBuilder (server)

**Files:**
- Create: `.../CursedDodgeball/Remotes.lua` (ReplicatedStorage)
- Create: `cursed-dodgeball/src/ServerScriptService/CursedDodgeball/ArenaBuilder.lua`

**Interfaces:**
- Produces: `Remotes.get(name) -> RemoteEvent` creating under `ReplicatedStorage.CursedDodgeball.Remotes` on the server, waiting on the client, names: `ShowEvent`, `ThrowRequest`, `CatchRequest`, `BallSpawn`, `BallState`, `TargetSync`, `Dodge`.
- Produces: `ArenaBuilder.build(config) -> arena` with `arena.Floor`, `arena.Kerbs[round]`, `arena.PitWalls`, `arena.Ring` (walkway part at pit top), `arena.Stands` folder, `arena.Tunnels`, `arena.Jumbotron` (part with SurfaceGui), `arena.FloorY`, `arena.RingY`, `arena.Centre: Vector3`, `arena:setRound(round)` which enables the kerb for that round, and `arena:spawnPointsCourt(n)`, `arena:spawnPointsRing(n)`, `arena:spawnPointsStands(n)` returning CFrames.

- [ ] Implement both. Verify with `bash scripts/luau-check.sh` on the files (no headless test; visual check in Studio).
- [ ] Commit.

### Task 7: ShowServer (server driver)

**Files:**
- Create: `.../ServerScriptService/CursedDodgeball/ShowServer.lua`
- Create: `.../ServerScriptService/CursedDodgeball/Main.server.lua`

**Interfaces:**
- Consumes: ShowState, Balls, ArenaBuilder, Remotes.
- Produces: `ShowServer.start(config)`; it steps ShowState on Heartbeat, mirrors events to clients over `ShowEvent` (`{type, ...}` tables), teleports characters on role changes (Live to court spawn, Ghost to ring, Spectator to stands, Waiting to stands), raises the Flood by scaling a paint Part inward at 2 studs/s, writes timer and live count to the jumbotron, respawns characters on Out without death (teleport, not Humanoid death), and exposes `ShowServer.state` and `ShowServer.arena` for BallServer.

- [ ] Implement. luau-check. Commit.

### Task 8: BallServer

**Files:**
- Create: `.../ServerScriptService/CursedDodgeball/BallServer.lua`

**Interfaces:**
- Consumes: BallFlight, Balls, ShowServer.state, Remotes.
- Produces: `BallServer.start(config, showServer)`; on `BallsDrawn` spawns ball Parts (sphere, colour from Balls.Defs, name `Ball_<n>`, attribute `BallId`) at the centre circle; pickup by touch when a Live player with no ball walks over an idle ball (network ownership to that player while idle); `ThrowRequest(ballName, targetUserId, charge01, clientStamp)` validated with `validateThrow` (max 6 studs) and a 0.3 s per-player cooldown, then the server steps the flight each Heartbeat with `segmentHitsSphere` against every Live player's HumanoidRootPart (radius 2.5) excluding the thrower until the first catch-window owner; a `CatchRequest(ballName)` within the catch window from a player the ball is about to hit resolves as catch; floor/wall contact ends the flight and makes the ball idle; balls outside the kerb roll back after 2 s; hold limit 8 s drops the ball; Ghost throws only accept `charge01 = 0` and plain balls, and use `ghostThrowHit`/`ghostThrowSpent`. Broadcasts `BallState` for client rendering: `{name, pos, dir, speed, state}`.

- [ ] Implement. luau-check. Commit.

### Task 9: Client movement kit

**Files:**
- Create: `cursed-dodgeball/src/StarterPlayer/StarterPlayerScripts/CursedDodgeball/Movement.client.lua`

**Interfaces:**
- Produces: sprint (hold Shift / touch button) at 1.5x while stamina > 0, stamina drain 4 s and refill 3 s, dodge (Q / touch button) 8 studs over 0.2 s in joystick direction with 0.25 bar cost and 0.8 s cooldown, one air dodge per jump reset on landing, stamina exposed on the character as attribute `Stamina` 0..1 and reported to the server over `Dodge` for the back strip. Sprint is cancelled while charging a throw (reads character attribute `Charging`).

- [ ] Implement. luau-check. Commit.

### Task 10: Client throwing, target picker and HUD

**Files:**
- Create: `.../StarterPlayerScripts/CursedDodgeball/Throwing.client.lua`
- Create: `.../StarterPlayerScripts/CursedDodgeball/HUD.client.lua`

**Interfaces:**
- Consumes: Targeting, BallFlight, Remotes.
- Produces: a bracket BillboardGui above the picked target (red in range, grey out), target picking on camera centre every frame with cycle on Tab / swipe right-half / tapping the bracket; throw on mouse 1 / touch button with hold to charge (sets `Charging` attribute), release sends `ThrowRequest`; catch on mouse 2 / touch button sends `CatchRequest` for the nearest incoming ball; local prediction renders the ball from `BallState`; HUD shows phase, timer, live count, round, stamina bar, hold timer ring, Ghost throws left.

- [ ] Implement. luau-check. Commit.

### Task 11: Client spectate camera

**Files:**
- Create: `.../StarterPlayerScripts/CursedDodgeball/Spectate.client.lua`

**Interfaces:**
- Produces: when role is Ghost or Spectator, a tap (C / touch button) cycles seat view, broadcast (fixed Scriptable camera at centre + 25 studs up, pitched 30 degrees), follow-ball (CameraSubject = most recently thrown ball), player cam (CameraSubject = next Live humanoid); resets to the player's own humanoid when role becomes Live.

- [ ] Implement. luau-check. Commit.

### Task 12: Install guide and Blender grey-box script

**Files:**
- Create: `cursed-dodgeball/INSTALL.md`
- Create: `cursed-dodgeball/blender/build_greybox.py`

- [ ] Write INSTALL.md (Rojo serve or copy-paste table like `docs/celebration-aura-install.md`, how to playtest with 6 players via Studio's local server). Write the Blender script that builds the pit, ring, stands and ball placeholders as one GLB for later art replacement.
- [ ] Run full tests and luau-check across `cursed-dodgeball/src`. Commit and push.
