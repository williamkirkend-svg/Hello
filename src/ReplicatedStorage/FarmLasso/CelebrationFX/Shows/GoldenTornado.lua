-- Shows.GoldenTornado: cut-out rune rings stack upward in a widening cone, each spinning against the one below, a
-- cream wind-sheet twisting up through them; gold coins fountain up the funnel and rain back down with physics;
-- loose props orbit; the player hangs tense inside the cone, then a 2-stud cream beam from the sky skewers every
-- ring at once, the rings fire outward as flat shock rings at their own heights, the pose snaps to an X and the
-- body drops into a superhero landing among the settled coins. (Oct 6 2026)
-- Set 1: three rings and a coin puff. Set 2: six rings, straw lift, a 3-stud hang, the beam slam. Set 3: a gold
-- sigil scribing itself rune by rune in the charge-up, nine rings, the 7-stud hang, the slam, coin rain, the landing.
local FX = require(script.Parent.Parent.Parent)
local K = require(script.Parent.Parent.AuraKit)
local V3, W, TAU, rng = Vector3.new, FX.W, K.TAU, FX.rng
local M = {Pre = 1.0}

-- "Hang": arms down and tense, chin tucked (a custom pose, blended by k)
local HANG = {RightShoulder = CFrame.Angles(.18, 0, .14), LeftShoulder = CFrame.Angles(.18, 0, -.14), RightElbow = CFrame.Angles(.55, 0, 0),
	LeftElbow = CFrame.Angles(.55, 0, 0), Neck = CFrame.Angles(-.3, 0, 0), Waist = CFrame.Angles(.14, 0, 0), RightHip = CFrame.Angles(-.1, 0, .05), LeftHip = CFrame.Angles(-.1, 0, -.05)}

-- the funnel: o.Rings flat rune rings in a widening cone (alternating spin, each lifting .3 studs on top of its base
-- height as the stack settles), a cream RibbonTwist wind-sheet spiralling up the middle, dark dust at the foot.
-- Returns F (F.Rings, F.Top, F:Fire() fires every ring outward as a shock ring at its own height).
local function funnel(ctx, c1, c2, c3, dark, o)
	local n = o.Rings
	local F = {Rings = {}, Top = o.BaseH + (n - 1) * 1.0, Fired = false}
	for i = 1, n do
		local m = K.Mesh(ctx, "TornadoRing", {Color = i % 3 == 0 and c3 or c2, Transparency = 1})
		F.Rings[i] = {M = m, R = 2.2 + (i - 1) * .5, Y = o.BaseH + (i - 1) * .7, Dir = i % 2 == 0 and -1 or 1, Delay = (i - 1) * .07, Gone = false}
	end
	local ribbon = K.Mesh(ctx, "RibbonTwist", {Color = c1, Transparency = 1})
	local dust = ctx:Emitter(ctx:Att(V3(0, .6, 0)), {Texture = K.Tex.Smoke, Color = {dark, c3}, Size = {{0, 1}, {1, 3}}, Transparency = {{0, .5}, {1, 1}}, Lifetime = {.8, 1.4},
		Speed = {3, 6}, SpreadAngle = Vector2.new(60, 10), Rate = 0, LightEmission = 0, Brightness = 1, RotSpeed = {-60, 60}, Drag = 2})
	local h = F.Top + 1 - o.BaseH
	ctx:Every(function(t)
		if t > o.T1 + .6 then for _, rg in F.Rings do rg.M:Destroy() end ribbon:Destroy() return true end
		local k = K.Env(t, o.T0, o.T1, .5, .5)
		local centre = ctx.Base.Position
		local settle = FX.ease((t - o.T0) / 1.4)
		for i, rg in F.Rings do
			if rg.Gone then continue end
			local ki = K.Env(t, o.T0 + rg.Delay, o.T1, .4, .5)
			local y = rg.Y + .3 * (i - 1) * settle
			local a = t * rg.Dir * (1.5 + i * .18)
			local s = rg.R / 3 * math.max(.02, ki)
			K.Place(rg.M, CFrame.new(centre + V3(0, y, 0)) * CFrame.Angles(.06 * math.sin(t * 1.3 + i), a, 0), V3(s, 1, s))
			rg.M.Transparency = ki > .03 and .08 or 1
		end
		local pulse = 1 + .12 * math.sin(t * 5.5)
		K.Place(ribbon, CFrame.new(centre + V3(0, o.BaseH + h * k / 2, 0)) * CFrame.Angles(0, -t * 3.4, 0), V3(pulse, h / 10 * math.max(.02, k), pulse))
		ribbon.Transparency = 1 - .55 * k
		dust.Rate = 10 * k * (ctx.Quality or 1)
	end)
	function F:Fire()
		self.Fired = true
		for i, rg in self.Rings do
			task.delay((i - 1) * .03, function()
				if not rg.M.Parent or rg.Gone then return end
				rg.Gone = true
				rg.M.Transparency = 1
				K.ShockRing(ctx, CFrame.new(rg.M.Position), rg.R * 2, rg.R * 2 + 18, i % 3 == 0 and c3 or c2, .45, .35)
			end)
		end
	end
	return F
end

-- gold coins: Count coins spiral up the funnel to o.Top, are flung off the rim and fall with gravity and one bounce
-- (the same integration K.Debris uses, plus a spin), lie on the ground through the hold and fade after o.Until.
local function coins(ctx, c1, c2, o)
	local n = K.Count(ctx, o.Count)
	local list = {}
	for i = 1, n do
		local m = K.Mesh(ctx, "Coin", {Color = i % 4 == 0 and c1 or c2, Transparency = 1})
		list[i] = {M = m, A = rng:NextNumber(0, TAU), Born = o.T0 + (i - 1) * (o.Stagger or .08), Spin = rng:NextNumber(5, 10), Dur = rng:NextNumber(.9, 1.3), State = 0}
	end
	ctx:Every(function(t, dt)
		if t > o.Until + 1.2 then for _, c in list do c.M:Destroy() end return true end
		dt = math.min(dt, 1 / 30)
		local centre = ctx.Base.Position
		for _, c in list do
			local age = t - c.Born
			if age < 0 then continue end
			if c.State == 0 then
				local u = age / c.Dur
				local a = c.A + u * 7
				if u >= 1 then
					c.State = 1
					local out = K.Polar(a, 1, 0)
					c.V = out * rng:NextNumber(4, 9) + V3(0, rng:NextNumber(3, 7), 0)
					c.Pos = c.M.Position
					c.GY = K.Ground(ctx, c.Pos).Y + .06
				else
					local r = 1.6 + u * (o.Spread or 3.5)
					K.Place(c.M, CFrame.new(centre + K.Polar(a, r, o.Top * u ^ .9)) * CFrame.Angles(c.Spin * age, a, 0), 1.2)
					c.M.Transparency = math.max(0, 1 - u * 8)
				end
			elseif c.State == 1 then
				c.V += V3(0, -55, 0) * dt
				c.Pos += c.V * dt
				if c.Pos.Y <= c.GY then
					c.Pos = V3(c.Pos.X, c.GY, c.Pos.Z)
					if not c.Bounced and math.abs(c.V.Y) > 6 then
						c.V = V3(c.V.X * .6, -c.V.Y * .3, c.V.Z * .6) c.Bounced = true
					else
						c.State = 2
						c.M.CFrame = CFrame.new(c.Pos) * CFrame.Angles(0, c.A, 0)
						continue
					end
				end
				c.M.CFrame = CFrame.new(c.Pos) * CFrame.Angles(c.Spin * age, c.A, c.Spin * .6 * age)
			elseif t > o.Until and not c.Fading then
				c.Fading = true
				FX.Tween(c.M, 1, {Transparency = 1})
			end
		end
	end)
	return list
end

-- the beam slam: a 2-stud cream cylinder grows down from 30 studs in .12 s and skewers every ring; on impact the hard
-- hit, the rings fire outward, dark dust rolls out at the foot; the beam fades over the next half second
local function slam(ctx, F, c1, c2, c3, dark, onHit)
	local pos = ctx.Base.Position
	local beam = ctx:Part({Shape = Enum.PartType.Cylinder, Color = c1, Size = V3(.1, 2, 2), Transparency = .05})
	local core = ctx:Part({Shape = Enum.PartType.Cylinder, Color = W, Size = V3(.1, .8, .8)})
	local light = ctx:Light(ctx:Att(V3(0, 3, 0)), c1, 40, 0)
	local t0, hit = os.clock(), false
	ctx:Every(function()
		local age = os.clock() - t0
		if age > .95 then beam:Destroy() core:Destroy() return true end
		local len = 30 * FX.ease(age / .12)
		local fade = FX.ease((age - .35) / .55)
		local w = 2 * (1 - fade) + .01
		local cf = CFrame.new(pos + V3(0, 30 - len / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		beam.Size, beam.CFrame = V3(math.max(.1, len), w, w), cf
		core.Size, core.CFrame = V3(math.max(.1, len), w * .4, w * .4), cf
		beam.Transparency, core.Transparency = .05 + fade * .95, fade
		light.Brightness = 10 * (1 - fade)
		if not hit and age >= .12 then
			hit = true
			K.Hit(ctx, pos, {Colors = {c1, c2}, Impact = true, Ring = 28, Burst = 14, Lines = 36, Shake = .45})
			F:Fire()
			ctx:Burst(pos + V3(0, .5, 0), K.Count(ctx, 20), {Texture = K.Tex.Smoke, Color = {dark, c3}, Size = {{0, 1.5}, {1, 4}}, Transparency = {{0, .4}, {1, 1}}, Lifetime = {.7, 1.2},
				Speed = {8, 14}, SpreadAngle = Vector2.new(80, 6), LightEmission = 0, Brightness = 1, Drag = 3, RotSpeed = {-60, 60}})
			if onHit then onHit() end
		end
	end)
end
-- the superhero landing: a kneel blended in over [t0, t1], a ground ring and dust at the touch-down
local function landing(ctx, P, t0, t1, c2, dark)
	ctx:At(t0 + .05, function()
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .2), 2, 16, c2, .45, .4)
		ctx:Burst(ctx.Base.Position + V3(0, .3, 0), K.Count(ctx, 12), {Texture = K.Tex.Smoke, Color = {dark, dark}, Size = {{0, 1}, {1, 2.5}}, Transparency = {{0, .5}, {1, 1}},
			Lifetime = {.5, .9}, Speed = {4, 8}, SpreadAngle = Vector2.new(80, 6), LightEmission = 0, Brightness = 1, Drag = 3})
		ctx:Shake(.25, .3)
	end)
	ctx:Every(function(t)
		if not P.Alive or t > t1 then return true end
		if t < t0 then return end
		P:Toward("Kneel", FX.ease((t - t0) / .18) * (1 - FX.ease((t - t1 + .5) / .5)))
	end)
end

---------------------------------------------------------------- Set 1: three rings and a coin puff (2.7 s)
function M.Set1(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 2.7
	funnel(ctx, c1, c2, c3, dark, {Rings = 3, BaseH = 1.2, T0 = 0, T1 = 2.0})
	ctx:At(.08, function()
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .15), 2, 14, c2, .45, .4)
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .2), 2, 18, dark, .6, .35)
		K.Starburst(ctx, ctx.Base.Position + V3(0, 2.5, 0), {Colors = {c1, c2}, Size = 6, Count = 18})
	end)
	coins(ctx, c1, c2, {Count = 8, T0 = .3, Top = 4, Spread = 2.5, Until = 1.6, Stagger = .08})
	ctx:Repeat(.4, 1.8, .35, function() ctx:Flare(ctx.Base.Position + K.Polar(rng:NextNumber(0, TAU), rng:NextNumber(2, 3.5), rng:NextNumber(1, 4)), rng:NextNumber(2, 3), c1, .3) end)
	K.Title(ctx, .9, "embers", 7.5)
	return LEN
end

---------------------------------------------------------------- Set 2: six rings, the hang, the beam slam (5.2 s)
function M.Set2(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN, SLAM = 5.2, 3.3
	local P = K.Performer(ctx)
	if not P then return M.Set1(ctx, def) end
	ctx:At(.02, function() P:Show() end)
	local F = funnel(ctx, c1, c2, c3, dark, {Rings = 6, BaseH = 1.0, T0 = .1, T1 = SLAM + .5})
	ctx:At(.1, function()
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .15), 2, 18, c2, .45, .4)
		K.Starburst(ctx, ctx.Base.Position + V3(0, 3, 0), {Colors = {c1, c2}, Size = 8, Count = 22})
	end)
	K.Debris(ctx, {At = .4, Count = 10, Radius = 6, Lift = 3, Orbit = 1.4, Until = SLAM, Centre = function() return ctx.Base.Position + V3(0, 3, 0) end})
	coins(ctx, c1, c2, {Count = 14, T0 = .6, Top = 6, Spread = 3.2, Until = 4.1, Stagger = .07})
	K.Herd(ctx, {At = 1.2, Radius = 14, Color = c2, Flavour = "bolt"})
	-- the body hangs tense inside the cone, spinning slowly; at the slam it snaps to the X
	K.Float(ctx, P, {T0 = .3, T1 = SLAM + .5, Height = 3, Rise = .9, Fall = .35, Spin = 1.1,
		OnK = function(k) if F.Fired then P:Toward("Star", k) else P:Pose(HANG, k) end end})
	ctx:At(SLAM, function()
		slam(ctx, F, c1, c2, c3, dark, function()
			P:Silhouette()
			task.delay(.1, function() if P.Alive then P:RestoreLook() end end)
		end)
	end)
	landing(ctx, P, SLAM + .55, 4.9, c2, dark)
	K.Title(ctx, SLAM + .25, "embers", 7.5)
	return LEN
end

---------------------------------------------------------------- Set 3: the sigil, nine rings, the slam and the landing (8 s + 1 s charge-up)
function M.Set3(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN, SLAM = 8.0, 4.8
	local P = K.Performer(ctx)
	if not P then return M.Set2(ctx, def) end
	local pre = ctx.Pre or 1
	-- charge-up: the crouch and the inhale, a gold sigil scribing itself rune by rune round the feet
	K.ChargeUp(ctx, P, {Sigil = "TornadoRing", SigilScale = 1.3, Pose = "Crouch", PoseK = .9})
	local runes = {}
	for i = 1, 12 do
		local m = K.Mesh(ctx, "Numeral", {Color = c2, Transparency = 1})
		runes[i] = {M = m, At = -pre + .1 + (i - 1) * (pre * .85 / 12), A = (i - 1) / 12 * TAU}
	end
	local sigilCF = K.GroundCF(ctx, ctx.Base.Position, .12)
	ctx:Every(function(t)
		if t >= 0 then for _, r in runes do r.M:Destroy() end return true end
		for _, r in runes do
			local k = FX.back((t - r.At) / .14)
			if k <= 0 then continue end
			K.Place(r.M, sigilCF * CFrame.Angles(0, r.A + t * .4, 0) * CFrame.new(0, .05, -4.6), .9 * k)
			r.M.Transparency = .1
		end
	end)
	-- t = 0: the detonation; the funnel builds, straw and cobbles lift, coins fountain
	ctx:At(0, function()
		ctx:Flash(c1, .45, .3)
		K.Starburst(ctx, ctx.Base.Position + V3(0, 3, 0), {Colors = {c1, c2}, Size = 12, Count = 36})
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .15), 2, 26, W, .35, .5)
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .2), 2, 32, c2, .55, .5)
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .25), 2, 38, dark, .8, .4)
		ctx:Shake(.35, .4)
		ctx:Grade({Brightness = .06, Contrast = .18, Saturation = .15, TintColor = Color3.fromRGB(255, 240, 214)}, .15, SLAM + 1.2, .8)
	end)
	local F = funnel(ctx, c1, c2, c3, dark, {Rings = 9, BaseH = 1.0, T0 = .05, T1 = SLAM + .5})
	K.Debris(ctx, {At = .5, Count = 16, Radius = 8, Lift = 4, Orbit = 1.6, Until = SLAM, Centre = function() return ctx.Base.Position + V3(0, 4, 0) end})
	coins(ctx, c1, c2, {Count = 24, T0 = .7, Top = 8.5, Spread = 3.8, Until = 7.0, Stagger = .06})
	K.Sweeps(ctx, {Colors = {c1, c2}, T0 = 1.0, T1 = 4.2, Period = .3, Radius = 6, Height = 4, Climb = 9, Dur = .6})
	K.Herd(ctx, {At = 1.4, Radius = 16, Color = c2, Flavour = "bolt"})
	K.Herd(ctx, {At = SLAM + .3, Radius = 16, Color = c2, Flavour = "lookup"})
	-- the body rises to the top ring, arms down and tense; the slam snaps it to the X; then the landing
	K.Float(ctx, P, {T0 = .35, T1 = SLAM + .6, Height = 7, Rise = 1.4, Fall = .4, Spin = 1.3,
		OnK = function(k) if F.Fired then P:Toward("Star", k) else P:Pose(HANG, k) end end})
	ctx:At(SLAM, function()
		slam(ctx, F, c1, c2, c3, dark, function()
			P:Silhouette()
			task.delay(.1, function() if P.Alive then P:RestoreLook() end end)
			K.FOV(ctx, -6, .1, .5, .3)
		end)
	end)
	landing(ctx, P, SLAM + .65, 7.0, c2, dark)
	K.Title(ctx, SLAM + .3, "embers", 8)
	return LEN
end

return M
