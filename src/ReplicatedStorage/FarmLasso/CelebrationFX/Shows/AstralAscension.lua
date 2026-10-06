-- Shows.AstralAscension: constellation wings (star points joined by ice-blue Beams over a violet fill) open wider as
-- the player climbs a stair of light steps that appear under each footfall, with stars orbiting the body in three
-- tilted rings. At the top, arms out and head back, a halo descends through the rings while the constellation of the
-- caught animal is drawn 14 studs up, point by point and line by line; a star settles over each herd animal and ties
-- it up into the map, and the player comes down feather-slow. (Oct 6 2026)
-- Set 1: one ring of stars, a small halo, a wing outline behind the back plane. Set 2: three rings, the wings, a
-- four-step stair, the map. Set 3: stars drawn in on Beams in the charge-up, the full climb, 20-stud wings, the halo,
-- the herd strung into the map, seekers, a shooting star.
local FX = require(script.Parent.Parent.Parent)
local K = require(script.Parent.Parent.AuraKit)
local V3, W, TAU, rng = Vector3.new, FX.W, K.TAU, FX.rng
local M = {Pre = 1.0}
-- the star map: a rough quadruped outline (head, withers, rump, tail, hind legs, belly, fore legs) and its lines
local PTS = {V3(3.9, 1.5, 0), V3(2.4, 1.2, 0), V3(-2.5, 1.2, 0), V3(-4, 2.2, 0), V3(-3, -1.7, 0), V3(-1.6, -1.7, 0), V3(.2, -.5, 0), V3(1.4, -1.7, 0), V3(2.8, -1.7, 0)}
local LINES = {{1, 2}, {2, 3}, {3, 4}, {3, 5}, {5, 6}, {6, 7}, {7, 8}, {8, 9}, {9, 2}}

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
-- the performer's feet (the double's, once a show has taken it over)
local function feet(ctx)
	local root = ctx.Performer and ctx.Performer.Alive and ctx.Performer.Root.CFrame or ctx.Hrp.CFrame
	return CFrame.new(root.Position) * CFrame.new(0, -2.6, 0)
end
-- tilted rings of orbiting stars round the body at Heights (studs above the feet), T0 to T1
local function starRings(ctx, o)
	local c1, c2 = o.Colors[1], o.Colors[2]
	local rings = {}
	for r, h in o.Heights do
		local list = {}
		for i = 1, K.Count(ctx, o.Count or 6) do local s = star(ctx, i % 2 == 0 and c2 or c1) s.Transparency = 1 list[i] = s end
		rings[r] = {Stars = list, H = h, Tilt = (r - 2) * .35, Dir = r % 2 == 0 and -1 or 1, Phase = r * 1.1}
	end
	ctx:Every(function(t)
		local k = K.Soft(t, o.T0 or 0, o.T1 or 99, .4, .5)
		local base = feet(ctx)
		for _, rg in rings do
			local plane = base * CFrame.new(0, rg.H, 0) * CFrame.Angles(rg.Tilt, 0, 0)
			for i, s in rg.Stars do
				local a = (i - 1) / #rg.Stars * TAU + t * (o.Speed or 1.4) * rg.Dir + rg.Phase
				local pos = (plane * CFrame.new(K.Polar(a, (o.Radius or 4) * (.4 + .6 * k), 0))).Position
				K.Place(s, face(pos, t * 2 + i), .55 + .15 * math.sin(t * 3 + i))
				s.Transparency = 1 - k
			end
		end
		if t > (o.T1 or 99) + .6 then for _, rg in rings do for _, s in rg.Stars do s:Destroy() end end return true end
	end)
end
-- the halo: a fat ring that hangs at Y0 above the feet from T0, descends to Y1 by T1, and is gone by Out
local function halo(ctx, o)
	local ring = K.Ring(ctx, "RingFat", 4.2, .45, o.Color, 1)
	ctx:Every(function(t)
		if t < o.T0 - .3 then return end
		if t > o.Out + .6 then ring:Destroy() return true end
		local k = K.Env(t, o.T0 - .3, o.Out, .3, .5)
		local y = o.Y0 + (o.Y1 - o.Y0) * FX.ease((t - o.T0) / (o.T1 - o.T0))
		ring.CFrame = feet(ctx) * CFrame.new(0, y, 0) * CFrame.Angles(math.sin(t * 1.2) * .12, t * .8, 0) * FX.FLAT
		K.SetRing(ring, 4.2 * math.max(.05, k))
		ring.Transparency = k > .02 and .1 or 1
	end)
end
-- the stair: Steps light steps on a rising helix from the feet (Rise studs up, Turn radians round a centre Radius
-- studs to the right). St.Path(u) is the walk line; each step pops in with overshoot as St.U passes it and stays
-- glowing as its print until Fade.
local function stair(ctx, o)
	local home = ctx.Hrp.CFrame
	local R, n = o.Radius or 4.5, o.Steps or 8
	local centre = home.Position + home.RightVector * R
	local d = home.Position - centre
	local a0 = math.atan2(d.Z, d.X)
	local function path(u) return centre + K.Polar(a0 + u * (o.Turn or TAU * .75), R, u * (o.Rise or 7)) end
	local steps = {}
	for i = 1, n do
		local u = i / n
		local p, q = path(u) - V3(0, .15, 0), path(u + .01)
		steps[i] = {M = K.Mesh(ctx, "LightStep", {Color = o.Colors[1], Transparency = 1}), CF = CFrame.lookAt(p, p + V3(q.X - p.X, 0, q.Z - p.Z)), At = u - .5 / n, T = nil}
	end
	local St = {Path = path, Top = path(1), U = 0}
	ctx:Every(function(t)
		for _, s in steps do
			if not s.T and St.U >= s.At then s.T = t ctx:Flare(s.CF.Position + V3(0, .3, 0), 2.5, o.Colors[2], .35) end
			if s.T then
				local k = FX.back((t - s.T) / .25)
				K.Place(s.M, s.CF, V3(math.max(.02, k), 1, math.max(.02, k)))
				s.M.Transparency = .15
			end
		end
		if t > o.Fade then for _, s in steps do FX.Tween(s.M, .6, {Transparency = 1}) end return true end
	end)
	return St
end
-- the climb: the performer walks the stair over T0..T1 with a code-driven walk cycle, one stride per step
local function climb(ctx, P, St, o)
	K.Fly(ctx, P, {T0 = o.T0, T1 = o.T1, Path = St.Path, Bank = 3, Pitch = .12, OnDone = o.OnDone,
		OnU = function(u)
			St.U = u
			local sw = math.sin(u * (o.Steps or 8) * math.pi)
			local k = 1 - FX.ease((u - .88) / .12)
			P:Pose({RightHip = CFrame.Angles(-.5 * sw - .2, 0, .05), LeftHip = CFrame.Angles(.5 * sw - .2, 0, -.05),
				RightKnee = CFrame.Angles(.25 + .55 * math.max(0, sw), 0, 0), LeftKnee = CFrame.Angles(.25 + .55 * math.max(0, -sw), 0, 0),
				RightShoulder = CFrame.Angles(.35 * sw, 0, .12), LeftShoulder = CFrame.Angles(-.35 * sw, 0, -.12),
				Waist = CFrame.Angles(-.08, 0, 0), Neck = CFrame.Angles(.15, 0, 0)}, k)
		end})
end
-- the top and the way down: arms out and head back from T0, then a feather-slow drift home from T1 to T2
local function topAndLand(ctx, P, St, o)
	local home = ctx.Hrp.CFrame
	local landing = CFrame.new(home.Position) * (home - home.Position)
	local top
	ctx:Every(function(t)
		if not P.Alive or t < o.T0 then return end
		if t > o.T2 + .1 then P:Toward("Hang", 0) return true end
		if not top then top = P.Root.CFrame end
		if t < o.T1 then
			P:Pivot(top * CFrame.new(0, math.sin((t - o.T0) * 1.6) * .15 * FX.ease((t - o.T0) / .5), 0))
			P:Toward("Star", FX.ease((t - o.T0) / .35) * .95)
		else
			local u = FX.ease((t - o.T1) / (o.T2 - o.T1))
			local sway = math.sin((t - o.T1) * 2.2) * .5 * math.sin(u * math.pi)
			P:Pivot(top:Lerp(landing, u) * CFrame.new(sway, 0, 0) * CFrame.Angles(0, 0, sway * .12))
			P:Toward("Hang", (1 - FX.ease((u - .85) / .15)) * .9)
		end
	end)
end
-- the star map of the caught animal: Points stars in a vertical plane Height studs up and Back studs behind the
-- player, drawn in turn from T0 with a Beam lighting to each as it lands. It stays until the show ends.
-- C.Nearest(pos) is the attachment of the map star nearest a world point.
local function starMap(ctx, o)
	local c1, c2 = o.Colors[1], o.Colors[2]
	local n = math.min(#PTS, o.Points or 9)
	local back = K.Behind(ctx)
	local centre = ctx.Base.Position + back * (o.Back or 6) + V3(0, o.Height or 14, 0)
	local cf = CFrame.lookAt(centre, centre - back)
	local C = {Stars = {}, Atts = {}, Beams = {}, CF = cf}
	for i = 1, n do
		local s = star(ctx, i % 3 == 0 and c2 or c1)
		s.Transparency = 1
		K.Place(s, cf * CFrame.new(PTS[i] * (o.Scale or 1)) * CFrame.Angles(math.pi / 2, 0, 0), .9)
		C.Stars[i], C.Atts[i] = s, ctx:Att(nil, s)
	end
	for _, l in LINES do
		if l[1] <= n and l[2] <= n then
			local b = ctx:Beam(C.Atts[l[1]], C.Atts[l[2]], {Color = {c1, c2}, Width0 = .14, Width1 = .14, Transparency = .1, Brightness = 2.5, Segments = 1})
			b.Enabled = false
			table.insert(C.Beams, {B = b, At = o.T0 + (math.max(l[1], l[2]) - 1) * (o.Gap or .13) + .1})
		end
	end
	local shown = {}
	ctx:Every(function(t)
		for i, s in C.Stars do
			local age = t - (o.T0 + (i - 1) * (o.Gap or .13))
			if age < 0 then continue end
			if not shown[i] then shown[i] = true ctx:Flare(s.Position, 3, c1, .3) end
			local k = FX.back(age / .3)
			K.Place(s, cf * CFrame.new(PTS[i] * (o.Scale or 1)) * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.Angles(0, t * .6 + i, 0), math.max(.05, k) * (.9 + .2 * math.sin(t * 2.5 + i)))
			s.Transparency = 0
		end
		for _, b in C.Beams do b.B.Enabled = t >= b.At end
	end)
	function C.Nearest(pos)
		local best, bd = C.Atts[1], math.huge
		for i, s in C.Stars do local d = (s.Position - pos).Magnitude if d < bd then best, bd = C.Atts[i], d end end
		return best
	end
	return C
end
-- a star settles over an animal and a Beam ties it up into the map (a K.Herd Effect), until T1
local function tieUp(ctx, C, c1, c2, t1)
	return function(tg)
		local s = star(ctx, c1)
		s.Transparency = 1
		local a = ctx:Att(nil, s)
		local b = ctx:Beam(a, C.Nearest(tg.Part.Position), {Color = {c1, c2}, Width0 = .1, Width1 = .16, Transparency = {{0, .2}, {1, .05}}, Brightness = 2, Segments = 1})
		local t0 = os.clock()
		ctx:Every(function(t)
			local age = os.clock() - t0
			if t > t1 or not tg.Part.Parent then s:Destroy() b:Destroy() return true end
			local k = K.Env(age, 0, 99, .3, .5)
			K.Place(s, face(tg.Part.Position + V3(0, tg.Part.Size.Y * .5 + 1.5 + math.sin(age * 3) * .15, 0), age * 2), .8 * math.max(.05, k))
			s.Transparency = 1 - math.min(1, k)
			b.Enabled = k > .5
		end)
	end
end
-- the wing silhouette flashes up behind the back plane for half a second (Set 1's hint of the wings)
local function wingFlash(ctx, color)
	local back = K.Behind(ctx)
	for side = -1, 1, 2 do
		local w = K.Mesh(ctx, "WingSilhouette", {Color = color, Transparency = 1, Material = Enum.Material.ForceField})
		local t0 = os.clock()
		ctx:Every(function()
			local u = (os.clock() - t0) / .5
			if u >= 1 then w:Destroy() return true end
			local k = FX.back(u / .3) * (1 - FX.ease((u - .6) / .4))
			local root = ctx.Hrp.CFrame * CFrame.new(side * .4, .6, 1.3)
			local yaw = CFrame.lookAt(root.Position, root.Position - back) * CFrame.Angles(0, side > 0 and 0 or math.pi, side * .3)
			K.Place(w, yaw * CFrame.Angles(0, side * -.3, side * .4 * (1 - k)), (1.1 * k + .05))
			w.Transparency = 1 - .6 * k
		end)
	end
end

---------------------------------------------------------------- Set 1: one ring, a small halo, a wing outline (2.6 s)
function M.Set1(ctx, def)
	local c1, c2, c3 = K.Palette(def)
	local LEN = 2.6
	starRings(ctx, {Colors = {c1, c2}, Heights = {3}, Count = 6, Radius = 4, T0 = .1, T1 = 2.0})
	halo(ctx, {Color = c1, Y0 = 7.2, Y1 = 6.4, T0 = .2, T1 = 2.0, Out = 2.0})
	K.Stamp(ctx, ctx.Base.Position, {Mesh = "ScorchRing", Color = c2, Scale = .9, Life = 2.2, Transparency = .4, Rise = .4})
	ctx:At(.3, function() K.Starburst(ctx, ctx.Base.Position + V3(0, 6.6, 0), {Colors = {c1, c2}, Size = 5, Count = 16}) end)
	ctx:At(.6, function() wingFlash(ctx, c3) end)
	ctx:Repeat(.5, 1.9, .3, function() ctx:Flare(ctx.Base.Position + K.Polar(rng:NextNumber(0, TAU), rng:NextNumber(2, 4), rng:NextNumber(1, 5)), 2.5, c1, .3) end)
	K.Title(ctx, 1.0, "embers", 8)
	return LEN
end

---------------------------------------------------------------- Set 2: three rings, the wings, a four-step stair, the map (5.2 s)
function M.Set2(ctx, def)
	local c1, c2, c3 = K.Palette(def)
	local LEN = 5.2
	local P = K.Performer(ctx)
	if not P then return M.Set1(ctx, def) end
	ctx:At(.02, function() P:Show() end)
	starRings(ctx, {Colors = {c1, c2}, Heights = {1, 3, 5.2}, Count = 6, Radius = 4, T0 = .15, T1 = 4.5})
	ctx:At(.2, function()
		K.Starburst(ctx, ctx.Base.Position + V3(0, 3, 0), {Colors = {c1, c2}, Size = 7, Count = 20})
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .15), 2, 16, c2, .45, .4)
		ctx:Flash(c1, .25, .3)
	end)
	K.Wings(ctx, P, {Span = 12, Colors = {c1, c2, c3}, Style = "constellation", Unfold = .3, Rise = 1.6, Fold = 4.5, Fall = .4})
	local St = stair(ctx, {Colors = {c1, c2}, Steps = 4, Rise = 3.5, Turn = TAU * .4, Radius = 4, Fade = 4.6})
	climb(ctx, P, St, {T0 = .5, T1 = 2.2, Steps = 4})
	topAndLand(ctx, P, St, {T0 = 2.2, T1 = 3.7, T2 = 4.9})
	halo(ctx, {Color = c1, Y0 = 6.8, Y1 = .6, T0 = 2.4, T1 = 3.5, Out = 3.7})
	starMap(ctx, {Colors = {c1, c2}, Points = 7, Height = 12, Back = 5, T0 = 2.5, Gap = .14})
	K.Herd(ctx, {At = 2.6, Radius = 16, Color = c2, Flavour = "lookup", Max = 5})
	K.Title(ctx, 3.4, "embers", 8.5)
	return LEN
end

---------------------------------------------------------------- Set 3: the full climb, the halo, the herd strung into the map (8.2 s + 1 s charge-up)
function M.Set3(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 8.2
	local P = K.Performer(ctx)
	if not P then return M.Set2(ctx, def) end
	local pre = ctx.Pre or 1
	-- charge-up: crouch, the dark sigil, the inhale; eight dark stars are drawn in from 20 studs on thin Beams
	K.ChargeUp(ctx, P, {Sigil = "Sigil", SigilScale = 1.1, Pose = "Crouch", PoseK = .9})
	local chest = ctx:Att(nil, P.Torso)
	local pull = {}
	for i = 1, K.Count(ctx, 8) do
		local s = star(ctx, dark)
		s.Transparency = 1
		local a = ctx:Att(nil, s)
		pull[i] = {M = s, B = ctx:Beam(a, chest, {Color = {dark, W}, Width0 = .08, Width1 = .02, Transparency = {{0, .4}, {1, .9}}, Brightness = 1, Segments = 1})}
	end
	ctx:Every(function(t)
		if t >= 0 then for _, p in pull do p.M:Destroy() p.B:Destroy() end return true end
		local u = 1 + t / pre
		local e = FX.ease(u) ^ 2
		for i, p in pull do
			local a = i / #pull * TAU + u * 1.5
			K.Place(p.M, face(ctx.Base.Position + K.Polar(a, 20 * (1 - e) + .5, 4 - 2 * e), u * 5), .6)
			p.M.Transparency = .2
		end
	end)
	-- t = 0: the detonation; the rings and the wings open, the first step lights
	ctx:At(0, function()
		K.Hit(ctx, ctx.Base.Position, {Colors = {c1, c2}, Impact = true, Ring = 30, Burst = 16, Lines = 36})
		ctx:Grade({Brightness = .05, Contrast = .15, Saturation = .1, TintColor = Color3.fromRGB(228, 238, 255)}, .1, 6.6, .8)
	end)
	starRings(ctx, {Colors = {c1, c2}, Heights = {1, 3, 5.3}, Count = 7, Radius = 4.2, T0 = .1, T1 = 7.3})
	K.Wings(ctx, P, {Span = 20, Colors = {c1, c2, c3}, Style = "constellation", Unfold = .3, Rise = 3.0, Fold = 7.0, Fall = .5})
	local St = stair(ctx, {Colors = {c1, c2}, Steps = 8, Rise = 7, Turn = TAU * .75, Radius = 4.5, Fade = 6.9})
	climb(ctx, P, St, {T0 = .5, T1 = 3.4, Steps = 8})
	topAndLand(ctx, P, St, {T0 = 3.4, T1 = 5.7, T2 = 7.2})
	-- one star per nearby player seeks them (none when nobody is near)
	local players = K.NearbyPlayers(ctx, 40)
	if #players > 0 then
		K.Seek(ctx, {Mesh = "StarPoint", Scale = 1, Colors = {c1, c2, c3}, Count = math.min(4, #players), Interval = .3, T0 = 1.8, Radius = 40, Speed = 16, Trail = .6,
			Circle = .7, Height = 2.5, From = function() return P.Torso.Position + V3(0, 1, 0) end})
	end
	-- the top: the halo descends through the rings, the map is drawn 14 studs up, every lantern goes blue-white
	halo(ctx, {Color = c1, Y0 = 11, Y1 = .6, T0 = 3.6, T1 = 5.3, Out = 5.6})
	local C = starMap(ctx, {Colors = {c1, c2}, Points = 9, Height = 14, Back = 7, Scale = 1.15, T0 = 3.6, Gap = .12})
	ctx:At(3.5, function()
		K.LightPaint(ctx, {At = 0, Radius = 40, Color = c1, Hold = 1.2, Boost = 2})
		K.Starburst(ctx, P.Torso.Position, {Colors = {W, c1}, Size = 8, Count = 20})
		ctx:Flash(c1, .3, .3)
	end)
	-- the herd is strung into the sky: a star over each animal, a Beam up to the nearest map star
	K.Herd(ctx, {At = 4.9, Radius = 20, Color = c2, Flavour = "lookup", Max = 4, Stagger = .15, Effect = tieUp(ctx, C, c1, c2, 7.6)})
	-- a shooting star crosses the sky behind the title
	ctx:At(5.2, function()
		local back = K.Behind(ctx)
		local right = back:Cross(Vector3.yAxis)
		local c = ctx.Base.Position + back * 16 + V3(0, 17, 0)
		ctx:Streak(function(u) return c + right * (18 - 36 * u) + V3(0, 3 - 6 * u, 0) end, .7, {W, c1, c2}, .9, .5)
	end)
	ctx:At(7.2, function() K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .2), 1.5, 12, c2, .4, .35) end)
	K.Title(ctx, 5.0, "embers", 9)
	return LEN
end

return M
