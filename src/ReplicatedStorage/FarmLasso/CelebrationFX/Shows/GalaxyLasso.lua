-- Shows.GalaxyLasso: a spiral galaxy spins at the player's feet. One arm detaches and rises as a rope of forty star
-- meshes joined by thin cyan Beams; the player whirls it over their head two turns a second and throws it. It lassos
-- the nearest herd animal (or a fence post, or the ground) and lands as a 6-stud ring round it, lifting the animal
-- 2 studs for a second. In Set 3 the player floats on the galaxy hub, a second loop pulls a constellation out of the
-- disc and hangs it 12 studs up, a ringed planet orbits at knee height and a shooting star crosses behind the title.
-- (Oct 6 2026) Set 1: the disc, four orbiting stars, a star sigil overhead. Set 2: the whirl, the throw, an animal
-- lifted. Set 3: the disc forms from stars sucked in from 15 studs, two lassos, the constellation, rim stars.
local FX = require(script.Parent.Parent.Parent)
local K = require(script.Parent.Parent.AuraKit)
local V3, W, TAU, rng = Vector3.new, FX.W, K.TAU, FX.rng
local M = {Pre = 1.0}

-- a four-point star mesh (the stand-in is a thin plate: the star lies in its XY plane, Z is its normal)
local function star(ctx, color)
	local s = K.Mesh(ctx, "StarPoint", {Color = color})
	if not s:IsA("MeshPart") then s.Size = V3(1.4, 1.4, .08) s:SetAttribute("BaseSize", s.Size) end
	return s
end
-- the ground galaxy: three spiral arms 120 degrees apart spinning round a white core over a glow disc, irised in at
-- In and out at Out. G.K is how open it is, G.Pos() the hub.
local function galaxy(ctx, o)
	local c1, c2, c3 = o.Colors[1], o.Colors[2], o.Colors[3]
	local arms = {}
	for i = 1, 3 do
		local a = K.Mesh(ctx, "GalaxyArm", {Color = i == 2 and c1 or c2, Transparency = 1})
		if not a:IsA("MeshPart") then a.Size = V3(1.6, .1, 5) a:SetAttribute("BaseSize", a.Size) end
		arms[i] = a
	end
	local core = K.Mesh(ctx, "GalaxyCore", {Color = W, Transparency = 1})
	if not core:IsA("MeshPart") then core.Size = V3(2.6, .3, 2.6) core:SetAttribute("BaseSize", core.Size) end
	local ground = K.GroundCF(ctx, ctx.Base.Position, .15)
	local att = ctx:Att(ground.Position - ctx.Base.Position + V3(0, .05, 0))
	local glow = ctx:Disc(att, {Texture = K.Tex.Glow, Color = {c2, c3}, Size = (o.Scale or 1) * 13, Transparency = {{0, 1}, {.1, .45}, {.9, .5}, {1, 1}}, Lifetime = 1.2, Rate = 0, Brightness = 2})
	local light = ctx:Light(att, c2, 22, 0)
	local G = {K = 0, Alive = true}
	function G.Pos() return ground.Position end
	ctx:Every(function(t)
		local k = K.Env(t, o.In or 0, o.Out or 99, o.Rise or .45, .5)
		G.K = k
		local s = (o.Scale or 1) * math.max(.02, k)
		local cf = ground * CFrame.Angles(0, (o.Spin or .9) * t, 0)
		for i, a in arms do
			K.Place(a, cf * CFrame.Angles(0, (i - 1) * TAU / 3, 0), s)
			a.Transparency = k > .02 and .1 or 1
		end
		K.Place(core, cf * CFrame.new(0, .1, 0) * CFrame.Angles(0, -t * .6, 0), s * .9)
		core.Transparency = k > .02 and 0 or 1
		glow.Rate = k > .3 and 1.5 or 0
		light.Brightness = 4 * math.min(1, k)
		if t > (o.Out or 99) + .6 then for _, a in arms do a:Destroy() end core:Destroy() G.Alive = false return true end
	end)
	return G
end
-- the rope: Count star meshes along a path joined by one Beam per 8 stars. R.Set(path, scale, tr) lays it along
-- path(u) (u 0..1, a closed loop); R.Fade(dur) lets it go.
local function rope(ctx, o)
	local c1, c2 = o.Colors[1], o.Colors[2]
	local n = K.Count(ctx, o.Count or 40)
	local R = {Stars = {}, Atts = {}, Beams = {}, Alive = true}
	for i = 1, n do
		local s = star(ctx, i % 4 == 0 and c2 or c1)
		s.Transparency = 1
		R.Stars[i] = s
		R.Atts[i] = ctx:Att(nil, s)
	end
	for i = 1, n, 8 do
		local b = ctx:Beam(R.Atts[i], R.Atts[i + 8 <= n and i + 8 or 1], {Color = {c1, c2}, Width0 = .14, Width1 = .14, Transparency = .15, Brightness = 3, Segments = 1})
		b.Enabled = false
		table.insert(R.Beams, b)
	end
	function R.Set(path, scale, tr)
		for i, s in R.Stars do
			local u = (i - 1) / n
			local p, q = path(u), path((u + .02) % 1)
			local d = q - p
			K.Place(s, (d.Magnitude > .001 and CFrame.lookAt(p, q) or CFrame.new(p)) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, i + os.clock() * 2), scale or .7)
			s.Transparency = tr or 0
		end
		for _, b in R.Beams do b.Enabled = (tr or 0) < .9 end
	end
	function R.Fade(dur)
		R.Alive = false
		for _, s in R.Stars do FX.Tween(s, dur, {Transparency = 1}) end
		for _, b in R.Beams do b.Enabled = false end
	end
	return R
end
-- what the lasso goes for: the nearest animal, else a prop, else a spot on the ground 8 studs ahead
local function pickTarget(ctx)
	local animals = K.NearbyAnimals(ctx, 22)
	if animals[1] then return animals[1] end
	local props = K.NearbyProps(ctx, 15, 3)
	if props[1] then return {Part = props[1], Kind = "prop"} end
	local p = K.Ground(ctx, ctx.Base.Position + ctx.Hrp.CFrame.LookVector * 8)
	return {Pos = p + V3(0, .6, 0), Kind = "point"}
end
-- the lasso: the rope rises off the disc (Rise..Whirl), whirls 2.5 studs over the head at two turns a second
-- (Whirl..Throw), flies to the target in .45 s, lands as a 6-stud ring round it and holds Hold seconds (an animal is
-- lifted 2 studs, absolute from the pose sampled at landing; the game re-takes it after), then lets go.
-- L.Centre is the loop's centre every frame, L.Phase its phase. OnLand(tg, pos), OnHold(age, centre), OnFree(tg).
local function lasso(ctx, P, G, o)
	local R = rope(ctx, {Colors = o.Colors})
	local tg = o.Target
	local land = o.Throw + .45
	local L = {Centre = ctx.Base.Position, Phase = "wait", Rope = R, Land = land}
	local pivot, flyFrom, ctrl
	local function head() return P.Head.Position + V3(0, 2.5, 0) end
	local function circle(c, v, t, r) return c + K.Polar(v * TAU + t * TAU * 2, r or 3, math.sin(v * TAU * 2) * .2) end
	local function goal() return (tg.Part and K.TargetPos(tg, o.Height or .9)) or tg.Pos end
	ctx:Every(function(t)
		if not P.Alive then return true end
		if t < o.Rise then return end
		if t >= land + o.Hold + .45 then return true end
		if t < o.Whirl then
			L.Phase = "rise"
			local u = FX.ease((t - o.Rise) / (o.Whirl - o.Rise))
			local hub, h = G.Pos(), head()
			R.Set(function(v) return K.Bezier(hub + K.Polar(v * TAU * 1.2 + t * .9, .8 + v * 5.5, .4), hub + V3(0, 6, 0), circle(h, v, t), u) end, .45 + .25 * u)
			L.Centre = hub:Lerp(h, u)
		elseif t < o.Throw then
			L.Phase = "whirl"
			local h = head()
			R.Set(function(v) return circle(h, v, t) end, .7)
			L.Centre = h
		elseif t < land then
			L.Phase = "fly"
			if not flyFrom then flyFrom = head() ctrl = (flyFrom + goal()) / 2 + V3(0, 5, 0) end
			local c = K.Bezier(flyFrom, ctrl, goal(), FX.ease((t - o.Throw) / .45))
			R.Set(function(v) return circle(c, v, t) end, .7)
			L.Centre = c
		elseif t < land + o.Hold then
			L.Phase = "hold"
			local age = t - land
			if not pivot then
				pivot = tg.Model and tg.Model:GetPivot() or CFrame.new(goal())
				if o.OnLand then o.OnLand(tg, goal()) end
			end
			if tg.Kind == "animal" and tg.Model.Parent then
				local lift = 2 * K.Soft(age, 0, o.Hold, .3, .35)
				pcall(function() tg.Model:PivotTo(pivot * CFrame.new(0, lift, 0) * CFrame.Angles(math.sin(age * 4) * .06, 0, 0)) end)
			end
			if o.OnHold then o.OnHold(age, tg) end
			local c = goal()
			R.Set(function(v) return c + K.Polar(v * TAU + t * 1.5, 3, 0) end, .7)
			L.Centre = c
		elseif R.Alive then
			L.Phase = "free"
			R.Fade(.4)
			if o.OnFree then o.OnFree(tg) end
		end
	end)
	return L
end
-- the body: the whirl on the right shoulder with the torso twisting (Whirl..Throw), then the throw
local function whirlPose(ctx, P, whirl, throw)
	ctx:Every(function(t)
		if not P.Alive then return true end
		if t > throw + .7 then P:Toward("Punch", 0) return true end
		local k = K.Soft(t, whirl - .25, throw, .3, .15)
		P:Toward("Whirl", k)
		P:Pose({Waist = CFrame.Angles(0, math.sin(t * TAU * 2) * .22, -.15)}, k)
		local th = FX.ease((t - throw) / .12) * (1 - FX.ease((t - throw - .25) / .3))
		if th > 0 then P:Toward("Punch", th) end
	end)
end
-- a small star hangs over whatever was lassoed for the hold
local function starOver(ctx, tg, color, life)
	local s = star(ctx, color)
	s.Transparency = 1
	local t0 = os.clock()
	ctx:Every(function()
		local age = os.clock() - t0
		if age >= life then s:Destroy() return true end
		local k = K.Env(age, 0, life, .3, .4)
		local p = tg.Part and tg.Part.Parent and tg.Part.Position + V3(0, tg.Part.Size.Y * .5 + 1.5, 0) or (tg.Pos or ctx.Base.Position) + V3(0, 2, 0)
		K.Place(s, CFrame.new(p) * CFrame.Angles(0, age * 2.5, 0), .8 * math.max(.05, k))
		s.Transparency = 1 - math.min(1, k)
	end)
end
-- stars shoot from the disc rim into the tall grass and glow there
local function rimStars(ctx, G, c1, c3)
	ctx:Burst(G.Pos() + V3(0, .4, 0), K.Count(ctx, 20), {Texture = K.Tex.Star, Color = {W, c1, c3}, Size = {{0, .6}, {.8, .5}, {1, 0}}, Transparency = {{0, 0}, {.7, .1}, {1, 1}},
		Lifetime = {1.4, 2.2}, Speed = {9, 15}, SpreadAngle = Vector2.new(75, 75), EmissionDirection = Enum.NormalId.Top, Acceleration = V3(0, -14, 0), Drag = 1.5, Brightness = 5})
end
-- the constellation of the caught animal: the Constellation mesh, or six stars joined by Beams in a rough quadruped
-- outline, in a vertical plane. C.Set(cf, s, tr) draws it; C.Fade(dur) lets it go.
local OUTLINE = {V3(2.6, 1.0, 0), V3(-1.8, .9, 0), V3(-2.7, -.9, 0), V3(-.5, -1.0, 0), V3(1.7, -1.0, 0), V3(3.3, .1, 0)}
local function constellation(ctx, c1, c2)
	local C = {Stars = {}, Beams = {}}
	if K.HasMesh("Constellation") then
		C.Mesh = K.Mesh(ctx, "Constellation", {Color = c1, Transparency = 1})
	else
		local atts = {}
		for i, p in OUTLINE do
			local s = star(ctx, i % 2 == 0 and c2 or c1)
			s.Transparency = 1
			C.Stars[i] = {M = s, P = p}
			atts[i] = ctx:Att(nil, s)
		end
		for i = 1, #OUTLINE do
			local b = ctx:Beam(atts[i], atts[i % #OUTLINE + 1], {Color = {c1, c2}, Width0 = .12, Width1 = .12, Transparency = .1, Brightness = 2.5, Segments = 1})
			b.Enabled = false
			C.Beams[i] = b
		end
	end
	function C.Set(cf, s, tr)
		if C.Mesh then
			K.Place(C.Mesh, cf * CFrame.Angles(math.pi / 2, 0, 0), math.max(.02, s))
			C.Mesh.Transparency = tr
		else
			for i, st in C.Stars do
				K.Place(st.M, cf * CFrame.new(st.P * s) * CFrame.Angles(0, 0, os.clock() * .7 + i), .8 * math.max(.05, s))
				st.M.Transparency = tr
			end
			for _, b in C.Beams do b.Enabled = tr < .9 end
		end
	end
	function C.Fade(dur)
		if C.Mesh then FX.Tween(C.Mesh, dur, {Transparency = 1}) end
		for _, st in C.Stars do FX.Tween(st.M, dur, {Transparency = 1}) end
		for _, b in C.Beams do b.Enabled = false end
	end
	return C
end

---------------------------------------------------------------- Set 1: the disc, four orbiting stars, a star sigil (2.6 s)
function M.Set1(ctx, def)
	local c1, c2, c3 = K.Palette(def)
	local LEN = 2.6
	galaxy(ctx, {Colors = {c1, c2, c3}, In = .05, Out = 2.0, Scale = .85, Spin = 1.1})
	ctx:At(.25, function()
		K.Starburst(ctx, ctx.Base.Position + V3(0, 1, 0), {Colors = {c1, c2}, Size = 6, Count = 18})
		K.ShockRing(ctx, K.GroundCF(ctx, ctx.Base.Position, .15), 2, 14, c2, .45, .4)
	end)
	-- four stars orbit the chest at the shell and a star sigil spins at the crown
	local orbit = {}
	for i = 1, K.Count(ctx, 4) do local s = star(ctx, i % 2 == 0 and c2 or c1) s.Transparency = 1 orbit[i] = s end
	local sigil = star(ctx, c1)
	sigil.Transparency = 1
	ctx:Every(function(t)
		if t > 2.3 then for _, s in orbit do s:Destroy() end sigil:Destroy() return true end
		local k = K.Env(t, .2, 2.1, .4, .4)
		for i, s in orbit do
			local a = i / #orbit * TAU + t * 2.6
			local pos = ctx.Base.Position + K.Polar(a, 4 * (.3 + .7 * math.min(1, k)), 3 + math.sin(t * 2 + i) * .4)
			K.Place(s, CFrame.new(pos) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, t * 3 + i), .8 * math.max(.05, k))
			s.Transparency = 1 - math.min(1, k)
		end
		K.Place(sigil, ctx.Base * CFrame.new(0, 6.4 + math.sin(t * 1.6) * .15, 0) * CFrame.Angles(0, t * 1.8, 0), 1.8 * math.max(.05, k))
		sigil.Transparency = 1 - math.min(1, k) * .9
	end)
	ctx:Repeat(.4, 1.9, .3, function() ctx:Flare(ctx.Base.Position + K.Polar(rng:NextNumber(0, TAU), rng:NextNumber(2, 5), rng:NextNumber(.3, 1)), 2.5, c1, .3) end)
	K.Title(ctx, 1.0, "embers", 8)
	return LEN
end

---------------------------------------------------------------- Set 2: the whirl, the throw, an animal lifted (5.2 s)
function M.Set2(ctx, def)
	local c1, c2, c3 = K.Palette(def)
	local LEN = 5.2
	local P = K.Performer(ctx)
	if not P then return M.Set1(ctx, def) end
	ctx:At(.02, function() P:Show() end)
	local G = galaxy(ctx, {Colors = {c1, c2, c3}, In = .05, Out = 4.6, Scale = 1, Spin = 1})
	ctx:At(.2, function() K.Starburst(ctx, ctx.Base.Position + V3(0, 1, 0), {Colors = {c1, c2}, Size = 7, Count = 20}) ctx:Flash(c1, .25, .3) end)
	local tg = pickTarget(ctx)
	lasso(ctx, P, G, {Colors = {c1, c2, c3}, Target = tg, Rise = .3, Whirl = .9, Throw = 2.3, Hold = 1.2,
		OnLand = function(target, pos)
			ctx:Ripple(K.GroundCF(ctx, pos, .2), 2, 12, {W, c2}, .5, K.Tex.Ring)
			K.Starburst(ctx, pos + V3(0, 1, 0), {Colors = {c1, c2}, Size = 5, Count = 14})
			ctx:Shake(.2, .3)
			starOver(ctx, target, c1, 1.3)
		end})
	whirlPose(ctx, P, .9, 2.3)
	ctx:At(1.4, function() rimStars(ctx, G, c1, c3) end)
	K.Herd(ctx, {At = 2.8, Radius = 16, Color = c2, Flavour = "lookup", Max = 5})
	K.Title(ctx, 3.0, "embers", 8)
	return LEN
end

---------------------------------------------------------------- Set 3: two lassos, the constellation, the planet (8 s + 1 s charge-up)
function M.Set3(ctx, def)
	local c1, c2, c3, dark = K.Palette(def)
	local LEN = 8.0
	local P = K.Performer(ctx)
	if not P then return M.Set2(ctx, def) end
	local pre = ctx.Pre or 1
	-- charge-up: crouch, the dark sigil, the inhale; a dozen dark stars are sucked in from 15 studs to form the disc
	K.ChargeUp(ctx, P, {Sigil = "Sigil", SigilScale = 1.1, Pose = "Crouch", PoseK = .9})
	local gather = {}
	for i = 1, K.Count(ctx, 12) do local s = star(ctx, dark) s.Transparency = 1 gather[i] = s end
	ctx:Every(function(t)
		if t >= 0 then for _, s in gather do s:Destroy() end return true end
		local u = 1 + t / pre
		local e = FX.ease(u) ^ 2
		for i, s in gather do
			local a = i / #gather * TAU + u * 2
			K.Place(s, CFrame.new(ctx.Base.Position + K.Polar(a, 15 * (1 - e), .4 + 1.5 * e)) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, u * 6), .6)
			s.Transparency = .2
		end
	end)
	-- t = 0: the disc detonates open, the player lifts onto the hub
	ctx:At(0, function()
		K.Hit(ctx, ctx.Base.Position, {Colors = {c1, c2}, Impact = true, Ring = 30, Burst = 16, Lines = 36})
		ctx:Grade({Brightness = .05, Contrast = .15, Saturation = .12, TintColor = Color3.fromRGB(225, 235, 255)}, .1, 6.4, .8)
	end)
	local G = galaxy(ctx, {Colors = {c1, c2, c3}, In = 0, Out = 7.3, Scale = 1.2, Spin = 1, Rise = .3})
	K.Float(ctx, P, {T0 = .3, T1 = 6.6, Height = 2, Rise = .5, Fall = .5})
	-- lasso one: the nearest animal, lifted inside the loop
	local tg = pickTarget(ctx)
	lasso(ctx, P, G, {Colors = {c1, c2, c3}, Target = tg, Rise = .3, Whirl = .9, Throw = 2.4, Hold = 1.2,
		OnLand = function(target, pos)
			ctx:Ripple(K.GroundCF(ctx, pos, .2), 2, 14, {W, c2}, .5, K.Tex.Ring)
			K.Starburst(ctx, pos + V3(0, 1, 0), {Colors = {c1, c2}, Size = 6, Count = 16})
			ctx:Shake(.25, .3)
			starOver(ctx, target, c1, 1.3)
		end})
	whirlPose(ctx, P, .9, 2.4)
	-- lasso two: thrown into the disc, it pulls the constellation of the caught animal up to 12 studs and hangs it
	local C = constellation(ctx, c1, c2)
	local back = K.Behind(ctx)
	local sky = {Pos = G.Pos() + V3(0, .5, 0), Kind = "sky"}
	local L2 = lasso(ctx, P, G, {Colors = {c1, c2, c3}, Target = sky, Rise = 2.6, Whirl = 3.1, Throw = 4.2, Hold = 2.65,
		OnLand = function(_, pos)
			K.Starburst(ctx, pos + V3(0, .5, 0), {Colors = {W, c1}, Size = 7, Count = 20})
			K.ShockRing(ctx, K.GroundCF(ctx, pos, .2), 2, 18, c3, .5, .45)
		end,
		OnHold = function(age, target) target.Pos = G.Pos() + V3(0, .5 + 11.5 * FX.ease(age / .9) + math.sin(age * 1.5) * .2, 0) end,
		OnFree = function() C.Fade(.6) end})
	whirlPose(ctx, P, 3.1, 4.2)
	ctx:Every(function(t)
		if t > 7.4 then return true end
		if L2.Phase ~= "hold" then return end
		local age = t - L2.Land
		local c = L2.Centre
		C.Set(CFrame.lookAt(c, c - back) * CFrame.Angles(0, math.sin(t) * .2, 0), 1.3 * FX.ease(age / .8), 1 - FX.ease(age / .5))
	end)
	-- a ringed planet orbits at knee height, out at the shell
	local planet = K.Mesh(ctx, "PlanetRinged", {Color = c2, Transparency = 1})
	ctx:Every(function(t)
		if t > 7.6 then planet:Destroy() return true end
		local k = K.Env(t, 1.0, 7.0, .5, .5)
		local a = t * 1.1 + 2
		K.Place(planet, CFrame.new(ctx.Base.Position + K.Polar(a, 5.5, 1.2 + math.sin(t * 1.4) * .3)) * CFrame.Angles(.35, t * 1.6, .15), .55 * math.max(.02, k))
		planet.Transparency = 1 - math.min(1, k) * .9
	end)
	ctx:At(1.3, function() rimStars(ctx, G, c1, c3) end)
	ctx:At(4.0, function() rimStars(ctx, G, c1, c3) end)
	K.Herd(ctx, {At = 3.0, Radius = 18, Color = c2, Flavour = "lookup", Max = 6})
	-- a shooting star crosses the sky behind the title
	ctx:At(5.9, function()
		local right = back:Cross(Vector3.yAxis)
		local c = ctx.Base.Position + back * 14 + V3(0, 13, 0)
		ctx:Streak(function(u) return c + right * (-16 + 32 * u) + V3(0, 4 - 7 * u, 0) end, .65, {W, c1, c2}, .9, .5)
	end)
	K.Title(ctx, 5.6, "embers", 8.5)
	return LEN
end

return M
