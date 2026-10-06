# Roblox VFX technique notes (from the research agent, 2026-10-06)

## Reference frame anatomy
- aura_blue: 3-4 tall flame-sheet emitters on the HRP (VelocityParallel, tall torn-streak texture, positive Squash); 2-3 sweeping arcs = Trails on attachments orbiting the character; body lightning = 4x4 flipbook emitter on UpperTorso (Shape Box, Surface, ZOffset .5); floor pool = one big soft-glow flat particle plus a hard ring texture; PointLight + ColorCorrection tint.
- starburst: radial streak lines = Sphere/Surface/Outward, VelocityParallel, Speed 80-150, Lifetime .15-.3, Size 15-30; ring texture emitted once, scaled 0->25 in .2 s; white core; all LightEmission 1.
- shards: petal/triangle textures, Sphere Surface Outward, Speed 30-50, Drag 4 (burst then hang), RotSpeed +-300, Lifetime 1-2.
- pickup_b: vertical streak cage = Cylinder Surface, EmissionDirection Top, VelocityParallel, Speed 30, Lifetime .6; behind it a Glass cylinder mesh with scrolling streak texture.
- nebula: tall Glass cylinder with nebula tile scrolled per frame; sky ring = one flat soft-ring particle at +15 studs, Size 30, slow RotSpeed; Box volume of tiny stars.
- ref9 (anime explosion): magic circles = long-lived flat particle or floor Beam quad with 1024 sigil texture; crystal spikes = cone MeshParts, Glass/Neon, Size tweened 0->H with base pinned; colour ramp white->yellow->orange->crimson->dark smoke; ground crack decal from raycast.

## Emitter recipes
- LightEmission 1, LightInfluence 0, Brightness 2-8 (push Brightness not Size for "hot").
- Sharp cutoffs: Transparency {(0,1),(.08,0),(.7,0),(1,1)}. The snap-out is the anime pop.
- White core -> hue: Color {(0,white),(.25,hue),(1,darkerHue)}; second emitter underneath pure hue, bigger, dimmer.
- Orientation: VelocityParallel for streaks/flames/sweeps; VelocityPerpendicular + tiny upward Speed to lie flat (rings, pools, sigils); FacingCamera for glows.
- Squash positive = taller/thinner (flame sheets), negative = wider/flatter (impact flashes).
- Shape volumes only work on a Part (Attachment emitters are point emission).
- Drag 2-6 for explode-then-hang; Acceleration (0,-12,0) petals; RotSpeed +-300 shards; SpreadAngle (10,10) sheets, (180,180) omni.
- ZOffset +.3-1 body overlays in front of limbs; -1 ground layers behind.
- Flipbooks: square power-of-two up to 1024, Grid2x2/4x4/8x8, Mode Loop/OneShot/PingPong/Random, Framerate 12-30 (OneShot stretches over Lifetime), FlipbookStartRandom true, ~4 px padding per frame.

## Beams
TextureMode Wrap, TextureLength 2-6, TextureSpeed +-1-4, CurveSize0/1 4-12 bends along attachment Axis, Segments 20-40, FaceCamera true for arcs, tapered Width0/Width1, LightEmission 1, Brightness 3. Floor quad: two attachments 10 studs apart rotated CFrame.Angles(rad 90,0,0), FaceCamera false, Width 10 = fastest sigil/pool.

## Trails
Two attachments on one moving part .5-2 studs apart (distance = width). Lifetime .25-.5, MinLength .1, WidthScale 1->0, Transparency {(0,0),(.6,.2),(1,1)}, TextureMode Stretch with tapered streak. trail:Clear() before teleporting.

## Character
- Highlight: FillColor hue, FillTransparency tween 0->1 in .15 s for hit flash, OutlineTransparency 1 (outlines look Roblox), DepthMode Occluded. 31 limit, disabled ones still count: Destroy.
- PointLight in HRP Brightness 3-6 Range 20-30. SurfaceLight on Bottom of a thin floor part = fake underglow pool.
- Mesh materials: Neon (glow, ignores textures, transparency kills glow), Glass (refractive tint, textured, quality >= ~8), ForceField (engine-animated emission mask, no control of scroll). UV scroll: Texture child OffsetStudsU/V per frame. SurfaceAppearance has no offset.
- Mesh transparency ramps: 1->.2 (In .1 s) then .2->1 (Quart Out .5 s).

## Textures
Engine-owned safe: rbxasset://textures/particles/{sparkles_main, smoke_main, fire_main, fire_sparks_main, explosion01_core_main, explosion01_implosion_main, explosion01_shockwave_main, explosion01_smoke_main, forcefield_vortex_main, forcefield_glow_main}.dds. No confident free numeric IDs; paint our own 512 px PNG alpha (white on transparent so Color tints): soft radial glow, hard ring, tall flame sheet, horizontal streak, 4-point star, petal/triangle shard, lightning 4x4 flipbook (1024), smoke 8x8 flipbook, quarter-arc sweep, ground crack, magic circle 1024, tileable nebula noise.

## Things coming out
- Ghost copies: char.Archivable = true, Clone, strip Humanoid/scripts/Highlights, parts Anchored, no collide/query/touch, ForceField or Glass, Transparency .4, Color hue, parent to CurrentCamera or local folder, PivotTo along a Bezier each frame. Targets = Players HRPs within radius.
- Shard explosion + reassemble: never detach Motor6Ds. Clone limbs as fakes, real limb LocalTransparencyModifier = 1, fling fakes outward, lerp back with Back easing over .4 s, destroy fakes, restore modifier.
- Wings: two anchored MeshParts, per RenderStepped CFrame = torso * offset * Angles(0, +-(20 + 35 sin 6t), 0) * pivot fix. Roblox recentres imported meshes: bake pivot offset.
- Flight loop: PlatformStand true, zero velocity, per frame hrp.CFrame = centre * Angles(0, 2t, 0) * CFrame.new(0, 4 sin 3t, 12) * Angles(0, pi/2, 0). Restore PlatformStand.

## Environment
- Ground crack/scorch: raycast down from HRP (filter char), .05-thick part at hit + normal*.03, CFrame lookAt(p, p+normal) * Angles(-pi/2,0,0) so Top-face Decal aligns; tween Decal Transparency.
- Terrain-conforming ring: 24 raycasts round the circle, place flat segments / attachments at hit heights for a floor Beam loop.
- Debris: GetPartBoundsInRadius(pos, 12); unanchored parts not owned: clone locally, hide original via LocalTransparencyModifier, AssemblyLinearVelocity (dir + up)*40, Debris 3 s. Anchored props: local CFrame jitter and restore (client CFrame never replicates).
- Wall flash: raycast 8 directions, Decal flash part on nearest hit with its normal.
- Lighting: tween ColorCorrection (Tint, Saturation +.3, Contrast +.2) and Bloom (Intensity 1.5, Threshold .8) in .1 s, restore .6 s; snapshot originals. FOV 70->78 in .08 s, back .4 s Quart. Atmosphere.Glare punch. All local.

## Performance
- Live particles per effect: ~1500 desktop, ~600 laptop, ~250 mobile (TouchEnabled + SavedQualityLevel).
- <= 10 emitters per burst, <= 6 persistent; <= 3 Beams, <= 4 Trails per character.
- Bursts: Enabled false + Emit(n <= 100). Loops: Rate <= 60 on mobile.
- Pre-build rigs in ReplicatedStorage, Clone, Debris after longest lifetime. Flipbooks <= 512 on mobile; one 1024 sigil only. No shadows on effect lights on mobile.

## Gotchas
Beam needs both attachments under Workspace (CurrentCamera fine). Attachment emitters ignore Part Size. Trail width = attachment distance. Mesh import recentres to bounding box: pin spike bases with base * CFrame.new(0, size.Y/2, 0) while tweening Size. Neon emits no light: add PointLight. Neon strength differs Future vs ShadowMap. Overlapping transparent neon meshes sort per part and pop: one transparent mesh per layer, rest particles (ZOffset), nest sizes.
