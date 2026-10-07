# Installing the Cursed Dodgeball grey-box (Phase 1)

This is a standalone experience, not part of Farm Lasso. Create a new empty place in Studio.

## Option A: Rojo

1. Install Rojo (`cargo install rojo` or the VS Code extension) and the Rojo Studio plugin.
2. From this folder run `rojo serve default.project.json` and connect from Studio.
3. The tree maps `src/ReplicatedStorage/CursedDodgeball`, `src/ServerScriptService/CursedDodgeball` and `src/StarterPlayer/StarterPlayerScripts/CursedDodgeball`.

## Option B: copy and paste (same style as the Farm Lasso install guide)

| File | Studio object |
|---|---|
| `src/ReplicatedStorage/CursedDodgeball/Config.lua` | ModuleScript `Config` in Folder `ReplicatedStorage.CursedDodgeball` |
| `src/ReplicatedStorage/CursedDodgeball/Remotes.lua` | ModuleScript `Remotes` in the same folder |
| `src/ReplicatedStorage/CursedDodgeball/Pure/Balls.lua` | ModuleScript `Balls` in Folder `CursedDodgeball.Pure` |
| `src/ReplicatedStorage/CursedDodgeball/Pure/ShowState.lua` | ModuleScript `ShowState` in `Pure` |
| `src/ReplicatedStorage/CursedDodgeball/Pure/BallFlight.lua` | ModuleScript `BallFlight` in `Pure` |
| `src/ReplicatedStorage/CursedDodgeball/Pure/Targeting.lua` | ModuleScript `Targeting` in `Pure` |
| `src/ServerScriptService/CursedDodgeball/ArenaBuilder.lua` | ModuleScript `ArenaBuilder` in Folder `ServerScriptService.CursedDodgeball` |
| `src/ServerScriptService/CursedDodgeball/ShowServer.lua` | ModuleScript `ShowServer` in the same folder |
| `src/ServerScriptService/CursedDodgeball/BallServer.lua` | ModuleScript `BallServer` in the same folder |
| `src/ServerScriptService/CursedDodgeball/Main.server.lua` | Script `Main` in the same folder |
| `src/StarterPlayer/StarterPlayerScripts/CursedDodgeball/*.client.lua` | one LocalScript each (`Movement`, `Throwing`, `HUD`, `Spectate`) in Folder `StarterPlayerScripts.CursedDodgeball` |

One thing to change by hand: `ShowState.lua` requires `./Balls` so the headless tests can run. In Studio that line must be `require(script.Parent.Balls)`. Rojo users can leave it: Rojo does not rewrite requires either, so change it in the source and keep the test runner happy by setting `LUAU_STUDIO_REQUIRE=1`... simpler: edit the one line after pasting. (Tracked as a follow-up to make both styles work.)

## Playtesting

- Studio: Test tab, Clients and Servers, set players to 6 or more (the show needs `Config.Players.Min`), Start.
- Game Settings: set max players to 20. Disable the default character reset on death; outs are teleports, not deaths.
- Controls: WASD, Shift sprint, Q dodge (also in the air), mouse 1 hold-to-charge throw, mouse 2 or F catch, Tab cycle target, C cycle spectator camera. Touch buttons appear on phones.
- What to look at first: the feel of the 8-second hold, the 0.25 s catch press, dodge reads, and whether 20 players on the 70 by 50 court is crowded enough.

## Tests and lint

```
bash scripts/test.sh                      # headless Luau tests for the pure modules
LUAU_ANALYZE=<path>/luau-analyze bash ../scripts/luau-check.sh src/**/*.lua
```
The Luau binaries come from https://github.com/luau-lang/luau/releases (luau-ubuntu.zip).
