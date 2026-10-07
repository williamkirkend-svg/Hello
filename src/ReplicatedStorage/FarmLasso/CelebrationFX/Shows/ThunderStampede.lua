-- Shows.ThunderStampede: the blue aura clip (plasma skin, tall flame sheets, arc sweeps, a sharp-edged floor pool),
-- then the stampede: crawling ground arcs race out along radial tracks like bulls, each track ends in a bolt that
-- slams down from 25 studs and leaves a scorched crater, and from every crater a flat lightning bull charges out
-- through the fences and bursts into sparks. At the peak the player is lifted into a ball-lightning cage that
-- bursts under one final mega-bolt and a 20-stud ice-white shock ring. (Oct 6 2026)
-- Set 1: the aura, three ground arcs, one bolt behind the player. Set 2: six tracks, the bolt ring (0.12 s stagger),
-- post flashes, craters, three bulls. Set 3: arcs crawl inward in the charge-up, eight tracks, the ring, eight bulls,
-- the ground webbed with arcs, the cage lift and the mega-bolt.
local FX = require(script.Parent.Parent.Parent)
local K = require(script.Parent.Parent.AuraKit)
local S = require(script.Parent.Parent.AuraSound)
local V3, W, TAU, rng = Vector3.new, FX.W, K.TAU, FX.rng
local M = {Pre = 1.0}
-- wide stance, fists down, chin up (the body between the bolts)
local STANCE = {RightShoulder = CFrame.Angles(.15, 0, .4), LeftShoulder = CFrame.Angles(.15, 0, -.4), RightHip = CFrame.Angles(0, 0, .3),
	LeftHip = CFrame.Angles(0, 0, -.3), Waist = CFrame.Angles(.12, 0, 0), Neck = CFrame.Angles(-.25, 0, 0)}
-- sound: the bolt ring's onLand, a ThunderCrack at every other crater (the first one loud)
local function crackOnLand(ctx)
	return function(i, e) if i % 2 == 1 then S.Now(ctx, "ThunderCrack", {At = e, Volume = i == 1 and 1 or .6}) end end
end

---------------------------------------------------------------- lightning helpers (shared with Stormbreaker by copy)
-- a sky bolt from p0 to p1: a white core bolt inside a coloured glow bolt, re-jagged three times over 0.2 s, standing
-- for `hold` more seconds, then faded and destroyed; a light flash, a starburst at the foot and a ring on the ground
local function strike(ctx, p0, p1, color, big, hold, quiet)
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
	if not quiet then K.Starburst(ctx, p1, {Colors = {W, color}, Size = big and 12 or 6, Count = big and 30 or 16}) end
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

---------------------------------------------------------------- the stampede pieces
-- the ends of n radial tracks, R studs out on the ground (a0 turns the whole fan)
local function trackEnds(ctx, n, R, a0)
	local ends = {}
	for i = 1, n do
		local a = (a0 or 0) + (i - 1) / n * TAU + rng:NextNumber(-.12, .12)
		ends[i] = K.Ground(ctx, ctx.Base.Position + K.Polar(a, R * rng:NextNumber(.9, 1.1), 0)) + V3(0, .35, 0)
	end
	return ends
end
-- arcs race along the ground from the feet to every track end (or inward when `inward`), onArrive(i, pos) at the end
local function tracks(A, ctx, ends, dur, inward, onArrive)
	local feet = ctx.Base.Position + V3(0, .3, 0)
	for i, e in ends do
		local from, to = feet, e
		if inward then from, to = e, feet end
		A:Run(function(u) return from:Lerp(to, u) end, dur, .06, onArrive and function() onArrive(i, e) end or nil)
	end
end
-- the scorched crater a strike leaves, an arc crawling round its lip for a second
local function crater(A, ctx, pos, dark)
	K.Stamp(ctx, pos, {Mesh = "ScorchRing", Color = dark, Material = Enum.Material.SmoothPlastic, Scale = .55, Life = 2.4, Rise = .15})
	local a0 = rng:NextNumber(0, TAU)
	A:Run(function(u) return pos + K.Polar(a0 + u * TAU * 1.5, 1.6, .1) end, 1, .06)
end
-- the ring of bolts: one strike per track end, `stagger` apart, every bolt standing until the last one has landed
local function boltRing(A, ctx, ends, c2, dark, at, stagger, onLand)
	for i, e in ends do
		ctx:At(at + (i - 1) * stagger, function()
			-- (quiet: the ring shares one starburst at its centre instead of one per bolt)
			strike(ctx, e + V3(0, 25, 0), e, c2, false, (#ends - i) * stagger + .25, i > 1)
			crater(A, ctx, e, dark)
			if onLand then onLand(i, e) end
		end)
	end
end
-- arcs webbing the ground between neighbouring craters
local function web(A, ctx, ends, dur)
	for i, e in ends do
		local f = ends[i % #ends + 1]
		local lift = rng:NextNumber(.2, 1.2)
		A:Run(function(u) return e:Lerp(f, u) + V3(0, lift * math.sin(u * math.pi), 0) end, dur, .06)
	end
end
-- a flat lightning-bull silhouette charges from `from` along `dir` at 18 studs/s for dur seconds with a trail,
-- sparks and a gallop bob, then vanishes in a starburst. The mesh faces +X and is centred at the chest.
local function bull(ctx, from, dir, c1, c2, dark, dur)
	local m = K.Mesh(ctx, "LightningBull", {Color = c1})
	S.Now(ctx, "BullCharge", {At = m, Volume = .6, Cooldown = .15}) -- sound: rides the bull, at most one per .15 s
	local rot = CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(0, math.pi / 2, 0)
	local a0, a1 = ctx:Att(V3(0, .9, 0), m), ctx:Att(V3(0, -.9, 0), m)
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.LightEmission, tr.LightInfluence = 1, 0
	tr.Lifetime = .3
	tr.Texture = K.Tex.Streak
	tr.TextureMode = Enum.TextureMode.Stretch
	tr.Color = FX.cseq({W, c2, dark})
	tr.Transparency = FX.nseq({{0, .1}, {.6, .4}, {1, 1}})
	tr.WidthScale = FX.nseq({{0, 1}, {1, 0}})
	pcall(function() tr.Brightness = 3 end)
	tr.Parent = m
	local sparks = ctx:Emitter(a1, {Texture = K.Tex.Star, Color = {W, c2}, Size = {.35, 0}, Lifetime = {.3, .6}, Speed = {3, 7}, SpreadAngle = Vector2.new(180, 180),
		Rate = 28 * (ctx.Quality or 1), Brightness = 5, Drag = 2})
	local light = ctx:Light(a0, c2, 14, 3)
	local t0 = os.clock()
	ctx:Every(function()
		local age = os.clock() - t0
		local u = age / dur
		if u >= 1 then
			K.Starburst(ctx, m.Position, {Colors = {W, c2}, Size = 5, Count = 14})
			m.Transparency = 1
			sparks.Rate = 0
			light.Brightness = 0
			task.delay(.4, function() m:Destroy() end)
			return true
		end
		local gallop = math.sin(age * 11)
		local pos = from + dir * (age * 18) + V3(0, 1.5 + math.abs(gallop) * .5, 0)
		K.Place(m, CFrame.new(pos) * rot * CFrame.Angles(0, 0, gallop * .12), .6 + .4 * FX.ease(u / .15))
		m.Transparency = u > .8 and (u - .8) / .2 * .6 or 0
	end)
end
-- the bulls: one per crater (every `step`-th), each charging on along its own track
local function bulls(ctx, ends, c1, c2, dark, at, step, stagger)
	local n = 0
	for i = 1, #ends, step do
		local e = ends[i]
		ctx:At(at + n * stagger, function()
			local dir = V3(e.X - ctx.Base.Position.X, 0, e.Z - ctx.Base.Position.Z)
			dir = dir.Magnitude > .1 and dir.Unit or Vector3.zAxis
			bull(ctx, e, dir, c1, c2, dark, 1.2)
		end)
		n += 1
	end
end
-- the aura clip's body: plasma skin with the lightning flipbook, tall flame sheets, arc sweeps peeling off
local function aura(ctx, c1, c2, c3, t0, t1, sweepT1)
	K.Skin(ctx, {Color = c2, Lightning = true, T0 = t0, T1 = t1})
	K.Sheets(ctx, {Colors = {c1, c2, c3}, T0 = t0 + .15, T1 = t1 - .2, Rate = 30})
	K.Sweeps(ctx, {Colors = {c1, c2}, T0 = t0 + .3, T1 = sweepT1, Period = .32, Radius = 4, Height = 2.5, Climb = 5})
end
-- the floor pool: a sharp-edged disc of light under the feet with a thin white ring edge and a dark rim
local function floorPool(ctx, c2, dark, t0, t1, d)
	ctx:At(t0, function() K.Stamp(ctx, ctx.Base.Position, {Mesh = "ScorchRing", Color = c2, Transparency = .45, Scale = d / 6.4, Life = t1 - t0, Rise = .3}) end)
	local edge = ctx:Ring("RingThin", d, .2, W, 1)
	local rim = ctx:Ring("RingFat", d * 1.15, .3, dark, 1)
	ctx:Every(function(t)
		if t > t1 + .1 then edge:Destroy() rim:Destroy() return true end
		local k = K.Soft(t, t0, t1, .35, .5)
		local pulse = 1 + math.sin(t * 6) * .03
		edge.Size = Vector3.new(.2, d * pulse * k, d * pulse * k)
		edge.CFrame = ctx.Base * CFrame.new(0, .12, 0) * FX.FLAT
		edge.Transparency = 1 - .8 * k
		rim.Size = Vector3.new(.3, d * 1.15 * k, d * 1.15 * k)
		rim.CFrame = ctx.Base * CFrame.new(0, .06, 0) * FX.FLAT
		rim.Transparency = 1 - .4 * k
	end)
end

---------------------------------------------------------------- Set 1: the aura, three arcs, one bolt (2.6 s)
function M.Set1(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 2.6
	local A = arcPool(ctx, c2, 4)
	aura(ctx, c1, c2, c3, 0, 2.0, 1.5)
	floorPool(ctx, c2, dark, .2, 2.2, 8)
	ctx:At(.35, function()
		K.Starburst(ctx, ctx.Base.Position + V3(0, 3, 0), {Colors = {c1, c2}, Size = 7, Count = 20})
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .15), 2, 14, c2, .45, .4)
	end)
	-- three tracks race out; the one behind the player ends in a bolt, the others in craters
	ctx:At(.4, function()
		local back = K.Behind(ctx)
		local ends = trackEnds(ctx, 3, 7, math.atan2(back.Z, back.X))
		tracks(A, ctx, ends, .5, false, function(i, e)
			if i == 1 then strike(ctx, e + V3(0, 25, 0), e, c2, false) S.Now(ctx, "ThunderCrack", {At = e}) end
			crater(A, ctx, e, dark)
		end)
		K.Chain(ctx, {At = 0, From = ctx.Base.Position + V3(0, .5, 0), Radius = 12, Count = K.Count(ctx, 3), Color = c2, Stagger = .08})
	end)
	ctx:Repeat(.5, 1.8, .3, function() ctx:Flare(ctx.Base.Position + K.Polar(rng:NextNumber(0, TAU), rng:NextNumber(2, 4), rng:NextNumber(1, 5)), rng:NextNumber(1.5, 3), c1, .3) end)
	ctx:At(2.3, function() A:Destroy() end)
	K.Title(ctx, 1.0, "glitch", 7.5)
	-- sound (Set 1: three cues): the shock ring at .35, the bolt's crack on its landing (above), the title
	S.Cue(ctx, .35, "CelShockwave")
	S.Cue(ctx, 1.0, "CelTitle")
	return LEN
end

---------------------------------------------------------------- Set 2: six tracks, the bolt ring, three bulls (5.0 s)
function M.Set2(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 5.0
	local P = K.Performer(ctx)
	if not P then return M.Set1(ctx, def) end
	local A = arcPool(ctx, c2, 8)
	ctx:At(.02, function() P:Show() end)
	ctx:Every(function(t) if t > 4.6 then return true end P:Pose(STANCE, K.Soft(t, .1, 4.4, .35, .4)) end)
	aura(ctx, c1, c2, c3, 0, 4.3, 3.6)
	floorPool(ctx, c2, dark, .2, 4.5, 9)
	ctx:At(.3, function()
		K.Starburst(ctx, ctx.Base.Position + V3(0, 3, 0), {Colors = {c1, c2}, Size = 8, Count = 24})
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .15), 2, 16, c2, .45, .4)
	end)
	-- the tracks race out, the ring of six bolts lands with a 0.12 s stagger, the posts flash, the herd flinches
	local ends
	ctx:At(.35, function()
		ends = trackEnds(ctx, 6, 9, rng:NextNumber(0, TAU))
		tracks(A, ctx, ends, .55)
		K.Chain(ctx, {At = 0, From = ctx.Base.Position + V3(0, .5, 0), Radius = 14, Count = K.Count(ctx, 4), Color = c2, Stagger = .06})
		boltRing(A, ctx, ends, c2, dark, .9, .12, crackOnLand(ctx))
	end)
	K.LightPaint(ctx, {At = 1.0, Radius = 30, Color = c1, Hold = .5, Boost = 2, Highlight = true})
	K.Herd(ctx, {At = 1.05, Radius = 14, Color = c2, Flavour = "flinch"})
	ctx:At(1.0, function() ctx:Shake(.25, .4) end)
	-- three bulls charge out of every other crater
	ctx:At(1.55, function() if ends then bulls(ctx, ends, c1, c2, dark, 0, 2, .12) end end)
	-- a second wave of arcs through the fences, no bolts
	ctx:At(2.9, function()
		local e2 = trackEnds(ctx, 6, 9, rng:NextNumber(0, TAU))
		tracks(A, ctx, e2, .55, false, function(_, e) crater(A, ctx, e, dark) end)
		K.Chain(ctx, {At = .2, From = ctx.Base.Position + V3(0, .5, 0), Radius = 14, Count = K.Count(ctx, 4), Color = c2, Stagger = .06})
	end)
	ctx:Repeat(.5, 3.8, .35, function() ctx:Flare(ctx.Base.Position + K.Polar(rng:NextNumber(0, TAU), rng:NextNumber(2, 5), rng:NextNumber(1, 6)), rng:NextNumber(1.5, 3), c1, .3) end)
	ctx:At(4.7, function() A:Destroy() end)
	K.Title(ctx, 2.3, "glitch", 7.5)
	-- sound: the detonation at .3, arcs crackling while the tracks race (.35 to .9 and the second wave), the chain
	-- lightning's impact at the nearest post, the title (the bolt cracks and the bulls come from the helpers)
	S.Duck(ctx, 0, LEN)
	S.Hit(ctx, .3, "L")
	S.Loop(ctx, .35, .95, "ArcCrackle", {K = .8})
	S.Cue(ctx, .35, "CelImpact", {Volume = .5, At = function() return K.NearbyProps(ctx, 14, 1)[1] end})
	S.Cue(ctx, 2.3, "CelTitle")
	S.Loop(ctx, 2.9, 3.5, "ArcCrackle", {K = .6})
	return LEN
end

---------------------------------------------------------------- Set 3: the full stampede and the cage (7.6 s + 1 s charge-up)
function M.Set3(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 7.6
	local P = K.Performer(ctx)
	if not P then return M.Set2(ctx, def) end
	local pre = ctx.Pre or 1
	K.ChargeUp(ctx, P, {Sigil = "ScorchRing", SigilScale = 1.4, Pose = "Crouch", PoseK = .8})
	local A = arcPool(ctx, c2, 16)
	-- charge-up: eight arcs crawl INWARD from ten studs out to the feet, the skin starts to crackle
	ctx:At(-pre + .15, function() tracks(A, ctx, trackEnds(ctx, 8, 10, 0), pre * .7, true) end)
	K.Skin(ctx, {Color = c2, Lightning = true, T0 = -.6, T1 = 6.7})
	-- t = 0: the detonation; the aura comes up, the pool opens, the body goes dark between the bolts
	ctx:At(0, function()
		K.Starburst(ctx, ctx.Base.Position + V3(0, 3, 0), {Colors = {c1, c2}, Size = 10, Count = 30})
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .15), 2, 22, c2, .5, .45)
		ctx:Flash(c1, .35, .3)
		ctx:Shake(.3, .4)
	end)
	K.Sheets(ctx, {Colors = {c1, c2, c3}, T0 = .05, T1 = 6.3, Rate = 32})
	K.Sweeps(ctx, {Colors = {c1, c2}, T0 = .2, T1 = 5.8, Period = .3, Radius = 4.5, Height = 2.5, Climb = 6})
	floorPool(ctx, c2, dark, 0, 7.0, 10)
	ctx:Every(function(t) if t > 3.3 then return true end if t > 0 then P:Pose(STANCE, K.Soft(t, .05, 3.2, .35, .4)) end end)
	-- the eight tracks race out, the ring of eight bolts lands with a 0.12 s stagger and stands like fence posts,
	-- arcs web the ground between the craters, the posts flash, the herd flinches, the player chars black
	local ends
	ctx:At(.1, function()
		ends = trackEnds(ctx, 8, 10, rng:NextNumber(0, TAU))
		tracks(A, ctx, ends, .55)
		K.Chain(ctx, {At = .25, From = ctx.Base.Position + V3(0, .5, 0), Radius = 15, Count = K.Count(ctx, 6), Color = c2, Stagger = .05})
		boltRing(A, ctx, ends, c2, dark, .7, .12, crackOnLand(ctx))
		ctx:At(.9, function() web(A, ctx, ends, 1.3) end)
	end)
	ctx:At(.7, function() P:Silhouette() end)
	ctx:At(2.0, function() P:RestoreLook() end)
	K.LightPaint(ctx, {At = .9, Radius = 36, Color = c1, Hold = .6, Boost = 2.5, Highlight = true})
	K.Herd(ctx, {At = .95, Radius = 16, Color = c2, Flavour = "flinch"})
	ctx:At(1.0, function() ctx:Shake(.3, .5) end)
	-- eight bulls leave the craters 0.08 s apart
	ctx:At(1.6, function() if ends then bulls(ctx, ends, c1, c2, dark, 0, 1, .08) end end)
	ctx:Repeat(.4, 5.6, .3, function() ctx:Flare(ctx.Base.Position + K.Polar(rng:NextNumber(0, TAU), rng:NextNumber(2, 5), rng:NextNumber(1, 7)), rng:NextNumber(1.5, 3.5), c1, .3) end)
	-- the cage: the player lifted three studs into a ball-lightning cage, hanging
	local cage = K.Cage(ctx, {Colors = {c1, c2}, T0 = 3.2, T1 = 4.95, Radius = 3.2, Height = 8, Rate = 60})
	K.Float(ctx, P, {T0 = 3.2, T1 = 4.85, Height = 3, Rise = .45, Fall = .3, Spin = .4, Pose = "Hang", PoseK = .9})
	ctx:At(3.25, function() ctx:Burst(P.Torso.Position, K.Count(ctx, 20), {Texture = K.Tex.Lightning, Color = {W, c2}, Size = {1.5, 2.5}, Lifetime = {.2, .35}, Speed = {4, 9},
		SpreadAngle = Vector2.new(180, 180), Rotation = {0, 360}, Brightness = 5}) end)
	-- the mega-bolt: the cage bursts, one big strike slams the player, a 20-stud ice-white ring detonates
	ctx:At(4.55, function()
		local torso = P.Torso.Position
		cage.Burst()
		strike(ctx, torso + V3(0, 30, 0) + K.Behind(ctx) * 3, torso, c1, true, .1)
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .2), 2, 40, c1, .6, .6)
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .25), 2, 46, dark, .8, .4)
		K.Hit(ctx, torso, {Colors = {c1, c2}, Impact = true, Ring = 24, Burst = 12, Lines = 30})
		tracks(A, ctx, trackEnds(ctx, 8, 12, rng:NextNumber(0, TAU)), .5)
		K.Chain(ctx, {At = 0, From = torso, Radius = 16, Count = K.Count(ctx, 6), Color = c1, Stagger = .04})
	end)
	K.Herd(ctx, {At = 4.6, Radius = 18, Color = c1, Flavour = "bolt"})
	-- the drop: a crouch on landing, then the aura settles
	ctx:Every(function(t)
		if t < 4.85 then return end
		if t > 5.9 then return true end
		P:Toward("Crouch", FX.ease((t - 4.85) / .15) * (1 - FX.ease((t - 5.3) / .6)) * .8)
	end)
	ctx:At(4.9, function() K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .15), 2, 12, c2, .35, .35) end)
	ctx:At(7.3, function() A:Destroy() end)
	K.Title(ctx, 2.4, "glitch", 8)
	-- sound: the inhale with arcs crawling in, the detonation with a crack, arcs under the tracks, bolts and web, the
	-- chain's impact at a post, the title, the cage lift, the mega-bolt (crack, the cage's detonate, the impact frame,
	-- the ring), the drop (the bolt cracks and the bulls come from the helpers)
	S.ChargeUp(ctx)
	S.Duck(ctx, -pre, LEN)
	S.Bed(ctx, .4, LEN - .8)
	S.Loop(ctx, -pre + .15, -.15, "ArcCrackle", {K = .5, Volume = .5})
	S.Hit(ctx, 0, "L")
	S.Cue(ctx, 0, "ThunderCrack")
	S.Loop(ctx, .1, 2.4, "ArcCrackle", {K = .8})
	S.Cue(ctx, .35, "CelImpact", {Volume = .5, At = function() return K.NearbyProps(ctx, 15, 1)[1] end})
	S.Cue(ctx, 2.4, "CelTitle")
	S.Cue(ctx, 3.2, "CelWhooshS")
	S.Cue(ctx, 4.55, "ThunderCrack", {Volume = 1})
	S.Cue(ctx, 4.55, "CelDetonate", {Volume = .6})
	S.Cue(ctx, 4.55, "CelImpact")
	S.Cue(ctx, 4.6, "CelShockwave")
	S.Cue(ctx, 4.9, "CelLand")
	return LEN
end

return M
