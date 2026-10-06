-- Shows.PhoenixRebirth: the player chars black, explodes, is reborn five studs up with flame wings, flies a rising
-- spiral leaving a fire helix, hangs as a black silhouette against a sun disc, bursts into golden embers at the apex
-- and lands in a kneel as the scorch ring turns gold. (Oct 6 2026)
-- Set 1: the flame-up. Set 2: explode, rebirth, a hover with flapping wings, a small sun. Set 3: the full flight.
local FX = require(script.Parent.Parent.Parent)
local K = require(script.Parent.Parent.AuraKit)
local V3, W, TAU, rng = Vector3.new, FX.W, K.TAU, FX.rng
local GOLD = Color3.fromRGB(255, 226, 120)
local SOOT = Color3.fromRGB(28, 16, 12)
local M = {Pre = 1.0}

-- ember veins crawl the limbs, ash rises off the shoulders, a dark scorch ring opens underfoot
local function char(ctx, c2, dark, t0, t1, ringScale)
	K.Skin(ctx, {Color = c2, T0 = t0, T1 = t1})
	local ash = ctx:Emitter(ctx:Att(V3(0, 4.2, 0)), {Texture = K.Tex.Smoke, Color = {dark, SOOT}, Size = {{0, .4}, {1, 1.6}}, Transparency = {{0, .4}, {1, 1}}, Lifetime = {1, 1.8},
		Speed = {1.5, 3}, SpreadAngle = Vector2.new(35, 35), Rate = 0, LightEmission = 0, Brightness = 1, Acceleration = V3(0, 1.5, 0), RotSpeed = {-30, 30}})
	ctx:At(t0, function() ash.Rate = 14 * (ctx.Quality or 1) end)
	ctx:At(t1, function() ash.Rate = 0 end)
	local ring = K.Stamp(ctx, ctx.Base.Position, {Mesh = "ScorchRing", Color = SOOT, Material = Enum.Material.SmoothPlastic, Scale = ringScale or 1.3, Life = 99, Rise = .6})
	-- (the stamp lives for the whole show; the show recolours it as the fire comes and goes)
	return ring
end
-- an ember ring pushed down by a wing downstroke
local function downstroke(ctx, P, c1, c2)
	local pos = P.Torso.Position
	ctx:Burst(pos - V3(0, 1, 0), K.Count(ctx, 26), {Texture = K.Tex.Flame, Color = {W, c1, c2}, Size = {{0, 1.4}, {.4, 2}, {1, .3}}, Transparency = {{0, .1}, {1, 1}},
		Lifetime = {.35, .6}, Speed = {12, 20}, SpreadAngle = Vector2.new(70, 70), EmissionDirection = Enum.NormalId.Bottom, Drag = 3, Brightness = 4,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = {{0, .7}, {1, 1.3}}})
	K.ShockRing(ctx, CFrame.new(pos - V3(0, 1.4, 0)), 1, 9, c2, .35, .35)
end
-- feathers drifting down over the area
local function featherRain(ctx, c1, c2, t0, t1, rate)
	local sky = ctx:Part({Transparency = 1, Size = V3(18, 1, 18)})
	local e = ctx:Emitter(sky, {Texture = K.Tex.Petal, Color = {c1, c2}, Size = {.8, .5}, Transparency = {{0, .1}, {.8, .2}, {1, 1}}, Lifetime = {2, 3}, Speed = {.5, 1.5},
		SpreadAngle = Vector2.new(180, 180), Rate = 0, Acceleration = V3(0, -5, 0), Drag = 2.5, RotSpeed = {-220, 220}, Rotation = {0, 360}, Brightness = 2,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume})
	ctx:Every(function(t)
		sky.CFrame = ctx.Base * CFrame.new(0, 12, 0)
		e.Rate = (t > t0 and t < t1) and (rate or 18) * (ctx.Quality or 1) or 0
		if t > t1 then return true end
	end)
end
local function flames(ctx, c1, c2, c3, t0, t1)
	K.Sheets(ctx, {Colors = {c1, c2, c3}, T0 = t0, T1 = t1, Rate = 30})
end

---------------------------------------------------------------- Set 1: the flame-up (2.6 s)
function M.Set1(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 2.6
	local ring = char(ctx, c2, dark, 0, 1.9, .9)
	ctx:At(.35, function() FX.Tween(ring, .3, {Color = c2}) ring.Material = Enum.Material.Neon end)
	flames(ctx, c1, c2, c3, .3, 1.9)
	K.Sweeps(ctx, {Colors = {c1, c2}, T0 = .4, T1 = 1.2, Period = .4, Radius = 4, Height = 2.5, Climb = 5})
	ctx:At(.35, function()
		K.Starburst(ctx, ctx.Base.Position + V3(0, 3, 0), {Colors = {c1, c2}, Size = 7, Count = 20})
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .15), 2, 14, c2, .45, .4)
	end)
	-- the wing silhouette flashes up behind the player for 0.4 s
	ctx:At(.8, function()
		local back = K.Behind(ctx)
		for side = -1, 1, 2 do
			local w = K.Mesh(ctx, "WingSilhouette", {Color = c1, Transparency = 1})
			local t0 = os.clock()
			ctx:Every(function()
				local u = (os.clock() - t0) / .45
				if u >= 1 then w:Destroy() return true end
				local k = FX.back(u / .3) * (1 - FX.ease((u - .6) / .4))
				local root = ctx.Hrp.CFrame * CFrame.new(side * .4, .6, 1.2)
				local yaw = CFrame.lookAt(root.Position, root.Position - back) * CFrame.Angles(0, side > 0 and 0 or math.pi, side * .35)
				K.Place(w, yaw * CFrame.Angles(0, side * -.3, side * .5 * (1 - k)), V3(side > 0 and 1 or -1, 1, 1) * (1.2 * k + .05))
				w.Transparency = 1 - .85 * k
			end)
		end
		ctx:Burst(ctx.Base.Position + V3(0, 4, 0), K.Count(ctx, 14), {Texture = K.Tex.Petal, Color = {c1, c2}, Size = {.8, .5}, Lifetime = {1.2, 1.8}, Speed = {3, 7},
			SpreadAngle = Vector2.new(180, 180), Acceleration = V3(0, -6, 0), Drag = 3, RotSpeed = {-200, 200}, Brightness = 2})
	end)
	ctx:Repeat(.5, 1.8, .3, function() ctx:Flare(ctx.Base.Position + K.Polar(rng:NextNumber(0, TAU), rng:NextNumber(2, 4), rng:NextNumber(1, 5)), rng:NextNumber(2, 3.5), c1, .3) end)
	ctx:At(1.9, function() FX.Tween(ring, .6, {Transparency = 1}) end)
	K.Title(ctx, .9, "embers", 7.5)
	return LEN
end

---------------------------------------------------------------- Set 2: explode, rebirth, hover (5.2 s)
function M.Set2(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 5.2
	local P = K.Performer(ctx)
	if not P then return M.Set1(ctx, def) end
	local ring = char(ctx, c2, dark, 0, .5, 1.1)
	ctx:At(.02, function() P:Show() end)
	ctx:Every(function(t) if t < .45 then P:Toward("Crouch", FX.ease(t / .4) * .8) end end)
	local home = ctx.Hrp.CFrame
	K.Shatter(ctx, P, {At = .45, Colors = {c1, c2, c3}, Chunks = 22, Reform = .7, ReformCF = home * CFrame.new(0, 3.5, 0), FanRadius = 7,
		OnExplode = function() ring.Material = Enum.Material.Neon FX.Tween(ring, .25, {Color = c2}) end})
	local Wg
	ctx:At(1.15, function()
		Wg = K.Wings(ctx, P, {Span = 12, Colors = {c1, c2, c3}, Unfold = 1.15, Fold = 4.2, Flap = .7, Flame = true})
	end)
	local lastFlap = 0
	K.Float(ctx, P, {T0 = 1.1, T1 = 4.15, Height = 3.5, Rise = .4, Fall = .35, Spin = math.pi / 3.2, Pose = "Wide", Anchor = home * CFrame.new(0, 3.5, 0),
		OnK = function(k, t)
			if Wg and Wg.Flap < .2 and lastFlap >= .2 then downstroke(ctx, P, c1, c2) end
			if Wg then lastFlap = Wg.Flap end
		end})
	K.Monument(ctx, {Mesh = "SunDisc", Height = 9, Behind = 7, Face = "camera", Scale = .55, Color = c1, In = 2.4, Out = 4.3, Spin = .15, Light = 5})
	K.Herd(ctx, {At = 1.3, Radius = 14, Color = c2, Flavour = "flinch"})
	featherRain(ctx, c1, c2, 1.6, 4.6, 10)
	-- landing: kneel, petals, the ring turns gold
	ctx:At(4.1, function()
		if Wg then Wg:Dissolve(.5) end
		K.PetalFan(ctx, K.GroundCF(ctx, ctx.Base.Position, .3), {Colors = {c1, c2, c3}, Radius = 7, Life = .6})
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .2), 2, 20, c2, .5, .45)
		ctx:Shake(.3, .35)
		FX.Tween(ring, .5, {Color = GOLD})
	end)
	ctx:Every(function(t)
		if t < 4.1 then return end
		if t > 5.1 then return true end
		local k = FX.ease((t - 4.1) / .2) * (1 - FX.ease((t - 4.6) / .5))
		P:Toward("Kneel", k)
	end)
	ctx:At(4.5, function() FX.Tween(ring, .7, {Transparency = 1}) end)
	K.Title(ctx, 4.2, "embers", 7.5)
	return LEN
end

---------------------------------------------------------------- Set 3: the full flight (7.4 s + 1 s charge-up)
function M.Set3(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 7.4
	local P = K.Performer(ctx)
	if not P then return M.Set2(ctx, def) end
	local pre = ctx.Pre or 1
	-- charge-up: crouch, soot, ember veins, the dark ring, grass wilting (a dark stamp), the inhale
	K.ChargeUp(ctx, P, {Sigil = "ScorchRing", SigilScale = 1.2, Pose = "Crouch", PoseK = .9})
	local ring = char(ctx, c2, dark, -pre + .1, .1, 1.3)
	ctx:At(-pre + .3, function() P:Silhouette() end)
	-- t = 0: the explosion; reborn five studs up at 0.75
	local home = ctx.Hrp.CFrame
	local reborn = home * CFrame.new(0, 5, 0)
	K.Shatter(ctx, P, {At = 0, Colors = {c1, c2, c3}, Chunks = 30, Spread = 1.1, Reform = .75, ReformCF = reborn, FanRadius = 9,
		OnExplode = function(origin)
			-- a twelve-stud fire column for a few frames, then the ring ignites
			local col = ctx:Part({Shape = Enum.PartType.Cylinder, Color = W, Transparency = .1, Size = V3(.1, .1, .1)})
			local t0 = os.clock()
			ctx:Every(function()
				local u = (os.clock() - t0) / .22
				if u >= 1 then col:Destroy() return true end
				local w = (1 - u) * 1.6 + .05
				col.Size = V3(12 * FX.ease(u / .3), w, w)
				col.CFrame = CFrame.new(origin.X, ctx.Base.Position.Y + 6, origin.Z) * CFrame.Angles(0, 0, math.pi / 2)
				col.Color = W:Lerp(c2, u)
			end)
			ctx:ImpactFrame()
			ring.Material = Enum.Material.Neon
			FX.Tween(ring, .3, {Color = c2})
			ctx:Grade({Brightness = .08, Contrast = .2, Saturation = .15, TintColor = Color3.fromRGB(255, 236, 214)}, .1, 4.4, .8)
		end})
	-- wings unfold as the body comes back
	local Wg
	ctx:At(.8, function()
		Wg = K.Wings(ctx, P, {Span = 14, Colors = {c1, c2, c3}, Unfold = .8, Fold = 5.0, Flap = .62, Flame = true})
	end)
	-- the spiral: two rising laps, radius 8 -> 4, altitude 2.5 -> 9, then the pull-up to 11
	local centre = home.Position
	local a0 = math.atan2(reborn.Position.Z - centre.Z, reborn.Position.X - centre.X)
	local function spiral(u)
		local a = a0 + u * TAU * 2
		local r = 8 - 4 * u
		local y = 2.5 + 6.5 * u * u + math.sin(u * TAU * 2) * .6
		return centre + V3(math.cos(a) * r, y, math.sin(a) * r)
	end
	local lastFlap, stamped = 0, false
	-- the fire helix the flight leaves behind: a long ribbon trail from the lower torso
	local ribbonHolder = ctx:Part({Transparency = 1, Size = Vector3.one * .2})
	local ra0, ra1 = ctx:Att(V3(0, .9, 0), ribbonHolder), ctx:Att(V3(0, -.9, 0), ribbonHolder)
	local ribbon = Instance.new("Trail")
	ribbon.Attachment0, ribbon.Attachment1 = ra0, ra1
	ribbon.LightEmission, ribbon.LightInfluence = 1, 0
	ribbon.Lifetime = 1.3
	ribbon.Texture = K.Tex.Streak
	ribbon.TextureMode = Enum.TextureMode.Stretch
	ribbon.Color = FX.cseq({W, c1, c2, c3})
	ribbon.Transparency = FX.nseq({{0, .05}, {.5, .3}, {1, 1}})
	ribbon.WidthScale = FX.nseq({{0, 1}, {.7, .8}, {1, 0}})
	ribbon.Enabled = false
	pcall(function() ribbon.Brightness = 3 end)
	ribbon.Parent = ribbonHolder
	K.Fly(ctx, P, {T0 = 1.05, T1 = 4.4, Path = spiral, Bank = 16, Pitch = .5, Pose = "Fly", EaseU = function(u) return u < .15 and FX.ease(u / .15) * .15 or u end,
		OnU = function(u, pos, tangent, cf)
			ribbonHolder.CFrame = cf * CFrame.new(0, -1.2, .6)
			ribbon.Enabled = u > .03
			if Wg and Wg.Flap < .2 and lastFlap >= .2 then downstroke(ctx, P, c1, c2) end
			if Wg then lastFlap = Wg.Flap end
			if not stamped and u > .05 then
				stamped = true
				K.Stamp(ctx, pos, {Mesh = "ScorchRing", Color = c2, Scale = .9, Life = 5})
			end
		end,
		OnDone = function() ribbon.Enabled = false end})
	K.Sweeps(ctx, {Colors = {c1, c2}, T0 = 1.6, T1 = 4.0, Period = .3, Radius = 7, Height = 5, Climb = 9, Dur = .6})
	K.Herd(ctx, {At = 1.5, Radius = 16, Color = c2, Flavour = "flinch"})
	K.Herd(ctx, {At = 3.2, Radius = 16, Color = c2, Flavour = "lookup"})
	featherRain(ctx, c1, c2, 1.5, 6.8, 14)
	-- sun dive: pull vertical to 11 studs, two frames black against the disc, every light in the plaza goes white
	local apex = centre + V3(0, 11, 0)
	local sun = K.Monument(ctx, {Mesh = "SunDisc", Height = 12, Behind = 9, Face = "camera", Scale = 1, Color = c1, In = 4.45, Out = 6.3, Spin = .12, Light = 8})
	K.Fly(ctx, P, {T0 = 4.4, T1 = 4.85, Path = function(u) local s = spiral(1) return s:Lerp(apex, FX.ease(u)) end, Bank = 0, Pitch = .2, Pose = "Star"})
	ctx:At(4.5, function()
		K.FOV(ctx, -7, .12, .5, .35)
		K.LightPaint(ctx, {At = 0, Radius = 45, Color = W, Hold = .6, Boost = 2.5})
		ctx:Flash(c1, .35, .25)
	end)
	ctx:At(4.7, function() P:Silhouette() if Wg then for _, S in Wg.Sides do for _, seg in S.Segs do seg.Color = SOOT end end end end)
	-- golden embers: the body shatters again at the apex, the wings dissolve into rising embers
	ctx:At(4.95, function() if Wg then Wg:Dissolve(.5) end end)
	local landing = CFrame.new(home.Position) * (home - home.Position)
	K.Shatter(ctx, P, {At = 5.0, Colors = {GOLD, c1, c2}, Chunks = 40, Spread = 1.3, Reform = .55, ReformCF = landing, FanRadius = 11,
		OnExplode = function(origin)
			ctx:Burst(origin, K.Count(ctx, 90), {Texture = K.Tex.Star, Color = {W, GOLD, c2}, Size = {{0, .7}, {1, .1}}, Lifetime = {1.4, 2.4}, Speed = {6, 18},
				SpreadAngle = Vector2.new(180, 180), Acceleration = V3(0, -9, 0), Drag = 1.5, Brightness = 5})
		end,
		OnReform = function()
			-- landing: a kneel, petals open flat, grass tufts fly, the scorch ring turns gold
			P:RestoreLook()
			K.PetalFan(ctx, K.GroundCF(ctx, landing.Position, .3), {Colors = {GOLD, c1, c2}, Radius = 9, Life = .6})
			K.ShockRing(ctx, K.GroundCF(ctx, landing.Position, .2), 2, 28, GOLD, .5, .5)
			K.Debris(ctx, {At = 0, Count = 8, Radius = 5, Lift = 2.5, Meshes = {"GrassClump"}, Until = ctx:Elapsed() + .45, Orbit = .2})
			ctx:Shake(.35, .4)
			K.FOV(ctx, 6, .06, .5)
			FX.Tween(ring, .6, {Color = GOLD})
		end})
	ctx:Every(function(t)
		if t < 5.55 then return end
		if t > 7.0 then return true end
		local k = FX.ease((t - 5.55) / .18) * (1 - FX.ease((t - 6.2) / .6))
		P:Toward("Kneel", k)
	end)
	ctx:At(6.6, function() FX.Tween(ring, .8, {Transparency = 1}) end)
	K.Title(ctx, 5.75, "embers", 8)
	return LEN
end

return M
