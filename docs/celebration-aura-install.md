# Installing the Aura celebration upgrade (Monster game)

Everything lives under the existing `ReplicatedStorage.FarmLasso.CelebrationFX` ModuleScript. Nothing on the server
changes; `CelebrationClient`, `Celebrations` and the sets-by-rarity logic are untouched. Celebrations without a show
module keep playing the old builders, so you can install one at a time and compare.

## 1. Back up

Copy `ReplicatedStorage.FarmLasso.CelebrationFX` (with all its children) into `ServerStorage.CelebrationAuraBackup_20261006`
and rename the copy `CelebrationFX_old` (disable nothing: ModuleScripts are inert until required).

## 2. Meshes

1. In Studio: Avatar tab (or File) > 3D Importer > `blender/Aura_Pack.glb`. Import as a Model with "Rig type: None",
   scale 1, keep the object names (54 MeshParts named `VFX2_*`).
2. Move every `VFX2_*` MeshPart into a new Folder named `AuraMeshes` under `ReplicatedStorage.FarmLasso.CelebrationFX`
   (the GLB import makes a Model; a Model works too, but a Folder keeps things tidy).
3. Keep the v1 folder `ReplicatedStorage.FarmLasso.ClaudeCelebrationPreview.VFXMeshes` where it is: the shows still use
   GalaxyArm, GalaxyCore, GodRay and the rings from it. If you moved it, put it at `ReplicatedStorage.FarmLasso.VFXMeshes`.
4. Nothing breaks without the meshes: AuraKit prints one warning per missing mesh and uses a plain Neon Part instead.

## 3. Textures (optional but recommended)

Upload the 12 PNGs in `textures/` as Decals (Creator Dashboard > Development Items > Decals, or Studio's Asset Manager).
For each, open it, copy the **image** id (the Decal's underlying image id; the Asset Manager shows it as the Texture
property once inserted) and paste it as `"rbxassetid://<id>"` into `CelebrationFX.AuraTextures`. Flipbooks need the
image id, not the decal id. Until an entry is filled in, the kit uses the engine's built-in particle textures.

## 4. Scripts (Script Sync folder `FarmLasso\ReplicatedStorage\FarmLasso\`)

Copy from `src/ReplicatedStorage/FarmLasso/`:

| File | Studio object |
|---|---|
| `CelebrationFX.lua` | replaces the source of `CelebrationFX` (only `Play` changed: the show dispatch; see the diff) |
| `CelebrationFX/AuraKit.lua` | new ModuleScript `AuraKit` under `CelebrationFX` |
| `CelebrationFX/AuraMeshData.lua` | new ModuleScript `AuraMeshData` under `CelebrationFX` |
| `CelebrationFX/AuraTextures.lua` | new ModuleScript `AuraTextures` under `CelebrationFX` |
| `CelebrationFX/Shows.lua` | new ModuleScript `Shows` under `CelebrationFX` |
| `CelebrationFX/Shows/<Id>.lua` | one ModuleScript per celebration Id under `Shows` (12) |

With Script Sync, dropping the files into the synced folder creates the objects. Choose "Keep Disk" for these new files
and for `CelebrationFX.lua`.

## 5. Test

Open LOADOUT, pick a celebration, TRY plays Set 3 (the preview camera). Forced throws: set workspace attribute
`LassoTestMult = 4` and catch an animal; the caught animal's rarity picks the set (Common to Rare = Set 1 on rainbow
throws only, Epic / Legendary = Set 2, Mythic / Secret = Set 3). Output must show no `[CelebrationFX]` or `[AuraKit]`
errors; `[AuraKit] mesh ... not imported` warnings mean step 2 is incomplete.

Mobile: counts drop automatically (K.Mobile); if a show stutters on a phone, lower `Rate` values in the show or
cut `Count` in its `K.Seek` / `K.Debris` calls.

## 6. Tuning knobs

- Set length: each show's `LEN` per set, and `Pre` (the charge-up) at the top of the file.
- Camera: unchanged (`CelebrationClient.showcase`); the showcase already fits 12 s.
- Visibility: `K.Window(ctx)` is available for any orbiter that crosses the chest; the shows keep orbiters at 4 studs or more.
- Palette: the catalog colours in `Celebrations.lua` drive everything; `K.Palette` derives the dark rim.
