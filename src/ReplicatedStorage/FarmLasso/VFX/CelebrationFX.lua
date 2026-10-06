--!strict
-- CelebrationFX: the aura. Builds a layered, code-driven celebration around a
-- character for one tier and tears it down when the reveal hold ends.
--
--   local fx = CelebrationFX.Play(character, tier, { Reduced = false })
--   fx:Stop()   -- optional early stop; it ends itself after the hold
--
-- Timeline (fractions of the tier's hold D):
--   0.00  impact: ground shock rings, sigil slams in, mist, floor swirls
--   0.00-0.30  rise: player lifts (CelebrationFloat), galaxy / halo column build,
--              orbit rings and gyro rings spawn in staggered
--   0.30  PEAK: white flash, radial slashes, star burst, god rays, wings unfold,
--              accretion ring + sky beam + mega bolt (rainbow), title pops
--   0.30-0.85  hold: everything orbits, hue cycles (rainbow), bolts strike
--   0.85-1.00  settle: all pieces implode into the chest, landing ring + dust
--
-- Everything is client-side under the camera. Nothing here replicates.
-- Reduced = true is what other players see: about half the pieces, no flash.

local Kit = require(script.Parent.VFXKit)
local Assets = require(script.Parent.VFXAssets)

local FX = {}

export type Options = {
	Reduced: boolean?,
	Duration: number?,
	Title: string?,
	Subtitle: string?,
	OnPeak: (() -> ())?,
}

export type Handle = {
	Stop: (self: Handle) -> (),
	Scene: Kit.Scene,
}

type Ctx = {
	Scene: Kit.Scene,
	Hrp: BasePart,
	Ground: Vector3,
	Tier: number,
	Pal: Assets.Palette,
	D: number,
	PeakAt: number,
	SettleAt: number,
	Density: number,
	Reduced: boolean,
	Col: (t: number, role: string, offset: number?) -> Color3,
	Settle: (t: number) -> number,
	Center: () -> Vector3,
}

local UP = Vector3.yAxis

-- ---------------------------------------------------------------- helpers
local function randomUnit(): Vector3
	local v = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1)
	return if v.Magnitude < 0.05 then UP else v.Unit
end

local function ringPos(center: Vector3, radius: number, angle: number, tilt: number, tiltAxis: number): Vector3
	local p = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	return center + (CFrame.Angles(0, tiltAxis, 0) * CFrame.Angles(tilt, 0, 0)):VectorToWorldSpace(p)
end

-- Expanding ground ring: scale 0 -> radius, fades out. Fire-and-forget.
local function shockRing(ctx: Ctx, at: number, radius: number, life: number, color: Color3?, y: number?)
	ctx.Scene:Delay(at, function()
		local ring = Kit.Mesh("ShockRing", color or ctx.Col(ctx.Scene.T, "Primary"), ctx.Scene.Root)
		local base = Kit.MeshBaseSize("ShockRing")
		local start = ctx.Scene.T
		local pos = Vector3.new(ctx.Ground.X, y or (ctx.Ground.Y + 0.15), ctx.Ground.Z)
		ctx.Scene:OnStep(function(t)
			local k = Kit.Span(t - start, 0, life)
			if k >= 1 then
				ring:Destroy()
				return
			end
			local e = Kit.Ease.OutExpo(k)
			local r = 0.3 + radius * e
			ring.Size = Vector3.new(base.X * r, base.Y * (1.2 - e), base.Z * r)
			ring.CFrame = CFrame.new(pos)
			ring.Transparency = k * k
		end)
	end)
end

-- ---------------------------------------------------------------- layers
local function layerSigil(ctx: Ctx)
	local tier = ctx.Tier
	local sigil = Kit.Mesh("Sigil", ctx.Col(0, "Accent"), ctx.Scene.Root)
	local sBase = Kit.MeshBaseSize("Sigil")
	local radius = ({ 5, 7, 9, 12 })[tier]
	local rune: BasePart? = nil
	local rBase = Vector3.one
	if tier >= 3 then
		rune = Kit.Mesh("RuneRing", ctx.Col(0, "Primary"), ctx.Scene.Root)
		rBase = Kit.MeshBaseSize("RuneRing")
	end
	local pos = ctx.Ground + Vector3.new(0, 0.1, 0)
	ctx.Scene:OnStep(function(t)
		local grow = Kit.Ease.OutBack(Kit.Span(t, 0, 0.45), 1.6)
		local s = ctx.Settle(t)
		local k = grow * (1 - s)
		local pulse = 1 + 0.06 * math.sin(t * 6)
		sigil.Size = sBase * (radius / sBase.X) * 2 * k * pulse
		sigil.CFrame = CFrame.new(pos) * CFrame.Angles(0, t * 0.6, 0)
		sigil.Color = ctx.Col(t, "Accent")
		sigil.Transparency = 0.1 + 0.9 * s
		if rune then
			rune.Size = rBase * (radius * 1.35 / rBase.X) * 2 * k
			rune.CFrame = CFrame.new(pos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, -t * 0.9, 0)
			rune.Color = ctx.Col(t, "Primary", 0.1)
			rune.Transparency = 0.15 + 0.85 * s
		end
	end)
end

local function layerSwirls(ctx: Ctx)
	if ctx.Tier < 2 then
		return
	end
	local base = Kit.MeshBaseSize("Swirl")
	local radius = ({ 0, 6, 9, 13 })[ctx.Tier]
	for i = 1, 2 do
		local swirl = Kit.Mesh("Swirl", ctx.Col(0, "Secondary"), ctx.Scene.Root)
		local dir = if i == 1 then 1 else -1
		ctx.Scene:OnStep(function(t)
			local k = Kit.Ease.OutCubic(Kit.Span(t, 0.1, 0.7)) * (1 - ctx.Settle(t))
			swirl.Size = base * (radius / base.X) * 2 * k
			swirl.CFrame = CFrame.new(ctx.Ground + Vector3.new(0, 0.2 + i * 0.05, 0)) * CFrame.Angles(0, t * 1.4 * dir + i, 0)
			swirl.Color = ctx.Col(t, "Secondary", 0.05 * i)
			swirl.Transparency = 0.35 + 0.65 * ctx.Settle(t)
		end)
	end
end

local function layerParticles(ctx: Ctx)
	local tier = ctx.Tier
	local groundAnchor = Kit.Anchor(ctx.Scene.Root, CFrame.new(ctx.Ground + Vector3.new(0, 0.5, 0)))
	local mist = Kit.Emitter(groundAnchor, {
		Texture = Assets.Textures.Smoke,
		Color = ctx.Pal.Secondary,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.2, 2.0),
		Speed = NumberRange.new(6, 12),
		Spread = Vector2.new(90, 90),
		Acceleration = Vector3.new(0, -2, 0),
		Drag = 3,
		LightEmission = 0.6,
		Brightness = 1,
		Rate = 0,
	})
	mist:Emit(14 * tier * ctx.Density)
	mist.Rate = 6 * tier * ctx.Density
	mist.Speed = NumberRange.new(1, 3)

	local bodyAnchor = Kit.Anchor(ctx.Scene.Root, ctx.Hrp.CFrame)
	local sparkle = Kit.Emitter(bodyAnchor, {
		Texture = Assets.Textures.Sparkle,
		Color = ctx.Pal.Accent,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.9), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0),
		Lifetime = NumberRange.new(0.8, 1.6),
		Speed = NumberRange.new(2, 7),
		Acceleration = Vector3.new(0, 4, 0),
		Drag = 1.5,
		Rate = 25 * tier * ctx.Density,
		Brightness = 3,
	})
	local light = Kit.Light(bodyAnchor, ctx.Pal.Primary, 30, 0)
	ctx.Scene:OnStep(function(t)
		bodyAnchor.CFrame = CFrame.new(ctx.Center())
		local s = ctx.Settle(t)
		light.Brightness = (1.5 + 2 * Kit.Span(t, 0, 0.4)) * (1 - s) * ({ 0.6, 0.8, 1.2, 1.8 })[tier]
		light.Color = ctx.Col(t, "Primary")
		if ctx.Pal.HueCycle then
			sparkle.Color = ColorSequence.new(ctx.Col(t, "Accent"), ctx.Col(t, "Primary", 0.3))
		end
		if s > 0 then
			sparkle.Rate = 0
			mist.Rate = 0
		end
	end)
	-- dust slam at the landing
	ctx.Scene:Delay(ctx.D * 0.97, function()
		mist:Emit(20 * ctx.Density)
	end)
end

local function layerGalaxy(ctx: Ctx)
	if ctx.Tier < 4 then
		return
	end
	local armBase = Kit.MeshBaseSize("GalaxyArm")
	local coreBase = Kit.MeshBaseSize("GalaxyCore")
	local radius = 15 -- studs, arm span
	local arms = {}
	for i = 1, 3 do
		arms[i] = Kit.Mesh("GalaxyArm", ctx.Col(0, "Primary"), ctx.Scene.Root)
	end
	local core = Kit.Mesh("GalaxyCore", ctx.Pal.Hot, ctx.Scene.Root)
	local pos = ctx.Ground + Vector3.new(0, 0.35, 0)
	ctx.Scene:OnStep(function(t)
		local k = Kit.Ease.OutCubic(Kit.Span(t, 0.05, 0.8)) * (1 - ctx.Settle(t))
		local wobble = CFrame.Angles(math.rad(4) * math.sin(t * 0.9), 0, math.rad(4) * math.cos(t * 0.7))
		for i, arm in ipairs(arms) do
			local scale = (radius * 2 / armBase.X) * k
			arm.Size = armBase * scale
			-- the arm's spiral centre is its pivot; Roblox centred the mesh on its
			-- bounding box, so push it back out by the stored offset
			arm.CFrame = CFrame.new(pos) * wobble * CFrame.Angles(0, t * 1.3 + (i - 1) * (math.pi * 2 / 3), 0)
				* CFrame.new(Assets.PivotOffsets.GalaxyArm * scale)
			arm.Color = ctx.Col(t, "Primary", 0.08 * i)
			arm.Transparency = 0.15 + 0.85 * ctx.Settle(t)
		end
		core.Size = coreBase * (7 / coreBase.X) * k * (1 + 0.08 * math.sin(t * 7))
		core.CFrame = CFrame.new(pos) * wobble
		core.Color = ctx.Pal.Hot
		core.Transparency = 0.05 + 0.95 * ctx.Settle(t)
	end)
end

local function layerHaloColumn(ctx: Ctx)
	if ctx.Tier < 3 then
		return
	end
	local colBase = Kit.MeshBaseSize("BeamColumn")
	local ringBase = Kit.MeshBaseSize("HaloRing")
	local height = if ctx.Tier >= 4 then 22 else 15
	local radius = if ctx.Tier >= 4 then 7 else 5
	local column = Kit.Mesh("BeamColumn", ctx.Col(0, "Primary"), ctx.Scene.Root)
	column.Transparency = 0.7
	local rings = {}
	for i = 1, 3 do
		rings[i] = Kit.Mesh("HaloRing", ctx.Col(0, "Accent"), ctx.Scene.Root)
	end
	ctx.Scene:OnStep(function(t)
		local k = Kit.Ease.OutCubic(Kit.Span(t, 0.1, 0.9)) * (1 - ctx.Settle(t))
		column.Size = Vector3.new(colBase.X * radius, colBase.Y * height * k, colBase.Z * radius)
		column.CFrame = CFrame.new(ctx.Ground + Vector3.new(0, height * k * 0.5, 0)) * CFrame.Angles(0, t * 0.8, 0)
		column.Color = ctx.Col(t, "Primary", 0.15)
		column.Transparency = 0.72 + 0.28 * ctx.Settle(t)
		for i, ring in ipairs(rings) do
			local y = ((t * 4.5 + (i - 1) * (height / 3)) % height)
			local fade = Kit.Span(y, height * 0.6, height)
			local r = (radius * 1.15 * 2 / ringBase.X) * k
			ring.Size = ringBase * r
			ring.CFrame = CFrame.new(ctx.Ground + Vector3.new(0, y * k, 0))
			ring.Color = ctx.Col(t, "Accent", 0.1 * i)
			ring.Transparency = math.max(fade, ctx.Settle(t))
		end
	end)
end

local function layerOrbits(ctx: Ctx)
	if ctx.Tier < 3 then
		return
	end
	local keys = { "ShardA", "ShardB", "ShardC" }
	type Orbiter = { Part: BasePart, Base: Vector3, Angle: number, Spin: Vector3, Scale: number, Born: number }
	local ringA: { Orbiter } = {}
	local ringB: { Orbiter } = {}
	local nA = math.floor(10 * ctx.Density + 0.5)
	for i = 1, nA do
		local key = keys[(i % #keys) + 1]
		local part = Kit.Mesh(key, ctx.Col(0, "Primary"), ctx.Scene.Root)
		table.insert(ringA, {
			Part = part,
			Base = Kit.MeshBaseSize(key),
			Angle = (i / nA) * math.pi * 2,
			Spin = randomUnit(),
			Scale = 1.6 + math.random() * 0.8,
			Born = 0.15 + i * 0.04,
		})
	end
	if ctx.Tier >= 4 then
		local nB = math.floor(8 * ctx.Density + 0.5)
		for i = 1, nB do
			local part = Kit.Mesh("OrbitCrystal", ctx.Col(0, "Accent"), ctx.Scene.Root)
			table.insert(ringB, {
				Part = part,
				Base = Kit.MeshBaseSize("OrbitCrystal"),
				Angle = (i / nB) * math.pi * 2,
				Spin = randomUnit(),
				Scale = 1.4,
				Born = 0.3 + i * 0.05,
			})
		end
	end
	ctx.Scene:OnStep(function(t)
		local c = ctx.Center()
		local s = ctx.Settle(t)
		local speedBoost = 1 + 1.5 * Kit.Span(t, ctx.PeakAt - 0.3, ctx.PeakAt + 0.2) -- whip at the peak
		for _, o in ipairs(ringA) do
			local k = Kit.Ease.OutBack(Kit.Span(t, o.Born, o.Born + 0.4), 2) * (1 - s)
			local a = o.Angle + t * 1.7 * speedBoost
			local p = ringPos(c + Vector3.new(0, 0.5, 0), 5.5, a, math.rad(18), 0.3)
			p = p:Lerp(c, s)
			o.Part.Size = o.Base * o.Scale * k
			o.Part.CFrame = CFrame.new(p) * CFrame.fromAxisAngle(o.Spin, t * 3 + a)
			o.Part.Color = ctx.Col(t, "Primary", a * 0.02)
			o.Part.Transparency = s
		end
		for _, o in ipairs(ringB) do
			local k = Kit.Ease.OutBack(Kit.Span(t, o.Born, o.Born + 0.4), 2) * (1 - s)
			local a = o.Angle - t * 1.1 * speedBoost
			local p = ringPos(c + Vector3.new(0, 2.5, 0), 8, a, math.rad(-32), 1.2)
			p = p:Lerp(c, s)
			o.Part.Size = o.Base * o.Scale * k
			o.Part.CFrame = CFrame.new(p) * CFrame.fromAxisAngle(o.Spin, t * 2 - a)
			o.Part.Color = ctx.Col(t, "Accent", a * 0.02)
			o.Part.Transparency = s
		end
	end)
end

local function layerGyro(ctx: Ctx)
	if ctx.Tier < 3 then
		return
	end
	local base = Kit.MeshBaseSize("RuneRing")
	local rings = {}
	local n = if ctx.Tier >= 4 then 3 else 2
	for i = 1, n do
		rings[i] = Kit.Mesh("RuneRing", ctx.Col(0, "Accent"), ctx.Scene.Root)
	end
	local crown: BasePart? = nil
	local crownBase = Vector3.one
	if ctx.Tier >= 3 then
		crown = Kit.Mesh("SpikeHalo", ctx.Col(0, "Accent"), ctx.Scene.Root)
		crownBase = Kit.MeshBaseSize("SpikeHalo")
	end
	ctx.Scene:OnStep(function(t)
		local c = ctx.Center()
		local s = ctx.Settle(t)
		for i, ring in ipairs(rings) do
			local k = Kit.Ease.OutBack(Kit.Span(t, 0.2 + i * 0.1, 0.7 + i * 0.1), 1.5) * (1 - s)
			local radius = 3.6 + i * 0.9
			local w = (1.2 + i * 0.5) * (if i % 2 == 0 then -1 else 1)
			ring.Size = base * (radius * 2 / base.X) * k
			ring.CFrame = CFrame.new(c + Vector3.new(0, 0.8, 0))
				* CFrame.Angles(0, t * w, 0)
				* CFrame.Angles(math.rad(25 + 30 * i) * math.sin(t * 0.7 + i), 0, math.rad(15 * i))
			ring.Color = ctx.Col(t, "Accent", 0.12 * i)
			ring.Transparency = 0.1 + 0.9 * s
		end
		if crown then
			local k = Kit.Ease.OutElastic(Kit.Span(t, ctx.PeakAt, ctx.PeakAt + 0.7)) * (1 - s)
			crown.Size = crownBase * (6 / crownBase.X) * k
			crown.CFrame = CFrame.new(c + Vector3.new(0, 4.2 + 0.2 * math.sin(t * 3), 0)) * CFrame.Angles(0, -t * 2.2, 0)
				* CFrame.Angles(math.rad(8) * math.sin(t * 1.3), 0, 0)
			crown.Color = ctx.Col(t, "Accent", 0.5)
			crown.Transparency = s
		end
	end)
end

local function layerWings(ctx: Ctx)
	if ctx.Tier < 3 then
		return
	end
	local base = Kit.MeshBaseSize("Wing")
	local scale = if ctx.Tier >= 4 then 1.35 else 1.0
	local wings = {}
	for i = 1, 2 do
		wings[i] = Kit.Mesh("Wing", ctx.Col(0, "Accent"), ctx.Scene.Root)
	end
	ctx.Scene:OnStep(function(t)
		local s = ctx.Settle(t)
		local unfold = Kit.Ease.OutBack(Kit.Span(t, ctx.PeakAt, ctx.PeakAt + 0.55), 1.4) * (1 - s)
		if unfold <= 0 then
			for _, w in ipairs(wings) do
				w.Transparency = 1
			end
			return
		end
		local flap = math.sin(t * 2.6) * math.rad(14)
		local back = ctx.Hrp.CFrame * CFrame.new(0, 0.9, 0.9) -- between the shoulder blades
		for i, w in ipairs(wings) do
			local side = if i == 1 then 1 else -1
			local mirror = if side == 1 then CFrame.identity else CFrame.Angles(0, math.pi, 0)
			local k = scale * unfold
			w.Size = base * k
			-- the wing root is its pivot; the stored offset moves the centred mesh
			-- so the root sits on the shoulder blade, mirrored for the left side
			w.CFrame = back
				* CFrame.Angles(0, -flap * side, math.rad(18) * side * unfold)
				* mirror
				* CFrame.new(Assets.PivotOffsets.Wing * k)
			w.Color = ctx.Col(t, "Accent", 0.05)
			w.Transparency = 0.05 + 0.95 * s
		end
	end)
end

local function layerAccretion(ctx: Ctx)
	if ctx.Tier < 4 then
		return
	end
	local base = Kit.MeshBaseSize("AccretionRing")
	local ring = Kit.Mesh("AccretionRing", ctx.Col(0, "Primary"), ctx.Scene.Root)
	local core = Instance.new("Part")
	core.Shape = Enum.PartType.Ball
	core.Material = Enum.Material.SmoothPlastic
	core.Color = Color3.new(0, 0, 0)
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.CastShadow = false
	core.Parent = ctx.Scene.Root
	ctx.Scene:OnStep(function(t)
		local s = ctx.Settle(t)
		local k = Kit.Ease.OutBack(Kit.Span(t, ctx.PeakAt, ctx.PeakAt + 0.6), 1.3) * (1 - s)
		local c = ctx.Center() + Vector3.new(0, 6.5, 0)
		local tilt = CFrame.Angles(math.rad(28), t * 2.1, math.rad(6) * math.sin(t * 0.8))
		ring.Size = base * (18 / base.X) * k
		ring.CFrame = CFrame.new(c) * tilt
		ring.Color = ctx.Col(t, "Primary", 0.45)
		ring.Transparency = 0.05 + 0.95 * s
		core.Size = Vector3.one * 3.4 * k
		core.CFrame = CFrame.new(c)
		core.Transparency = s
	end)
end

local function layerSkyBeam(ctx: Ctx)
	if ctx.Tier < 4 or ctx.Reduced then
		return
	end
	local base = Kit.MeshBaseSize("BeamColumn")
	local beam = Kit.Mesh("BeamColumn", ctx.Pal.Hot, ctx.Scene.Root)
	local top = 60
	ctx.Scene:OnStep(function(t)
		local s = ctx.Settle(t)
		local drop = Kit.Ease.OutExpo(Kit.Span(t, ctx.PeakAt - 0.15, ctx.PeakAt + 0.25))
		local fade = Kit.Span(t, ctx.PeakAt + 0.9, ctx.PeakAt + 1.6)
		local h = top * drop
		local r = 2.2 + 1.5 * (1 - drop)
		beam.Size = Vector3.new(base.X * r, base.Y * h, base.Z * r)
		beam.CFrame = CFrame.new(ctx.Ground + Vector3.new(0, top - h * 0.5, 0)) * CFrame.Angles(0, t * 1.5, 0)
		beam.Color = ctx.Col(t, "Hot")
		beam.Transparency = math.max(0.35 + 0.65 * fade, s)
	end)
end

local function layerBolts(ctx: Ctx)
	if ctx.Tier < 4 or ctx.Reduced then
		return
	end
	local function strike(from: Vector3, to: Vector3, width: number, life: number)
		local key = if math.random() < 0.5 then "BoltA" else "BoltB"
		local bolt = Kit.Mesh(key, ctx.Pal.Accent, ctx.Scene.Root)
		local base = Kit.MeshBaseSize(key)
		local len = (to - from).Magnitude
		local mid = (from + to) * 0.5
		local yaw = math.random() * math.pi * 2
		bolt.Size = Vector3.new(base.X * width, len, base.Z * width)
		bolt.CFrame = CFrame.new(mid) * CFrame.Angles(0, yaw, 0)
		local light = Kit.Light(bolt, ctx.Pal.Accent, 40, 6)
		local start = ctx.Scene.T
		shockRing(ctx, 0, 3, 0.35, ctx.Pal.Accent, to.Y + 0.1)
		ctx.Scene:OnStep(function(t)
			local k = Kit.Span(t - start, 0, life)
			if k >= 1 then
				bolt:Destroy()
				return
			end
			local flicker = if (math.floor(t * 60) % 3) == 0 then 0.35 else 0
			bolt.Transparency = k * k + flicker
			light.Brightness = 6 * (1 - k)
		end)
	end
	-- the mega bolt that lands on the player at the peak
	ctx.Scene:Delay(ctx.PeakAt, function()
		local c = ctx.Center()
		strike(c + Vector3.new(0, 45, 0), c + Vector3.new(0, 1, 0), 3.5, 0.3)
	end)
	-- ring of strikes through the hold
	local n = 0
	local function nextStrike()
		if not ctx.Scene.Alive then
			return
		end
		local t = ctx.Scene.T
		if t < ctx.SettleAt - 0.3 then
			n += 1
			local a = n * 2.4 + math.random() * 0.6
			local r = 5 + math.random() * 6
			local hit = ctx.Ground + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			strike(hit + Vector3.new(0, 28, 0), hit, 1.6, 0.22)
			ctx.Scene:Delay(t + 0.28 + math.random() * 0.2, nextStrike)
		end
	end
	ctx.Scene:Delay(ctx.PeakAt + 0.25, nextStrike)
end

local function layerPeakBurst(ctx: Ctx)
	local tier = ctx.Tier
	ctx.Scene:Delay(ctx.PeakAt, function()
		local c = ctx.Center()
		local start = ctx.Scene.T
		-- flash sphere (skipped for Reduced so the plaza stays readable)
		if not ctx.Reduced then
			local flash = Instance.new("Part")
			flash.Shape = Enum.PartType.Ball
			flash.Material = Enum.Material.Neon
			flash.Color = ctx.Pal.Hot
			flash.Anchored = true
			flash.CanCollide = false
			flash.CanQuery = false
			flash.CastShadow = false
			flash.Parent = ctx.Scene.Root
			local radius = ({ 6, 9, 14, 22 })[tier]
			ctx.Scene:OnStep(function(t)
				local k = Kit.Span(t - start, 0, 0.32)
				if k >= 1 then
					flash:Destroy()
					return
				end
				flash.Size = Vector3.one * radius * Kit.Ease.OutExpo(k)
				flash.CFrame = CFrame.new(c)
				flash.Transparency = 0.1 + 0.9 * k
			end)
		end
		-- radial slashes
		local slashBase = Kit.MeshBaseSize("Slash")
		local nS = math.floor(({ 4, 6, 8, 12 })[tier] * ctx.Density + 0.5)
		for i = 1, nS do
			local slash = Kit.Mesh("Slash", ctx.Pal.Hot, ctx.Scene.Root)
			local axis = randomUnit()
			local roll = math.random() * math.pi * 2
			local life = 0.4 + math.random() * 0.25
			local size = (({ 8, 11, 14, 18 })[tier]) * (0.7 + math.random() * 0.6)
			ctx.Scene:OnStep(function(t)
				local k = Kit.Span(t - start, 0, life)
				if k >= 1 then
					slash:Destroy()
					return
				end
				local e = Kit.Ease.OutExpo(k)
				slash.Size = slashBase * (size / slashBase.X) * (0.3 + 0.7 * e)
				slash.CFrame = CFrame.new(c) * CFrame.fromAxisAngle(axis, roll + e * 1.2) * CFrame.new(0, 0, size * 0.25)
				slash.Color = ctx.Col(t, "Hot", 0.3 * i / nS)
				slash.Transparency = k * k
			end)
		end
		-- star burst
		local starBase = Kit.MeshBaseSize("StarShard")
		local nStars = math.floor(({ 6, 10, 14, 20 })[tier] * ctx.Density + 0.5)
		for i = 1, nStars do
			local star = Kit.Mesh("StarShard", ctx.Pal.Accent, ctx.Scene.Root)
			local dir = randomUnit()
			local speed = 10 + math.random() * 14
			local spin = randomUnit()
			local life = 0.5 + math.random() * 0.4
			local sz = 1.2 + math.random() * 1.6
			ctx.Scene:OnStep(function(t)
				local k = Kit.Span(t - start, 0, life)
				if k >= 1 then
					star:Destroy()
					return
				end
				local d = Kit.Ease.OutCubic(k) * speed * life
				star.Size = starBase * (sz / starBase.X) * (1 - k * 0.6)
				star.CFrame = CFrame.new(c + dir * d) * CFrame.fromAxisAngle(spin, t * 6)
				star.Color = ctx.Col(t, "Accent", i * 0.03)
				star.Transparency = k * k
			end)
		end
		-- god rays fanned behind the player
		if tier >= 3 then
			local rayBase = Kit.MeshBaseSize("GodRay")
			local nR = math.floor(12 * ctx.Density + 0.5)
			for i = 1, nR do
				local ray = Kit.Mesh("GodRay", ctx.Pal.Hot, ctx.Scene.Root)
				local a = (i / nR) * math.pi * 2
				local len = 14 + math.random() * 8
				ctx.Scene:OnStep(function(t)
					local s = ctx.Settle(t)
					local k = Kit.Span(t - start, 0, 0.5)
					local out = Kit.Span(t, ctx.SettleAt - 0.6, ctx.SettleAt)
					local e = Kit.Ease.OutExpo(k) * (1 - out)
					local back = ctx.Hrp.CFrame * CFrame.new(0, 1, 1.5)
					local spin = t * 0.5
					ray.Size = Vector3.new(rayBase.X * 7, rayBase.Y * len * e, rayBase.Z * 7)
					ray.CFrame = back * CFrame.Angles(0, 0, a + spin) * CFrame.new(0, len * e * 0.5, 0)
					ray.Color = ctx.Col(t, "Hot", 0.1)
					ray.Transparency = math.max(0.45 + 0.55 * (1 - e), s)
				end)
			end
		end
		-- extra ground ring on the peak
		shockRing(ctx, 0, ({ 8, 12, 16, 24 })[tier], 0.7)
	end)
end

local function layerTitle(ctx: Ctx, title: string, subtitle: string)
	local anchor = Kit.Anchor(ctx.Scene.Root, ctx.Hrp.CFrame)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(520, 200)
	gui.AlwaysOnTop = true
	gui.MaxDistance = if ctx.Reduced then 160 else 400
	gui.LightInfluence = 0
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5.5, 0)
	gui.Parent = anchor

	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = gui

	local function label(text: string, size: number, font: Enum.Font, y: number, color: Color3): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, size + 16)
		l.Position = UDim2.new(0, 0, 0, y)
		l.Text = text
		l.TextSize = size
		l.Font = font
		l.TextColor3 = color
		l.TextStrokeTransparency = 0
		l.TextStrokeColor3 = Color3.new(0, 0, 0)
		l.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Parent = l
		return l
	end

	local big = label(title, 72, Assets.Fonts.Title, 20, ctx.Pal.Accent)
	local small = label(subtitle, 34, Assets.Fonts.Body, 110, Color3.new(1, 1, 1))

	ctx.Scene:OnStep(function(t)
		local c = ctx.Center()
		anchor.CFrame = CFrame.new(c)
		local pop = Kit.Ease.OutBack(Kit.Span(t, ctx.PeakAt, ctx.PeakAt + 0.45), 2.2)
		local out = Kit.Ease.InCubic(Kit.Span(t, ctx.SettleAt, ctx.SettleAt + 0.3))
		scale.Scale = (if ctx.Reduced then 0.7 else 1) * pop * (1 - out) * (1 + 0.04 * math.sin(t * 9))
		gui.StudsOffsetWorldSpace = Vector3.new(0, 5.5 + (t - ctx.PeakAt) * 0.4, 0)
		big.TextColor3 = ctx.Col(t, "Accent", 0.2)
		big.Rotation = math.sin(t * 2.3) * 3
		small.TextTransparency = out
	end)
end

-- ---------------------------------------------------------------- play
function FX.Play(character: Model, tier: number, opts: Options?): Handle?
	local o: Options = opts or {}
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return nil
	end
	tier = math.clamp(math.floor(tier), 1, 4)
	local pal = Assets.Palettes[tier]
	local D = o.Duration or Assets.Durations[tier]
	local reduced = o.Reduced == true
	local scene = Kit.NewScene("Celebration_" .. pal.Name)

	-- ground under the player (so the rings sit on the plaza, not mid-air)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace.CurrentCamera }
	local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -12, 0), params)
	local ground = if hit then hit.Position else hrp.Position - Vector3.new(0, 3, 0)

	local settleAt = D * 0.85
	local ctx: Ctx = {
		Scene = scene,
		Hrp = hrp,
		Ground = ground,
		Tier = tier,
		Pal = pal,
		D = D,
		PeakAt = D * 0.3,
		SettleAt = settleAt,
		Density = if reduced then 0.5 else 1,
		Reduced = reduced,
		Col = function(t: number, role: string, offset: number?): Color3
			local base = (pal :: any)[role] :: Color3
			if pal.HueCycle and role ~= "Hot" then
				return Kit.Rainbow(t, (offset or 0) + (if role == "Accent" then 0.33 elseif role == "Secondary" then 0.66 else 0), 0.75)
			end
			return if offset and offset ~= 0 then Kit.HueShift(base, offset * 0.08) else base
		end,
		Settle = function(t: number): number
			return Kit.Ease.InCubic(Kit.Span(t, settleAt, settleAt + 0.4))
		end,
		Center = function(): Vector3
			return hrp.Position + Vector3.new(0, 0.5, 0)
		end,
	}

	-- impact
	shockRing(ctx, 0, ({ 8, 11, 14, 20 })[tier], 0.6)
	shockRing(ctx, 0.12, ({ 5, 7, 9, 13 })[tier], 0.5, pal.Accent)
	layerSigil(ctx)
	layerSwirls(ctx)
	layerParticles(ctx)
	-- build
	layerGalaxy(ctx)
	layerHaloColumn(ctx)
	layerOrbits(ctx)
	layerGyro(ctx)
	-- peak
	layerPeakBurst(ctx)
	layerWings(ctx)
	layerAccretion(ctx)
	layerSkyBeam(ctx)
	layerBolts(ctx)
	local titles = Assets.Titles[tier]
	layerTitle(ctx, o.Title or titles[1], o.Subtitle or titles[2])
	if o.OnPeak then
		scene:Delay(ctx.PeakAt, o.OnPeak)
	end
	-- landing
	shockRing(ctx, D * 0.97, ({ 6, 8, 10, 14 })[tier], 0.5)

	scene:Delay(D + 0.6, function()
		scene:Destroy()
	end)

	local handle = { Scene = scene }
	function handle.Stop(_self: Handle)
		scene:Destroy()
	end
	return (handle :: any) :: Handle
end

return FX
