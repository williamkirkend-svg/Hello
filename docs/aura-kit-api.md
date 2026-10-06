# AuraKit API (for writing a celebration show)

A show lives at `src/ReplicatedStorage/FarmLasso/CelebrationFX/Shows/<Id>.lua` and returns

```lua
return {Pre = 1.0, Set1 = function(ctx, def) ... return LEN end, Set2 = ..., Set3 = ...}
```

`ctx` is the CelebrationFX context (see `CelebrationFX.lua`); `def` is the catalog entry (`def.Id`, `def.Name`, `def.Colors[1..3]`). Each builder schedules everything with `ctx:At`, `ctx:Repeat`, `ctx:Every` and returns its length in seconds. Set 3 gets `Pre` seconds of charge-up before t = 0: during it `t` is negative (so `ctx:At(-0.6, fn)` works) and `K.ChargeUp` draws the inhale. Set 1 is 2 to 3 s and must not move the camera, flash the screen or touch the world. Set 2 is 4 to 6 s. Set 3 is 7 to 9 s.

Load the kit with `local K = require(script.Parent.Parent.AuraKit)` and the toolkit with `local FX = require(script.Parent.Parent.Parent)` (CelebrationFX). Shows must never require Free, Premium, Spectacle, Tiers or AuraAccents.

## ctx (CelebrationFX toolkit)

- `ctx.Base` CFrame at the feet (follows the character), `ctx.Hrp`, `ctx.Char`, `ctx.Hum`, `ctx.Folder` (everything you create goes here), `ctx.Local` (true for your own show), `ctx.Quality` (1 own, .7 / .4 others), `ctx.Set` (1-3), `ctx.Pre`, `ctx.Def`.
- `ctx:At(t, fn)`, `ctx:Repeat(t0, t1, period, fn(i))`, `ctx:Every(fn(t, dt))` (return true to stop), `ctx:Elapsed()`.
- `ctx:Part(props)` anchored Neon part; `ctx:Ring(kind, d, thick, color, tr)` ring union ("Ring", "RingThin", "RingFat", "Arc"; axis X, `* FX.FLAT` lays it flat); `ctx:Att(cfOrVec3, parent)`.
- `ctx:Emitter(parent, props)` ParticleEmitter with LightEmission 1, Rate 0 by default; props accept plain tables for Size/Transparency/Color/Lifetime/Speed/SpreadAngle (`{a, b}` or `{{t, v}, ...}`), plus `Brightness`.
- `ctx:Disc(att, props)` a flat sticker particle; `ctx:Light(att, color, range, bright)`; `ctx:Beam(a0, a1, props)`; `ctx:Bolt(n, width, color) -> set(p0, p1, jag, tr), parts`.
- `ctx:Streak(pathFn(u) -> Vector3, dur, color, width, life)` a trail flown along a path; `ctx:Flare(posOrAtt, size, color, life)` a four-point flare billboard; `ctx:Burst(pos, count, props)`; `ctx:Ripple(cf, d0, d1, color, life, tex)`.
- Screen (own show only, no-ops otherwise): `ctx:Flash(color, alpha, dur)` (throttled), `ctx:ImpactFrame()` (manga frame), `ctx:Grade(props, tIn, hold, tOut)` ColorCorrection, `ctx:Shake(amp, dur)`.
- `ctx:Title(at, height)` the celebration name above the head (use `K.Title` for the themed version).
- `FX.ease(x)`, `FX.back(x)` (overshoot), `FX.Tween(obj, t, props, style, dir)`, `FX.cseq`, `FX.nseq`, `FX.T.*` engine textures, `FX.W` white, `FX.FLAT`, `FX.rng`.

## K (AuraKit)

Maths and queries
- `K.Ease`, `K.Back`, `K.Env(t, a, b, rise, fall)` (grow in with overshoot, fade out by b), `K.Soft` (no overshoot), `K.Flap(t, period)` (snap-down / ease-up 0..1), `K.Polar(a, r, y)`, `K.RandUnit()`, `K.Bezier(p0, p1, p2, u)`, `K.Behind(ctx)` flat direction away from the camera, `K.Count(ctx, n)` quality-scaled count, `K.Palette(def) -> c1, c2, c3, dark`.
- `K.Ground(ctx, pos) -> pos, normal`, `K.GroundCF(ctx, pos, lift)` a CFrame lying on the ground (UpVector = normal).
- `K.NearbyPlayers(ctx, r)`, `K.NearbyAnimals(ctx, r)`, `K.Targets(ctx, count, r)` (players, then animals, then orbit points; each `{Part, Model, Kind}` or `{Pos, Kind = "point"}`), `K.TargetPos(tg, y)`, `K.NearbyProps(ctx, r, n)` anchored prop parts (fence posts, lanterns).
- `K.Tex.<Name>` texture id with engine fallback: Glow, Ring, Flame, Streak, Star, Petal, Lightning, Smoke, Arc, Crack, Sigil, Nebula. `K.Flipbook(emitter, "Lightning" | "Smoke", mode, fps)` only applies when the painted sheet is uploaded.

Meshes
- `K.Mesh(ctx, name, props)` clones VFX2_<name> (or VFX_<name>, or a stand-in Part). Names: WingUpper/Fore/Primaries (+L), Feather, WingSilhouette, FlamePetalFan, FlamePetal, SunDisc, ScorchRing, ShardChunk, ShardSliver, RiftLip, RiftVoid, GhostWisp, ClockRing, ClockHand, ClockHandShort, TickSigil, Numeral, GlassShard, Hourglass, CrackA/B/C, Cobble, GrassClump, HayStraw, CloudLobe, LightningBull, TornadoRing, Coin, RibbonTwist, StarPoint, PlanetRinged, LassoLoop, Constellation, LightStep, HaloCrystal, PrismCrystal, Gem, CherryTrunk, Canopy, Lotus, FlowerCrown, LotusPetal, SpikeCrown, IceSpike, IceSpikeCluster, AccretionDisc, LensSphere, PortalFrame; v1: GalaxyArm, GalaxyCore, AccretionRing, ShockRing, HaloRing, RuneRing, Sigil, ShardA/B/C, OrbitCrystal, Slash, BoltA/B, StarShard, GodRay, BeamColumn, Swirl, Wing, SpikeHalo.
- `K.Release(part, dur)` ends a kit stamp early (fade, destroy). `K.Place(part, cf, scale)` sizes (number or Vector3) and puts the mesh's authored origin at cf. Axes after import: a thing authored "up" is +Y; a thing authored "along its length" (cracks, clock hands, petals, lotus petal) runs along -Z (the LookVector); wings extend +X (right) / -X (the L meshes); flat discs lie in the XZ plane with +Y as their normal.
- `K.HasMesh(name)`, `K.Ring(ctx, kind, d, thick, color, tr)`, `K.SetRing(ring, d)`.

Hits and bursts
- `K.FOV(ctx, delta, tIn, tOut, hold)` own camera only. `K.Hit(ctx, pos, {Colors, Impact = true, Flash, Shake, FOV, Ring, Burst, Lines})` the combined hard hit. `K.Starburst(ctx, pos, {Colors, Size, Count})` radial streak lines + core + ring, gone in .3 s. `K.PetalFan(ctx, cf, {Colors, Radius, Life})` the two-frame flat petal pop (cf UpVector = fan normal). `K.ShockRing(ctx, cf, d0, d1, color, life, thick)` an expanding ring mesh on a plane.

The performer (the body)
- `local P = K.Performer(ctx)` a client-side double of the character; `P:Show()` hides the real one and shows the double (do this before posing or moving it; `K.ChargeUp` shows it for you). `P:Pivot(cf)` moves it (stops following), `P:Toward("Crouch" | "Star" | "Wide" | "FistUp" | "Fly" | "Kneel" | "Hang" | "Pulled" | "Whirl" | "Rider" | "Punch" | "Freeze", k)` blends a pose every frame, `P:Pose({RightShoulder = CFrame.Angles(...), ...}, k)` a custom one (R15 joint names: Neck, Waist, RightShoulder, LeftShoulder, RightElbow, LeftElbow, RightHip, LeftHip, RightKnee, LeftKnee), `P:Visible(bool)`, `P:SetTransparency(tr)`, `P:Silhouette()` (black), `P:RestoreLook()`, `P.Torso`, `P.Head`, `P.RightHand`, `P.LeftHand`, `P.Root`, `P.Parts`. It releases itself with the show.
- `K.Float(ctx, P, {T0, T1, Height, Rise, Fall, Spin, Pose, PoseK, OnK(k, t)})` lift, hover with a bob, come down.
- `K.Fly(ctx, P, {T0, T1, Path = fn(u) -> Vector3, Bank, Pitch, Pose, OnU(u, pos, tangent, cf), OnDone, EaseU})` fly a path, heading on the tangent, banking into turns.
- `K.Shatter(ctx, P, {At, Colors, Chunks, Spread, Reform, ReformCF, FanRadius, OnExplode(origin), OnReform})` explode into chunks with trails, retrace, reveal chest-first.
- `K.Wings(ctx, P, {Span, Colors, Unfold, Fold, Flap = period, Flame, Style = "feather" | "constellation"}) -> Wg` (`Wg.Flap` 0..1 stroke phase, `Wg.K` open amount, `Wg:Dissolve(dur)`).
- `K.Echo(ctx, P, {Count, Delay, Color, Transparency, T0, T1})` past copies trailing the double.

Things that come out and touch the world
- `K.Seek(ctx, {Mesh | Build(ctx, i), Scale, Colors, Count, Interval, T0, From = pos | fn(i), Radius, Speed, Trail, Light, Circle, Height, Return, Wobble, OnTouch(tg, pos), OnSpawn(part, i), Targets = list}) -> Sk` (`Sk.Parts`, `Sk:Freeze()`) seekers that fly to other players, then animals, circle, phase through (Highlight flicker), dissolve, optionally streak home.
- `K.Herd(ctx, {At, Radius, Color, Flavour = "flinch" | "bolt" | "freeze" | "bounce" | "lookup", Max, Stagger, Ring, Effect(tg)})` the herd reacts.
- `K.Cracks(ctx, {At, Count, Len, Color, Life, Radius, Stagger})` ground cracks. `K.Debris(ctx, {At, Count, Radius, Lift, Centre = fn, Orbit, Until, Meshes, Color, Stretch})` loose props lift, orbit, drop. `K.Stamp(ctx, pos, {Mesh, Color, Scale, Life, Material, Transparency, Rise, OnAge(m, age)})` a ground stamp.
- `K.TimeScale(ctx, {T0, T1, Radius, Scale})` slow the world (own show only). `K.LightPaint(ctx, {At, Radius, Color, Hold, Boost, Highlight})` every light swings to the colour, props flash (own show only). `K.Chain(ctx, {At, From, Radius, Count, Color, Stagger})` chain lightning to props.
- `K.Skin(ctx, {Color, Lightning, T0, T1})` plasma skin. `K.Sheets(ctx, {Colors, T0, T1, Rate})` tall flame sheets on the body. `K.Sweeps(ctx, {Colors, T0, T1, Period, Radius, Height, Climb, Dur, Width, Life})` arc trails that orbit and fly off. `K.Cage(ctx, {Colors, T0, T1, Radius, Height, Rate}) -> {Burst()}` the vertical streak cage. `K.Monument(ctx, {Mesh, Height, Tilt, Face = "camera", Scale, Color, In, Out, Spin, Behind, Material, Transparency, Light}) -> {Part, Pos()}` a big mesh in the sky.
- `K.ChargeUp(ctx, P, {Sigil, SigilScale, Pose, PoseK})` the shared inhale before t = 0 (call it first in Set 3). `K.Title(ctx, at, "embers" | "glitch", height)`. `K.Rewind(ctx) -> R` (`R:Track(part)`, `R:TrackAll(list)`, `R:Play(speed, onDone)`). `K.Window(ctx) -> fn(pos) -> 0..1` fade factor for things crossing the chest.

## Rules

1. One hero at a time. Sequence: build (0 to 15 %), detonate, the new silhouette, the signature moment near 60 to 70 %, settle. The previous hero fades to half as the next arrives.
2. The player stays visible: floor, back plane (1.5 studs behind the torso), orbit shell (4 studs or more), crown (1.5 studs above the head). Nothing persistent within 2 studs of the torso unless it is at least 40 percent transparent. Full-screen flashes at most 3 frames (`ctx:Flash` is already throttled).
3. White core, theme colours in the middle, the dark colour (`K.Palette`'s fourth value) on the rim: smoke, soot, outer rings.
4. Counts through `K.Count`; per-frame work only in `ctx:Every`; never create instances inside `ctx:Every` except through kit helpers that destroy themselves. Keep emitters under 10 per burst and 6 persistent.
5. Reduced shows (`ctx.Local == false`) keep the body, wings, seekers and the sky piece; the kit already skips camera, Lighting and time effects for them.
6. End every builder with the settle: things fade with `FX.Tween(part, t, {Transparency = 1})` or by the kit's own envelopes, `K.Title` at the right moment, and `return LEN`. Set 3 LEN excludes the charge-up (CelebrationFX adds Pre).
7. Nothing in a show may require Free, Premium, Spectacle, Tiers or AuraAccents, touch the server, or move the real character.
