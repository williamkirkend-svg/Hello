-- Shows.SpiritStampede: a standing portal (gold rune frame, navy void, ForceField interior) opens behind the player
-- and out gallop ghost copies of the player's own herd: lilac ForceField voxel rigs with gold eyes and long lilac
-- trails, running the game's real gait on a rising spiral round the player, hooves stamping gold sparks and glowing
-- hoofprints, passing through nearby players. Last out is a giant spirit bison that leaps clean over the player; in
-- Set 3 the player rides the lead ghost for a loop and the bison stops before the camera and bellows. (Oct 6 2026)
-- Set 1: a 3-stud portal, three ghosts doing a half-lap, gold sparks. Set 2: the full portal, eight ghosts in a lap,
-- hoofprints, the real herd looking up and flinching, the bison leap, the ghosts leaping into the sky. Set 3: gold
-- runes orbit inward and the ground thuds in the charge-up; sixteen ghosts in two counter-rotating laps, the ride,
-- the bison leap and bellow, the herd ascending.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FX = require(script.Parent.Parent.Parent)
local K = require(script.Parent.Parent.AuraKit)
local V3, W, TAU, rng = Vector3.new, FX.W, K.TAU, FX.rng
local NAVY = Color3.fromRGB(22, 18, 60)
local FALLBACK_HERD = {"Horse", "Bison", "Cow", "Llama", "Reindeer", "Donkey"}
local M = {Pre = 1.0}

-- the voxel animal module (ghosts are built from it; without it the show plays with silhouettes)
local function voxel()
	local ok, V = pcall(function()
		local root = ReplicatedStorage:FindFirstChild("FarmLasso")
		local m = root and root:FindFirstChild("Voxel")
		return m and require(m)
	end)
	return ok and type(V) == "table" and V.Build and V.Pose and V.Has and V.Rigs and V or nil
end
-- the species in the player's own herd (attribute "Herd" = "Chick:3,Pig:1"), else the fallback list
local function species(ctx, V)
	local out = {}
	local pl = Players:GetPlayerFromCharacter(ctx.Char)
	local herd = pl and pl:GetAttribute("Herd")
	if type(herd) == "string" then
		for name in string.gmatch(herd, "([%a_]+):%d+") do if not V or V.Has(name) then table.insert(out, name) end end
	end
	if #out == 0 then for _, name in FALLBACK_HERD do if not V or V.Has(name) then table.insert(out, name) end end end
	if #out == 0 then out = {FALLBACK_HERD[1]} end
	return out
end
-- a mesh authored base-at-origin stood on cf; a centred stand-in (no pivot data) is lifted by half its height
local function stand(p, cf, scale)
	K.Place(p, cf, scale)
	if (p.Position - cf.Position).Magnitude < .01 then p.CFrame = cf * CFrame.new(0, p.Size.Y / 2, 0) end
end

-- the portal: the frame standing 6 studs behind the player facing them, a navy nebula void behind it, a ForceField
-- disc inside; opens with overshoot at T0, closes at T1. Returns Pt (Pt.Pos the centre, Pt.Back, Pt.Ground).
local function portal(ctx, c1, c2, c3, dark, o)
	local back = K.Behind(ctx)
	local g = K.Ground(ctx, ctx.Base.Position + back * 6)
	local baseCF = CFrame.lookAt(g, g - back)
	local s = o.Scale or 1
	local frame = K.Mesh(ctx, "PortalFrame", {Color = c3, Transparency = 1})
	local void = K.Mesh(ctx, "RiftVoid", {Color = NAVY, Material = Enum.Material.Glass, Transparency = 1})
	local tex = Instance.new("Texture")
	tex.Texture, tex.Color3, tex.Transparency = K.Tex.Nebula, c2, .35
	tex.StudsPerTileU, tex.StudsPerTileV, tex.Face = 4, 4, Enum.NormalId.Front
	tex.Parent = void
	local disc = ctx:Part({Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField, Color = c2, Transparency = 1})
	local light = ctx:Light(ctx:Att(g + V3(0, 3.5 * s, 0) - ctx.Base.Position), c2, 30, 0)
	local Pt = {Pos = g + V3(0, 3.5 * s, 0), Back = back, Ground = g}
	ctx:Every(function(t, dt)
		if t > o.T1 + .6 then frame:Destroy() void:Destroy() disc:Destroy() return true end
		local k = math.max(.02, FX.back((t - o.T0) / .5) * (1 - FX.ease((t - o.T1) / .5)))
		stand(frame, baseCF, s * k)
		local centre = frame.Position
		Pt.Pos = centre
		local rot = CFrame.new(centre) * (baseCF - baseCF.Position)
		K.Place(void, rot * CFrame.new(0, 0, .3), V3(s * k * .9, s * k * .7, 1))
		disc.Size = V3(.15, 6 * s * k, 6 * s * k)
		disc.CFrame = rot * CFrame.new(0, 0, .12) * CFrame.Angles(0, math.pi / 2, 0)
		tex.OffsetStudsV = (tex.OffsetStudsV + dt * 1.6) % 4
		local on = k > .04
		frame.Transparency, void.Transparency, disc.Transparency = on and .05 or 1, on and .2 or 1, on and .45 or 1
		light.Brightness = 6 * k
	end)
	return Pt
end
-- one ghost: a lilac ForceField voxel rig (or a LightningBull silhouette), gold eyes, a lilac trail, a spark emitter
local function ghost(ctx, V, sp, scale, tint, c3)
	local g = {Hop = rng:NextNumber(0, 6), Phase = rng:NextNumber(0, TAU), Gone = false, LastSpark = 0, LastPrint = 0}
	if V and V.Has(sp) then
		local ok, m = pcall(V.Build, {Id = sp, Scale = scale}, ctx.Folder)
		local rig = ok and m and V.Rigs[m]
		if rig then
			g.Model, g.Rig, g.Root, g.Parts, g.Foot = m, rig, rig.Root, rig.Parts, m:GetAttribute("FootOffset") or 1.5
			g.Head = m:FindFirstChild("Head", true)
			ctx:OnCleanup(function() V.Rigs[m] = nil end)
		end
	end
	if not g.Root then
		local m = K.Mesh(ctx, "LightningBull", {Color = tint})
		K.Place(m, ctx.Base * CFrame.new(0, -50, 0), scale)
		g.Model, g.Root, g.Parts, g.Foot = m, m, {m}, 1.5 * scale
	end
	for _, p in g.Parts do
		p.Material, p.Color, p.Transparency, p.CastShadow, p.Anchored = Enum.Material.ForceField, tint, 1, false, true
	end
	if g.Head then g.Eye = ctx:Part({Color = c3, Size = V3(math.max(.3, g.Head.Size.X * .7), .12, .14), Transparency = 1}) end
	local a0, a1 = ctx:Att(V3(0, .9 * scale, 0), g.Root), ctx:Att(V3(0, -.9 * scale, 0), g.Root)
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.LightEmission, tr.LightInfluence = 1, 0
	tr.Lifetime = .7
	tr.Texture = K.Tex.Streak
	tr.TextureMode = Enum.TextureMode.Stretch
	tr.Color = FX.cseq({W, tint})
	tr.Transparency = FX.nseq({{0, .2}, {.6, .5}, {1, 1}})
	tr.WidthScale = FX.nseq({{0, 1}, {1, 0}})
	tr.Enabled = false
	pcall(function() tr.Brightness = 2.5 end)
	tr.Parent = g.Root
	g.Trail = tr
	g.Sparks = ctx:Emitter(a1, {Texture = K.Tex.Star, Color = {W, c3}, Size = {.45, 0}, Lifetime = {.3, .6}, Rate = 0, Speed = {3, 7}, SpreadAngle = Vector2.new(180, 180),
		Acceleration = V3(0, -12, 0), Drag = 2, Brightness = 5})
	return g
end
-- pose a ghost at cf (the game's gait through Voxel, or a gallop bob for the silhouette) into the bulk-move lists
local function pose(V, g, cf, t, walking, parts, cfs)
	if g.Rig then
		V.Pose(g.Rig, cf, t, {Walking = walking, Hop = g.Hop, Phase = g.Phase}, parts, cfs)
	else
		local bob = walking and math.abs(math.sin(g.Hop * .5)) * .4 or 0
		table.insert(parts, g.Root)
		table.insert(cfs, cf * CFrame.new(0, bob, 0) * CFrame.Angles(walking and math.sin(g.Hop * .5) * .12 or 0, 0, 0))
	end
end
local function setTr(g, tr) for _, p in g.Parts do p.Transparency = tr end if g.Eye then g.Eye.Transparency = tr end end
local function eye(g)
	if g.Eye and g.Head then g.Eye.CFrame = g.Head.CFrame * CFrame.new(0, g.Head.Size.Y * .15, -g.Head.Size.Z / 2) end
end
-- the ghost pops: a flare and gold sparks where it was, then it is hidden
local function vanish(ctx, g, c3)
	g.Gone = true
	setTr(g, 1)
	g.Trail.Enabled = false
	ctx:Flare(g.Root.Position, 4, c3, .4)
	ctx:Burst(g.Root.Position, K.Count(ctx, 18), {Texture = K.Tex.Star, Color = {W, c3}, Size = {.7, 0}, Lifetime = {.4, .8}, Speed = {6, 14}, SpreadAngle = Vector2.new(180, 180), Drag = 3, Brightness = 5})
end

-- the herd: o.Count ghosts leave the portal from o.Born every o.Interval and lap the player (o.R(i) radius, o.Dir(i)
-- spin, o.Dur seconds a lap, altitude o.Alt(t) above the ground) until o.Until (or o.Laps laps), then climb away and
-- pop. Hooves spark and stamp hoofprints while low; ghosts within 3 studs of another player flicker their Highlight.
-- Returns H (H.Ghosts, H.LeadAlt for the ride).
local function herd(ctx, V, Pt, c1, c2, c3, o)
	local list = species(ctx, V)
	local n = K.Count(ctx, o.Count)
	local H = {Ghosts = {}, LeadAlt = nil, LeadK = 0}
	local groundY = K.Ground(ctx, ctx.Base.Position).Y
	local a0 = math.atan2(Pt.Back.Z, Pt.Back.X)
	for i = 1, n do
		local g = ghost(ctx, V, list[(i - 1) % #list + 1], .9, i % 3 == 0 and c2 or c1, c3)
		g.Born = o.Born + (i - 1) * o.Interval
		g.Until = o.Until or (g.Born + (o.Laps or 1) * o.Dur)
		g.R, g.Dir, g.A0, g.Prints = o.R(i), o.Dir(i), a0, i <= K.Count(ctx, 8)
		H.Ghosts[i] = g
	end
	local players = {}
	for j, tg in K.NearbyPlayers(ctx, 24) do
		if j > 4 then break end
		local hl = Instance.new("Highlight")
		hl.Adornee, hl.FillColor, hl.OutlineColor = tg.Model, c2, c1
		hl.FillTransparency, hl.OutlineTransparency = 1, 1
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = ctx.Folder
		players[j] = {Part = tg.Part, Hl = hl, Hot = 0}
	end
	local spawn = V3(Pt.Pos.X, groundY, Pt.Pos.Z)
	ctx:Every(function(t, dt)
		if t > (o.End or 99) then for _, g in H.Ghosts do if not g.Gone then vanish(ctx, g, c3) end end for _, p in players do p.Hl:Destroy() end return true end
		local parts, cfs = {}, {}
		local centre = ctx.Base.Position
		for i, g in H.Ghosts do
			local age = t - g.Born
			if g.Gone or age < 0 then continue end
			local over = t - g.Until
			if over > .6 then vanish(ctx, g, c3) continue end
			local vis = math.clamp(age / .35, 0, 1)
			local alt = o.Alt(t) + math.max(0, over) ^ 2 * 16
			if i == 1 and H.LeadAlt then alt += (H.LeadAlt - alt) * H.LeadK end
			local a = g.A0 + g.Dir * (age / o.Dur) * TAU
			local lap = V3(centre.X, groundY, centre.Z) + K.Polar(a, g.R, alt + g.Foot)
			local pos = (spawn + V3(0, g.Foot, 0)):Lerp(lap, FX.ease(vis))
			local tangent = K.Polar(a + g.Dir * .15, g.R, 0) - K.Polar(a, g.R, 0) + V3(0, (over > 0 and .5 or .06) * g.R * .15, 0)
			g.Hop += dt * 13
			pose(V, g, CFrame.lookAt(pos, pos + tangent), t, true, parts, cfs)
			setTr(g, math.min(1, .4 + (1 - vis) * .6 + math.max(0, over) / .6 * .6))
			g.Trail.Enabled = vis > .5 and over < .2
			if alt < 1.5 and vis >= 1 then
				if t - g.LastSpark > .3 then g.LastSpark = t g.Sparks:Emit(K.Count(ctx, 6)) end
				if g.Prints and t - g.LastPrint > .5 then g.LastPrint = t K.Stamp(ctx, V3(pos.X, groundY + .3, pos.Z), {Mesh = "StarPoint", Color = c3, Scale = .25, Life = 1.2, Rise = .1}) end
			end
			for _, p in players do if p.Part.Parent and (p.Part.Position - pos).Magnitude < 3 then p.Hot = .4 end end
		end
		if #parts > 0 then workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged) end
		for _, g in H.Ghosts do if not g.Gone then eye(g) end end
		for _, p in players do
			p.Hot = math.max(0, p.Hot - dt)
			p.Hl.FillTransparency = p.Hot > 0 and (.35 + .35 * math.abs(math.sin(t * 40))) or 1
			p.Hl.OutlineTransparency = p.Hot > 0 and .1 or 1
		end
	end)
	return H
end
-- the giant spirit bison: out of the portal at o.Born, half a lap at 4 studs over o.Lap seconds, then a parabola
-- clean over the player over o.Leap seconds; then it climbs away, or (o.Bellow) stops beside the player facing the
-- camera, raises its head and bellows a lilac breath for o.Bellow seconds before fading.
local function bison(ctx, V, Pt, c1, c2, c3, o)
	local g = ghost(ctx, V, (V and V.Has("Bison")) and "Bison" or "Horse", 1.8, c1, c3)
	local groundY = K.Ground(ctx, ctx.Base.Position).Y
	local a0 = math.atan2(Pt.Back.Z, Pt.Back.X)
	local R, ALT = 7.5, 4
	local breath
	if o.Bellow then
		breath = ctx:Emitter(ctx:Att(V3(0, .4, -1.2), g.Head or g.Root), {Texture = K.Tex.Smoke, Color = {c1, c2}, Size = {{0, .6}, {1, 2.4}}, Transparency = {{0, .3}, {1, 1}}, Lifetime = {.6, 1},
			Rate = 0, Speed = {5, 8}, SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Front, Brightness = 1.5, Drag = 2})
	end
	local spawn = V3(Pt.Pos.X, groundY + g.Foot, Pt.Pos.Z)
	local stop, stopCF
	ctx:Every(function(t, dt)
		local age = t - o.Born
		if age < 0 or g.Gone then return g.Gone end
		local parts, cfs = {}, {}
		local centre = V3(ctx.Base.Position.X, groundY, ctx.Base.Position.Z)
		local walking, tr, pos, cf = true, .4, nil, nil
		local aEnd = a0 - (math.pi + .2)
		if age < o.Lap then
			local u = age / o.Lap
			local a = a0 - u * (math.pi + .2)
			local lap = centre + K.Polar(a, R, ALT + g.Foot)
			pos = spawn:Lerp(lap, FX.ease(u / .3))
			cf = CFrame.lookAt(pos, pos + K.Polar(a - .15, R, 0) - K.Polar(a, R, 0))
			tr = .4 + .6 * (1 - math.clamp(u / .3, 0, 1))
		elseif age < o.Lap + o.Leap then
			local v = (age - o.Lap) / o.Leap
			local p1, p2 = centre + K.Polar(aEnd, R, ALT + g.Foot), centre + K.Polar(aEnd + math.pi, R, ALT + g.Foot)
			pos = p1:Lerp(p2, v) + V3(0, 7 * math.sin(v * math.pi), 0)
			cf = CFrame.lookAt(pos, pos + (p2 - p1).Unit + V3(0, math.cos(v * math.pi) * .6, 0))
			if not g.Leapt and v > .45 then g.Leapt = true if o.OnLeap then o.OnLeap(pos) end end
		elseif o.Bellow then
			local w = age - o.Lap - o.Leap
			if not stop then
				local cam = workspace.CurrentCamera
				local right = Pt.Back:Cross(Vector3.yAxis)
				stop = centre + (-Pt.Back * 4 + right * 6.5) + V3(0, g.Foot, 0)
				local eyePos = cam and cam.CFrame.Position or (stop - Pt.Back * 10)
				stopCF = CFrame.lookAt(stop, V3(eyePos.X, stop.Y, eyePos.Z))
			end
			local p2 = centre + K.Polar(aEnd + math.pi, R, ALT + g.Foot)
			local k = FX.ease(w / .7)
			pos = p2:Lerp(stop, k)
			local bell = FX.ease((w - .7) / .35)
			cf = CFrame.lookAt(pos, pos + (stop - p2).Unit):Lerp(stopCF * CFrame.Angles(.3 * bell, 0, 0), k)
			walking = k < 1
			if breath then breath.Rate = (w > .9 and w < .9 + o.Bellow) and 40 * (ctx.Quality or 1) or 0 end
			if w > .9 + o.Bellow then tr = .4 + (w - .9 - o.Bellow) / .5 * .6 end
			if w > 1.4 + o.Bellow then vanish(ctx, g, c3) return true end
		else
			local w = age - o.Lap - o.Leap
			local p2 = centre + K.Polar(aEnd + math.pi, R, ALT + g.Foot)
			pos = p2 + K.Polar(aEnd + math.pi, w * 10, 0) + V3(0, w * w * 18, 0)
			cf = CFrame.lookAt(pos, pos + K.Polar(aEnd + math.pi, 1, 0) + V3(0, w * 1.5, 0))
			tr = .4 + w / .6 * .6
			if w > .6 then vanish(ctx, g, c3) return true end
		end
		g.Hop += dt * 10
		pose(V, g, cf, t, walking, parts, cfs)
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		eye(g)
		setTr(g, math.min(1, tr))
		g.Trail.Enabled = tr < .7
	end)
	return g
end
-- the portal opening hit (own show only for the screen parts)
local function open(ctx, Pt, c1, c2, c3, big)
	K.Starburst(ctx, Pt.Pos, {Colors = {c1, c2}, Size = big and 12 or 7, Count = big and 36 or 20})
	ctx:Ripple(CFrame.new(Pt.Pos) * (CFrame.lookAt(Vector3.zero, -Pt.Back) * CFrame.Angles(math.pi / 2, 0, 0)), 2, big and 22 or 12, {W, c2}, .6, K.Tex.Ring)
	if big then ctx:Flash(c1, .4, .3) ctx:Shake(.3, .35) K.FOV(ctx, 6, .08, .5) end
end

---------------------------------------------------------------- Set 1: a small portal, three ghosts, a half-lap (2.8 s)
function M.Set1(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 2.8
	local V = voxel()
	local Pt = portal(ctx, c1, c2, c3, dark, {Scale = .45, T0 = .05, T1 = 2.2})
	ctx:At(.12, function() open(ctx, Pt, c1, c2, c3, false) end)
	herd(ctx, V, Pt, c1, c2, c3, {Count = 3, Born = .35, Interval = .15, Dur = 2.2, Laps = .5, End = 2.5,
		R = function() return 5.5 end, Dir = function() return 1 end, Alt = function(t) return math.max(0, (t - .8)) * .6 end})
	K.Title(ctx, .9, "embers", 7.5)
	return LEN
end

---------------------------------------------------------------- Set 2: the full portal, eight ghosts, the leap (5.2 s)
function M.Set2(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 5.2
	local P = K.Performer(ctx)
	if not P then return M.Set1(ctx, def) end
	local V = voxel()
	ctx:At(.02, function() P:Show() end)
	local Pt = portal(ctx, c1, c2, c3, dark, {Scale = 1, T0 = .05, T1 = 4.4})
	ctx:At(.15, function() open(ctx, Pt, c1, c2, c3, true) end)
	herd(ctx, V, Pt, c1, c2, c3, {Count = 8, Born = .4, Interval = .14, Dur = 2.4, Until = 4.0, End = 4.8,
		R = function() return 7 end, Dir = function() return 1 end, Alt = function(t) return 3 * FX.ease((t - .8) / 3.2) end})
	bison(ctx, V, Pt, c1, c2, c3, {Born = 2.2, Lap = 1.0, Leap = .6, OnLeap = function() ctx:Shake(.2, .3) K.FOV(ctx, 4, .08, .4) end})
	K.Herd(ctx, {At = .9, Radius = 16, Color = c2, Flavour = "lookup"})
	K.Herd(ctx, {At = 3.4, Radius = 16, Color = c2, Flavour = "flinch"})
	K.Float(ctx, P, {T0 = .3, T1 = 4.3, Height = 1.5, Rise = .6, Fall = .4, Spin = .35, Pose = "Wide"})
	ctx:At(4.0, function() K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .2), 2, 24, c2, .5, .4) end)
	K.Title(ctx, 3.3, "embers", 7.5)
	return LEN
end

---------------------------------------------------------------- Set 3: two counter-rotating laps, the ride, the leap and the bellow (8 s + 1 s charge-up)
function M.Set3(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 8.0
	local P = K.Performer(ctx)
	if not P then return M.Set2(ctx, def) end
	local V = voxel()
	local pre = ctx.Pre or 1
	-- charge-up: gold runes orbit inward over the dark sigil, the ground thuds
	K.ChargeUp(ctx, P, {Sigil = "Constellation", SigilScale = 1.6, Pose = "Crouch", PoseK = .9})
	local runes = {}
	for i = 1, 8 do runes[i] = {M = K.Mesh(ctx, "Numeral", {Color = c3, Transparency = 1}), A = (i - 1) / 8 * TAU} end
	local sigilCF = K.GroundCF(ctx, ctx.Base.Position, .3)
	ctx:Every(function(t)
		if t >= 0 then for _, r in runes do r.M:Destroy() end return true end
		local u = 1 + t / pre
		for _, r in runes do
			local a = r.A + u * 3
			K.Place(r.M, sigilCF * CFrame.new(math.cos(a) * (9 - 7 * FX.ease(u)), 0, math.sin(a) * (9 - 7 * FX.ease(u))) * CFrame.Angles(0, -a, 0), .9)
			r.M.Transparency = 1 - FX.ease(u / .3) * .9
		end
	end)
	ctx:Repeat(-pre + .25, -.05, .33, function()
		ctx:Shake(.12, .18)
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .15), 1, 7, dark, .4, .3)
	end)
	-- t = 0: the portal opens; the herd pours out in two counter-rotating laps
	local Pt = portal(ctx, c1, c2, c3, dark, {Scale = 1, T0 = 0, T1 = 6.6})
	ctx:At(.1, function()
		open(ctx, Pt, c1, c2, c3, true)
		ctx:Grade({Brightness = .04, Contrast = .15, Saturation = .2, TintColor = Color3.fromRGB(240, 228, 255)}, .15, 6.4, .9)
	end)
	local H = herd(ctx, V, Pt, c1, c2, c3, {Count = 16, Born = .4, Interval = .12, Dur = 2.6, Until = 6.0, End = 6.8,
		R = function(i) return i % 2 == 0 and 9.5 or 6.5 end, Dir = function(i) return i % 2 == 0 and -1 or 1 end,
		Alt = function(t) return 4 * FX.ease((t - 1) / 4.5) end})
	K.Herd(ctx, {At = .8, Radius = 16, Color = c2, Flavour = "lookup"})
	K.Herd(ctx, {At = 4.9, Radius = 16, Color = c2, Flavour = "flinch"})
	-- the body: arms wide, then scooped onto the lead ghost for one loop at 5 studs, then set down
	K.Float(ctx, P, {T0 = .3, T1 = 2.9, Height = 2, Rise = .6, Fall = .35, Spin = .4, Pose = "Wide"})
	local R0, R1 = 2.95, 5.2
	local startCF, endCF
	ctx:Every(function(t)
		if not P.Alive then return true end
		if t < R0 then return end
		local lead = H.Ghosts[1]
		if not lead or lead.Gone then P.Follow = true return true end
		local saddle = lead.Root.CFrame * CFrame.new(0, 2.2, 0)
		if t < R1 then
			local k = FX.ease((t - R0) / .3)
			H.LeadAlt, H.LeadK = 5, k
			startCF = startCF or P.Root.CFrame
			P:Pivot(startCF:Lerp(saddle, k))
			P:Toward("Rider", k)
			return
		end
		local u = (t - R1) / .45
		if u >= 1 then P.Follow = true return true end
		endCF = endCF or saddle
		P:Pivot(endCF:Lerp(ctx.Hrp.CFrame, FX.ease(u)))
		P:Toward("Rider", 1 - FX.ease(u))
	end)
	ctx:At(R0 + .1, function() ctx:Burst(P.Torso.Position, K.Count(ctx, 20), {Texture = K.Tex.Star, Color = {W, c3}, Size = {.6, 0}, Lifetime = {.4, .8}, Speed = {4, 9}, SpreadAngle = Vector2.new(180, 180), Drag = 3, Brightness = 5}) end)
	ctx:At(R1 + .5, function() K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .2), 2, 20, c2, .45, .4) end)
	-- the bison: out at 3.2, the leap over the player at about 4.9, the bellow before the camera, then it fades
	bison(ctx, V, Pt, c1, c2, c3, {Born = 3.2, Lap = 1.3, Leap = .7, Bellow = 1.0,
		OnLeap = function(pos)
			ctx:ImpactFrame()
			ctx:Shake(.3, .35)
			K.FOV(ctx, 6, .08, .5)
			K.Starburst(ctx, pos, {Colors = {c1, c3}, Size = 10, Count = 24})
		end})
	-- the herd climbs away and pops; the portal closes behind it
	ctx:At(6.6, function()
		K.ShockRing(ctx, CFrame.new(Pt.Pos) * (CFrame.lookAt(Vector3.zero, -Pt.Back) * CFrame.Angles(math.pi / 2, 0, 0)), 4, 26, c3, .6, .4)
		ctx:Flare(Pt.Pos, 10, c2, .5)
	end)
	K.Title(ctx, 5.0, "embers", 8)
	return LEN
end

return M
