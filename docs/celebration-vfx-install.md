# Celebration VFX: install and tune

What this is: a code-driven, cinematic celebration aura for Farm Lasso's luck
reveal. Gold and rainbow lift the catcher into the air in a commanding pose,
surround them with orbiting crystals, gyro rings, wings, a galaxy underfoot, an
accretion ring overhead, a sky beam, lightning strikes and a flash-and-slash
peak, while the camera orbits them. Copper and silver get a ground burst, a
cheer pose and a title. Other players see a reduced aura on the catcher.

## Files

| Path in repo | Where it goes in Studio | Type |
|---|---|---|
| `blender/VFX_Pack.glb` | `ReplicatedStorage.FarmLasso.VFXMeshes` (Folder) | 20 MeshParts |
| `src/ReplicatedStorage/FarmLasso/VFX/VFXAssets.lua` | `ReplicatedStorage.FarmLasso.VFX.VFXAssets` | ModuleScript |
| `src/ReplicatedStorage/FarmLasso/VFX/VFXKit.lua` | `ReplicatedStorage.FarmLasso.VFX.VFXKit` | ModuleScript |
| `src/ReplicatedStorage/FarmLasso/VFX/CelebrationFX.lua` | `ReplicatedStorage.FarmLasso.VFX.CelebrationFX` | ModuleScript |
| `src/ReplicatedStorage/FarmLasso/VFX/CelebrationFloat.lua` | `ReplicatedStorage.FarmLasso.VFX.CelebrationFloat` | ModuleScript |
| `src/ReplicatedStorage/FarmLasso/VFX/CelebrationCamera.lua` | `ReplicatedStorage.FarmLasso.VFX.CelebrationCamera` | ModuleScript |
| `src/StarterPlayerScripts/CelebrationClient.client.lua` | `StarterPlayer.StarterPlayerScripts.CelebrationClient` | LocalScript |
| `src/ServerScriptService/CelebrationServer.lua` | `ServerScriptService.CelebrationServer` | ModuleScript |
| `blender/build_vfx_pack.py` | not needed in Studio | rebuilds the GLB in Blender |

## Install (about 10 minutes)

1. **Back up first**, per the project rule: copy `FarmLassoServer` into
   `ServerStorage.CelebrationBackup_YYYYMMDD` as `FarmLassoServer_old`, disabled.
2. **Import the meshes.** In Studio: File > Import 3D, pick `VFX_Pack.glb`.
   In the importer, set Scale Unit to **Studs**, leave "Merge Meshes" **off**,
   and import. It lands in Workspace as a Model with 20 MeshParts named
   `VFX_...`. Create a Folder `VFXMeshes` under `ReplicatedStorage.FarmLasso`
   and move all 20 MeshParts into it (names must stay as they are). Delete the
   empty import Model.
3. **Add the scripts.** Create a Folder `VFX` under `ReplicatedStorage.FarmLasso`
   and add the five ModuleScripts with the file contents above. Add the
   LocalScript to `StarterPlayerScripts` and the ModuleScript to
   `ServerScriptService`. Script Sync will pick the new scripts up and mirror
   them into the FarmLasso folder on disk.
4. **Wire the server.** In `FarmLassoServer`, at the point where the throw's
   `Tier` has been decided and the `Throw` event is sent, add:

   ```lua
   require(script.Parent.CelebrationServer).Fire(player, tier, {
       Mult = multiplier,   -- the final throw multiplier (2, 4, 10...)
       Animal = animalName, -- species being revealed, optional
   })
   ```

   Use the same local names FarmLassoServer already has for those values.
5. **Test.** Press Play. Hold Left Ctrl and press 7, 8, 9, 0 for copper,
   silver, gold, rainbow on yourself. Output must show no errors. Then test with
   two clients (Test > Clients and Servers, 2 players) to see the reduced aura
   on the other player. The Ctrl keys only work in Studio.
6. Save to Roblox and write the changelog
   (`claude/changelog-celebration-vfx.md`) in the project style.

If the meshes aren't imported yet the effect still runs: every mesh falls back
to a plain neon block and the Output shows one warning per missing mesh.

## What each tier does

| Layer | Copper | Silver | Gold | Rainbow |
|---|---|---|---|---|
| Ground shock rings | yes | yes | yes | yes |
| Sigil (magic circle) | 5 studs | 7 | 9 + rune ring | 12 + rune ring |
| Floor swirls | no | yes | yes | yes |
| Mist + sparkles + light | low | medium | high | highest, hue cycling |
| Float + pose | cheer only | cheer only | lift 4.2 studs | lift 6 studs |
| Camera orbit | no | no | 70 degree sweep | 95 degree sweep |
| Halo column + rising rings | no | no | 15 studs | 22 studs |
| Orbiting shard ring | no | no | 10 shards | 10 shards + 8 crystals |
| Gyro rune rings + spiked crown | no | no | 2 rings + crown | 3 rings + crown |
| Peak flash + slashes + stars | small | medium | large + god rays | huge + god rays |
| Wings | no | no | yes | yes, larger |
| Galaxy disc underfoot | no | no | no | yes |
| Accretion ring + dark core | no | no | no | yes |
| Sky beam + lightning strikes | no | no | no | yes (local view only) |
| Title | NICE! | SILVER! | GOLDEN! | LEGENDARY!!! |

Reduced mode (what others see): half the shards, stars and slashes, no flash,
no sky beam, no bolts, smaller title, no camera change.

## Tuning knobs

- `VFXAssets.Durations`: hold per tier. Keep in step with `Config.Celebrations`
  and `s.FlightEnd` in the game; the aura's peak is at 30% and settle at 85%.
- `VFXAssets.Palettes`: colours per tier. Rainbow ignores Primary/Secondary/Accent
  and cycles hue; `Hot` is the flash colour.
- `VFXAssets.Titles`: the two-line title per tier. The server's `Mult` and
  `Animal` override the second line.
- `CelebrationFloat`: `maxHeight` (6 / 4.2), rise ends at 30%, landing starts
  at 86%. Pose angles are at the bottom of the `Stepped` handler.
- `CelebrationCamera`: distance, height, sweep and the FOV punch (22) are the
  `Options` plus the constants in `Peak`.
- `CelebrationFX`: every layer has its sizes in a `{ copper, silver, gold,
  rainbow }` table at the top of the layer. Bolt cadence is in `layerBolts`
  (0.28 to 0.48 s).

## How it respects the project rules

- Animation is code: Motor6D.Transform on `Stepped`, parts moved on
  `RenderStepped`, no uploaded animations.
- Network stays quiet: one small RemoteEvent per throw; all visuals are local
  and live under the camera so nothing replicates.
- Screen shake and the FOV punch are reserved for gold and rainbow.
- FarmLassoClient is not touched; the new client script is separate.
- No night-time assumptions. No external asset ids (textures are Roblox
  built-ins; meshes are your own import).

## Rebuilding the meshes

`blender/build_vfx_pack.py` builds all 20 meshes procedurally. Run it in
Blender 4.x or 5.x (`blender --background --python build_vfx_pack.py`) and
export as glTF 2.0 (.glb). Each piece is a separate white mesh at the origin,
sized in studs.
