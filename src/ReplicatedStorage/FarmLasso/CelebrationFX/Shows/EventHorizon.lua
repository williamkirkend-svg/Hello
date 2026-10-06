-- Shows.EventHorizon: a black hole tears open eight studs above the player: a lensing Glass sphere round a black ball,
-- a tilted three-layer accretion disc (white inner edge, orange body, dark rim) spinning fast, and everything loose
-- stretched into orange streaks toward it: dust, cobbles, straw, tall grass; the herd dangles a stud off the ground by
-- its leads; the player is pulled up feet-first to hang upside down beneath the disc. Nothing comes out until the
-- disc flips vertical, the hole collapses to a point and the frame goes black for one frame: then the supernova (a
-- cream shell to thirty studs, an orange-red shock ring, the starburst with the impact frame, slow dark-red ash) and
-- the player is ejected downward as a white comet into a glowing crater. (Oct 6 2026)
-- Set 1: a coin-sized void behind the back plane. Set 2: the disc, the pull, a 15-stud supernova. Set 3: the full collapse.
local Players = game:GetService("Players")
local FX = require(script.Parent.Parent.Parent)
local K = require(script.Parent.Parent.AuraKit)
local V3, W = Vector3.new, FX.W
local BLACK = Color3.new()
local M = {Pre = 1.0}

-- the hole: a black SmoothPlastic ball, the Glass lens sphere slightly larger round it, the accretion disc in three
-- copies (orange body, a smaller white inner edge, a larger dark rim at half transparency) tilted 20 degrees and
-- spinning, an orange light, and a box shell that streaks dust inward. o: Centre (fn -> pos), Size (ball diameter),
-- Disc (scale, nil for none), Ring (true: the thin Set 1 ring instead), Shell (studs), Dust (rate), Open (seconds),
-- Colors {c1, c2, c3, dark}. H:Collapse(dur) flips the disc vertical and shrinks the hole to a point; H:Pos().
local function hole(ctx, o)
	local c2, dark = o.Colors[2], o.Colors[4]
	local H = {Centre = o.Centre, K = 0}
	local ball = ctx:Part({Shape = Enum.PartType.Ball, Color = BLACK, Material = Enum.Material.SmoothPlastic, Size = Vector3.one * .1})
	local lens = K.Mesh(ctx, "LensSphere", {Material = Enum.Material.Glass, Color = Color3.fromRGB(215, 222, 235), Transparency = .45})
	if not lens:IsA("MeshPart") then lens.Shape = Enum.PartType.Ball end
	local discs = {}
	if o.Disc then
		for i, spec in {{c2, 1, 0, 7, 0}, {W, .5, .04, 11, 0}, {dark, 1.4, -.04, 4, .5}} do
			discs[i] = {M = K.Mesh(ctx, "AccretionDisc", {Color = spec[1], Transparency = spec[5]}), S = spec[2] * o.Disc, Y = spec[3], Spin = spec[4], Tr = spec[5]}
		end
	end
	local ring = o.Ring and ctx:Ring("RingThin", .1, .08, c2, 0)
	local shellSize = o.Shell or 14
	local shell = ctx:Part({Transparency = 1, Size = Vector3.one * shellSize})
	local dust = ctx:Emitter(shell, {Texture = K.Tex.Streak, Color = {dark, c2, W}, Size = {{0, .25}, {.5, 1.1}, {1, .15}}, Transparency = {{0, 1}, {.15, .1}, {1, .4}},
		Lifetime = {.45, .7}, Speed = {shellSize * .9, shellSize * 1.3}, Rate = 0, Brightness = 4, Drag = -1.5, Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Orientation = Enum.ParticleOrientation.VelocityParallel,
		Squash = {{0, 1.8}, {1, 3.5}}})
	local light = ctx:Light(ctx:Att(nil, ball), c2, 30, 0)
	local t0 = os.clock()
	local collapseAt, collapseDur
	ctx:Every(function()
		local age = os.clock() - t0
		local pos = H.Centre()
		local k = FX.back(age / (o.Open or .4))
		local tilt = math.rad(20)
		if collapseAt then
			local cu = (os.clock() - collapseAt) / collapseDur
			if cu >= 1 then
				ball:Destroy() lens:Destroy() shell:Destroy()
				if ring then ring:Destroy() end
				for _, d in discs do d.M:Destroy() end
				return true
			end
			tilt += (math.pi / 2 - tilt) * FX.ease(cu)
			k *= 1 - cu * cu
		end
		H.K = k
		local kc = math.clamp(k, 0, 1)
		local d = o.Size * k
		ball.Size = Vector3.one * math.max(.05, d)
		ball.CFrame = CFrame.new(pos)
		K.Place(lens, CFrame.new(pos) * CFrame.Angles(age * .3, age * .5, 0), d * .75 + .01)
		for _, disc in discs do
			K.Place(disc.M, CFrame.new(pos + V3(0, disc.Y, 0)) * CFrame.Angles(tilt, 0, 0) * CFrame.Angles(0, age * disc.Spin, 0), math.max(.01, disc.S * k))
			disc.M.Transparency = disc.Tr + (1 - disc.Tr) * (1 - kc)
		end
		if ring then
			K.SetRing(ring, math.max(.1, d * 2.6))
			ring.CFrame = CFrame.new(pos) * CFrame.Angles(tilt, age * 3, 0) * FX.FLAT
		end
		shell.CFrame = CFrame.new(pos)
		dust.Rate = (o.Dust or 40) * kc * (ctx.Quality or 1)
		light.Brightness = 4 * kc
	end)
	function H:Pos() return self.Centre() end
	function H:Collapse(dur) collapseAt, collapseDur = os.clock(), dur or .3 end
	return H
end
-- a cream shell expanding from pos to `size` studs over 0.35 s and fading
local function shellPop(ctx, pos, size, c1)
	local shell = ctx:Part({Shape = Enum.PartType.Ball, Color = W, Transparency = .3, Size = Vector3.one * .5, CFrame = CFrame.new(pos)})
	local t0 = os.clock()
	ctx:Every(function()
		local u = (os.clock() - t0) / .35
		if u >= 1 then shell:Destroy() return true end
		shell.Size = Vector3.one * (.5 + (size - .5) * FX.ease(u))
		shell.CFrame = CFrame.new(pos)
		shell.Transparency = .3 + .7 * u * u
		shell.Color = W:Lerp(c1, u)
	end)
end
-- the pull: the double rises feet-first over 0.8 s, turning over as it goes, and hangs upside down h studs up with its
-- arms dangling until `drop`
local DANGLE = {RightShoulder = CFrame.Angles(0, 0, 2.7), LeftShoulder = CFrame.Angles(0, 0, -2.7)}
local function pullUp(ctx, P, t0, drop, h)
	local home = ctx.Hrp.CFrame
	ctx:Every(function(t)
		if not P.Alive then return true end
		if t < t0 then return end
		if t > drop then return true end
		local u = FX.ease((t - t0) / .8)
		local base = CFrame.new(ctx.Hrp.Position) * (home - home.Position)
		local y = h * u + math.sin(t * 1.5) * .2 * u
		P:Pivot(base * CFrame.new(0, y, 0) * CFrame.Angles(math.pi * u, 0, math.sin(t * 1.1) * .06 * u))
		P:Toward("Hang", u)
		P:Pose(DANGLE, u)
		P:Pose({RightElbow = CFrame.Angles(.3 + math.sin(t * 2.3) * .3, 0, 0), LeftElbow = CFrame.Angles(.3 + math.cos(t * 2.1) * .3, 0, 0)}, u)
	end)
end
-- an animal lifted a stud by its lead (after the kit's look-up hop), legs kicking, held until `drop`, then dropped
local function dangle(ctx, tg, drop)
	if not K.CanMove(tg) then return end
	local m = tg.Model
	local base = m:GetPivot()
	local t0 = os.clock()
	ctx:Every(function(t)
		if not m.Parent then return true end
		local age = os.clock() - t0
		local up = FX.ease((age - .35) / .5)
		if t > drop then
			local d = (t - drop) / .22
			if d >= 1 then pcall(function() m:PivotTo(base) end) return true end
			up *= 1 - d * d
		end
		local kick = math.sin(age * 9 + tg.Dist) * .1 * up
		pcall(function() m:PivotTo(base * CFrame.new(0, up + math.sin(age * 3 + tg.Dist) * .1 * up, 0) * CFrame.Angles(kick, 0, kick * .6)) end)
	end)
end
-- one frame of total black: the kit's flash (capped at .7) plus our own opaque frame for two frames (own show only)
local function blackout(ctx)
	ctx:Flash(BLACK, 1, .08)
	if not ctx.Local then return end
	local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then return end
	local gui = Instance.new("ScreenGui")
	gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder = true, false, 40
	local f = Instance.new("Frame")
	f.Size, f.BorderSizePixel, f.BackgroundColor3 = UDim2.fromScale(1, 1), 0, BLACK
	f.Parent = gui
	gui.Parent = pg
	local frames = 0
	ctx:Every(function() frames += 1 if frames >= 2 then gui:Destroy() return true end end)
	task.delay(.12, function() if gui.Parent then gui:Destroy() end end)
end
-- the supernova at pos: the sky starburst, the cream shell to `size` studs, an orange-red shock ring facing the camera,
-- the ground hit with the impact frame, and `ashT` seconds of dark-red ash falling slowly from twenty studs up
local function supernova(ctx, pos, size, C, ashT)
	local c1, c2, c3, dark = C[1], C[2], C[3], C[4]
	K.Starburst(ctx, pos, {Colors = {c1, c2}, Size = size, Count = 48})
	shellPop(ctx, pos, size, c1)
	local cam = workspace.CurrentCamera
	local eye = cam and cam.CFrame.Position or pos - K.Behind(ctx) * 20
	K.ShockRing(ctx, CFrame.lookAt(pos, eye) * CFrame.Angles(math.pi / 2, 0, 0), 2, size * 2, c2:Lerp(c3, .5), .5, .6)
	K.Hit(ctx, ctx.Base.Position + V3(0, 2, 0), {Colors = {c1, c2}, Impact = true, Ring = size * 1.4, Burst = size * .35, Lines = 24, FOV = 9, Shake = .5})
	local l = K.Light(ctx, pos - ctx.Base.Position, c1, size * 2.5, 10)
	FX.Tween(l, .8, {Brightness = 0})
	local sky = ctx:Part({Transparency = 1, Size = V3(24, 1, 24)})
	local ash = ctx:Emitter(sky, {Texture = K.Tex.Petal, Color = {c3, dark}, Size = {.6, .35}, Transparency = {{0, .2}, {.8, .3}, {1, 1}}, Lifetime = {2.5, 3.5}, Speed = {.3, 1},
		SpreadAngle = Vector2.new(180, 180), Rate = 0, Acceleration = V3(0, -3, 0), Drag = 2, RotSpeed = {-150, 150}, Rotation = {0, 360}, Brightness = 2,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume})
	local a0 = os.clock()
	ctx:Every(function()
		local age = os.clock() - a0
		sky.CFrame = ctx.Base * CFrame.new(0, 20, 0)
		ash.Rate = age < ashT and 20 * (ctx.Quality or 1) or 0
		if age > ashT + 3.6 then sky:Destroy() return true end
	end)
end
-- the comet: the double reappears at from() in a star pose at t0 and dives straight down for 0.3 s behind a white
-- trail; onLand runs as it touches down
local function comet(ctx, P, from, t0, C, onLand)
	local c1, c2 = C[1], C[2]
	local holder = ctx:Part({Transparency = 1, Size = Vector3.one * .2})
	local ta0, ta1 = ctx:Att(V3(0, .9, 0), holder), ctx:Att(V3(0, -.9, 0), holder)
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = ta0, ta1
	tr.LightEmission, tr.LightInfluence = 1, 0
	tr.Lifetime = .45
	tr.Texture = K.Tex.Streak
	tr.TextureMode = Enum.TextureMode.Stretch
	tr.Color = FX.cseq({W, W, c1, c2})
	tr.Transparency = FX.nseq({{0, 0}, {.6, .3}, {1, 1}})
	tr.WidthScale = FX.nseq({{0, 1}, {1, 0}})
	tr.Enabled = false
	pcall(function() tr.Brightness = 4 end)
	tr.Parent = holder
	local glow = ctx:Emitter(ta0, {Texture = K.Tex.Glow, Color = {W, c1}, Size = {2.5, 0}, Transparency = {{0, .2}, {1, 1}}, Lifetime = {.2, .35}, Rate = 0, Brightness = 5})
	local start, land
	ctx:At(t0, function()
		if not P.Alive then return end
		start = from()
		land = CFrame.new(ctx.Hrp.Position) * (ctx.Hrp.CFrame - ctx.Hrp.CFrame.Position)
		P:Pivot(CFrame.new(start) * (land - land.Position))
		for _, p in P.Parts do p.Transparency = p.Name == "HumanoidRootPart" and 1 or 0 end
		P:Toward("Star", 1)
		tr.Enabled = true
		glow.Rate = 40 * (ctx.Quality or 1)
		K.Starburst(ctx, start, {Colors = {W, c1}, Size = 6, Count = 16})
	end)
	K.Fly(ctx, P, {T0 = t0, T1 = t0 + .3, Pitch = 0, Bank = 0, Pose = "Star",
		Path = function(u) local s = start or from() return s:Lerp(land and land.Position or s, u) end,
		OnU = function(_, _, _, cf) holder.CFrame = cf * CFrame.new(0, .5, 0) end,
		OnDone = function()
			tr.Enabled = false
			glow.Rate = 0
			task.delay(.6, function() holder:Destroy() end)
			if land then P:Pivot(land) end
			P.Follow = true
			onLand()
		end})
end
-- the crater: an orange scorch ring and cracks underfoot, a ground ring, sparks, a shake, and a kneel held until near
-- the end of the show (t0 is the landing time)
local function crater(ctx, P, C, t0, len)
	local c1, c2 = C[1], C[2]
	local pos = ctx.Base.Position
	K.Stamp(ctx, pos, {Mesh = "ScorchRing", Color = c2, Scale = 1.6, Life = len - t0 - .1, Rise = .3})
	K.Cracks(ctx, {At = t0, Count = 8, Len = 7, Color = c2, Life = len - t0 - .3, Stagger = .03})
	K.ShockRing(ctx, K.GroundCF(ctx, pos, .2), 2, 24, c2, .45, .5)
	ctx:Burst(pos + V3(0, 1, 0), K.Count(ctx, 40), {Texture = K.Tex.Star, Color = {W, c1, c2}, Size = {.5, 0}, Lifetime = {.6, 1.2}, Speed = {8, 18}, SpreadAngle = Vector2.new(80, 80),
		Acceleration = V3(0, -20, 0), Drag = 1, Brightness = 5})
	ctx:Shake(.35, .4)
	ctx:Every(function(t)
		if not P.Alive or t > len - .3 then return true end
		local k = FX.ease((t - t0) / .18) * (1 - FX.ease((t - (len - 1.1)) / .6))
		P:Toward("Kneel", k)
	end)
end

---------------------------------------------------------------- Set 1: the coin-sized void (2.6 s)
function M.Set1(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 2.6
	local back = K.Behind(ctx)
	-- a void at chest height behind the back plane: a thin orange ring and the lens sphere, dust streaking in
	local H = hole(ctx, {Colors = {c1, c2, c3, dark}, Centre = function() return ctx.Hrp.Position + back * 1.8 + V3(0, .4, 0) end, Size = .6, Ring = true, Shell = 8,
		Dust = 30, Open = .35})
	ctx:At(1.7, function() H:Collapse(.25) end)
	-- the small cream pop
	ctx:At(1.95, function()
		local pos = H:Pos()
		K.Starburst(ctx, pos, {Colors = {c1, c2}, Size = 6, Count = 18})
		shellPop(ctx, pos, 5, c1)
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .15), 1, 10, c2, .4, .35)
	end)
	K.Title(ctx, 1.9, "embers", 7.5)
	return LEN
end

---------------------------------------------------------------- Set 2: the disc, the pull, a 15-stud supernova (5.2 s)
function M.Set2(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local C = {c1, c2, c3, dark}
	local LEN = 5.2
	local P = K.Performer(ctx)
	if not P then return M.Set1(ctx, def) end
	ctx:At(.02, function() P:Show() end)
	local centre = function() return ctx.Hrp.Position + V3(0, 8, 0) end
	local H = hole(ctx, {Colors = C, Centre = centre, Size = 2.2, Disc = .8, Shell = 14, Dust = 40, Open = .45})
	-- debris streams and the grass stretch up into it; the herd dangles; the player hangs upside down beneath the disc
	K.Debris(ctx, {At = .2, Count = 10, Radius = 6, Lift = 6, Centre = centre, Until = 3.1, Orbit = .5, Stretch = true})
	K.Debris(ctx, {At = .3, Count = 6, Radius = 5, Lift = 5, Centre = centre, Until = 3.1, Meshes = {"GrassClump"}, Stretch = true})
	pullUp(ctx, P, .3, 2.95, 4)
	K.Herd(ctx, {At = 1.2, Radius = 14, Color = c2, Flavour = "lookup", Max = 3, Effect = function(tg) dangle(ctx, tg, 3.0) end})
	-- the collapse: the disc flips vertical, the hole shrinks to a point, the black frame, the supernova
	ctx:At(2.95, function() H:Collapse(.3) end)
	ctx:At(3.25, function() P:Visible(false) blackout(ctx) end)
	ctx:At(3.33, function() supernova(ctx, centre(), 15, C, 1.6) end)
	comet(ctx, P, centre, 3.5, C, function() crater(ctx, P, C, 3.8, LEN) end)
	K.Title(ctx, 3.95, "embers", 7.5)
	return LEN
end

---------------------------------------------------------------- Set 3: the full collapse (7.4 s + 1 s charge-up)
function M.Set3(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local C = {c1, c2, c3, dark}
	local LEN = 7.4
	local P = K.Performer(ctx)
	if not P then return M.Set2(ctx, def) end
	local pre = ctx.Pre or 1
	-- charge-up: the inhale with the arms dragged upward, the plaza's lights swing to dark red, a flare where the hole will open
	K.ChargeUp(ctx, P, {Sigil = "ScorchRing", SigilScale = 1.2, Pose = "Pulled", PoseK = .7})
	K.LightPaint(ctx, {At = -pre + .1, Radius = 45, Color = c3, Hold = pre + 4.3, Boost = 1.3})
	local centre = function() return ctx.Hrp.Position + V3(0, 8, 0) end
	ctx:At(-.5, function() ctx:Flare(centre(), 4, c2, .5) end)
	-- t = 0: the hole tears open, the picture pulls in three degrees, a dark ring contracts on the ground
	local H
	ctx:At(0, function()
		H = hole(ctx, {Colors = C, Centre = centre, Size = 2.6, Disc = 1, Shell = 14, Dust = 50, Open = .35})
		K.FOV(ctx, -3, .3, .6, 2.5)
		ctx:Shake(.2, .3)
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .15), 30, 2, dark, .4, .5)
	end)
	-- everything goes in: debris streams, the tall grass stretching, the herd dangling, the player hung upside down
	K.Debris(ctx, {At = .1, Count = 16, Radius = 7, Lift = 6, Centre = centre, Until = 4.2, Orbit = .5, Stretch = true})
	K.Debris(ctx, {At = .2, Count = 10, Radius = 6, Lift = 5, Centre = centre, Until = 4.2, Meshes = {"GrassClump"}, Stretch = true})
	pullUp(ctx, P, .4, 3.95, 4)
	K.Herd(ctx, {At = 1.1, Radius = 16, Color = c2, Flavour = "lookup", Max = 3, Effect = function(tg) dangle(ctx, tg, 4.0) end})
	-- the collapse: the flip, the point, the black frame, the 30-stud supernova, the comet, the crater
	ctx:At(3.95, function() if H then H:Collapse(.3) end end)
	ctx:At(4.25, function() P:Visible(false) blackout(ctx) end)
	ctx:At(4.33, function() supernova(ctx, centre(), 30, C, 2.5) end)
	comet(ctx, P, centre, 4.55, C, function() crater(ctx, P, C, 4.85, LEN) end)
	K.Title(ctx, 5.1, "embers", 8)
	return LEN
end

return M
