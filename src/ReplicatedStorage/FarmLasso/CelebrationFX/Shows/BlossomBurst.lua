-- Shows.BlossomBurst: a cherry tree grows behind the player in half a second with a bending overshoot, its canopy
-- pops as three blossoms and pink god rays fan out through it; a 16-petal fan bursts edge-on at the peak with two
-- more waves at other tilts, then petals rain; five plasma orbs (Glass over a Neon pink core, lavender trails) leave
-- on lazy arcs and home on the herd, popping as small blossoms and leaving flower crowns on the animals; flowers pop
-- up in a ring under the canopy; the player floats on a lotus platform, arms wide, with a gentle spin. (Oct 6 2026)
-- Set 1: one blossom pop behind the back plane, three star flares, four god rays, a petal puff. Set 2: the tree,
-- the petal burst, eight god rays, orbs to the animals, flower crowns, the lotus platform. Set 3: a lavender bud
-- closes round the player in the charge-up and bursts at 0, the tree grows, the body explodes into the blossom
-- and re-forms a stud higher, the 12-petal lotus opens petal by petal, three petal waves, petal rain, the lotus
-- closing round the player at the end.
local FX = require(script.Parent.Parent.Parent)
local K = require(script.Parent.Parent.AuraKit)
local V3, W, TAU, rng = Vector3.new, FX.W, K.TAU, FX.rng
local M = {Pre = 1.0}

-- a mesh authored base-at-origin stood on cf; a centred stand-in (no pivot data) is lifted by half its height
local function stand(p, cf, scale)
	K.Place(p, cf, scale)
	if (p.Position - cf.Position).Magnitude < .01 then p.CFrame = cf * CFrame.new(0, p.Size.Y / 2, 0) end
end
-- a lotus petal (authored along -Z from its base) at cf; the stand-in part is pushed out so its base sits at cf
local function petalAt(p, cf, scale)
	if p:IsA("MeshPart") then K.Place(p, cf, scale) else K.Place(p, cf * CFrame.new(0, 0, -1.2 * scale), scale) end
end
-- the fan plane facing this viewer's camera at pos (K.PetalFan wants the normal as UpVector)
local function facing(pos)
	local cam = workspace.CurrentCamera
	local eye = cam and cam.CFrame.Position or (pos + V3(0, 0, 10))
	return CFrame.lookAt(pos, eye) * CFrame.Angles(math.pi / 2, 0, 0)
end

-- the cherry tree: a trunk 6 studs behind the player grown with a bending overshoot over .5 s, three canopy blossoms
-- popping at the top; everything fades after o.T1. Returns T with T.Top (the canopy centre) and T.Base.
local function tree(ctx, c1, c2, c3, dark, o)
	local back = K.Behind(ctx)
	local baseCF = K.GroundCF(ctx, ctx.Base.Position + back * 6, .05)
	local trunkH = o.Height or 12
	local trunk = K.Mesh(ctx, "CherryTrunk", {Color = dark:Lerp(Color3.fromRGB(120, 70, 60), .5), Material = Enum.Material.SmoothPlastic, Transparency = 1})
	local T = {Base = baseCF.Position, Top = baseCF.Position + V3(0, trunkH, 0)}
	local lobes = {}
	for i, off in {V3(0, 0, 0), V3(2.4, -1.2, 1.2), V3(-2.2, -.9, -1.4)} do
		lobes[i] = {M = K.Mesh(ctx, "Canopy", {Color = ({c2, c1, c3})[i], Transparency = 1}), Off = off, S = i == 1 and 1 or .7, Delay = (i - 1) * .08}
	end
	local tPop = o.T0 + .45
	ctx:Every(function(t)
		if t > o.T1 + .8 then trunk:Destroy() for _, l in lobes do l.M:Destroy() end return true end
		local u = (t - o.T0) / .5
		if u < 0 then return end
		local k = FX.back(u)
		local sway = math.sin(math.min(u, 3) * 7) * .14 * math.max(0, 1 - u / 2.5)
		local fade = 1 - FX.ease((t - o.T1) / .7)
		stand(trunk, baseCF * CFrame.Angles(0, 0, sway), V3(1, trunkH / 10 * math.max(.02, k), 1))
		trunk.Transparency = 1 - fade
		T.Top = (trunk.CFrame * CFrame.new(0, trunk.Size.Y / 2, 0)).Position
		for _, l in lobes do
			local kl = FX.back((t - tPop - l.Delay) / .3)
			K.Place(l.M, CFrame.new(T.Top + l.Off * (trunkH / 12)) * CFrame.Angles(0, t * .1, 0), l.S * (trunkH / 12) * math.max(.02, kl) * (o.Scale or 1))
			l.M.Transparency = kl > .02 and (1 - .9 * fade) or 1
		end
	end)
	return T
end
-- n god rays fanned in the camera plane from origin(), slowly rotating, pink; in at T0, out by T1
local function rays(ctx, n, origin, color, T0, T1, len)
	local list = {}
	for i = 1, n do list[i] = {M = K.Mesh(ctx, "GodRay", {Color = color, Transparency = 1}), A = (i - .5) / n * 3.6 - 1.8, W = rng:NextNumber(.7, 1.3)} end
	ctx:Every(function(t)
		if t > T1 + .6 then for _, r in list do r.M:Destroy() end return true end
		local k = K.Soft(t, T0, T1, .5, .5)
		local o = origin()
		local plane = CFrame.lookAt(o, o + K.Behind(ctx))
		for i, r in list do
			local a = r.A + math.sin(t * .5 + i) * .12
			K.Place(r.M, plane * CFrame.Angles(0, 0, a), V3(r.W * 1.6 * k, (len or 14) * k + .01, .1))
			r.M.Transparency = 1 - .45 * k
		end
	end)
end
-- petals drifting down over the area (a box volume emitter 18 studs up)
local function petalRain(ctx, c1, c2, t0, t1, rate)
	local sky = ctx:Part({Transparency = 1, Size = V3(18, 1, 18)})
	local e = ctx:Emitter(sky, {Texture = K.Tex.Petal, Color = {c1, c2}, Size = {.8, .5}, Transparency = {{0, .1}, {.8, .2}, {1, 1}}, Lifetime = {2.2, 3.2}, Speed = {.5, 1.5},
		SpreadAngle = Vector2.new(180, 180), Rate = 0, Acceleration = V3(0, -4.5, 0), Drag = 2.5, RotSpeed = {-220, 220}, Rotation = {0, 360}, Brightness = 2,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume})
	ctx:Every(function(t)
		sky.CFrame = ctx.Base * CFrame.new(0, 18, 0)
		e.Rate = (t > t0 and t < t1) and (rate or 18) * (ctx.Quality or 1) or 0
		if t > t1 then return true end
	end)
end
-- the petal fan waves: a 16-petal pop at cf, then more at other tilts, .15 s apart
local function waves(ctx, cf, colors, radius, tilts)
	for i, tilt in tilts do
		task.delay((i - 1) * .15, function() K.PetalFan(ctx, cf * CFrame.Angles(tilt, 0, tilt * .6), {Colors = colors, Radius = radius * (1 - (i - 1) * .15), Life = .55}) end)
	end
end
-- 12 flowers pop up in a ring (lotus petals standing closed), staggered, gone after life
local function flowerRing(ctx, centre, r, c1, c2, at, life)
	local n = K.Count(ctx, 12)
	local list = {}
	for i = 1, n do list[i] = {M = K.Mesh(ctx, "LotusPetal", {Color = i % 2 == 0 and c1 or c2, Transparency = 1}), A = (i - 1) / n * TAU, D = (i - 1) * .05} end
	ctx:Every(function(t)
		local age = t - at
		if age < 0 then return end
		if age > life then for _, f in list do f.M:Destroy() end return true end
		for _, f in list do
			local k = FX.back((age - f.D) / .2) * (1 - FX.ease((age - life + .5) / .5))
			f.G = f.G or K.GroundCF(ctx, centre + K.Polar(f.A, r, 0), .05)
			petalAt(f.M, f.G * CFrame.Angles(0, f.A, 0) * CFrame.Angles(1.1, 0, 0), .8 * math.max(.02, k))
			f.M.Transparency = k > .02 and .05 or 1
		end
	end)
end
-- the plasma orbs: Count Glass balls with a Neon pink core and a lavender trail leave the chest on lazy arcs, animals
-- first, then other players, then spots in the grass; each pops as a small blossom and crowns the animal with a
-- FlowerCrown that follows its head until o.Until.
local function orbs(ctx, c1, c2, c3, o)
	local n = K.Count(ctx, o.Count or 5)
	local targets = K.NearbyAnimals(ctx, 30)
	for _, p in K.NearbyPlayers(ctx, 40) do table.insert(targets, p) end
	local j = 0
	while #targets < n do
		j += 1
		table.insert(targets, {Pos = K.Ground(ctx, ctx.Base.Position + K.Polar(j / n * TAU + rng:NextNumber(0, .5), rng:NextNumber(8, 14), 0)) + V3(0, .6, 0), Kind = "point"})
	end
	local list, crowns = {}, {}
	local function from()
		local P = ctx.Performer
		return (P and P.Alive and P.Torso or ctx.Hrp).Position
	end
	ctx:At(o.T0, function()
		for i = 1, n do
			local tg = targets[(i - 1) % #targets + 1]
			local p0 = from()
			local shell = ctx:Part({Shape = Enum.PartType.Ball, Material = Enum.Material.Glass, Color = c3, Size = Vector3.one * 1.1, Transparency = .3, CFrame = CFrame.new(p0)})
			local core = ctx:Part({Shape = Enum.PartType.Ball, Color = c2, Size = Vector3.one * .5, CFrame = CFrame.new(p0)})
			local a0, a1 = ctx:Att(V3(0, .4, 0), shell), ctx:Att(V3(0, -.4, 0), shell)
			local tr = Instance.new("Trail")
			tr.Attachment0, tr.Attachment1 = a0, a1
			tr.LightEmission, tr.LightInfluence = 1, 0
			tr.Lifetime = .9
			tr.Color = FX.cseq({W, c2, c3})
			tr.Transparency = FX.nseq({{0, .1}, {.5, .4}, {1, 1}})
			tr.WidthScale = FX.nseq({{0, 1}, {1, 0}})
			pcall(function() tr.Brightness = 2.5 end)
			tr.Parent = shell
			ctx:Light(a0, c2, 12, 3)
			local goal = K.TargetPos(tg, 2.4)
			list[i] = {Shell = shell, Core = core, Tg = tg, P0 = p0, Born = o.T0 + (i - 1) * (o.Interval or .2), Dur = math.max(.8, (goal - p0).Magnitude / 12),
				Ctrl = (p0 + goal) / 2 + V3(rng:NextNumber(-6, 6), rng:NextNumber(5, 9), rng:NextNumber(-6, 6)), Done = false}
		end
	end)
	ctx:Every(function(t)
		if t > o.Until + .8 then for _, c in crowns do c.M:Destroy() end return true end
		for _, ob in list do
			if ob.Done then continue end
			local u = (t - ob.Born) / ob.Dur
			if u < 0 then continue end
			local goal = K.TargetPos(ob.Tg, 2.4)
			if u >= 1 then
				ob.Done = true
				ob.Shell:Destroy() ob.Core:Destroy()
				K.PetalFan(ctx, CFrame.new(goal), {Colors = {c1, c2, c3}, Radius = 3, Life = .45})
				ctx:Burst(goal, K.Count(ctx, 14), {Texture = K.Tex.Petal, Color = {c1, c2}, Size = {.6, .3}, Lifetime = {.8, 1.4}, Speed = {2, 5}, SpreadAngle = Vector2.new(180, 180),
					Acceleration = V3(0, -5, 0), Drag = 3, RotSpeed = {-200, 200}, Brightness = 2})
				if ob.Tg.Model and ob.Tg.Kind ~= "point" then
					local hl = Instance.new("Highlight")
					hl.Adornee, hl.FillColor, hl.OutlineColor = ob.Tg.Model, c2, c1
					hl.FillTransparency, hl.OutlineTransparency = .3, 0
					hl.DepthMode = Enum.HighlightDepthMode.Occluded
					hl.Parent = ctx.Folder
					FX.Tween(hl, .45, {FillTransparency = 1, OutlineTransparency = 1})
					task.delay(.5, function() hl:Destroy() end)
					table.insert(crowns, {M = K.Mesh(ctx, "FlowerCrown", {Color = c2}), Tg = ob.Tg, Head = ob.Tg.Model:FindFirstChild("Head"), Born = t})
				end
			else
				local pos = K.Bezier(ob.P0, ob.Ctrl, goal, FX.ease(u)) + V3(0, math.sin(t * 6 + ob.Born) * .3, 0)
				ob.Shell.CFrame = CFrame.new(pos) * CFrame.Angles(t * 2, t * 3, 0)
				ob.Core.CFrame = CFrame.new(pos)
				ob.Core.Size = Vector3.one * (.5 + .1 * math.sin(t * 14))
			end
		end
		for _, c in crowns do
			local part = c.Head or c.Tg.Part
			if not part or not part.Parent then c.M.Transparency = 1 continue end
			local k = FX.back((t - c.Born) / .3) * (1 - FX.ease((t - o.Until) / .6))
			K.Place(c.M, CFrame.new(part.Position + V3(0, part.Size.Y / 2 + .35, 0)) * CFrame.Angles(0, t * .8, 0), math.max(.02, k))
			c.M.Transparency = k > .02 and .05 or 1
		end
	end)
end
-- the lotus platform under the performer's feet: a single Lotus mesh (o.Single) opening with overshoot, or 12 lotus
-- petals opening one by one; closes again from o.T1 and is gone by o.T2
local function lotus(ctx, P, c1, c2, c3, o)
	local hip = (ctx.Hum and ctx.Hum.HipHeight or 2) + P.Root.Size.Y / 2 - .2
	local petals = {}
	if o.Single then
		petals[1] = {M = K.Mesh(ctx, "Lotus", {Color = c2, Transparency = 1})}
	else
		for i = 1, 12 do petals[i] = {M = K.Mesh(ctx, "LotusPetal", {Color = i % 3 == 0 and c3 or (i % 2 == 0 and c1 or c2), Transparency = 1}), A = (i - 1) / 12 * TAU, D = (i - 1) * .06} end
	end
	ctx:Every(function(t)
		if not P.Alive or t > o.T2 then for _, p in petals do p.M:Destroy() end return true end
		local lv = P.Root.CFrame.LookVector
		local cf = CFrame.new(P.Root.Position - V3(0, hip, 0)) * CFrame.Angles(0, math.atan2(-lv.X, -lv.Z), 0)
		local vis = 1 - FX.ease((t - o.T1 - .5) / (o.T2 - o.T1 - .5))
		if o.Single then
			local k = FX.back((t - o.T0) / .4) * (1 - FX.ease((t - o.T1) / .4))
			K.Place(petals[1].M, cf * CFrame.Angles(0, t * .3, 0), (o.Scale or 1.1) * math.max(.02, k))
			petals[1].M.Transparency = k > .02 and 1 - .9 * vis or 1
		else
			for _, p in petals do
				local open = FX.ease((t - o.T0 - p.D) / .3) * (1 - FX.ease((t - o.T1 - p.D * .6) / .45))
				local k = FX.back((t - o.T0 - p.D) / .25)
				petalAt(p.M, cf * CFrame.Angles(0, p.A + t * .25, 0) * CFrame.new(0, 0, -.5) * CFrame.Angles(1.35 * (1 - open), 0, 0), 1.15 * math.max(.02, k))
				p.M.Transparency = k > .02 and 1 - .92 * vis or 1
			end
		end
	end)
end

---------------------------------------------------------------- Set 1: one blossom, three flares, four rays, a petal puff (2.8 s)
function M.Set1(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 2.8
	local back = K.Behind(ctx)
	local lobe = K.Mesh(ctx, "Canopy", {Color = c2, Transparency = 1})
	local pos = ctx.Base.Position + back * 3.5 + V3(0, 5.5, 0)
	ctx:Every(function(t)
		if t > 2.4 then lobe:Destroy() return true end
		local k = FX.back(t / .3) * (1 - FX.ease((t - 1.9) / .5))
		K.Place(lobe, CFrame.new(pos) * CFrame.Angles(0, t * .2, 0), .8 * math.max(.02, k))
		lobe.Transparency = k > .02 and .05 or 1
	end)
	rays(ctx, 4, function() return pos end, c2, .15, 2.1, 9)
	ctx:At(.12, function()
		K.PetalFan(ctx, facing(pos), {Colors = {c1, c2, c3}, Radius = 5, Life = .5})
		ctx:Burst(pos, K.Count(ctx, 18), {Texture = K.Tex.Petal, Color = {c1, c2}, Size = {.8, .5}, Lifetime = {1.2, 1.8}, Speed = {3, 7}, SpreadAngle = Vector2.new(180, 180),
			Acceleration = V3(0, -5, 0), Drag = 3, RotSpeed = {-200, 200}, Brightness = 2})
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .15), 2, 12, c2, .45, .35)
	end)
	ctx:Repeat(.4, 1.3, .3, function(i) ctx:Flare(ctx.Base.Position + K.Polar(i * 2.1, 2.5, 2 + i), 2.8, i == 2 and c3 or c1, .35) end)
	K.Title(ctx, .9, "embers", 7.5)
	return LEN
end

---------------------------------------------------------------- Set 2: the tree, the petal burst, orbs, the lotus (5.2 s)
function M.Set2(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 5.2
	local P = K.Performer(ctx)
	if not P then return M.Set1(ctx, def) end
	ctx:At(.02, function() P:Show() end)
	local T = tree(ctx, c1, c2, c3, dark, {T0 = .1, T1 = 4.4, Height = 12})
	rays(ctx, 8, function() return T.Top end, c2, .6, 4.4, 14)
	ctx:At(.55, function()
		waves(ctx, facing(T.Top), {c1, c2, c3}, 9, {0, .5})
		K.Starburst(ctx, T.Top, {Colors = {c1, c2}, Size = 9, Count = 24})
		ctx:Shake(.2, .3)
	end)
	petalRain(ctx, c1, c2, .8, 4.6, 12)
	orbs(ctx, c1, c2, c3, {T0 = 1.0, Count = 5, Interval = .2, Until = 4.4})
	flowerRing(ctx, T.Base, 4, c1, c2, 1.3, 3.2)
	K.Herd(ctx, {At = 1.2, Radius = 14, Color = c2, Flavour = "lookup"})
	lotus(ctx, P, c1, c2, c3, {Single = true, T0 = .85, T1 = 4.3, T2 = 5.0})
	K.Float(ctx, P, {T0 = .9, T1 = 4.4, Height = 3, Rise = .7, Fall = .4, Spin = .5, Pose = "Wide"})
	K.Title(ctx, 1.0, "embers", 7.5)
	return LEN
end

---------------------------------------------------------------- Set 3: the bud, the tree, the blossom re-form, the 12-petal lotus (8 s + 1 s charge-up)
function M.Set3(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 8.0
	local P = K.Performer(ctx)
	if not P then return M.Set2(ctx, def) end
	local pre = ctx.Pre or 1
	K.ChargeUp(ctx, P, {Sigil = "Lotus", SigilScale = 1.4, Pose = "Crouch", PoseK = .8})
	-- the lavender bud: two Glass canopy halves close round the player during the charge-up and glow from inside
	local halves = {}
	for i = 1, 2 do halves[i] = K.Mesh(ctx, "Canopy", {Color = c3, Material = Enum.Material.Glass, Transparency = 1}) end
	local budLight = ctx:Light(ctx:Att(V3(0, 3, 0)), c3, 18, 0)
	ctx:Every(function(t)
		if t >= 0 then
			for i, h in halves do FX.Tween(h, .3, {Transparency = 1, CFrame = h.CFrame * CFrame.new(0, i == 1 and 5 or -2, 0)}) task.delay(.35, function() h:Destroy() end) end
			FX.Tween(budLight, .3, {Brightness = 0})
			return true
		end
		local u = 1 + t / pre
		local k = FX.ease(u)
		local c = ctx.Hrp.Position
		K.Place(halves[1], CFrame.new(c + V3(0, 9 - 6.6 * k, 0)) * CFrame.Angles(0, t * .3, 0), V3(.75, .55, .75))
		K.Place(halves[2], CFrame.new(c + V3(0, -6 + 4.4 * k, 0)) * CFrame.Angles(math.pi, t * .3, 0), V3(.75, .55, .75))
		for _, h in halves do h.Transparency = .9 - .45 * k end
		budLight.Brightness = 6 * k * (.8 + .2 * math.sin(t * 9))
	end)
	-- t = 0: the bud bursts; the tree grows behind
	ctx:At(0, function()
		ctx:Flash(c1, .4, .3)
		K.Starburst(ctx, ctx.Hrp.Position, {Colors = {c1, c2}, Size = 12, Count = 36})
		K.PetalFan(ctx, facing(ctx.Hrp.Position), {Colors = {c3, c2, c1}, Radius = 7, Life = .5})
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .2), 2, 30, c2, .5, .5)
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .25), 2, 36, dark, .8, .4)
		ctx:Shake(.3, .35)
		ctx:Grade({Brightness = .05, Contrast = .15, Saturation = .2, TintColor = Color3.fromRGB(255, 236, 246)}, .15, 6.5, .9)
	end)
	local T = tree(ctx, c1, c2, c3, dark, {T0 = .1, T1 = 7.0, Height = 16})
	rays(ctx, 10, function() return T.Top end, c2, .6, 6.9, 18)
	-- the body goes to blossom and re-forms a stud higher with petals peeling off the skin; the lotus opens under it
	local home = ctx.Hrp.CFrame
	K.Shatter(ctx, P, {At = .7, Colors = {c1, c2, c3}, Chunks = 24, Spread = .9, Reform = .6, ReformCF = home * CFrame.new(0, 1, 0), FanRadius = 8,
		OnReform = function()
			local peel = ctx:Emitter(ctx:Att(nil, P.Torso), {Texture = K.Tex.Petal, Color = {c1, c2}, Size = {.7, .4}, Transparency = {{0, .1}, {1, 1}}, Lifetime = {.9, 1.5},
				Speed = {2, 4}, SpreadAngle = Vector2.new(180, 180), Rate = 24 * (ctx.Quality or 1), Acceleration = V3(0, -4, 0), Drag = 3, RotSpeed = {-200, 200}, Brightness = 2,
				Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface})
			task.delay(1.0, function() peel.Rate = 0 end)
		end})
	K.Herd(ctx, {At = .75, Radius = 16, Color = c2, Flavour = "flinch"})
	lotus(ctx, P, c1, c2, c3, {T0 = 1.2, T1 = 6.2, T2 = 7.2})
	K.Float(ctx, P, {T0 = 1.24, T1 = 6.4, Height = 3.5, Rise = .9, Fall = .45, Spin = .55, Pose = "Wide"})
	-- the peak: the canopy pops with the petal fan edge-on behind the player, two more waves, the rain, the orbs leave
	ctx:At(1.35, function()
		waves(ctx, facing(T.Top), {c1, c2, c3}, 10, {0, .5, -.5})
		K.Starburst(ctx, T.Top, {Colors = {c1, c2}, Size = 10, Count = 28})
		K.FOV(ctx, 5, .08, .5)
	end)
	petalRain(ctx, c1, c2, 1.4, 7.0, 16)
	orbs(ctx, c1, c2, c3, {T0 = 1.8, Count = 5, Interval = .2, Until = 6.8})
	flowerRing(ctx, T.Base, 4.5, c1, c2, 2.0, 4.6)
	K.Herd(ctx, {At = 2.6, Radius = 16, Color = c2, Flavour = "lookup"})
	-- the settle: the lotus closes round the player, petals and rays fade, the tree goes last
	ctx:At(6.3, function() K.PetalFan(ctx, K.GroundCF(ctx, ctx.Base.Position, .3), {Colors = {c3, c2, c1}, Radius = 6, Life = .6}) end)
	K.Title(ctx, 1.7, "embers", 8)
	return LEN
end

return M
