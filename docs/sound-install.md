# Installing the sound pack (Monster game)

Everything new sits beside what is there: three ModuleScripts under `ReplicatedStorage.FarmLasso`, one under
`CelebrationFX`, one LocalScript, the 12 show modules updated with cues, and a two-line patch in `AuraKit`. Nothing on
the server changes unless you want the volume sliders saved (step 6). The game runs with a half-uploaded pack: a cue
whose files have no id yet is silent and warns once in Output.

## 1. Back up

Copy `ReplicatedStorage.FarmLasso.CelebrationFX` (with children) into `ServerStorage.SoundBackup_20261007` as
`CelebrationFX_old`. Nothing else that exists is patched.

## 2. Upload the pack

The files are in `audio/pack/*.ogg` (187 files, 3.3 MB, all 32 s or shorter). Upload them as Audio assets: Creator Dashboard >
Development Items > Audio > Upload (multi-select works; keep the file names), or Studio's Asset Manager > Audio.
Audio you upload to your own account or group is usable in your own experiences without extra permissions.

Then paste the ids: open `src/ReplicatedStorage/FarmLasso/SoundIds.lua`, one line per file, and set each
`"rbxassetid://<id>"`. Use the asset id shown on the Audio page. The `audio/pack/manifest.json` lists every file
with its cue and length if you want to upload a subset first (the lasso loop, UI and footsteps make the biggest
difference; the celebrations can follow).

Tip: in the Creator Dashboard, the Audio list can be exported to CSV; a short script that joins file names to ids is
quicker than pasting 187 lines by hand. Keep the ids pasted in: `audio/build_sfx_pack.py --lua` regenerates the file
and preserves every id already there.

## 3. Scripts (Script Sync folder `FarmLasso\`)

Copy from `src/`:

| File | Studio object |
|---|---|
| `ReplicatedStorage/FarmLasso/SoundKit.lua` | new ModuleScript `SoundKit` under `ReplicatedStorage.FarmLasso` |
| `ReplicatedStorage/FarmLasso/SoundCues.lua` | new ModuleScript `SoundCues` under `ReplicatedStorage.FarmLasso` |
| `ReplicatedStorage/FarmLasso/SoundIds.lua` | new ModuleScript `SoundIds` under `ReplicatedStorage.FarmLasso` (with your ids) |
| `ReplicatedStorage/FarmLasso/CelebrationFX/AuraSound.lua` | new ModuleScript `AuraSound` under `CelebrationFX` |
| `ReplicatedStorage/FarmLasso/CelebrationFX/AuraKit.lua` | replaces `AuraKit` (two lines in `K.TimeScale`: `ctx.TimeRate`) |
| `ReplicatedStorage/FarmLasso/CelebrationFX/Shows/<Id>.lua` | replaces each of the 12 show modules (sound cues added, visuals unchanged) |
| `StarterPlayer/StarterPlayerScripts/GameSounds.client.lua` | new LocalScript `GameSounds` under `StarterPlayerScripts` |

With Script Sync, dropping the files in creates the objects; choose "Keep Disk" for these. Don't add attributes or
tags to the scripts (Script Sync drops them).

GameSounds works on its own: music, ambience, the fountain, random animal calls, herd joins (it watches the `Herd`
attribute on the player and the character), footsteps for every character, hover / click / open / close / tab on every
button and panel, selling (a RemoteEvent named `Sold`, or `Event` with `"Sold"` as its first argument), quest flashes
(a BindableEvent named `QuestFlash`) and the settings panel (the note button bottom-left; move it with the
`ButtonPosition` attribute on the `SoundSettings` ScreenGui).

## 4. The lasso loop: one-line hooks in FarmLassoClient

The kit cannot see the meter or the fight, so FarmLassoClient fires these. Put
`local Snd = require(ReplicatedStorage.FarmLasso.SoundKit)` at the top (inside a `(function() ... end)()` block if the
script is at its local limit; `Snd` can also be fetched where needed with `require(...)`). Then, in the existing
handlers:

| Where (what the code already does) | Add |
|---|---|
| charge starts (the meter begins to fill) | `s.ChargeSnd = Snd.Loop("LassoCharge")` |
| every frame while charging, with the charge 0..1 | `if s.ChargeSnd then s.ChargeSnd:Set(charge) end` |
| the charge crosses into a zone (x1.5 / x2 / x4) | `Snd.Play("MeterGood")` / `"MeterPerfect"` / `"MeterMega"` |
| release (the throw starts); `mult` is the meter multiplier | `if s.ChargeSnd then s.ChargeSnd:Stop(.15) s.ChargeSnd = nil end` then `Snd.Play(mult >= 4 and "StingMega" or mult >= 2 and "StingPerfect" or mult >= 1.5 and "StingGood" or "Throw")` and `Snd.Play("Throw")` (always) and `if mult >= 2 then Snd.Play("ThrowBig") end` |
| the rope reaches the animal | `Snd.Play("RopeLand", {At = animalPart})` |
| each luck-reveal tick (the number climbing); `i` = tick index, `n` = total | `Snd.Play("LuckTick", {Pitch = 1 + i / n})` |
| the reveal lands (`s.FlightEnd`) with `s.Tier` 1..4 | `Snd.Ladder("LuckImpact", s.Tier)` then `Snd.Ladder("Fanfare", s.Tier, {Delay = .15})` and `Snd.Duck("Music", .5, 3)` |
| the animal is hooked (fight starts) | `Snd.Play("Hooked", {At = animalPart})` then `s.TugSnd = Snd.Loop("TugLoop")` |
| each tap in the tug-of-war | `Snd.Play("TugTick")` |
| every frame of the fight, with the catch meter 0..1 | `if s.TugSnd then s.TugSnd:Set(fill) end` and, while draining (no tap for .12 s and fill < .35), `Snd.Play("TugDanger")` (its cooldown spaces it) |
| catch succeeds; `rarity` 1..7 | `if s.TugSnd then s.TugSnd:Stop(.1) s.TugSnd = nil end` `Snd.Play("CatchPop")` `Snd.Play("CatchChime", {Delay = .12})` `Snd.Ladder("RareReveal", rarity, {Delay = .3})` |
| the animal escapes / times out | `if s.TugSnd then s.TugSnd:Stop(.1) s.TugSnd = nil end` `Snd.Play("Escape")` |
| the bag is full (a throw or catch refused for capacity) | `Snd.Play("BagFull")` |
| sell (if the client handles the button rather than the `Sold` event) | `Snd.Play("SellShower")` `Snd.Play("SellDing", {Delay = 1.1})` |

Shop and quest screens (LassoClient3D, QuestLassoClient): the generic button hook already plays `Buy`, `Equip`,
`NoCoins` (grey Need pills), `QuestComplete` (Claim) and `TabSwitch` from the pill text. If a purchase is refused by the
server after the click, add `Snd.Play("NoCoins")` in the refusal handler; on a quest step completing add
`Snd.Play("QuestTick")`; on a quest accepted `Snd.Play("QuestAccept")`.

Hook the animal's sound at the animal: pass its PrimaryPart as `At` so the rope land, the hook and the species call
come from where it stands. The species call on a hook: `GameSounds` plays it when the `Herd` attribute grows; for the
hook moment itself add `Snd.Play("Animal" .. species:gsub("%s", ""), {At = animalPart, Pitch = 1.2})` next to
`Hooked` (the cue names are `Animal` + the roster name without spaces; unknown species: `AnimalGeneric`).

## 5. Test

- Output must show no `[SoundKit]`, `[AuraSound]` or `[GameSounds]` errors. `[SoundKit] X: no asset id pasted` warnings
  mean step 2 is incomplete for that cue.
- Walk on grass, the cobbles and a porch: three different footsteps. Open the shop: PanelOpen; hover and click the
  pills; a grey Need pill buzzes.
- Set workspace attribute `LassoTestMult = 4` and catch an animal: charge loop rising, the mega sting, the throw,
  rising luck ticks, the rainbow impact and fanfare, the hook with the species call, the tug loop with ticks and the
  danger cue when you stop tapping, the pop, chime and rarity reveal.
- LOADOUT > a celebration > TRY: the inhale, the detonation, the show's signature sounds, the landing; music dips and
  comes back. Stand next to another player's show: it is quieter and has no bed.
- The note button bottom-left opens the sliders; drag them and the groups follow at once.

## 6. Saving the sliders (optional, server)

GameSounds reads the `SoundVolumes` attribute on the Player (a JSON string like `{"Music":0.5,"SFX":1,"Ambience":0.4}`)
and fires `ReplicatedStorage.FarmLasso.SoundSettings` (a RemoteEvent) with a table when a slider moves. To persist:

1. Add a RemoteEvent named `SoundSettings` under `ReplicatedStorage.FarmLasso`.
2. In `FarmLassoData`, add `SoundVolumes = ""` to the default profile (a new field needs its patch there, as the
   skill says) and on load `player:SetAttribute("SoundVolumes", profile.SoundVolumes or "")`.
3. In `FarmLassoServer` (or a tiny new Script):

```lua
local HttpService = game:GetService("HttpService")
ReplicatedStorage.FarmLasso.SoundSettings.OnServerEvent:Connect(function(player, tbl)
	if type(tbl) ~= "table" then return end
	local clean = {}
	for _, k in {"Music", "SFX", "Ambience"} do clean[k] = math.clamp(tonumber(tbl[k]) or 1, 0, 1) end
	local raw = HttpService:JSONEncode(clean)
	player:SetAttribute("SoundVolumes", raw)
	Data.Set(player, "SoundVolumes", raw) -- however FarmLassoData writes a field
end)
```

Until then the sliders hold for the session.

## 7. Tuning knobs

- Per-cue loudness and pitch spread: `SoundCues` (never in the files).
- Group defaults and the voice budget: the top of `SoundKit` (`K.Defaults`, `K.MaxOneShots`, `K.MaxLoops`).
- Celebration levels and what far shows skip: `AuraSound` (`AIR` list) and the `o.Volume` on each cue in the shows.
- Footstep stride (3.6 studs), the ambient call interval (8 to 20 s, 60 studs) and the panel threshold (15 percent of
  the screen) at the top of each block in `GameSounds`.
- The pack itself: `audio/recipes_*.py`, re-rendered with `python3 -I audio/build_sfx_pack.py` (deterministic).
