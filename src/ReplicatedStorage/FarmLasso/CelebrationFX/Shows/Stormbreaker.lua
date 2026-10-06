-- Shows.Stormbreaker: a barn-sized storm cloud forms in the sky with lightning flickering inside it and the plaza
-- darkens under it; a spiked thunder crown hangs over the player with bolts arcing between its spikes; braided
-- lightning twists down from the crown to the raised fist, lifts the player, tightens to white, and the fist comes
-- down into the ground: a low cyan shockwave with crawling arcs on its edge flattens the grass outward, and where
-- the second ring stops an ice-spike ring erupts. (Oct 6 2026)
-- Set 1: one bolt to the fist, a small ring, crawling floor arcs. Set 2: the cloud, the crown, a braid of three, the
-- slam, a 15-stud ring. Set 3: the sky darkens in the charge-up, the crown splits in two, a braid of five, two rings
-- 0.4 s apart, the ice-spike ring, and the braid lingering as a column the player stands in.
local FX = require(script.Parent.Parent.Parent)
local K = require(script.Parent.Parent.AuraKit)
local V3, W, TAU, rng = Vector3.new, FX.W, K.TAU, FX.rng
local M = {Pre = 1.0}
-- feet planted, the right fist up catching the braid, the torso leaning 15 degrees into the strain
local STRAIN = {RightShoulder = CFrame.Angles(0, 0, 2.95), RightElbow = CFrame.Angles(.3, 0, 0), LeftShoulder = CFrame.Angles(.3, 0, -.5),
	Waist = CFrame.Angles(-.26, 0, .2), Neck = CFrame.Angles(.45, 0, 0), RightHip = CFrame.Angles(0, 0, .25), LeftHip = CFrame.Angles(0, 0, -.25)}
local SPEED = 18 -- the shockwave's speed, studs per second

---------------------------------------------------------------- lightning helpers (shared with ThunderStampede by copy)
-- a sky bolt from p0 to p1: a white core bolt inside a coloured glow bolt, re-jagged three times over 0.2 s, standing
-- for `hold` more seconds, then faded and destroyed; a light flash, a starburst at the foot and a ring on the ground
local function strike(ctx, p0, p1, color, big, hold)
	local n = big and 14 or 10
	local setC, core = ctx:Bolt(n, big and .4 or .22, W)
	local setG, glow = ctx:Bolt(n, big and 1.3 or .7, color)
	local jag = (p1 - p0).Magnitude * (big and .07 or .09)
	local function jagAll(trC, trG) setC(p0, p1, jag, trC) setG(p0, p1, jag, trG) end
	jagAll(0, .35)
	task.delay(.07, function() jagAll(.1, .5) end)
	task.delay(.14, function() jagAll(0, .35) end)
	task.delay(.2 + (hold or 0), function()
		for _, q in core do FX.Tween(q, .25, {Transparency = 1}) end
		for _, q in glow do FX.Tween(q, .25, {Transparency = 1}) end
	end)
	task.delay(.5 + (hold or 0), function() for _, q in core do q:Destroy() end for _, q in glow do q:Destroy() end end)
	local att = ctx:Att(p1 + V3(0, 1.5, 0) - ctx.Base.Position)
	local l = ctx:Light(att, color, big and 40 or 22, big and 12 or 6)
	FX.Tween(l, .35 + (hold or 0), {Brightness = 0})
	task.delay(.45 + (hold or 0), function() att:Destroy() end)
	K.Starburst(ctx, p1, {Colors = {W, color}, Size = big and 12 or 6, Count = big and 30 or 16})
	K.ShockRing(ctx, K.GroundCF(ctx, p1, .15), 1, big and 16 or 7, color, .35, .35)
end
-- a pool of crawling arcs (the old Free builder's ground arcs, pooled): each is a white core bolt plus a coloured
-- glow bolt, hidden while free. Run(path, dur, period, onDone) crawls one along path(u) (world positions) for dur
-- seconds, re-jagging it every `period` seconds with the tail a fifth of the path behind the head.
local function arcPool(ctx, color, n)
	local A = {Bolts = {}, Alive = true}
	for i = 1, n do
		local setC, core = ctx:Bolt(5, .14, W)
		local setG, glow = ctx:Bolt(5, .45, color)
		local b = {SetC = setC, SetG = setG, Parts = {}, Free = true}
		for _, q in core do q.Transparency = 1 table.insert(b.Parts, q) end
		for _, q in glow do q.Transparency = 1 table.insert(b.Parts, q) end
		A.Bolts[i] = b
	end
	local function hide(b) for _, q in b.Parts do q.Transparency = 1 end b.Free = true end
	function A:Run(path, dur, period, onDone)
		local b
		for _, x in self.Bolts do if x.Free then b = x break end end
		if not b then if onDone then onDone() end return end
		b.Free = false
		local t0, last = os.clock(), -1
		ctx:Every(function()
			local u = (os.clock() - t0) / dur
			if u >= 1 or not self.Alive then hide(b) if onDone then onDone() end return true end
			if os.clock() - last >= (period or .06) then
				last = os.clock()
				local head, tail = path(u), path(math.max(0, u - .2))
				local jag = math.max(.3, (head - tail).Magnitude * .25)
				b.SetC(tail, head, jag, 0)
				b.SetG(tail, head, jag, .45)
			end
		end)
	end
	function A:Destroy() self.Alive = false for _, b in self.Bolts do for _, q in b.Parts do q:Destroy() end end end
	return A
end
-- n arcs crawl out along the ground from the feet to R studs out
local function floorArcs(A, ctx, n, R, dur)
	local feet = ctx.Base.Position + V3(0, .3, 0)
	for i = 1, n do
		local e = K.Ground(ctx, feet + K.Polar(i / n * TAU + rng:NextNumber(-.3, .3), R * rng:NextNumber(.8, 1.1), 0)) + V3(0, .35, 0)
		A:Run(function(u) return feet:Lerp(e, u) end, dur, .06)
	end
end

---------------------------------------------------------------- the storm pieces
-- the sky cloud: three dark lobes hanging behind the player, lightning flickering inside, the light pulsing
local function cloud(ctx, dark, c2, tIn, tOut)
	local lobes = {}
	for i, o in {{Behind = 7, Height = 14, Scale = 1.5}, {Behind = 9.5, Height = 14.8, Scale = 1.15}, {Behind = 4.5, Height = 13.2, Scale = 1.1}} do
		lobes[i] = K.Monument(ctx, {Mesh = "CloudLobe", Height = o.Height, Behind = o.Behind, Scale = o.Scale, Color = dark, Material = Enum.Material.SmoothPlastic,
			Transparency = .15, Light = 0, In = tIn + (i - 1) * .12, Out = tOut, Spin = .05, Tilt = 0, Rise = .7, FallbackSize = V3(9, 4.5, 6)})
	end
	local inner = ctx:Att(V3(0, -.3, 0), lobes[1].Part)
	local flick = ctx:Emitter(inner, {Texture = K.Tex.Lightning, Color = {W, c2}, Size = {5, 7}, Transparency = {{0, 1}, {.1, .2}, {.7, .3}, {1, 1}}, Lifetime = {.12, .25},
		Rate = 0, Speed = 0, Rotation = {0, 360}, Brightness = 5, ZOffset = 1.5})
	K.Flipbook(flick, "Lightning", Enum.ParticleFlipbookMode.Loop, 24)
	local light = ctx:Light(inner, c2, 45, 0)
	ctx:Every(function(t)
		if t > tOut then flick.Rate = 0 light.Brightness = 0 return true end
		local k = K.Soft(t, tIn + .3, tOut, .5, .5)
		flick.Rate = 6 * k * (ctx.Quality or 1)
		light.Brightness = 7 * k * (rng:NextNumber() < .12 and 1 or .12)
	end)
	return lobes
end
-- the thunder crown: a spiked halo over the head (height a number or fn(t)), spinning, bolts arcing between its
-- spikes every quarter second. Returns {Part, Att, Pos()}; Att is where the braid hangs from.
local function crown(ctx, A, c1, c2, t0, t1, height, scale, spin)
	local m = K.Mesh(ctx, "SpikeCrown", {Color = c1, Transparency = 1})
	local att = ctx:Att(V3(0, -.3, 0), m)
	local light = ctx:Light(att, c2, 24, 0)
	local C = {Part = m, Att = att}
	function C.Pos() return m.Position end
	ctx:Every(function(t)
		if t > t1 + .6 then m:Destroy() return true end
		local k = K.Env(t, t0, t1, .5, .5)
		local h = type(height) == "function" and height(t) or height
		K.Place(m, CFrame.new(ctx.Hrp.Position + V3(0, h, 0)) * CFrame.Angles(0, t * spin, 0) * CFrame.Angles(math.sin(t * 1.3) * .06, 0, math.cos(t) * .06), scale * math.max(.02, k))
		m.Transparency = k > .02 and .05 or 1
		light.Brightness = 5 * k
	end)
	local R = 2.8 * scale
	ctx:Repeat(t0 + .3, t1 - .3, .24, function()
		local a0 = rng:NextNumber(0, TAU)
		A:Run(function(u) return m.Position + K.Polar(a0 + u * TAU / 6, R, .3 + math.sin(u * math.pi) * .4) end, .3, .08)
	end)
	return C
end
-- the braided bolt: n Beams between two attachments whose curve handles are driven every frame with phase-offset
-- sines so they twist round each other. Beam 1 is the white core, the rest alternate the theme colours.
-- B:Tighten(dur) pulls the braid tight and white over dur; B:Retarget(att) moves its foot; B:Stop() ends it.
local function braid(ctx, a0, a1, c1, c2, n, t0, t1)
	local B = {Beams = {}, Amp = 2.2, Alive = true}
	for i = 1, n do
		local core = i == 1
		B.Beams[i] = ctx:Beam(a0, a1, {Color = core and W or (i % 2 == 0 and c2 or c1), Width0 = core and .35 or .5, Width1 = core and .35 or .5,
			Transparency = core and 0 or .15, Brightness = core and 6 or 4, Segments = 18, Enabled = false})
	end
	function B:Tighten(dur) self.T0 = os.clock() self.Dur = dur end
	function B:Retarget(att) for _, b in self.Beams do b.Attachment1 = att end end
	function B:Stop() self.Alive = false for _, b in self.Beams do b.Enabled = false end end
	ctx:Every(function(t)
		if not B.Alive or t > t1 then B:Stop() return true end
		if t < t0 then return end
		local tight = B.T0 and FX.ease((os.clock() - B.T0) / B.Dur) or 0
		local amp = B.Amp * (1 - tight * .85)
		for i, b in B.Beams do
			b.Enabled = true
			local ph = t * 9 + (i - 1) / n * TAU
			b.CurveSize0 = math.sin(ph) * amp
			b.CurveSize1 = math.cos(ph * 1.15) * amp
			if i > 1 and B.T0 and tight < 1 then
				b.Color = FX.cseq((i % 2 == 0 and c2 or c1):Lerp(W, tight))
				b.Width0 = .5 * (1 - tight * .5)
				b.Width1 = b.Width0
			end
		end
	end)
	return B
end
-- the physical shockwave: a low cyan ring racing out to radius R with crawling arcs on its edge (a box-surface
-- lightning emitter on a follower part that grows with the ring), a dark rim behind it, the grass blown flat as it
-- passes, the props flashed, the herd pushed when it reaches them
local function shockwave(ctx, at, c1, c2, dark, R)
	local life = R / SPEED
	ctx:At(at, function()
		local g = K.GroundCF(ctx, ctx.Base.Position, .2)
		K.ShockRing(ctx, g, 1, R * 2, c2, life, .6)
		K.ShockRing(ctx, g * CFrame.new(0, -.08, 0), 1, R * 2.2, dark, life * 1.15, .45)
		local edge = ctx:Part({Transparency = 1, Size = V3(1, .8, 1), CFrame = g * CFrame.new(0, .4, 0)})
		local arcs = ctx:Emitter(edge, {Texture = K.Tex.Lightning, Color = {W, c2}, Size = {1.4, 2.4}, Transparency = {{0, 1}, {.1, 0}, {.8, 0}, {1, 1}}, Lifetime = {.1, .2},
			Rate = 0, Speed = 0, Rotation = {0, 360}, Brightness = 5, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface})
		K.Flipbook(arcs, "Lightning", Enum.ParticleFlipbookMode.Loop, 30)
		local t0 = os.clock()
		ctx:Every(function()
			local u = (os.clock() - t0) / life
			if u >= 1 then arcs.Rate = 0 task.delay(.3, function() edge:Destroy() end) return true end
			local d = 1 + (R * 2 - 1) * FX.ease(u)
			edge.Size = V3(d, .8, d)
			arcs.Rate = (30 + d * 4) * (ctx.Quality or 1)
		end)
	end)
	-- the grass is lifted .4 studs as the ring reaches it and dropped at once, so it looks blown flat
	for _, r in {R * .35, R * .75} do
		local reach = at + (r / R) * life * .6
		K.Debris(ctx, {At = reach, Count = 5, Radius = r, Lift = .4, Meshes = {"GrassClump"}, Until = reach + .35, Orbit = 0})
	end
	K.LightPaint(ctx, {At = at, Radius = R * 1.6, Color = c2, Hold = life + .2, Boost = 2, Highlight = true})
	K.Herd(ctx, {At = at + (R * .5) / SPEED, Radius = R, Color = c2, Flavour = "bolt"})
end
-- the ice-spike ring where the second shockwave stops: n glass spikes with neon cores grow out of the ground with
-- overshoot over 0.25 s (scale (1, k, 1), base pinned), hold, then shatter and fade
local function iceSpikes(ctx, at, c1, c2, R, n)
	ctx:At(at, function()
		local centre = ctx.Base.Position
		local spikes = {}
		for i = 1, n do
			local a = (i - 1) / n * TAU + rng:NextNumber(-.15, .15)
			-- rooted on the ground, its local X pointing away from the centre, leaning a little outward and a little sideways
			local base = K.GroundCF(ctx, centre + K.Polar(a, R, 0), 0) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, -rng:NextNumber(.1, .3)) * CFrame.Angles(rng:NextNumber(-.15, .15), 0, 0)
			local shell = K.Mesh(ctx, "IceSpike", {Color = c1, Material = Enum.Material.Glass, Transparency = .25})
			local core = K.Mesh(ctx, "IceSpike", {Color = W})
			spikes[i] = {Shell = shell, Core = core, Base = base, S = rng:NextNumber(1.1, 1.7), Delay = (i - 1) * .03, H = (shell:GetAttribute("BaseSize") or V3(.6, 3, .6)).Y}
		end
		local t0 = os.clock()
		ctx:Every(function()
			local age = os.clock() - t0
			if age > .75 then
				K.Starburst(ctx, centre + V3(0, 2, 0), {Colors = {W, c1}, Size = 10, Count = 24})
				for i, s in spikes do
					task.delay((i - 1) * .05, function()
						ctx:Burst(s.Shell.Position, K.Count(ctx, 10), {Texture = K.Tex.Star, Color = {W, c1}, Size = {.6, 0}, Lifetime = {.25, .5}, Speed = {6, 12},
							SpreadAngle = Vector2.new(180, 180), Drag = 4, Brightness = 5})
					end)
					FX.Tween(s.Shell, .3, {Transparency = 1}) FX.Tween(s.Core, .3, {Transparency = 1})
					task.delay(.45, function() s.Shell:Destroy() s.Core:Destroy() end)
				end
				ctx:Burst(centre + V3(0, 1, 0), K.Count(ctx, 30), {Texture = K.Tex.Star, Color = {W, c1, c2}, Size = {.5, 0}, Lifetime = {.4, .8}, Speed = {8, 16},
					SpreadAngle = Vector2.new(180, 180), Drag = 3, Brightness = 5})
				return true
			end
			for _, s in spikes do
				local k = math.max(.01, FX.back((age - s.Delay) / .25))
				-- (AuraMeshData.Pivots pins the spike's base to the ground; K.Place scales about that base)
				local cf = s.Base
				K.Place(s.Shell, cf, V3(s.S, s.S * k, s.S))
				K.Place(s.Core, cf, V3(s.S * .4, s.S * k * .92, s.S * .4))
			end
		end)
	end)
end
-- the fist attachment the braid lands on
local function fistAtt(ctx, P) return ctx:Att(V3(0, -.5, 0), P.RightHand or P.Torso) end
-- the slam: the punch pose snaps in, the hard hit, then the pose eases out
local function slam(ctx, P, at, c1, c2, release)
	ctx:Every(function(t)
		if t < at then return end
		if t > release + .7 then return true end
		P:Toward("Punch", FX.ease((t - at) / .1) * (1 - FX.ease((t - release) / .6)))
	end)
	ctx:At(at + .05, function()
		K.Hit(ctx, ctx.Base.Position + V3(0, .3, 0), {Colors = {c1, c2}, Impact = true, Ring = 20, Burst = 12, Lines = 30})
		K.Cracks(ctx, {At = 0, Count = 6, Len = 5, Color = c2, Life = 2.5, Radius = 1, Stagger = .03})
	end)
end

---------------------------------------------------------------- Set 1: one bolt to the fist, a small ring, floor arcs (2.6 s)
function M.Set1(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 2.6
	local A = arcPool(ctx, c2, 5)
	K.Skin(ctx, {Color = c2, Lightning = true, T0 = .05, T1 = 2.0})
	K.Sweeps(ctx, {Colors = {c1, c2}, T0 = .5, T1 = 1.6, Period = .35, Radius = 4, Height = 2.5, Climb = 5})
	ctx:At(.2, function() floorArcs(A, ctx, 3, 5, .3) end)
	-- the bolt to the fist, a small ring, the floor arcs run again
	ctx:At(.55, function()
		local hand = ctx.Char:FindFirstChild("RightHand") or ctx.Char:FindFirstChild("Right Arm") or ctx.Hrp
		local fist = hand.Position + V3(0, .3, 0)
		strike(ctx, fist + V3(0, 25, 0) + K.Behind(ctx) * 3, fist, c2, false, .1)
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .15), 2, 12, c2, .4, .4)
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .1), 2, 14, dark, .5, .3)
		floorArcs(A, ctx, 5, 7, .5)
	end)
	ctx:At(1.4, function() floorArcs(A, ctx, 4, 6, .5) end)
	ctx:Repeat(.6, 1.8, .3, function() ctx:Flare(ctx.Base.Position + K.Polar(rng:NextNumber(0, TAU), rng:NextNumber(2, 4), rng:NextNumber(1, 5)), rng:NextNumber(1.5, 3), c1, .3) end)
	ctx:At(2.3, function() A:Destroy() end)
	K.Title(ctx, 1.0, "glitch", 7.5)
	return LEN
end

---------------------------------------------------------------- Set 2: the cloud, the crown, a braid of three, the slam (5.2 s)
function M.Set2(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 5.2
	local P = K.Performer(ctx)
	if not P then return M.Set1(ctx, def) end
	local A = arcPool(ctx, c2, 8)
	ctx:At(.02, function() P:Show() end)
	ctx:Grade({Brightness = -.15, Contrast = .08, Saturation = -.1}, .5, 3.4, .8)
	cloud(ctx, dark, c2, .1, 4.5)
	K.Skin(ctx, {Color = c2, Lightning = true, T0 = .2, T1 = 4.4})
	-- the crown rises to ten studs over the head and lifts away as the player comes up; the braid of three twists
	-- down to the raised fist; the body strains into it
	local Cr = crown(ctx, A, c1, c2, .3, 4.3, function(t) return 10 + 2.5 * FX.ease((t - .9) / .8) end, 1, .5)
	local fist = fistAtt(ctx, P)
	local B = braid(ctx, Cr.Att, fist, c1, c2, 3, .8, 2.75)
	ctx:At(.8, function() strike(ctx, Cr.Pos() + V3(0, 14, 0) + K.Behind(ctx) * 4, Cr.Pos(), c2, false) end)
	ctx:Every(function(t) if t > 2.4 then return true end P:Pose(STRAIN, K.Soft(t, .35, 2.35, .35, .15)) end)
	K.Float(ctx, P, {T0 = .9, T1 = 2.3, Height = 4, Rise = .55, Fall = .2})
	ctx:At(1.8, function() B:Tighten(.5) end)
	-- the slam: the fist comes down, the 15-stud shockwave leaves it
	slam(ctx, P, 2.3, c1, c2, 3.3)
	shockwave(ctx, 2.35, c1, c2, dark, 7.5)
	ctx:At(2.35, function() ctx:Grade({Brightness = .1, Contrast = .15}, .05, .12, .4) end)
	ctx:Repeat(.6, 2.2, .3, function() ctx:Flare(ctx.Base.Position + K.Polar(rng:NextNumber(0, TAU), rng:NextNumber(2, 4), rng:NextNumber(2, 8)), rng:NextNumber(1.5, 3), c1, .3) end)
	ctx:At(4.8, function() A:Destroy() end)
	K.Title(ctx, 2.6, "glitch", 7.5)
	return LEN
end

---------------------------------------------------------------- Set 3: the split crown, a braid of five, two rings, the ice spikes (7.8 s + 1 s charge-up)
function M.Set3(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 7.8
	local P = K.Performer(ctx)
	if not P then return M.Set2(ctx, def) end
	local pre = ctx.Pre or 1
	K.ChargeUp(ctx, P, {Sigil = "ScorchRing", SigilScale = 1.3, Pose = "Crouch", PoseK = .8})
	local A = arcPool(ctx, c2, 12)
	-- charge-up: the sky darkens under the forming cloud, ice crystals hang in the air round the body
	ctx:At(-pre + .05, function() ctx:Grade({Brightness = -.15, Contrast = .08, Saturation = -.1}, .6, LEN + pre - 1.55, .9) end)
	cloud(ctx, dark, c2, -pre + .1, 6.6)
	local shell = ctx:Part({Transparency = 1, Size = V3(14, 8, 14)})
	local crystals = ctx:Emitter(shell, {Texture = K.Tex.Star, Color = {c1, W}, Size = {{0, 0}, {.3, .4}, {1, 0}}, Transparency = {{0, 1}, {.2, .1}, {1, 1}}, Lifetime = {1, 1.6},
		Speed = 0, Rate = 0, Brightness = 3, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, RotSpeed = {-60, 60}})
	ctx:Every(function(t)
		if t > .3 then shell:Destroy() return true end
		shell.CFrame = ctx.Hrp.CFrame * CFrame.new(0, 2, 0)
		crystals.Rate = 24 * K.Soft(t, -pre + .1, .2, .4, .2) * (ctx.Quality or 1)
	end)
	K.Skin(ctx, {Color = c2, Lightning = true, T0 = -.3, T1 = 6.6})
	-- t = 0: the detonation; the crown rises and the braid of five catches the fist
	ctx:At(0, function()
		K.Starburst(ctx, ctx.Base.Position + V3(0, 3, 0), {Colors = {c1, c2}, Size = 10, Count = 30})
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .15), 2, 20, c2, .45, .45)
		ctx:Flash(c1, .35, .3)
		floorArcs(A, ctx, 6, 8, .5)
	end)
	local Cr = crown(ctx, A, c1, c2, .1, 5.4, function(t) return 10 + 3 * FX.ease((t - .7) / .9) end, 1, .5)
	local Cr2 = crown(ctx, A, c1, c2, 2.2, 5.2, function(t) return 13 + 3.5 * FX.ease((t - 2.2) / .6) end, .8, -.8)
	local fist = fistAtt(ctx, P)
	local B = braid(ctx, Cr.Att, fist, c1, c2, 5, .5, 4.75)
	ctx:At(.5, function() strike(ctx, Cr.Pos() + V3(0, 16, 0) + K.Behind(ctx) * 4, Cr.Pos(), c2, false, .1) end)
	ctx:Every(function(t) if t > 3.3 then return true end if t > 0 then P:Pose(STRAIN, K.Soft(t, .2, 3.25, .35, .15)) end end)
	K.Float(ctx, P, {T0 = .7, T1 = 3.2, Height = 4, Rise = .6, Fall = .2, Spin = .25})
	-- the crown splits: the second crown rises off the first under a bolt
	ctx:At(2.2, function()
		strike(ctx, Cr.Pos() + V3(0, 18, 0) + K.Behind(ctx) * 3, Cr.Pos(), c1, false)
		K.Starburst(ctx, Cr.Pos(), {Colors = {W, c2}, Size = 6, Count = 16})
	end)
	ctx:At(2.7, function() B:Tighten(.5) end)
	-- the slam: two 25-stud shockwaves 0.4 s apart, the grass flattened, the ice-spike ring where the second stops
	slam(ctx, P, 3.2, c1, c2, 4.6)
	shockwave(ctx, 3.25, c1, c2, dark, 12.5)
	shockwave(ctx, 3.65, c1, c2, dark, 12.5)
	ctx:At(3.25, function() ctx:Grade({Brightness = .12, Contrast = .18}, .05, .12, .4) K.Debris(ctx, {At = 0, Count = 6, Radius = 5, Lift = 3, Until = ctx:Elapsed() + .5, Orbit = .3}) end)
	iceSpikes(ctx, 3.65 + 12.5 / SPEED, c1, c2, 12, 8)
	-- the braid lingers as a column the player stands in
	local ground = ctx:Att(V3(0, .2, 0))
	ctx:At(3.5, function() B:Retarget(ground) B.Amp = 3 end)
	local cage = K.Cage(ctx, {Colors = {c1, c2}, T0 = 3.5, T1 = 4.7, Radius = 3, Height = 10, Rate = 50})
	ctx:At(4.7, function() cage.Burst() B:Stop() end)
	ctx:Repeat(.4, 3.0, .3, function() ctx:Flare(ctx.Base.Position + K.Polar(rng:NextNumber(0, TAU), rng:NextNumber(2, 4), rng:NextNumber(2, 9)), rng:NextNumber(1.5, 3.5), c1, .3) end)
	K.Herd(ctx, {At = 4.8, Radius = 18, Color = c1, Flavour = "lookup"})
	-- the settle: the last arcs sweep off the body as the cloud thins
	K.Sweeps(ctx, {Colors = {c1, c2}, T0 = 4.8, T1 = 6.0, Period = .35, Radius = 4.5, Height = 3, Climb = 6})
	ctx:At(7.4, function() A:Destroy() end)
	K.Title(ctx, 3.9, "glitch", 8)
	return LEN
end

return M
