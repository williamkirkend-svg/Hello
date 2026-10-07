-- Shows.ChronoRift: time breaks. A giant time sigil lifts its numerals as orbiting shards, freezes them, reverses
-- them and shatters into a standing rift; ghosts pour out of the tear and go looking for everyone else; the whole
-- plaza rewinds, stands dead still, then time snaps back and the rift shatters into glass. (Oct 6 2026)
-- Set 1: the sigil ticks, one ghost circles the player, six shards. Set 2: the rift to 3.5 studs, three ghosts, a
-- ghost-only rewind. Set 3: the full timeline with the world slowed, cobbles lifting and the world rewind.
local FX = require(script.Parent.Parent.Parent)
local K = require(script.Parent.Parent.AuraKit)
local Snd = require(script.Parent.Parent.AuraSound) -- (not `S`: the sets bind `S` to the sigil)
local V3, W, TAU, rng = Vector3.new, FX.W, K.TAU, FX.rng
local SEPIA = Color3.fromRGB(255, 232, 196)
local M = {Pre = 1.0}

---------------------------------------------------------------- pieces
-- the time sigil on the ground with one hand that jumps a tick every .1 s; returns {Sigil, Hand, Stop()}
local function sigil(ctx, c2, dark, scale, t0, t1)
	local sig = K.Stamp(ctx, ctx.Base.Position, {Mesh = "TickSigil", Color = c2, Scale = scale or 1, Life = 99, Rise = .01, Transparency = .1})
	local hand = K.Mesh(ctx, "ClockHandShort", {Color = W})
	local tick, ticks = 0, 0
	local S = {Sigil = sig, Hand = hand, Alive = true}
	local g = K.GroundCF(ctx, ctx.Base.Position, .14)
	Snd.Loop(ctx, t0, t1, "ClockTick", {K = .5, FadeIn = .1}) -- sound: the tick for as long as the hand jumps
	ctx:Every(function(t)
		if not S.Alive then hand:Destroy() return true end
		if t < t0 then return end
		if t - tick >= .1 then tick = t ticks += 1 end
		local a = ticks * TAU / 60 * (S.Reverse and -1 or 1)
		K.Place(hand, g * CFrame.Angles(0, -a, 0), (scale or 1) * .9)
		if t > t1 then S.Alive = false end
	end)
	function S.Stop() S.Alive = false K.Release(sig, .3) end
	return S
end
-- the standing tear: a hairline of light that rips open to `gap` studs between two torn lips with a gear void behind
local function rift(ctx, c1, c2, c3, dark, back)
	local centre = ctx.Base.Position + back * 3.2 + V3(0, 4.6, 0)
	local face = CFrame.lookAt(centre, centre - back) -- -Z faces the player
	local R = {Centre = centre, Face = face, Gap = 0, Height = 9, Open = 0, Alive = true}
	local line = ctx:Part({Color = W, Size = V3(.08, .1, .08)})
	local lens = K.Mesh(ctx, "LensSphere", {Material = Enum.Material.Glass, Color = c1, Transparency = .55})
	local lipL = K.Mesh(ctx, "RiftLip", {Color = c2, Transparency = 1})
	local lipR = K.Mesh(ctx, "RiftLip", {Color = c2, Transparency = 1})
	local void = K.Mesh(ctx, "RiftVoid", {Material = Enum.Material.Glass, Color = c3, Transparency = 1})
	local plate = ctx:Part({Color = c3:Lerp(Color3.new(), .5), Transparency = 1, Size = V3(.1, .1, .1)})
	local tex = Instance.new("Texture")
	tex.Texture = K.Tex.Nebula
	tex.Color3 = c2
	tex.Transparency = .45
	tex.StudsPerTileU, tex.StudsPerTileV = 5, 5
	tex.Face = Enum.NormalId.Front
	tex.Parent = void
	local glow = ctx:Att(centre - ctx.Base.Position)
	local haze = ctx:Emitter(glow, {Texture = K.Tex.Glow, Color = {W, c2}, Size = {6, 10}, Transparency = {{0, 1}, {.2, .6}, {1, 1}}, Lifetime = {.8, 1.2}, Rate = 0,
		Speed = {.5, 1}, SpreadAngle = Vector2.new(180, 180), Brightness = 2, ZOffset = -2})
	local light = ctx:Light(glow, c2, 26, 0)
	ctx:Every(function(t)
		if not R.Alive then return true end
		local g = R.Gap
		local h = R.Height * math.max(.05, R.Open)
		local base = face * CFrame.new(0, -R.Height / 2, 0)
		line.Size = V3(.08 + g * .02, h, .08)
		line.CFrame = face * CFrame.new(0, -R.Height / 2 + h / 2, 0)
		line.Transparency = g > 3 and .6 or 0
		K.Place(lens, face * CFrame.new(0, 0, -.6), V3(.35 + g * .08, h / 2, .3))
		local lipK = math.clamp(g / 1.5, 0, 1)
		K.Place(lipL, base * CFrame.new(-g / 2, 0, 0), V3(1, R.Open, 1))
		K.Place(lipR, base * CFrame.new(g / 2, 0, 0) * CFrame.Angles(0, math.pi, 0), V3(1, R.Open, 1))
		lipL.Transparency = 1 - lipK
		lipR.Transparency = 1 - lipK
		K.Place(void, face * CFrame.new(0, 0, .25) * CFrame.Angles(0, 0, 0), V3(math.max(.02, g / 5), R.Open, 1))
		void.Transparency = 1 - .75 * lipK
		plate.Size = V3(math.max(.05, g * .95), math.max(.05, h * .98), .1)
		plate.CFrame = face * CFrame.new(0, 0, .45)
		plate.Transparency = 1 - .9 * lipK
		tex.OffsetStudsV = (tex.OffsetStudsV + .06) % 5
		haze.Rate = 6 * lipK * (ctx.Quality or 1)
		light.Brightness = 2 + 5 * lipK + math.sin(t * 50) * lipK
	end)
	function R.Close(dur)
		local g0 = R.Gap
		local t0 = os.clock()
		ctx:Every(function()
			local u = (os.clock() - t0) / (dur or .25)
			if u >= 1 then R.Gap = 0 return true end
			R.Gap = g0 * (1 - FX.ease(u))
		end)
	end
	function R.Destroy(dur)
		R.Alive = false
		for _, p in {line, lens, lipL, lipR, void, plate} do FX.Tween(p, dur or .3, {Transparency = 1}) end
		haze.Rate = 0
		FX.Tween(light, dur or .3, {Brightness = 0})
	end
	return R
end
-- the twelve numerals: they lift off the sigil, orbit the chest, freeze, reverse and slam into the rift
local function numerals(ctx, c1, c2, n)
	local list = {}
	for i = 1, n do
		local m = K.Mesh(ctx, "Numeral", {Color = i % 3 == 0 and W or c1, Transparency = 1})
		list[i] = {M = m, A = i / n * TAU, Y = 3 + math.sin(i) * .6}
	end
	return list
end
-- the hairline shatters: glass shards fired in a vertical fan, each embedding in the ground tilted and dissolving
local function glassFan(ctx, origin, c1, c2, count)
	local n = K.Count(ctx, count)
	local list = {}
	for i = 1, n do
		local m = K.Mesh(ctx, "GlassShard", {Material = Enum.Material.Glass, Color = c1, Transparency = .1})
		local a0 = ctx:Att(V3(0, .4, 0), m)
		local a1 = ctx:Att(V3(0, -.4, 0), m)
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.LightEmission, tr.LightInfluence = 1, 0
		tr.Lifetime = .3
		tr.Texture = K.Tex.Streak
		tr.TextureMode = Enum.TextureMode.Stretch
		tr.Color = FX.cseq({W, c2})
		tr.Transparency = FX.nseq({{0, .2}, {1, 1}})
		tr.WidthScale = FX.nseq({{0, 1}, {1, 0}})
		pcall(function() tr.Brightness = 3 end)
		tr.Parent = m
		local ang = (i / n - .5) * math.pi * 1.1
		local vel = V3(math.sin(ang) * rng:NextNumber(10, 22), rng:NextNumber(8, 20), math.cos(ang) * rng:NextNumber(-6, 6))
		local p0 = origin + V3(0, rng:NextNumber(-3, 3), 0)
		list[i] = {M = m, V = vel, P = p0, Spin = K.RandUnit() * 8, Done = false, Rot = CFrame.Angles(rng:NextNumber(0, TAU), 0, 0),
			GY = K.Ground(ctx, p0 + V3(vel.X, 0, vel.Z) * .6).Y}
		K.Place(m, CFrame.new(p0), 1)
	end
	local dt = 1 / 60
	ctx:Every(function()
		local all = true
		for _, s in list do
			if s.Done then continue end
			all = false
			s.V = s.V + V3(0, -45, 0) * dt
			s.P = s.P + s.V * dt
			local gy = s.GY
			if s.P.Y <= gy + .3 and s.V.Y < 0 then
				s.Done = true
				s.P = V3(s.P.X, gy + .6, s.P.Z)
				s.M.CFrame = CFrame.new(s.P) * CFrame.Angles(rng:NextNumber(.3, .8), rng:NextNumber(0, TAU), rng:NextNumber(-.3, .3))
				FX.Tween(s.M, 1.1, {Transparency = 1})
				task.delay(1.2, function() s.M:Destroy() end)
			else
				s.M.CFrame = CFrame.new(s.P) * s.Rot * CFrame.Angles(s.Spin.X * dt, 0, 0)
				s.Rot = s.Rot * CFrame.Angles(s.Spin.X * dt, s.Spin.Y * dt, s.Spin.Z * dt)
			end
		end
		return all
	end)
end
-- a tick ring over a target's head
local function tickRing(ctx, c2, tg)
	local r = ctx:Ring("RingThin", 1.5, .18, c2, 0)
	local t0 = os.clock()
	ctx:Every(function()
		local u = (os.clock() - t0) / .6
		if u >= 1 then r:Destroy() return true end
		local pos = K.TargetPos(tg, 3.4)
		K.SetRing(r, 1.5 + u * 2)
		r.CFrame = CFrame.new(pos) * CFrame.Angles(0, u * 3, 0) * FX.FLAT
		r.Transparency = u
	end)
end
-- the stutter: snap the pose by small offsets every .1 s while frozen
local function stutter(ctx, P, t0, t1)
	local last, seed = -1, 0
	ctx:Every(function(t)
		if t < t0 then return end
		if t > t1 then return true end
		if t - last >= .1 then last = t seed = rng:NextNumber(-1, 1) end
		local off = seed * .08
		local F = P.Poses.Freeze
		P:Pose({Neck = F.Neck * CFrame.Angles(off, off * .5, 0), RightShoulder = F.RightShoulder * CFrame.Angles(0, 0, off * 1.5), LeftShoulder = F.LeftShoulder,
			Waist = F.Waist * CFrame.Angles(0, 0, off * .6)}, 1)
	end)
end
local function sand(ctx, c1, c2, t0, t1)
	local hg = K.Mesh(ctx, "Hourglass", {Color = c1, Transparency = 1})
	local att = ctx:Att(V3(0, 9.2, 0))
	local stream = ctx:Emitter(att, {Texture = K.Tex.Glow, Color = {W, c2}, Size = {.25, .15}, Transparency = {{0, .2}, {1, .6}}, Lifetime = {.75, .85}, Speed = {12, 14},
		SpreadAngle = Vector2.new(2, 2), EmissionDirection = Enum.NormalId.Bottom, Rate = 0, Brightness = 3, Acceleration = V3(0, -16, 0)})
	ctx:Every(function(t)
		local k = K.Env(t, t0, t1, .3, .3)
		K.Place(hg, ctx.Base * CFrame.new(0, 10, 0) * CFrame.Angles(0, t * .5, 0), k)
		hg.Transparency = 1 - k
		stream.Rate = 90 * k * (ctx.Quality or 1)
		if t > t1 then hg:Destroy() return true end
	end)
end

---------------------------------------------------------------- Set 1: the sigil ticks (2.6 s)
function M.Set1(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 2.6
	local S = sigil(ctx, c2, dark, .9, 0, 2.2)
	local back = K.Behind(ctx)
	local R = rift(ctx, c1, c2, c3, dark, back)
	ctx:Every(function(t)
		R.Open = FX.ease(t / .25)
		R.Gap = t > .4 and 1.4 * FX.back((t - .4) / .3) * (1 - FX.ease((t - 1.9) / .3)) or 0
		if t > 2.3 then R.Destroy(.3) return true end
	end)
	ctx:At(.1, function() ctx:Grade({Saturation = -.5, TintColor = SEPIA}, .15, .25, .35) end)
	K.Seek(ctx, {Mesh = "GhostWisp", Colors = {c1, c2, c3}, Count = 1, T0 = .55, From = R.Centre, Speed = 10, Trail = .9, Circle = .7, Height = 3,
		Targets = {{Part = ctx.Hrp, Model = ctx.Char, Kind = "self"}}, Return = true, OnTouch = function(tg) tickRing(ctx, c2, tg) end})
	ctx:At(1.95, function()
		S.Reverse = true
		glassFan(ctx, R.Centre, c1, c2, 6)
		K.Starburst(ctx, R.Centre, {Colors = {c1, c2}, Size = 6, Count = 16})
	end)
	ctx:At(2.2, S.Stop)
	K.Title(ctx, 1.0, "glitch", 7.5)
	-- sound (Set 1: three cues): ClockTick from sigil(), the title, the glass fan
	Snd.Cue(ctx, 1.0, "CelTitle")
	Snd.Cue(ctx, 1.95, "GlassBreak", {Volume = .8})
	return LEN
end

---------------------------------------------------------------- Set 2: the rift opens, three ghosts, a ghost rewind (5.0 s)
function M.Set2(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 5.4
	local P = K.Performer(ctx)
	if not P then return M.Set1(ctx, def) end
	ctx:At(.02, function() P:Show() end)
	local S = sigil(ctx, c2, dark, 1, 0, 1.0)
	ctx:At(.05, function() ctx:Grade({Saturation = -.6, Contrast = .1, TintColor = SEPIA}, .15, .6, .4) end)
	stutter(ctx, P, .05, .6)
	local back = K.Behind(ctx)
	local R = rift(ctx, c1, c2, c3, dark, back)
	local nums = numerals(ctx, c1, c2, 12)
	local Rw = K.Rewind(ctx)
	local opened = false
	ctx:Every(function(t)
		R.Open = FX.ease(t / .25)
		-- numerals lift off the sigil (0 to .5), orbit, freeze at .6, reverse and slam into the rift by .95
		for i, n in nums do
			local lift = FX.ease((t - i * .03) / .4)
			local a
			if t < .6 then a = n.A + t * 2 else a = n.A + .6 * 2 - FX.ease((t - .6) / .35) ^ 2 * 2.5 end
			local pull = FX.ease((t - .75) / .2)
			local pos = ctx.Base.Position + K.Polar(a, 4.5 * (1 - pull), n.Y * lift + .2)
			pos = pos:Lerp(R.Centre, pull)
			if n.M.Parent then
				K.Place(n.M, CFrame.lookAt(pos, pos + K.Polar(a, 1, 0)), lift * (1 - pull * .7))
				n.M.Transparency = 1 - lift
			end
		end
		if t >= .95 and not opened then
			opened = true
			K.Hit(ctx, R.Centre, {Colors = {c1, c2}, Shake = .3, FOV = 8, Ring = 22, Burst = 10, Lines = 24})
			S.Stop()
		end
		if opened then R.Gap = 3.5 * FX.back((t - .95) / .3) end
		if t > 5.2 then R.Destroy(.3) return true end
	end)
	ctx:At(.95, function() for _, n in nums do n.M:Destroy() end end)
	K.Float(ctx, P, {T0 = 1.0, T1 = 4.25, Height = 2, Rise = .5, Fall = .25, Spin = -.6, Pose = "Wide"})
	K.Echo(ctx, P, {Count = 2, Delay = .3, Color = c2, Transparency = .6, T0 = 1.2, T1 = 3.9})
	local Sk = K.Seek(ctx, {Mesh = "GhostWisp", Colors = {c1, c2, c3}, Count = 3, Interval = .35, T0 = 1.15, From = R.Centre, Speed = 14, Trail = 1.1, Circle = .6, Height = 2.8,
		Return = true, OnTouch = function(tg) tickRing(ctx, c2, tg) end})
	local tracked = {}
	ctx:Every(function(t)
		if t > 3.9 then return true end
		for _, p in Sk.Parts do if not tracked[p] then tracked[p] = true Rw:Track(p) end end
	end)
	ctx:At(3.95, function() Sk:Freeze() Rw:Play(7, function() end) R.Close(.3) end)
	ctx:At(4.3, function()
		ctx:Grade({Saturation = 0, TintColor = W}, .05, .1, .1)
		glassFan(ctx, R.Centre, c1, c2, 16)
		ctx:Flash(c1, .5, .2)
		ctx:Shake(.25, .3)
		K.Herd(ctx, {At = 0, Radius = 18, Color = c2, Flavour = "flinch"})
	end)
	ctx:Every(function(t)
		if t < 4.3 then return end
		if t > 5 then return true end
		P:Toward("Punch", FX.ease((t - 4.3) / .15) * (1 - FX.ease((t - 4.7) / .3)))
	end)
	K.Title(ctx, 4.35, "glitch", 7.5)
	-- sound: the duck, the numerals reversing, the slam into the rift as the detonation (ClockTick from sigil()), one
	-- whoosh per ghost as it launches, the rewind, the glass, the drop, the title
	Snd.Duck(ctx, 0, LEN)
	Snd.Cue(ctx, .6, "ReverseWhoosh")
	Snd.Hit(ctx, .95, "M")
	for i = 1, math.min(3, K.Count(ctx, 3)) do Snd.Cue(ctx, 1.15 + (i - 1) * .35, "CelWhooshS", {Volume = .4}) end
	Snd.Cue(ctx, 3.95, "Rewind")
	Snd.Cue(ctx, 4.3, "GlassBreak")
	Snd.Cue(ctx, 4.3, "CelLand")
	Snd.Cue(ctx, 4.35, "CelTitle")
	return LEN
end

---------------------------------------------------------------- Set 3: the full timeline (7.0 s + 1 s charge-up)
function M.Set3(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 7.4
	local P = K.Performer(ctx)
	if not P then return M.Set2(ctx, def) end
	local pre = ctx.Pre or 1
	-- charge-up: the plaza goes sepia and slows to a tenth, the sigil scribes itself underfoot
	K.ChargeUp(ctx, P, {Sigil = "TickSigil", SigilScale = 1, Pose = "Freeze", PoseK = .9})
	ctx:At(-pre + .05, function() ctx:Grade({Saturation = -.7, Contrast = .12, Brightness = -.04, TintColor = SEPIA}, pre * .8, 6.2, .3) end)
	K.TimeScale(ctx, {T0 = -pre + .05, T1 = 6.05, Radius = 30, Scale = .1})
	local S = sigil(ctx, c2, dark, 1, 0, .8)
	-- freeze: the stutter, the numerals lift and orbit then hang mid-orbit; the hairline stands behind the player
	stutter(ctx, P, 0, .55)
	local back = K.Behind(ctx)
	local R = rift(ctx, c1, c2, c3, dark, back)
	local nums = numerals(ctx, c1, c2, 12)
	local Rw = K.Rewind(ctx)
	for _, n in nums do Rw:Track(n.M) end
	local hands = {K.Mesh(ctx, "ClockHand", {Color = W, Transparency = 1}), K.Mesh(ctx, "ClockHandShort", {Color = c1, Transparency = 1})}
	local clock = K.Monument(ctx, {Mesh = "ClockRing", Height = 7.5, Behind = 2, Tilt = .45, Scale = 1, Color = c2, In = .9, Out = 6.1, Spin = 0, Light = 3})
	local rewinding, clockT = false, 0
	-- sound: the sky clock ticks under the hands, quickening as they do, until the rewind
	local ticks = Snd.Loop(ctx, .9, 5.25, "ClockTick", {At = function() return clock.Part end, FadeIn = .2})
	ctx:Every(function(t)
		R.Open = FX.ease(t / .25)
		for i, n in nums do
			local lift = FX.ease((t - i * .03) / .4)
			local a
			if t < .5 then a = n.A + t * 2.2 else a = n.A + .5 * 2.2 - FX.ease((t - .5) / .3) ^ 2 * 3 end
			local pull = FX.ease((t - .62) / .18)
			local pos = ctx.Base.Position + K.Polar(a, 4.8 * (1 - pull), n.Y * lift + .2)
			pos = pos:Lerp(R.Centre, pull)
			if t < .85 then
				K.Place(n.M, CFrame.lookAt(pos, pos + K.Polar(a, 1, 0)), lift * (1 - pull * .7))
				n.M.Transparency = 1 - lift
			end
		end
		-- the clock hands sweep backward, faster and faster, then spin back to twelve in the rewind
		local k = clock.Part.Transparency < .5 and 1 or 0
		if not rewinding then clockT = clockT + (1 / 60) * (1 + math.max(0, t - 1) * .9) else clockT = math.max(0, clockT - .25) end
		ticks:Set(math.clamp((t - 1) / 4.5, 0, 1))
		local cf = clock.Part.CFrame
		if hands[1].Parent then
			K.Place(hands[1], cf * CFrame.Angles(0, -clockT * 1.1, 0) * CFrame.new(0, .12, 0), .95)
			K.Place(hands[2], cf * CFrame.Angles(0, -clockT * .12, 0) * CFrame.new(0, .14, 0), .95)
			for _, h in hands do h.Transparency = 1 - k end
		end
		if t > 6.2 and hands[1].Parent then for _, h in hands do h:Destroy() end end
		if t > 7.3 then R.Destroy(.3) return true end
	end)
	-- tear: the numerals slam in, the sigil shatters, the hairline rips to five studs, the player is jerked back
	ctx:At(.82, function()
		for _, n in nums do n.M.Transparency = 1 end
		S.Stop()
		K.Starburst(ctx, ctx.Base.Position + V3(0, .5, 0), {Colors = {c1, c2}, Size = 9, Count = 24})
		K.Hit(ctx, R.Centre, {Colors = {c1, c2}, Impact = true, Shake = .4, FOV = 10, Ring = 26, Burst = 12, Lines = 28})
		K.ShockRing(ctx, R.Face * CFrame.Angles(-math.pi / 2, 0, 0), 1, 18, c2, .5, .4)
		local t0 = os.clock()
		ctx:Every(function()
			local u = (os.clock() - t0) / .3
			if u >= 1 then R.Gap = 5 return true end
			R.Gap = 5 * FX.back(u)
		end)
	end)
	ctx:Every(function(t)
		if t < .8 then return end
		if t > 1.3 then return true end
		local k = FX.ease((t - .8) / .12) * (1 - FX.ease((t - 1.0) / .3))
		P:Toward("Pulled", k)
		P:Pivot(ctx.Hrp.CFrame * CFrame.new(0, 0, 1.0 * k))
	end)
	local debris = K.Debris(ctx, {At = .9, Count = 14, Radius = 7, Lift = 3, Centre = function() return R.Centre end, Orbit = .6, Until = 5.3, Meshes = {"Cobble", "GrassClump", "Cobble"}})
	ctx:At(1.1, function() for _, it in debris do Rw:Track(it.M) end end)
	sand(ctx, c1, c2, 1.0, 5.2)
	-- the dead come out: the player hangs three studs up rotating backward with three echoes; eleven ghosts hunt
	K.Float(ctx, P, {T0 = 1.3, T1 = 6.02, Height = 3, Rise = .6, Fall = .25, Spin = -.55, Pose = "Wide"})
	K.Echo(ctx, P, {Count = 3, Delay = .3, Color = c2, Transparency = .6, T0 = 1.5, T1 = 5.2})
	local function hop(tg)
		if not K.CanMove(tg) then return end
		local m = tg.Model
		local base = m:GetPivot()
		local away = base.Position - ctx.Base.Position
		away = away.Magnitude > .1 and V3(away.X, 0, away.Z).Unit or Vector3.zAxis
		local t0 = os.clock()
		ctx:Every(function()
			local u = (os.clock() - t0) / .4
			if u >= 1 or not m.Parent then return true end
			pcall(function() m:PivotTo(base * CFrame.new(0, math.sin(u * math.pi) * 1.1, 0) + away * 3 * FX.ease(u)) end)
		end)
	end
	local Sk = K.Seek(ctx, {Mesh = "GhostWisp", Colors = {c1, c2, c3}, Count = 9, Interval = .3, T0 = 1.4, From = R.Centre, Speed = 15, Trail = 1.2, Circle = .6, Height = 2.8,
		Return = true, Radius = 40, OnTouch = function(tg) tickRing(ctx, c2, tg) hop(tg) end})
	-- frost prints under the ghosts; every ghost joins the rewind buffer as it is born
	local tracked, lastPrint = {}, 0
	ctx:Every(function(t)
		if t > 5.2 then return true end
		for _, p in Sk.Parts do if not tracked[p] then tracked[p] = true Rw:Track(p) end end
		if t - lastPrint > .4 then
			lastPrint = t
			for i, p in Sk.Parts do
				if i <= 4 and p.Parent and p.Transparency < .7 then
					local g = K.Ground(ctx, p.Position)
					if (p.Position - g).Magnitude < 6 then K.Stamp(ctx, g, {Mesh = "StarPoint", Color = c1, Scale = .35, Life = 1.6, Rise = .15, Transparency = .3}) end
				end
			end
		end
	end)
	K.Herd(ctx, {At = 2.2, Radius = 20, Color = c2, Flavour = "freeze"})
	-- rewind: everything retraces at 3x, the clock spins back, the lips slam shut, then dead stillness
	ctx:At(5.25, function()
		rewinding = true
		Sk:Freeze()
		ctx:Flash(c1, .3, .15)
		Rw:Play(9, function()
			-- stillness: every emitter at zero for .2 s
			for _, d in ctx.Folder:GetDescendants() do if d:IsA("ParticleEmitter") then d.TimeScale = 0 end end
			task.delay(.22, function() for _, d in ctx.Folder:GetDescendants() do if d:IsA("ParticleEmitter") then d.TimeScale = 1 end end end)
		end)
		R.Close(.35)
	end)
	-- snap: time resumes in one frame, every animal startles at once, the hairline shatters into glass
	ctx:At(6.05, function()
		ctx:Grade({Saturation = 0, Contrast = 0, Brightness = 0, TintColor = W}, .04, .1, .1)
		glassFan(ctx, R.Centre, c1, c2, 40)
		ctx:ImpactFrame()
		K.Hit(ctx, R.Centre, {Colors = {c1, c2}, Shake = .45, FOV = 12, Ring = 34, Burst = 14, Lines = 36})
		K.Herd(ctx, {At = 0, Radius = 30, Color = c2, Flavour = "flinch", Stagger = .01})
		K.LightPaint(ctx, {At = 0, Radius = 30, Color = c2, Hold = .4, Boost = 2})
		K.Cracks(ctx, {At = 0, Count = 6, Len = 7, Color = c2, Life = 1.6, Radius = 1})
	end)
	ctx:Every(function(t)
		if t < 6.06 then return end
		if t > 6.95 then return true end
		P:Toward("Punch", FX.ease((t - 6.06) / .15) * (1 - FX.ease((t - 6.5) / .4)))
	end)
	K.Title(ctx, 6.15, "glitch", 8)
	-- sound: the inhale (ClockTick from sigil(), then the sky clock's loop above), the duck, the numerals reversing, the
	-- tear as the detonation, the bed, the lift, one whoosh for each of the first six ghosts, the rewind, the snap (glass,
	-- the impact frame, the hit), the drop, the title
	Snd.ChargeUp(ctx)
	Snd.Duck(ctx, -pre, LEN)
	Snd.Cue(ctx, .5, "ReverseWhoosh")
	Snd.Hit(ctx, .82, "L")
	Snd.Bed(ctx, 1.0, LEN - .8)
	Snd.Cue(ctx, 1.3, "CelWhooshL", {Volume = .7, At = function() return P.Torso end})
	for i = 1, math.min(6, K.Count(ctx, 9)) do Snd.Cue(ctx, 1.4 + (i - 1) * .3, "CelWhooshS", {Volume = .4}) end
	Snd.Cue(ctx, 5.25, "Rewind")
	Snd.Cue(ctx, 6.05, "GlassBreak")
	Snd.Cue(ctx, 6.05, "CelImpact", {Volume = .6})
	Snd.Hit(ctx, 6.05, "M")
	Snd.Cue(ctx, 6.1, "CelLand")
	Snd.Cue(ctx, 6.15, "CelTitle")
	return LEN
end

return M
