-- CelebrationFX: plays a special celebration (catalog: FarmLasso.Celebrations) round a character. Client only.
-- CelebrationFX.Play(char, id, opts) -> ctx
--   opts.Local = true for your own character: adds the screen-side hits (flashes, impact frames, colour grading,
--   camera shake). Other players' celebrations are world-only.
--   opts.Set = 1, 2 or 3 (default 3), picked by the caught animal's rarity (Oct 5 2026): Set 1 and Set 2 are the
--   short and mid versions in the child module Tiers; Set 3 is the full show plus Tiers.Overdrive, with a
--   Tiers.Pre-second charge-up before t = 0. ctx.Duration is the real length including that charge-up.
-- The effect builders live in the child modules Free (the 5 unlockable ones) and Premium (the 3 Robux ones);
-- each is Builders[id](ctx, def) and returns its length in seconds. This module is the toolkit they share (ctx:*).
-- Look rules (from the reference clips): white-hot cores with coloured falloff, additive particles
-- (LightEmission 1, LightInfluence 0 so the effect reads the same under any lighting), Neon parts, PointLights
-- spilling colour on the ground, a short anticipation, a hard flash, a sustained loop and a fade.
-- Everything lives in workspace.CelebrationFX/<id> and cleans itself up.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FX = {}
local Assets = ReplicatedStorage:WaitForChild("CelebrationAssets")
local Cat = require(script.Parent:WaitForChild("Celebrations"))

local T = {
	Spark = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Embers = "rbxasset://textures/particles/fire_sparks_main.dds",
	Shock = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	Core = "rbxasset://textures/particles/explosion01_core_main.dds",
	Implode = "rbxasset://textures/particles/explosion01_implosion_main.dds",
	Puff = "rbxasset://textures/particles/explosion01_smoke_main.dds",
	Vortex = "rbxasset://textures/particles/forcefield_vortex_main.dds",
	Glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
}
FX.T = T
FX.W = Color3.new(1, 1, 1)
FX.FLAT = CFrame.Angles(0, 0, math.pi / 2) -- turns a ring (axis X) to lie flat (axis Y)
FX.Rainbow = {Color3.fromRGB(255, 70, 90), Color3.fromRGB(255, 160, 40), Color3.fromRGB(255, 240, 60), Color3.fromRGB(80, 240, 120),
	Color3.fromRGB(60, 200, 255), Color3.fromRGB(150, 110, 255), Color3.fromRGB(255, 90, 220)}
local rng = Random.new()
FX.rng = rng
local TITLE_FONT = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic)

---------------------------------------------------------------- value helpers
local function cseq(v)
	if typeof(v) == "ColorSequence" then return v end
	if typeof(v) == "Color3" then return ColorSequence.new(v) end
	local k = {}
	for i, c in v do table.insert(k, ColorSequenceKeypoint.new(#v == 1 and 0 or (i - 1) / (#v - 1), c)) end
	if #v == 1 then table.insert(k, ColorSequenceKeypoint.new(1, v[1])) end
	return ColorSequence.new(k)
end
local function nseq(v)
	if typeof(v) == "NumberSequence" then return v end
	if type(v) == "number" then return NumberSequence.new(v) end
	local k = {}
	if type(v[1]) == "table" then
		for _, p in v do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2])) end
	else
		for i, n in v do table.insert(k, NumberSequenceKeypoint.new((i - 1) / (#v - 1), n)) end
	end
	return NumberSequence.new(k)
end
local function nrange(v)
	if type(v) == "number" then return NumberRange.new(v) end
	if type(v) == "table" then return NumberRange.new(v[1], v[2]) end
	return v
end
FX.cseq, FX.nseq, FX.nrange = cseq, nseq, nrange
local RANGE = {Lifetime = true, Speed = true, Rotation = true, RotSpeed = true}
local SEQ = {Size = true, Transparency = true, Squash = true}

local function tween(o, t, props, style, dir, delay)
	local x = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, 0, false, delay or 0), props)
	x:Play()
	return x
end
FX.Tween = tween
function FX.ease(x) x = math.clamp(x, 0, 1) return 1 - (1 - x) ^ 3 end
function FX.back(x) x = math.clamp(x, 0, 1) local c = 1.9 return 1 + (c + 1) * (x - 1) ^ 3 + c * (x - 1) ^ 2 end

local rootFolder
local function folderRoot()
	if not rootFolder or not rootFolder.Parent then
		rootFolder = workspace:FindFirstChild("CelebrationFX") or Instance.new("Folder")
		rootFolder.Name = "CelebrationFX"
		rootFolder.Parent = workspace
	end
	return rootFolder
end

---------------------------------------------------------------- ctx
local Ctx = {}
Ctx.__index = Ctx
FX.Active = {} -- [char] = ctx

function Ctx:Elapsed() return os.clock() - self.T0 end
-- run fn(t, dt) every frame until it returns true or the celebration ends
function Ctx:Every(fn) table.insert(self.Fns, fn) end
-- run fn at t seconds after the start
function Ctx:At(t, fn)
	task.delay(math.max(0, t - self:Elapsed()), function()
		if self.Alive then
			local ok, err = pcall(fn)
			if not ok then warn("[CelebrationFX] " .. self.Def.Id .. ": " .. tostring(err)) end
		end
	end)
end
-- every `period` seconds from t0 to t1, call fn(i)
function Ctx:Repeat(t0, t1, period, fn)
	local i = 0
	local t = t0
	while t < t1 do
		i += 1
		local n = i
		self:At(t, function() fn(n) end)
		t += period
	end
end
function Ctx:Part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Size = Vector3.one
	p.CFrame = self.Base
	if props then for k, v in props do p[k] = v end end
	p.Parent = self.Folder
	return p
end
-- Ring kinds: "Ring" (medium band), "RingThin", "RingFat", "Arc" (a crescent). Axis is local X; use FX.FLAT to lay it flat.
function Ctx:Ring(kind, d, thick, color, tr)
	local r = Assets[kind]:Clone()
	r.Size = Vector3.new(thick or .3, d, d)
	r.Color = color or FX.W
	r.Transparency = tr or 0
	r.CFrame = self.Base
	r.Parent = self.Folder
	return r
end
function Ctx.RingSize(d, thick) return Vector3.new(thick or .3, d, d) end
-- an attachment on the anchor (which follows the character's feet); cf may be a Vector3 or a CFrame
function Ctx:Att(cf, parent)
	local a = Instance.new("Attachment")
	if typeof(cf) == "Vector3" then a.Position = cf elseif cf then a.CFrame = cf end
	a.Parent = parent or self.Anchor
	return a
end
function Ctx:Emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Texture = T.Spark
	e.LightEmission, e.LightInfluence = 1, 0
	e.Rate = 0
	e.Lifetime = NumberRange.new(1)
	e.Speed = NumberRange.new(0)
	local bright = 2
	if props then
		for k, v in props do
			if k == "Brightness" then bright = v
			elseif RANGE[k] then e[k] = nrange(v)
			elseif SEQ[k] then e[k] = nseq(v)
			elseif k == "Color" then e.Color = cseq(v)
			elseif k == "SpreadAngle" and type(v) == "number" then e.SpreadAngle = Vector2.new(v, v)
			else e[k] = v end
		end
	end
	e.Rate *= self.Quality or 1
	pcall(function() e.Brightness = bright end)
	e.Parent = parent
	return e
end
-- a flat particle sticker lying on the attachment's plane (its up axis is the normal): spinning discs, ripples
function Ctx:Disc(att, props)
	props = props or {}
	local p = {Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top, Speed = .02, SpreadAngle = 0,
		LockedToPart = true, Rotation = {0, 360}}
	for k, v in props do p[k] = v end
	return self:Emitter(att, p)
end
function Ctx:Light(parent, color, range, bright, kind)
	local l = Instance.new(kind or "PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, range or 16, bright or 2, false
	l.Parent = parent
	return l
end
function Ctx:Beam(a0, a1, props)
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.LightEmission, b.LightInfluence = 1, 0
	b.FaceCamera = true
	b.Segments = 12
	local bright = 3
	for k, v in props or {} do
		if k == "Brightness" then bright = v
		elseif k == "Color" then b.Color = cseq(v)
		elseif k == "Transparency" then b.Transparency = nseq(v)
		else b[k] = v end
	end
	pcall(function() b.Brightness = bright end)
	b.Parent = self.Folder
	return b
end
-- a lightning bolt of n neon segments; returns set(p0, p1, jag) to re-strike it (flicker) and the parts
function Ctx:Bolt(n, width, color)
	local parts = {}
	for i = 1, n do parts[i] = self:Part({Size = Vector3.new(width, width, 1), Color = color}) end
	local function set(p0, p1, jag, tr)
		local pts = {p0}
		local dir = p1 - p0
		local len = dir.Magnitude
		if len < .01 then return end
		local cf = CFrame.lookAt(p0, p1)
		for i = 1, n - 1 do
			local k = i / n
			local off = (cf.RightVector * rng:NextNumber(-1, 1) + cf.UpVector * rng:NextNumber(-1, 1)) * (jag or len * .08) * math.sin(k * math.pi) ^ .5
			pts[i + 1] = p0 + dir * k + off
		end
		pts[n + 1] = p1
		for i = 1, n do
			local a, b = pts[i], pts[i + 1]
			local p = parts[i]
			p.Size = Vector3.new(p.Size.X, p.Size.Y, (b - a).Magnitude + p.Size.X * .6)
			p.CFrame = CFrame.lookAt((a + b) / 2, b)
			if tr then p.Transparency = tr end
		end
	end
	return set, parts
end
-- a glowing streak: an invisible part with a Trail flown along path(u) (u 0..1, world positions) over dur seconds
function Ctx:Streak(path, dur, color, width, life)
	local p = self:Part({Transparency = 1, Size = Vector3.one * .2, CFrame = CFrame.new(path(0))})
	local a0 = self:Att(Vector3.new(0, (width or .6) / 2, 0), p)
	local a1 = self:Att(Vector3.new(0, -(width or .6) / 2, 0), p)
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.LightEmission, tr.LightInfluence = 1, 0
	tr.FaceCamera = true
	tr.Lifetime = life or .35
	tr.Color = cseq(color)
	tr.Transparency = nseq({{0, 0}, {.6, .4}, {1, 1}})
	tr.WidthScale = nseq({{0, 1}, {1, 0}})
	pcall(function() tr.Brightness = 3 end)
	tr.Parent = p
	local t0 = os.clock()
	self:Every(function()
		if not p.Parent then return true end
		local u = (os.clock() - t0) / dur
		if u >= 1 then
			p.CFrame = CFrame.new(path(1))
			task.delay(tr.Lifetime + .05, function() p:Destroy() end)
			return true
		end
		local a, b = path(u), path(math.min(1, u + .02))
		p.CFrame = (b - a).Magnitude > .001 and CFrame.lookAt(a, b) or CFrame.new(a)
	end)
	return p
end
-- a four-point star flare that pops at a world position (or attachment)
function Ctx:Flare(where, size, color, life)
	local att = typeof(where) == "Instance" and where or self:Att(where - self.Base.Position)
	life = life or .35
	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	pcall(function() bb.Brightness = 4 end)
	bb.Size = UDim2.fromScale(size, size)
	bb.Adornee = att
	bb.Parent = self.Folder
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency, holder.Size, holder.AnchorPoint, holder.Position = 1, UDim2.fromScale(1, 1), Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
	holder.Parent = bb
	local sc = Instance.new("UIScale")
	sc.Scale = 0
	sc.Parent = holder
	local grad = nseq({{0, 1}, {.5, 0}, {1, 1}})
	for i = 0, 3 do
		local f = Instance.new("Frame")
		local long = i < 2
		f.BorderSizePixel = 0
		f.BackgroundColor3 = i % 2 == 0 and FX.W or color
		f.AnchorPoint, f.Position = Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
		f.Size = long and UDim2.fromScale(1, .045) or UDim2.fromScale(.55, .03)
		f.Rotation = (i == 1 or i == 3) and 90 or 0
		if i >= 2 then f.Rotation += 45 f.BackgroundColor3 = color end
		local g = Instance.new("UIGradient")
		g.Transparency = grad
		g.Parent = f
		f.Parent = holder
	end
	local glow = Instance.new("Frame")
	glow.BackgroundColor3 = color
	glow.BackgroundTransparency = .35
	glow.AnchorPoint, glow.Position, glow.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromScale(.16, .16)
	local gc = Instance.new("UICorner")
	gc.CornerRadius = UDim.new(.5, 0)
	gc.Parent = glow
	glow.Parent = holder
	tween(sc, life * .4, {Scale = 1}, Enum.EasingStyle.Back)
	tween(holder, life, {Rotation = rng:NextNumber(-40, 40)})
	task.delay(life * .45, function() if sc.Parent then tween(sc, life * .55, {Scale = 0}, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end end)
	task.delay(life + .05, function() bb:Destroy() if att.Parent == self.Anchor and typeof(where) ~= "Instance" then att:Destroy() end end)
	return bb
end
-- a burst of particles from a world position
function Ctx:Burst(pos, count, props)
	local a = self:Att(pos - self.Base.Position)
	local e = self:Emitter(a, props)
	e:Emit(math.max(1, math.floor(count * (self.Quality or 1))))
	local life = e.Lifetime.Max
	task.delay(life + .1, function() a:Destroy() end)
	return e
end
-- a ripple ring on the ground (or on any plane: cf is the plane, its up vector the normal), world space
function Ctx:Ripple(cf, d0, d1, color, life, tex)
	local holder = self:Part({Transparency = 1, Size = Vector3.one * .2, CFrame = cf})
	local a = self:Att(nil, holder)
	local e = self:Disc(a, {Texture = tex or T.Shock, Color = color, Size = {d0, d1}, Transparency = {{0, .05}, {.6, .35}, {1, 1}},
		Lifetime = life or .9, Brightness = 3, LockedToPart = true, Rotation = {0, 360}})
	e:Emit(1)
	task.delay((life or .9) + .1, function() holder:Destroy() end)
	return e
end

---------------------------------------------------------------- screen-side (own character only)
local screenGui
local function screen()
	if screenGui and screenGui.Parent then return screenGui end
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CelebrationScreen"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 35
	screenGui.Parent = pg
	return screenGui
end
local lastFlash = 0
-- a soft full-screen flash (throttled to ~3 a second; never fully opaque)
function Ctx:Flash(color, alpha, dur)
	if not self.Local then return end
	local now = os.clock()
	if now - lastFlash < .3 then return end
	lastFlash = now
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color or FX.W
	f.BackgroundTransparency = 1 - math.min(alpha or .5, .7)
	f.ZIndex = 5
	f.Parent = screen()
	tween(f, dur or .35, {BackgroundTransparency = 1})
	task.delay((dur or .35) + .05, function() f:Destroy() end)
end
-- the manga impact frame: two frames, white with ink spikes then ink with white spikes, aimed at the character
function Ctx:ImpactFrame()
	if not self.Local then return end
	lastFlash = os.clock()
	local cam = workspace.CurrentCamera
	local vp = cam.ViewportSize
	local sp = self.Hrp and cam:WorldToViewportPoint(self.Hrp.Position) or Vector3.new(vp.X / 2, vp.Y / 2, 0)
	local function frame(bg, fg)
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = bg
		f.ZIndex = 8
		f.Parent = screen()
		local len = vp.Magnitude
		for i = 1, 22 do
			local s = Instance.new("Frame")
			s.BorderSizePixel = 0
			s.BackgroundColor3 = fg
			s.AnchorPoint = Vector2.new(0, .5)
			s.Position = UDim2.fromOffset(sp.X, sp.Y)
			s.Size = UDim2.fromOffset(len, rng:NextNumber(6, 30))
			s.Rotation = i * (360 / 22) + rng:NextNumber(-6, 6)
			s.ZIndex = 9
			local g = Instance.new("UIGradient")
			g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(rng:NextNumber(.05, .2), 1), NumberSequenceKeypoint.new(.35, 0), NumberSequenceKeypoint.new(1, 0)})
			g.Parent = s
			s.Parent = f
		end
		return f
	end
	local a = frame(FX.W, Color3.fromRGB(12, 10, 18))
	task.delay(.06, function()
		a:Destroy()
		local b = frame(Color3.fromRGB(12, 10, 18), FX.W)
		task.delay(.05, function() b:Destroy() end)
	end)
end
-- tint the whole picture for a moment (a local ColorCorrection of our own, faded back out)
function Ctx:Grade(props, tIn, hold, tOut)
	if not self.Local then return end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "CelebrationGrade"
	cc.Parent = Lighting
	table.insert(self.Grades, cc)
	tween(cc, tIn or .2, props)
	task.delay((tIn or .2) + (hold or .3), function()
		if not cc.Parent then return end
		tween(cc, tOut or .5, {Brightness = 0, Contrast = 0, Saturation = 0, TintColor = FX.W})
		task.delay((tOut or .5) + .05, function() cc:Destroy() end)
	end)
	return cc
end
-- camera shake (amp in studs, decays over dur)
function Ctx:Shake(amp, dur)
	if not self.Local or not self.Hum then return end
	local t0 = os.clock()
	self.ShakeUntil = math.max(self.ShakeUntil or 0, t0 + dur)
	self:Every(function()
		local u = (os.clock() - t0) / dur
		if u >= 1 then return true end
		local k = amp * (1 - u) ^ 2
		self.ShakeOffset += Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * k
	end)
end

---------------------------------------------------------------- title card
-- The celebration name in a glowing serif above the character; no artificial odds.
function Ctx:Title(at, height)
	local def = self.Def
	self:At(at or .4, function()
		local a = self:Att(Vector3.new(0, height or 8.6, 0))
		local bb = Instance.new("BillboardGui")
		bb.Name = "Title"
		bb.AlwaysOnTop = false -- (AlwaysOnTop billboards on your own character don't draw in this place)
		bb.LightInfluence = 0
		pcall(function() bb.Brightness = 2.5 end)
		bb.Size = UDim2.fromScale(12, 2)
		bb.MaxDistance = Cat.ViewRange
		bb.Adornee = a
		bb.Parent = self.Folder
		local sc = Instance.new("UIScale")
		sc.Scale = .3
		sc.Parent = bb
		local function label(text, y, h, color, stroke)
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Size = UDim2.fromScale(1, h)
			l.Position = UDim2.fromScale(0, y)
			l.FontFace = TITLE_FONT
			l.Text = text
			l.TextScaled = true
			l.TextColor3 = FX.W
			l.TextTransparency = 1
			l.Parent = bb
			local s = Instance.new("UIStroke")
			s.Color = stroke
			s.Thickness = 2.5
			s.Transparency = 1
			s.Parent = l
			local g = Instance.new("UIGradient")
			g.Color = cseq(color)
			g.Rotation = 90
			g.Parent = l
			tween(l, .35, {TextTransparency = 0})
			tween(s, .35, {Transparency = .1})
			return l, g, s
		end
		local c = def.Colors
		local dark = c[3]:Lerp(Color3.new(), .55)
		local name, g = label(string.upper(def.Name), 0, 1, def.Id == "PrismSupernova" and FX.Rainbow or {FX.W, c[1], c[2], c[3]}, dark)
		tween(sc, .5, {Scale = 1}, Enum.EasingStyle.Back)
		local t0 = os.clock()
		self:Every(function()
			if not bb.Parent then return true end
			local t = os.clock() - t0
			g.Rotation = 90 + math.sin(t * 2.2) * 25
			g.Offset = Vector2.new(0, math.sin(t * 3) * .15)
			a.Position = Vector3.new(0, (height or 8.6) + math.sin(t * 1.6) * .25, 0)
		end)
		self.TitleGui = bb
	end)
end

---------------------------------------------------------------- lifecycle
-- the builders are loaded on first use (they require this module, so not while it is loading)
local Builders
local function builders()
	if Builders then return Builders end
	Builders = {}
	for _, name in {"Free", "Premium", "Spectacle", "Tiers"} do
		local m = script:WaitForChild(name, 10)
		if m then
			local ok, t = pcall(require, m)
			if ok and type(t) == "table" then
				for id, fn in t do if Cat.ById[id] then Builders[id] = fn end end
				FX[name] = t
			else
				warn("[CelebrationFX] " .. name .. ": " .. tostring(t))
			end
		end
	end
	return Builders
end

-- the aura shows (Oct 6 2026): CelebrationFX.Shows[id] = {Set1, Set2, Set3, Pre}. When a celebration has one, it
-- replaces the old builder AND the stacked layers (Spectacle.Augment, Tiers.Overdrive, AuraAccents) so the show
-- stays readable: one hero element at a time, the player visible. Ids without a show keep the old path.
local ShowTable
local function shows()
	if ShowTable == nil then
		local m = script:FindFirstChild("Shows")
		if m then
			local ok, t = pcall(require, m)
			ShowTable = ok and type(t) == "table" and t or false
			if not ok then warn("[CelebrationFX] Shows: " .. tostring(t)) end
		else
			ShowTable = false
		end
	end
	return ShowTable or nil
end
FX.Shows = shows

-- the effects' ground level: a little above the feet so ground rings float over the tall grass
local GROUND_LIFT = .8
local function feet(hrp, hum)
	local h = hum and hum.HipHeight or 2
	return hrp.Position - Vector3.new(0, h + hrp.Size.Y / 2 - GROUND_LIFT, 0)
end

function Ctx:Stop(fast)
	if not self.Alive then return end
	self.Alive = false
	if self.ReleaseAvatar then self.ReleaseAvatar() end
	self.Fns = {} -- freeze the animation while everything fades
	if self.Hum and self.Local then self.Hum.CameraOffset = Vector3.zero end
	if FX.Active[self.Char] == self then FX.Active[self.Char] = nil end
	local fade = fast and .25 or .7
	for _, d in self.Folder:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			if d:IsA("ParticleEmitter") then d.Rate = 0 else tween(d, fade, {}) d.Enabled = false end
		elseif d:IsA("BasePart") then
			if d.Transparency < 1 then tween(d, fade, {Transparency = 1}) end
		elseif d:IsA("Light") then tween(d, fade, {Brightness = 0})
		elseif d:IsA("Highlight") then tween(d, fade, {FillTransparency = 1, OutlineTransparency = 1})
		elseif d:IsA("TextLabel") then tween(d, fade, {TextTransparency = 1})
		elseif d:IsA("UIStroke") then tween(d, fade, {Transparency = 1})
		elseif d:IsA("Frame") then tween(d, fade, {BackgroundTransparency = 1}) end
	end
	for _, cc in self.Grades do
		if cc.Parent then tween(cc, .4, {Brightness = 0, Contrast = 0, Saturation = 0, TintColor = FX.W}) task.delay(.45, function() cc:Destroy() end) end
	end
	task.delay(fade + 1.6, function()
		if self.Conn then self.Conn:Disconnect() end
		if self.Hum and self.Local then self.Hum.CameraOffset = Vector3.zero end
		for _, f in self.Cleanups do pcall(f) end
		self.Folder:Destroy()
	end)
end
function Ctx:OnCleanup(fn) table.insert(self.Cleanups, fn) end

-- play celebration `id` round `char`; returns the ctx (or nil)
function FX.Play(char, id, opts)
	opts = opts or {}
	local def = Cat.ById[id]
	local build = builders()[id]
	local set = math.clamp(math.floor(tonumber(opts.Set) or 3), 1, 3)
	local showList = shows()
	local show = showList and showList[id]
	local pre
	if show then
		build = show["Set" .. set] or show.Set3 or show.Set2 or show.Set1
		pre = (set == 3 and (show.Pre or 1)) or (set == 2 and (show.Pre2 or 0)) or 0
	else
		if set < 3 then
			local small = FX.Tiers and FX.Tiers["Set" .. set] and FX.Tiers["Set" .. set][id]
			if small then build = small else set = 3 end
		end
		pre = (set == 3 and FX.Tiers and id ~= "PrismSupernova") and FX.Tiers.Pre or 0
	end
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not def or not build or not hrp then return nil end
	local distance = 0
	local localChar = Players.LocalPlayer and Players.LocalPlayer.Character
	local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
	if opts.Local ~= true and localRoot then
		distance = (localRoot.Position - hrp.Position).Magnitude
		if distance > Cat.ViewRange then return nil end
		local remoteCount, oldest = 0, nil
		for _, active in FX.Active do
			if active.Alive and not active.Local and active.Char ~= char then
				remoteCount += 1
				if not oldest or active.T0 < oldest.T0 then oldest = active end
			end
		end
		if remoteCount >= 3 and oldest then oldest:Stop(true) end
	end
	local old = FX.Active[char]
	if old then old:Stop(true) end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local folder = Instance.new("Folder")
	folder.Name = id
	folder.Parent = folderRoot()
	local base = CFrame.new(feet(hrp, hum))
	local self = setmetatable({Char = char, Hrp = hrp, Hum = hum, Def = def, Folder = folder, Local = opts.Local == true,
		T0 = os.clock() + pre, Quality = opts.Local == true and 1 or (distance < 120 and .7 or .4), Fns = {}, Alive = true, Grades = {}, Cleanups = {}, Base = base, ShakeOffset = Vector3.zero, Tier = opts.Tier or 4,
		Set = set, Pre = pre, Show = show ~= nil}, Ctx)
	self.Anchor = self:Part({Name = "Anchor", Transparency = 1, Size = Vector3.one * .2, CFrame = base})
	FX.Active[char] = self
	-- (Heartbeat when the game isn't running, so the effects can be previewed in edit mode)
	self.Conn = (RunService:IsRunning() and RunService.RenderStepped or RunService.Heartbeat):Connect(function(dt)
		if not hrp.Parent then self:Stop(true) return end
		if self.Alive then
			self.Base = CFrame.new(feet(hrp, hum))
			self.Anchor.CFrame = self.Base
		end
		self.ShakeOffset = Vector3.zero
		local t = os.clock() - self.T0
		local i = 1
		while i <= #self.Fns do
			local ok, done = pcall(self.Fns[i], t, dt)
			if not ok then warn("[CelebrationFX] " .. id .. ": " .. tostring(done)) done = true end
			if done then table.remove(self.Fns, i) else i += 1 end
		end
		if self.Local and hum and self.Alive then hum.CameraOffset = self.ShakeOffset end
	end)
	local ok, len = pcall(build, self, def)
	if not ok then
		warn("[CelebrationFX] " .. id .. ": " .. tostring(len))
		len = 1
	end
	self.Length = len or 6
	self.Duration = self.Length + pre
	if ok and show then
		-- the aura shows carry their own hits, camera and title; nothing is stacked on them
	elseif ok and set == 3 and FX.Spectacle and FX.Spectacle.Augment then
		local enhanced, err = pcall(FX.Spectacle.Augment, self, def, self.Length)
		if not enhanced then warn("[CelebrationFX] enhancement " .. id .. ": " .. tostring(err)) end
	end
	if ok and not show and set == 3 and FX.Tiers and FX.Tiers.Overdrive then
		local over, err = pcall(FX.Tiers.Overdrive, self, def, self.Length)
		if not over then warn("[CelebrationFX] overdrive " .. id .. ": " .. tostring(err)) end
	end
	if ok and not show and set >= 2 and opts.Enhancements ~= false then
		local additive, err = pcall(function() require(script.AuraAccents).Append(self, def, self.Length) end)
		if not additive then warn("[CelebrationFX] aura accents: " .. tostring(err)) end
	end
	-- your own unlockable celebrations dim and punch up the picture a little so the glow reads in daylight
	if self.Local and def.Kind == "Unlock" and set >= 2 then
		self:Grade({Brightness = -.07, Contrast = .18, Saturation = .12}, .3, math.max(.5, self.Duration - 1.3), .8)
	end
	self:At(self.Length, function() self:Stop() end)
	return self
end

return FX

