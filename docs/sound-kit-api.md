# SoundKit API (for the live scripts and the celebration shows)

```lua
local Snd = require(game.ReplicatedStorage.FarmLasso.SoundKit)
```

Cues are named in `SoundCues` (docs/sound-pitch.md section 3.1 is the same table in prose); their files map to asset ids
in `SoundIds`. A cue with no id yet is silent and warns once. Everything is client-side; on the server every call is a
no-op, so shared modules can require the kit safely.

## One-shots

- `Snd.Play(name, o) -> handle | nil`. `o.At` = a BasePart, Attachment, Model or Vector3 for 3D (nil = 2D);
  `o.Volume` (x the cue's), `o.Pitch` (x the cue's random spread; a number or `{lo, hi}`), `o.Rate` (x playback speed,
  for time scaling), `o.Delay` (s), `o.Group` (override), `o.Cooldown` (override; default 40 ms per cue).
  Returns nil when silent, on cooldown or over budget. Variants round-robin and never repeat back to back.
- `Snd.Ladder("LuckImpact", tier, o)` plays `LuckImpact<tier>` clamped to the highest cue that exists
  (`LuckImpact1..4`, `Fanfare1..4`, `RareReveal1..7`).
- `handle:Stop(fade)`, `handle:SetVolume(v)`, `handle:SetPitch(p)`, `handle:SetRate(r)`.

## Loops

- `Snd.Loop(name, o) -> handle | nil`. Same `o` plus `o.K` (starting intensity) and `o.FadeIn` (s; default .25 or the
  cue's). Starts at a random position (cues with `RandomStart = false` start at 0).
- `handle:Set(k)`: 0..1 along the cue's `Curve` (`Pitch = {lo, hi}`, `Volume = {lo, hi}`), smoothed so a jittery input
  does not buzz. `handle:Stop(fade)` fades out (default 0; pass .2 to .4 for loops).
- `Snd.StopLoops(name, fade)` stops every loop of a cue (nil = all loops); `Snd.StopAll(fade)`.

## Groups and volumes

- Groups: `Master > Music, SFX (> UI, Celebration), Ambience`. Defaults: Music .45, SFX 1, UI .8, Celebration 1,
  Ambience .35 (`Snd.Defaults`).
- `Snd.SetVolume("Music", v)` / `Snd.GetVolume("Music")`: the player's slider (0..1), multiplied with the default.
  Setting `SFX` also sets `UI` and `Celebration`. `Snd.Volumes()` / `Snd.LoadVolumes(tbl)` for saving;
  `Snd.OnVolumeChanged(fn(name, v))`.
- `Snd.Duck("Music", level, hold, fade)` dips a group to `level` for `hold` seconds (down in .15 s, back over `fade`,
  default .6). Overlapping ducks keep the lowest level and the latest end. `Snd.DuckHold(name, level)` returns a
  release function.

## Budget and misc

- At most 24 one-shots (14 on touch) and 8 loops at once; the oldest one-shot or loop is dropped first.
- `Snd.Preload(names)` warms the cache (nil = every cue). `Snd.Has(name)` true when the cue has an id.
- `Snd.Mobile` (touch without a keyboard), `Snd.Cues`, `Snd.Ids`, `Snd.Cues.Species` (the 24 roster names).

## Writing a cue (SoundCues)

```lua
Throw = {File = "throw_whoosh", Volume = .8, Pitch = {.92, 1.08}},                 -- variants throw_whoosh_1.. found by SoundIds
TugLoop = {File = "tug_loop", Volume = .8, Loop = true, Curve = {Pitch = {.9, 1.3}, Volume = {.4, 1}}, FadeIn = .15},
StepGrass = {File = "step_grass", Volume = .25, Pitch = {.9, 1.1}, Min = 4, Max = 25, Cooldown = .08},
```

`File` defaults to the snake_case of the cue name. `Min` / `Max` are the 3D rolloff in studs (defaults 8 / 80), used only
when the cue is played with `At`. `Group` defaults to `SFX`.

# AuraSound API (for the celebration shows)

```lua
local S = require(script.Parent.Parent.AuraSound)   -- from a Shows/<Id>.lua
```

- `S.Cue(ctx, t, name, o)`: a one-shot at show time `t` (negative = charge-up), 3D at the player's feet (`ctx.Anchor`)
  or `o.At` (a part, attachment, Vector3, or a function returning one, evaluated at `t`). `o.Volume`, `o.Pitch`,
  `o.Cooldown`; `o.Local = true` only for your own show; `o.MinSet` skips below that set; `o.Chance` (0..1);
  `o.Air = true` marks a tail / shimmer (skipped on far shows, like the cues in AuraSound's AIR list).
- `S.Now(ctx, name, o)`: play immediately (inside OnExplode / OnU / an Every body). Returns the handle.
- `S.Loop(ctx, t0, t1, name, o)`: a loop between two beats (nil `t1` = until the show stops), returns a proxy with
  `:Set(k)`, `:SetRate(r)`, `:Stop(fade)` that work before and after the loop starts. Other players' shows: only one
  remote show at a time keeps loops.
- `S.Hit(ctx, t, "S" | "M" | "L", o)`: CelImpact; CelDetonate; CelDetonate + CelShockwave + CelShimmer.
- `S.Bed(ctx, t0, t1, o)`: the CelBed pad loop (own show only, skipped far away), returns the proxy.
- `S.Duck(ctx, t0, t1, music, ambience)`: Music / Ambience down (default .3 / .6) for the window; own show only.
- `S.ChargeUp(ctx)`: the inhale cue ending at t = 0 when the show has `ctx.Pre`.

Volume scales by `ctx.Quality` (1 own, .7 within 120 studs, .4 beyond); every live show sound follows `ctx.TimeRate`
(AuraKit.TimeScale sets it to its Scale and back to 1) and stops with the show.
