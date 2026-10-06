-- Shows.StarfallHalo: a crystal halo opens in the sky, tilted, with twelve stalactites hung from its inner edge, and
-- pours a pillar of starlight on the player. Four-point stars detach from the halo and fall down the pillar in a
-- double helix trailing pale cyan, skip once on the ground and leave pink star-prints, seek the other players and
-- ride the herd. In Set 3 a second halo stacks above the first, and the first tilts and drops over the player like a
-- ring toss, landing round their feet as the floor sigil under a white flash. (Oct 6 2026)
-- Set 1: a small halo at the crown and a dozen stars rising off the floor. Set 2: the 14-stud halo, the pillar, the
-- float, falling stars with prints, stars riding animals. Set 3: two halos, the double helix, seekers, the ring toss.
local FX = require(script.Parent.Parent.Parent)
local K = require(script.Parent.Parent.AuraKit)
local V3, W, TAU, rng = Vector3.new, FX.W, K.TAU, FX.rng
local M = {Pre = 1.0}

-- a pale streak trail hung on a part
local function trail(ctx, part, colors, life, width)
	local a0 = ctx:Att(V3(0, (width or .5) / 2, 0), part)
	local a1 = ctx:Att(V3(0, -(width or .5) / 2, 0), part)
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.LightEmission, tr.LightInfluence = 1, 0
	tr.Lifetime = life or .5
	tr.Texture = K.Tex.Streak
	tr.TextureMode = Enum.TextureMode.Stretch
	tr.Color = FX.cseq(colors)
	tr.Transparency = FX.nseq({{0, .05}, {.6, .35}, {1, 1}})
	tr.WidthScale = FX.nseq({{0, 1}, {1, 0}})
	pcall(function() tr.Brightness = 3 end)
	tr.Parent = part
	return tr
end
-- a four-point star mesh: a flat XZ plate with +Y as its normal (like every flat disc in the pack)
local function star(ctx, color)
	local s = K.Mesh(ctx, "StarPoint", {Color = color})
	if not s:IsA("MeshPart") then s.Size = V3(1.4, .08, 1.4) s:SetAttribute("BaseSize", s.Size) end
	return s
end
-- a star standing in the air reads as a flare: its plate (+Y normal) faces the camera, spun about that normal
local function face(pos, spin)
	local cam = workspace.CurrentCamera
	local eye = cam and cam.CFrame.Position or pos + Vector3.zAxis
	return CFrame.lookAt(pos, eye) * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.Angles(0, spin or 0, 0)
end
-- the pink star-print: a star stamp lying on the ground (K.GroundCF's frame is already Y-up; the stand-in plate is big)
local function starPrint(ctx, pos, color, life)
	return K.Stamp(ctx, pos, {Mesh = "StarPoint", Color = color, Scale = K.HasMesh("StarPoint") and 1.4 or .25, Life = life or 3, Rise = .2, Transparency = .1})
end
-- the crystal halo: the HaloRing mesh (or a fat ring) D studs across with crystal stalactites hung from its inner
-- edge pointing down. H.Place(cf, k) draws it at cf at size k; its own loop hangs it Height studs up, tilted and
-- spinning, from In to Out. H.Detach() stops that loop and hands the current CFrame to the show (the ring toss).
local function halo(ctx, o)
	local c1, c2 = o.Colors[1], o.Colors[2]
	local d = o.D or 14
	local ring = K.HasMesh("HaloRing") and K.Mesh(ctx, "HaloRing", {Color = o.Color or c1}) or ctx:Ring("RingFat", d, .55, o.Color or c1, 0)
	local isMesh = ring:IsA("MeshPart")
	local base = ring:GetAttribute("BaseSize") or ring.Size
	local cr = {}
	for i = 1, K.Count(ctx, o.Crystals or 12) do cr[i] = K.Mesh(ctx, "HaloCrystal", {Color = c1}) end
	local att = ctx:Att(V3(0, o.Height or 12, 0))
	local light = ctx:Light(att, c2, d * 2, 0)
	local H = {Ring = ring, Crystals = cr, Alive = true, K = 0, CrystalTr = 0, CF = ctx.Base * CFrame.new(0, o.Height or 12, 0)}
	function H.Place(cf, k)
		local s = math.max(.02, k)
		if isMesh then K.Place(ring, cf, d / math.max(base.X, base.Z) * s) else K.SetRing(ring, d * s) ring.CFrame = cf * FX.FLAT end
		local tr = k > .02 and (o.Transparency or 0) or 1
		ring.Transparency = tr
		local cs = (o.CrystalScale or 1) * s
		for i, c in cr do
			K.Place(c, cf * CFrame.Angles(0, (i - 1) / #cr * TAU, 0) * CFrame.new(d * .5 * s - .45 * cs, -.9 * cs, 0), cs)
			c.Transparency = math.max(tr, H.CrystalTr)
		end
		light.Brightness = 5 * math.min(1, k)
	end
	function H.Fade(dur)
		H.Alive = false
		FX.Tween(ring, dur, {Transparency = 1})
		FX.Tween(light, dur, {Brightness = 0})
		for _, c in cr do FX.Tween(c, dur, {Transparency = 1}) end
	end
	function H.Detach() H.Alive = false return H.CF end
	ctx:Every(function(t)
		if not H.Alive then return true end
		local k = K.Env(t, o.In or 0, o.Out or 99, o.Rise or .5, .5)
		H.K = k
		H.CF = ctx.Base * CFrame.new(0, (o.Height or 12) + math.sin(t * 1.3) * .2, 0) * CFrame.Angles(o.Tilt or 0, 0, 0) * CFrame.Angles(0, (o.Spin or .3) * t, 0)
		H.Place(H.CF, k)
		if t > (o.Out or 99) + .6 then ring:Destroy() for _, c in cr do c:Destroy() end return true end
	end)
	return H
end
-- stars detach from the halo's inner edge and fall down the pillar in a double helix, each trailing pale cyan; a
-- star that reaches the ground leaves a pink star-print, skips once and goes out. One loop drives the whole list.
local function starfall(ctx, o)
	local c1, c2, c3 = o.Colors[1], o.Colors[2], o.Colors[3]
	local n = K.Count(ctx, o.Count or 10)
	ctx:At(o.T0 or 0, function()
		local list = {}
		for i = 1, n do
			local s = star(ctx, i % 3 == 0 and c3 or c1)
			s.Transparency = 1
			trail(ctx, s, {W, c1, c2}, .55, .6)
			list[i] = {M = s, Start = (i - 1) * (o.Stagger or .18), Side = i % 2 == 0 and 0 or math.pi}
		end
		local a0 = rng:NextNumber(0, TAU)
		local top, r, rTop, dur, turns = o.Top or 12, o.Radius or 3, o.RTop or 6, o.Dur or 1.6, o.Turns or 1.5
		local t0 = os.clock()
		local left = n
		ctx:Every(function()
			local age = os.clock() - t0
			local centre = ctx.Base.Position
			for _, st in list do
				if st.Done then continue end
				local u = (age - st.Start) / dur
				if u < 0 then continue end
				local m = st.M
				if u < 1 then
					local e = u * u * .55 + u * .45 -- slow off the edge, faster near the ground
					local a = a0 + st.Side + e * TAU * turns
					local rr = r + (rTop - r) * (1 - math.min(1, e / .25))
					local pos = centre + K.Polar(a, rr, top * (1 - e))
					K.Place(m, face(pos, age * 4), .8)
					m.Transparency = 0
					st.Land, st.A = pos, a
				else
					local v = (u - 1) / .4
					st.Land, st.A = st.Land or centre, st.A or a0
					if not st.Printed then
						st.Printed = true
						starPrint(ctx, st.Land, c3, o.PrintLife or 3)
						ctx:Burst(st.Land, K.Count(ctx, 10), {Texture = K.Tex.Star, Color = {W, c3}, Size = {.5, 0}, Lifetime = {.3, .6}, Speed = {3, 7}, SpreadAngle = Vector2.new(60, 60), Drag = 3, Brightness = 4})
					end
					if v >= 1 then m:Destroy() st.Done = true left -= 1 continue end
					local pos = st.Land + K.Polar(st.A, 1.4 * v, math.sin(v * math.pi) * 1.1)
					K.Place(m, face(pos, age * 4), .8 * (1 - v * .5))
					m.Transparency = v * .6
				end
			end
			return left <= 0
		end)
	end)
end
-- a star settles 1.5 studs over an animal and rides it, glowing, for 3 s (a K.Herd Effect)
local function rider(ctx, color)
	return function(tg)
		local s = star(ctx, color)
		s.Transparency = 1
		local t0 = os.clock()
		ctx:Every(function()
			local age = os.clock() - t0
			if age >= 3 or not tg.Part.Parent then s:Destroy() return true end
			local k = K.Env(age, 0, 3, .3, .5)
			K.Place(s, face(tg.Part.Position + V3(0, tg.Part.Size.Y * .5 + 1.5 + math.sin(age * 3) * .15, 0), age * 2), .8 * math.max(.05, k))
			s.Transparency = 1 - math.min(1, k)
		end)
	end
end
-- the pillar's floor ring frosts the grass white-blue
local function frost(ctx, c1, life, scale)
	return K.Stamp(ctx, ctx.Base.Position, {Mesh = "ScorchRing", Color = c1, Scale = scale or 1.1, Life = life, Transparency = .35, Rise = .4})
end

---------------------------------------------------------------- Set 1: a small halo and a dozen stars (2.6 s)
function M.Set1(ctx, def)
	local c1, c2, c3 = K.Palette(def)
	local LEN = 2.6
	halo(ctx, {Colors = {c1, c2, c3}, D = 6, Height = 6.5, Tilt = .2, Crystals = 6, CrystalScale = .6, In = .1, Out = 2.0, Spin = .6})
	frost(ctx, c1, 2.2, .9)
	ctx:At(.3, function() K.Starburst(ctx, ctx.Base.Position + V3(0, 6.5, 0), {Colors = {c1, c2}, Size = 5, Count = 16}) end)
	-- a dozen stars at the feet spiral up into the halo and wink out at its edge
	local n = K.Count(ctx, 12)
	local stars = {}
	for i = 1, n do local s = star(ctx, i % 3 == 0 and c3 or c1) s.Transparency = 1 stars[i] = s end
	ctx:Every(function(t)
		if t < .25 then return end
		if t > 2.2 then for _, s in stars do s:Destroy() end return true end
		for i, s in stars do
			local u = FX.ease((t - .25 - (i - 1) * .06) / 1.4)
			local a = i / n * TAU + t * 2.2
			local pos = ctx.Base.Position + K.Polar(a, 3.4 - .6 * u, .3 + 6.2 * u * u)
			K.Place(s, face(pos, t * 3 + i), .7)
			s.Transparency = (u <= 0 or u >= .97) and 1 or 0
		end
	end)
	ctx:Repeat(.5, 1.9, .35, function() ctx:Flare(ctx.Base.Position + K.Polar(rng:NextNumber(0, TAU), 3, rng:NextNumber(5.5, 7)), 2.5, c3, .3) end)
	K.Title(ctx, 1.0, "embers", 8)
	return LEN
end

---------------------------------------------------------------- Set 2: the halo, the pillar, the float, falling stars (5.2 s)
function M.Set2(ctx, def)
	local c1, c2, c3 = K.Palette(def)
	local LEN = 5.2
	local P = K.Performer(ctx)
	if not P then return M.Set1(ctx, def) end
	ctx:At(.02, function() P:Show() end)
	halo(ctx, {Colors = {c1, c2, c3}, D = 14, Height = 12, Tilt = .35, Crystals = 12, In = .1, Out = 4.5, Spin = .3})
	ctx:At(.35, function()
		K.Starburst(ctx, ctx.Base.Position + V3(0, 12, 0), {Colors = {c1, c2}, Size = 9, Count = 24})
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .15), 2, 16, c2, .45, .4)
		ctx:Flash(c1, .3, .3)
	end)
	frost(ctx, c1, 4.6)
	K.Cage(ctx, {Colors = {c1, c2}, T0 = .4, T1 = 4.2, Radius = 3.2, Height = 10, Rate = 50})
	-- lifted inside the pillar, arms out, one slow turn
	K.Float(ctx, P, {T0 = .6, T1 = 4.3, Height = 3, Rise = .6, Fall = .45, Spin = TAU / 3.7, Pose = "Wide", PoseK = .9})
	starfall(ctx, {Colors = {c1, c2, c3}, T0 = 1.0, Count = 10, Stagger = .2, Top = 11, Radius = 2.9, RTop = 6, Dur = 1.5, Turns = 1.25})
	K.Herd(ctx, {At = 2.0, Radius = 16, Color = c2, Flavour = "lookup", Max = 6, Effect = rider(ctx, c3)})
	ctx:At(4.3, function() K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .2), 1.5, 12, c3, .4, .35) end)
	K.Title(ctx, 2.6, "embers", 8.5)
	return LEN
end

---------------------------------------------------------------- Set 3: two halos, the double helix, the ring toss (7.8 s + 1 s charge-up)
function M.Set3(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 7.8
	local P = K.Performer(ctx)
	if not P then return M.Set2(ctx, def) end
	local pre = ctx.Pre or 1
	-- charge-up: crouch, the dark sigil, the inhale; the halo's dark shadow spins up overhead, uncoloured
	K.ChargeUp(ctx, P, {Sigil = "Sigil", SigilScale = 1.1, Pose = "Crouch", PoseK = .9})
	local shadow = K.Ring(ctx, "RingThin", 14, .3, dark, .4)
	ctx:Every(function(t)
		if t >= 0 then shadow:Destroy() return true end
		local u = 1 + t / pre
		shadow.CFrame = ctx.Base * CFrame.new(0, 12, 0) * CFrame.Angles(.35, 0, 0) * CFrame.Angles(0, u * 2, 0) * FX.FLAT
		K.SetRing(shadow, 14 * FX.ease(u / .6))
		shadow.Transparency = .4 + .5 * (1 - FX.ease(u / .5))
	end)
	-- t = 0: the halo irises open in colour, the pillar slams down
	ctx:At(0, function()
		K.Hit(ctx, ctx.Base.Position, {Colors = {c1, c2}, Impact = true, Ring = 28, Burst = 16, Lines = 36})
		ctx:Grade({Brightness = .05, Contrast = .15, Saturation = .1, TintColor = Color3.fromRGB(225, 240, 255)}, .1, 6.2, .8)
	end)
	local H1 = halo(ctx, {Colors = {c1, c2, c3}, D = 14, Height = 12, Tilt = .35, Crystals = 12, In = 0, Rise = .35, Spin = .3})
	halo(ctx, {Colors = {c1, c2, c3}, D = 20, Height = 17, Tilt = -.25, Crystals = 16, CrystalScale = 1.2, In = .35, Out = 5.8, Spin = -.2, Transparency = .1})
	frost(ctx, c1, 7.2, 1.3)
	local cage = K.Cage(ctx, {Colors = {c1, c2}, T0 = .05, T1 = 5.2, Radius = 3.4, Height = 14, Rate = 70})
	K.Float(ctx, P, {T0 = .3, T1 = 5.3, Height = 6, Rise = .7, Fall = .5, Spin = TAU / 5, Pose = "Wide", PoseK = .9})
	starfall(ctx, {Colors = {c1, c2, c3}, T0 = .7, Count = 16, Stagger = .15, Top = 16, Radius = 3, RTop = 6.5, Dur = 1.9, Turns = 1.75, PrintLife = 4})
	-- one star per nearby player seeks them and hovers over their head (none when nobody is near)
	local players = K.NearbyPlayers(ctx, 40)
	if #players > 0 then
		K.Seek(ctx, {Mesh = "StarPoint", Scale = 1, Colors = {c1, c2, c3}, Count = math.min(4, #players), Interval = .3, T0 = 1.4, Radius = 40, Speed = 16, Trail = .6,
			Circle = .7, Height = 2.5, From = function(i) return H1.CF.Position + K.Polar(i * 1.7, 6.5, -.5) end})
	end
	K.Herd(ctx, {At = 2.3, Radius = 18, Color = c2, Flavour = "lookup", Max = 6, Effect = rider(ctx, c3)})
	-- the peak frame: a silhouette halfway up the pillar, two halos above, pink stars spiralling past
	ctx:At(2.6, function() P:Silhouette() ctx:Flash(c1, .3, .3) end)
	ctx:At(3.2, function() P:RestoreLook() K.Starburst(ctx, P.Torso.Position, {Colors = {W, c1}, Size = 7, Count = 18}) end)
	-- the signature: the pillar bursts, the first halo tilts and drops over the player like a ring toss and lands
	-- round their feet as the floor sigil under a white flash
	ctx:At(5.35, function() cage.Burst() end)
	ctx:At(5.5, function()
		local from = H1.Detach()
		local to = K.GroundCF(ctx, ctx.Base.Position, .12)
		local t0 = os.clock()
		ctx:Every(function()
			local u = (os.clock() - t0) / .7
			if u >= 1 then
				H1.Place(to, .85)
				K.Hit(ctx, ctx.Base.Position, {Colors = {W, c3}, Flash = .5, Ring = 30, Burst = 14, Lines = 30})
				ctx:Burst(ctx.Base.Position + V3(0, .5, 0), K.Count(ctx, 30), {Texture = K.Tex.Star, Color = {W, c3}, Size = {.6, 0}, Lifetime = {.5, .9}, Speed = {6, 14},
					SpreadAngle = Vector2.new(70, 70), EmissionDirection = Enum.NormalId.Top, Drag = 2, Brightness = 5})
				local l0 = os.clock()
				ctx:Every(function()
					local age = os.clock() - l0
					if age > 1.0 then H1.Fade(.6) return true end
					H1.Place(to * CFrame.Angles(0, age * .5, 0), .85)
				end)
				return true
			end
			local k = FX.back(u)
			local rot = from:Lerp(to, FX.ease(u))
			local pos = from.Position:Lerp(to.Position, k)
			if pos.Y < to.Position.Y then pos = V3(pos.X, to.Position.Y, pos.Z) end
			H1.CrystalTr = math.min(1, u * 2)
			H1.Place((rot - rot.Position) + pos, 1 - .15 * FX.ease(u))
		end)
	end)
	K.Title(ctx, 6.3, "embers", 8.5)
	return LEN
end

return M
