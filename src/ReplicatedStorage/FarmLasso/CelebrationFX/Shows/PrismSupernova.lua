-- Shows.PrismSupernova: time freezes properly: emitters and animals within thirty studs stop and the world drains to
-- grey while the player stutters mid-cheer under a glass prism; a white star condenses at the chest, time snaps back
-- and it explodes in three stacked shells (a white starburst, a magenta petal fan, cyan ribbon arcs leaving the
-- frame); seven coloured rays fan out of the prism and sweep the plaza like a lighthouse, painting every animal and
-- player they cross, with a lens flare when one points at the camera; glass shards scatter with rainbow trails and
-- embed in the ground; the body shatters for three frames and re-forms hovering two studs up with palms out under a
-- crown of seven gems that cycles through the spectrum, and lands with it. (Oct 6 2026)
-- Set 1: a 0.2 s desaturation, a triple flash behind the back plane, four arcs, a small crown. Set 2: the freeze, the
-- triple shell, one ray rotation, the crown. Set 3: colour drains over the charge-up, two rotations, the shard scatter.
local FX = require(script.Parent.Parent.Parent)
local K = require(script.Parent.Parent.AuraKit)
local S = require(script.Parent.Parent.AuraSound)
local V3, W, TAU, rng = Vector3.new, FX.W, K.TAU, FX.rng
local RB = FX.Rainbow
local PALMS = {RightElbow = CFrame.Angles(.85, 0, .35), LeftElbow = CFrame.Angles(.85, 0, -.35)}
local M = {Pre = 1.0}

local function headPos(ctx)
	local P = ctx.Performer
	local h = (P and P.Alive and P.Head) or ctx.Char:FindFirstChild("Head")
	return h and h.Position or ctx.Hrp.Position + V3(0, 1.5, 0)
end
-- the spectrum, shifted one step every 0.3 s
local function hue(t, i) return RB[((i - 1 + math.floor(t / .3)) % 7) + 1] end

-- the prism: a Glass crystal 2.6 studs over the head, slowly turning, with a white Neon core at .6 scale. Pm.Pos().
local function prism(ctx, o)
	local crystal = K.Mesh(ctx, "PrismCrystal", {Material = Enum.Material.Glass, Color = Color3.fromRGB(235, 240, 255), Transparency = 1})
	local core = K.Mesh(ctx, "PrismCrystal", {Color = W, Transparency = 1})
	local light = ctx:Light(ctx:Att(nil, core), W, 14, 0)
	local Pm = {Last = headPos(ctx) + V3(0, 2.6, 0)}
	function Pm.Pos() return Pm.Last end -- (cached: the rays keep reading it for a few frames after the prism goes)
	ctx:Every(function(t)
		if t > o.T1 + .5 then crystal:Destroy() core:Destroy() return true end
		local k = K.Env(t, o.T0, o.T1, .35, .45)
		local kc = math.clamp(k, 0, 1)
		local cf = CFrame.new(headPos(ctx) + V3(0, 2.6 + math.sin(t * 1.3) * .1, 0)) * CFrame.Angles(0, t * .7, math.sin(t * .9) * .08)
		Pm.Last = cf.Position
		K.Place(crystal, cf, (o.Scale or 1) * math.max(.01, k))
		K.Place(core, cf * CFrame.Angles(0, -t * .4, 0), (o.Scale or 1) * .6 * math.max(.01, k))
		crystal.Transparency = 1 - .7 * kc
		core.Transparency = 1 - kc
		light.Brightness = 3 * kc
	end)
	return Pm
end
-- the crown: seven gems in spectral colours orbiting 1.6 studs over the head at Radius, hues stepping round every
-- 0.3 s, under a thin ring that cycles with them; it follows the head, so it lands when the player does
local function crown(ctx, o)
	local R = o.Radius or 1.6
	local gems = {}
	for i = 1, 7 do gems[i] = K.Mesh(ctx, "Gem", {Color = RB[i], Transparency = 1}) end
	local ring = ctx:Ring("RingThin", R * 2.2, .1, W, 1)
	local light = ctx:Light(ctx:Att(nil, ring), W, 10, 0)
	ctx:Every(function(t)
		if t > o.T1 + .5 then for _, g in gems do g:Destroy() end ring:Destroy() return true end
		local k = K.Env(t, o.T0, o.T1, .4, .45)
		local kc = math.clamp(k, 0, 1)
		local centre = headPos(ctx) + V3(0, 1.6, 0)
		for i, g in gems do
			local a = (i - 1) / 7 * TAU + t * 1.5
			K.Place(g, CFrame.new(centre + K.Polar(a, R * k, math.sin(t * 2.2 + i) * .12)) * CFrame.Angles(t * 2, t * 1.3 + i, 0), (o.Scale or 1) * math.max(.01, k))
			g.Color = hue(t, i)
			g.Transparency = 1 - kc
		end
		K.SetRing(ring, math.max(.1, R * 2.2 * k))
		ring.CFrame = CFrame.new(centre + V3(0, .25, 0)) * CFrame.Angles(0, t * .6, 0) * FX.FLAT
		ring.Color = hue(t, 1)
		ring.Transparency = 1 - .85 * kc
		light.Brightness = 2.5 * kc
		light.Color = hue(t, 4)
	end)
end
-- the freeze: the double snaps into the cheer and holds it with three stutter ticks (the pose offsets snap a further
-- 0.08 rad every 0.12 s) while two past copies trail it; ends at t1 (the snap)
local function freeze(ctx, P, t0, t1)
	local last, tbl = -1, {}
	ctx:Every(function(t)
		if not P.Alive then return true end
		if t < t0 then return end
		if t >= t1 then return true end
		local n = math.min(3, math.floor((t - t0) / .12))
		if n ~= last then
			last = n
			tbl = {}
			for name, off in P.Poses.Freeze do tbl[name] = off * CFrame.Angles(.08 * n, 0, .05 * n * (n % 2 == 0 and 1 or -1)) end
		end
		P:Pose(tbl, 1)
	end)
	K.Echo(ctx, P, {Count = 2, Delay = .12, Color = W, Transparency = .5, T0 = t0, T1 = t1 + .15})
end
-- the white star condensing at the chest: one locked particle growing from nothing to four studs over 0.4 s
local function star(ctx, P, at, c3)
	local att = ctx:Att(nil, P.Torso)
	local e = ctx:Emitter(att, {Texture = K.Tex.Star, Color = {c3, W, W}, Size = {{0, 0}, {.7, 2.5}, {1, 4}}, Transparency = {{0, .7}, {.5, .2}, {1, 0}}, Lifetime = .4,
		LockedToPart = true, Rate = 0, Brightness = 8, Rotation = {0, 45}, RotSpeed = {120, 120}})
	local l = ctx:Light(att, W, 18, 0)
	ctx:At(at, function() e:Emit(1) FX.Tween(l, .4, {Brightness = 8}) end)
	ctx:At(at + .42, function() l.Brightness = 0 end)
end
-- the three stacked shells at the snap: a white starburst, a magenta petal fan facing the camera, `arcs` cyan arcs
-- that orbit once and climb out of the frame
local function shells(ctx, pos, at, size, c2, c3, arcs)
	K.Starburst(ctx, pos, {Colors = {W, W}, Size = size, Count = 44})
	local cam = workspace.CurrentCamera
	local eye = cam and cam.CFrame.Position or pos - K.Behind(ctx) * 20
	K.PetalFan(ctx, CFrame.lookAt(pos, eye) * CFrame.Angles(math.pi / 2, 0, 0), {Colors = {c2, W, c2}, Radius = size * .55, Life = .55})
	K.Sweeps(ctx, {Colors = {c3, W}, T0 = at, T1 = at + arcs * .05, Period = .05, Radius = 4.5, Height = 3, Climb = 12, Dur = .5, Width = .9})
end
-- the seven rays: thin wedges thirty studs long fanned from the prism in spectral order, tilted down a little, sweeping
-- round like a lighthouse (one turn per 2.4 s) with a light twelve studs out; a lens flare when a ray points at the
-- camera; every animal or player a ray crosses is painted in that ray's colour for half a second (one Highlight per
-- target, retinted). o: T0, Turns, Origin (fn -> pos), Leave (seconds the last tint stays after the rays end)
local function rays(ctx, o)
	local T0, T1 = o.T0, o.T0 + o.Turns * 2.4
	local list, targets = {}, {}
	for i = 1, 7 do S.Cue(ctx, T0 + (i - 1) * .1, "LighthouseSweep", {Pitch = 1 + i * .06, Volume = .6, At = o.Origin}) end
	ctx:At(T0, function()
		for i = 1, 7 do
			local r = K.Mesh(ctx, "GodRay", {Color = RB[i], Transparency = .35})
			list[i] = {M = r, L = ctx:Light(ctx:Att(V3(0, -3, 0), r), RB[i], 14, 0), Last = 0}
		end
		for _, tg in K.NearbyAnimals(ctx, 30) do if #targets < 10 then table.insert(targets, tg) end end
		for _, tg in K.NearbyPlayers(ctx, 30) do if #targets < 12 then table.insert(targets, tg) end end
		for _, tg in targets do
			local hl = Instance.new("Highlight")
			hl.Adornee = tg.Model
			hl.FillTransparency, hl.OutlineTransparency = 1, 1
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.Parent = ctx.Folder
			tg.HL = hl
		end
	end)
	local EL = math.rad(12)
	local leave = o.Leave or 0
	ctx:Every(function(t)
		if t < T0 or #list == 0 then return end
		if t > T1 + leave + .5 then
			for _, r in list do r.M:Destroy() end
			for _, tg in targets do tg.HL:Destroy() end
			return true
		end
		local now = os.clock()
		local k = K.Soft(t, T0, T1, .3, .35)
		local pos = o.Origin()
		local cam = workspace.CurrentCamera
		local look = cam and cam.CFrame.LookVector
		for i, r in list do
			local yaw = (t - T0) * TAU / 2.4 + (i - 1) * TAU / 7
			local dir = V3(math.cos(yaw) * math.cos(EL), -math.sin(EL), math.sin(yaw) * math.cos(EL))
			K.Place(r.M, CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-math.pi / 2, 0, 0), V3(.4 + .3 * k, 30 * math.max(.01, k), .4 + .3 * k))
			r.M.Transparency = 1 - .65 * k
			r.L.Brightness = 3 * k
			if look and k > .5 and dir:Dot(look) < -.9 and now - r.Last > .6 then r.Last = now ctx:Flare(pos + dir * 30, 7, RB[i], .3) end
			if k > .5 then
				for _, tg in targets do
					if tg.Part.Parent then
						local d = tg.Part.Position - pos
						local diff = (math.atan2(d.Z, d.X) - yaw + math.pi) % TAU - math.pi
						if math.abs(diff) < math.rad(7) and d.Magnitude < 32 then tg.Hit, tg.Col = now, RB[i] end
					end
				end
			end
		end
		for _, tg in targets do
			if tg.Hit then
				local fade = FX.ease((now - tg.Hit) / .5)
				if t > T1 and leave > 0 then fade = math.min(fade, .4) end -- each painted thing keeps its last colour
				if t > T1 + leave then fade = math.max(fade, FX.ease((t - T1 - leave) / .5)) end
				tg.HL.FillColor, tg.HL.OutlineColor = tg.Col, tg.Col
				tg.HL.FillTransparency, tg.HL.OutlineTransparency = .3 + .7 * fade, fade
			end
		end
	end)
end
-- the glass shards: Count(24) Glass slivers flung out from the prism with rainbow trails, falling under gravity,
-- embedding tilted in the ground and fading
local function shards(ctx, at, origin)
	ctx:At(at, function()
		local from = origin()
		S.Now(ctx, "GlassShatter", {At = from})
		local list = {}
		for i = 1, K.Count(ctx, 24) do
			local col = RB[(i - 1) % 7 + 1]
			local m = K.Mesh(ctx, "GlassShard", {Material = Enum.Material.Glass, Color = col, Transparency = .15})
			if not m:IsA("MeshPart") then m.Size = V3(.6, 2.2, .06) m:SetAttribute("BaseSize", m.Size) end
			local a0, a1 = ctx:Att(V3(0, .5, 0), m), ctx:Att(V3(0, -.5, 0), m)
			local tr = Instance.new("Trail")
			tr.Attachment0, tr.Attachment1 = a0, a1
			tr.LightEmission, tr.LightInfluence = 1, 0
			tr.Lifetime = .4
			tr.Texture = K.Tex.Streak
			tr.TextureMode = Enum.TextureMode.Stretch
			tr.Color = FX.cseq({W, col})
			tr.Transparency = FX.nseq({{0, .1}, {.6, .4}, {1, 1}})
			tr.WidthScale = FX.nseq({{0, 1}, {1, 0}})
			pcall(function() tr.Brightness = 3 end)
			tr.Parent = m
			local dir = (K.RandUnit() * V3(1, .5, 1) + V3(0, .55, 0)).Unit
			local v = dir * rng:NextNumber(13, 22)
			local gy = K.Ground(ctx, from + V3(v.X, 0, v.Z) * .9).Y
			list[i] = {M = m, Tr = tr, Pos = from, V = v, Spin = rng:NextNumber(3, 8), G = gy, S = rng:NextNumber(.7, 1.2)}
		end
		local age = 0
		ctx:Every(function(_, dt)
			age += dt
			local live = false
			for _, s in list do
				if s.Done then continue end
				live = true
				s.V += V3(0, -40, 0) * dt
				s.Pos += s.V * dt
				if s.Pos.Y <= s.G + .5 and s.V.Y < 0 then
					s.Pos = V3(s.Pos.X, s.G + .5, s.Pos.Z)
					s.Done = true
					s.Tr.Enabled = false
					FX.Tween(s.M, 1.4, {Transparency = 1})
					task.delay(1.5, function() s.M:Destroy() end)
				end
				K.Place(s.M, CFrame.lookAt(s.Pos, s.Pos + s.V) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, age * s.Spin, 0), s.S)
			end
			return not live
		end)
	end)
end
-- the re-formed body hovers h studs up with arms wide and palms out from t0, settling to the ground over the last
-- 0.45 s before t1, then follows the real character again
local function hover(ctx, P, t0, t1, h)
	local home = ctx.Hrp.CFrame
	ctx:Every(function(t)
		if not P.Alive then return true end
		if t < t0 then return end
		if t > t1 then P.Follow = true return true end
		local k = 1 - FX.ease((t - (t1 - .45)) / .45)
		local base = CFrame.new(ctx.Hrp.Position) * (home - home.Position)
		P:Pivot(base * CFrame.new(0, h * k + math.sin(t * 1.7) * .2 * k, 0) * CFrame.Angles(math.sin(t * 1.1) * .03 * k, 0, math.cos(t * .9) * .03 * k))
		P:Toward("Wide", k)
		P:Pose(PALMS, k)
	end)
end

---------------------------------------------------------------- Set 1: the triple flash (2.6 s)
function M.Set1(ctx, def)
	local _, c2, c3 = K.Palette(def)
	local LEN = 2.6
	-- a 0.2 s desaturation (no time scale), the small prism, three flashes behind the back plane 0.08 s apart
	ctx:Grade({Saturation = -1}, .05, .15, .3)
	prism(ctx, {T0 = 0, T1 = 2.1, Scale = .7})
	local back = K.Behind(ctx)
	for i, c in {c2, c3, W} do
		ctx:At(.3 + (i - 1) * .08, function()
			K.Starburst(ctx, ctx.Hrp.Position + back * 3 + V3(0, 1, 0), {Colors = {W, c}, Size = 5 + i * 2, Count = 14 + i * 4})
		end)
	end
	ctx:At(.3, function() K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .15), 2, 12, c2, .45, .4) end)
	-- four ribbon arcs leave the frame, the small crown forms
	K.Sweeps(ctx, {Colors = {c3, W}, T0 = .35, T1 = .55, Period = .05, Radius = 4, Height = 3, Climb = 10, Dur = .5, Width = .8})
	crown(ctx, {T0 = .5, T1 = 2.15, Radius = 1.2, Scale = .7})
	S.Cue(ctx, .3, "CelShockwave")
	S.Cue(ctx, .5, "GemCrown", {Volume = .6})
	S.Cue(ctx, 1.0, "CelTitle")
	K.Title(ctx, 1.0, "glitch", 7.5)
	return LEN
end

---------------------------------------------------------------- Set 2: the freeze, the triple shell, one rotation (5.2 s)
function M.Set2(ctx, def)
	local _, c2, c3 = K.Palette(def)
	local LEN = 5.2
	local P = K.Performer(ctx)
	if not P then return M.Set1(ctx, def) end
	ctx:At(.02, function() P:Show() end)
	local SNAP = .55
	-- the 0.4 s world freeze: time stops, the picture drains, the double stutters under the prism, the star condenses
	K.TimeScale(ctx, {T0 = .05, T1 = SNAP, Radius = 30, Scale = .02})
	ctx:Grade({Saturation = -1}, .1, SNAP - .1, .4)
	freeze(ctx, P, .05, SNAP)
	for i = 1, 2 do S.Cue(ctx, .05 + i * .12, "CelImpact", {Volume = .35, Pitch = 1.3, Rate = 1}) end -- sound: the stutter ticks (rate pinned inside the freeze)
	local Pm = prism(ctx, {T0 = .15, T1 = 4.4})
	star(ctx, P, SNAP - .4, c3)
	-- the snap: time resumes, the impact frame, the body shatters for three frames inside the three shells
	local home = ctx.Hrp.CFrame
	K.Shatter(ctx, P, {At = SNAP, Colors = {W, c2, c3}, Chunks = 20, Spread = .9, Reform = .35, ReformCF = home * CFrame.new(0, 2, 0), FanRadius = 3,
		OnExplode = function(origin)
			ctx:ImpactFrame()
			S.Now(ctx, "CelImpact")
			S.Now(ctx, "CelDetonate", {At = origin})
			shells(ctx, origin, SNAP, 18, c2, c3, 6)
		end})
	K.Herd(ctx, {At = SNAP + .05, Radius = 16, Color = c2, Flavour = "flinch"})
	-- re-formed hovering with palms out; the rays sweep once and paint the plaza; the crown forms and lands with the player
	hover(ctx, P, SNAP + .37, 4.6, 2)
	rays(ctx, {T0 = 1.0, Turns = 1, Origin = Pm.Pos})
	crown(ctx, {T0 = 1.0, T1 = 4.8, Radius = 1.6})
	S.Duck(ctx, 0, LEN)
	for i = 0, 2 do S.Cue(ctx, SNAP + i * .12, "CelShockwave", {Volume = i == 0 and 1 or .7}) end
	S.Cue(ctx, 1.0, "GemCrown")
	S.Cue(ctx, 3.8, "CelTitle")
	S.Cue(ctx, 4.6, "CelLand")
	K.Title(ctx, 3.8, "glitch", 7.5)
	return LEN
end

---------------------------------------------------------------- Set 3: the full freeze, two rotations, the shards (7.6 s + 1 s charge-up)
function M.Set3(ctx, def)
	local _, c2, c3 = K.Palette(def)
	local LEN = 7.6
	local P = K.Performer(ctx)
	if not P then return M.Set2(ctx, def) end
	local pre = ctx.Pre or 1
	local SNAP = .7
	-- charge-up: the inhale into the cheer while colour drains from the whole scene over Pre seconds; the double is left
	-- as it is, the brightest thing in a grey frame; the prism forms over the head
	K.ChargeUp(ctx, P, {Pose = "Freeze", PoseK = .9})
	ctx:Grade({Saturation = -1}, pre, SNAP, .4)
	local Pm = prism(ctx, {T0 = -.45, T1 = 6.9})
	-- t = 0: the freeze proper: time stops within thirty studs, the stutter ticks, the star condenses at the chest
	K.TimeScale(ctx, {T0 = 0, T1 = SNAP, Radius = 30, Scale = .02})
	freeze(ctx, P, 0, SNAP)
	for i = 1, 2 do S.Cue(ctx, i * .12, "CelImpact", {Volume = .35, Pitch = 1.3, Rate = 1}) end -- sound: the stutter ticks (rate pinned inside the freeze)
	star(ctx, P, SNAP - .42, c3)
	-- the snap: the FOV punch and impact frame, the three shells, every light flashes white, the shards scatter, the
	-- herd restarts at once, the body re-forms hovering
	local home = ctx.Hrp.CFrame
	K.Shatter(ctx, P, {At = SNAP, Colors = {W, c2, c3}, Chunks = 26, Spread = 1.1, Reform = .35, ReformCF = home * CFrame.new(0, 2, 0), FanRadius = 3,
		OnExplode = function(origin)
			ctx:ImpactFrame()
			S.Now(ctx, "CelImpact")
			S.Now(ctx, "CelDetonate", {At = origin})
			K.FOV(ctx, 12, .06, .45)
			shells(ctx, origin, SNAP, 22, c2, c3, 6)
			K.LightPaint(ctx, {At = 0, Radius = 40, Color = W, Hold = .5, Boost = 2})
		end})
	shards(ctx, SNAP + .03, Pm.Pos)
	K.Herd(ctx, {At = SNAP + .05, Radius = 18, Color = c2, Flavour = "bounce"})
	hover(ctx, P, SNAP + .37, 6.9, 2)
	-- the rays sweep two full rotations and leave every animal a colour; the crown cycles for the hold and lands
	rays(ctx, {T0 = 1.15, Turns = 2, Origin = Pm.Pos, Leave = 1.0})
	crown(ctx, {T0 = 1.1, T1 = 7.1, Radius = 1.6})
	S.ChargeUp(ctx)
	S.Duck(ctx, -pre, LEN)
	for i = 0, 2 do S.Cue(ctx, SNAP + i * .12, "CelShockwave", {Volume = i == 0 and 1 or .7}) end
	S.Cue(ctx, SNAP + .3, "CelShimmer")
	S.Bed(ctx, SNAP + .4, LEN - .8)
	S.Cue(ctx, 1.1, "GemCrown")
	S.Cue(ctx, 5.9, "CelTitle")
	S.Cue(ctx, 6.9, "CelLand")
	K.Title(ctx, 5.9, "glitch", 8)
	return LEN
end

return M
