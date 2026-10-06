-- CelebrationFX.AuraKit: the shared "aura" toolkit every celebration show is composed from (Oct 6 2026).
-- Everything here is client-side, lives in the celebration's ctx.Folder and dies with ctx:Stop().
-- The grammar (from the reference clips): one hot white core, a coloured middle, a dark rim; things that LEAVE the
-- frame; two acts with a silhouette change; authored shapes (meshes, painted alpha textures) instead of spheres;
-- rings stacked at the floor, the chest and the sky.
--
-- Shows get the toolkit with  local K = require(script.Parent.Parent.AuraKit)  and call K.<thing>(ctx, opts).
-- Counts scale with ctx.Quality (1 for your own show, .7 / .4 for other players' by distance) and K.Mobile.
-- Anything that touches the camera, Lighting, or the world's time only runs when ctx.Local (your own show).
--
-- Meshes: K.Mesh(ctx, "WingUpper") clones VFX2_WingUpper from ReplicatedStorage.FarmLasso.CelebrationFX.AuraMeshes
-- (the Aura_Pack.glb import), or VFX_<name> from the v1 folder, or falls back to a Neon Part so a missing import
-- never errors. K.Place(part, cf, scale) sizes it and puts its authored origin at cf (Roblox centres imported meshes
-- on their bounding box; AuraMeshData holds each mesh's bounding-box centre so the pivot comes back).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local FX = require(script.Parent)
local okData, Data = pcall(require, script.Parent:FindFirstChild("AuraMeshData") or script)
if not okData or type(Data) ~= "table" or not Data.Pivots then Data = {Pivots = {}, Textures = {}} end
local okTex, Tex = pcall(require, script.Parent:FindFirstChild("AuraTextures") or script)
if not okTex or type(Tex) ~= "table" then Tex = {} end

local T, W, FLAT, rng = FX.T, FX.W, FX.FLAT, FX.rng
local V3 = Vector3.new
local TAU = math.pi * 2
local K = {}
K.Mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
K.W = W
K.FLAT = FLAT
K.TAU = TAU

---------------------------------------------------------------- textures (painted pack with engine fallbacks)
-- AuraTextures.lua maps names to rbxassetid:// strings once the PNGs in textures/ are uploaded; until then the
-- engine textures stand in, so nothing here depends on an upload.
local FALLBACK = {
	Glow = T.Glow, Ring = T.Shock, Flame = T.Fire, Streak = T.Spark, Star = T.Spark, Petal = T.Spark,
	Lightning = T.Spark, Smoke = T.Smoke, Arc = T.Spark, Crack = T.Shock, Sigil = T.Vortex, Nebula = T.Vortex,
}
K.Tex = setmetatable({}, {__index = function(_, name)
	local id = Tex[name]
	if type(id) == "string" and id ~= "" and id ~= "0" then return id end
	return FALLBACK[name] or T.Spark
end})
-- flipbook settings when the painted sheet is in, nothing when the engine fallback is in
function K.Flipbook(e, name, mode, fps)
	local id = Tex[name]
	if type(id) ~= "string" or id == "" or id == "0" then return end
	pcall(function()
		e.FlipbookLayout = name == "Smoke" and Enum.ParticleFlipbookLayout.Grid8x8 or Enum.ParticleFlipbookLayout.Grid4x4
		e.FlipbookMode = mode or Enum.ParticleFlipbookMode.Loop
		e.FlipbookFramerate = NumberRange.new(fps or 24, (fps or 24) + 6)
		e.FlipbookStartRandom = true
	end)
end

---------------------------------------------------------------- maths
function K.Ease(x) return FX.ease(x) end
function K.Back(x) return FX.back(x) end
function K.Lerp(a, b, k) return a + (b - a) * k end
-- grows in from a (back ease) and fades out ending at b
function K.Env(t, a, b, rise, fall)
	rise, fall = rise or .4, fall or .45
	return FX.back((t - a) / rise) * (1 - FX.ease((t - b + fall) / fall))
end
function K.Soft(t, a, b, rise, fall)
	rise, fall = rise or .4, fall or .45
	return FX.ease((t - a) / rise) * (1 - FX.ease((t - b + fall) / fall))
end
-- a snap-down / ease-up flap curve: 0 at the top of the stroke, 1 at the bottom; period seconds
function K.Flap(t, period)
	local u = (t / period) % 1
	local down = .4 -- share of the period spent on the downstroke (the snap)
	if u < down then return FX.ease(u / down) ^ .7 end
	local v = (u - down) / (1 - down)
	return 1 - (1 - math.cos(v * math.pi)) / 2
end
function K.Polar(a, r, y) return V3(math.cos(a) * r, y or 0, math.sin(a) * r) end
function K.RandUnit()
	local v = V3(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	return v.Magnitude > .05 and v.Unit or Vector3.yAxis
end
function K.Bezier(p0, p1, p2, u)
	local v = 1 - u
	return p0 * (v * v) + p1 * (2 * v * u) + p2 * (u * u)
end
-- flat direction pointing away from this viewer's camera (sky pieces hang behind the player, out of the way)
function K.Behind(ctx)
	local cam = workspace.CurrentCamera
	local look = cam and cam.CFrame.LookVector or V3(0, 0, -1)
	local b = V3(look.X, 0, look.Z)
	return b.Magnitude > .05 and b.Unit or V3(0, 0, -1)
end
function K.Count(ctx, n) return math.max(1, math.floor(n * (ctx.Quality or 1) * (K.Mobile and .55 or 1) + .5)) end
function K.Palette(def)
	local c1, c2, c3 = def.Colors[1], def.Colors[2], def.Colors[3]
	return c1, c2, c3, c3:Lerp(Color3.new(), .6)
end

---------------------------------------------------------------- world queries
local effectFolders = {"CelebrationFX", "PartyFX", "FarmLassoVisuals", "FarmLassoLeashes", "_LassoFX"}
local function excludeList(ctx, keepVisuals)
	local list = {ctx.Char, ctx.Folder}
	for _, n in effectFolders do
		if keepVisuals and (n == "FarmLassoVisuals" or n == "FarmLassoLeashes") then continue end
		local f = workspace:FindFirstChild(n)
		if f then table.insert(list, f) end
	end
	for _, pl in Players:GetPlayers() do if pl.Character then table.insert(list, pl.Character) end end
	return list
end
-- the ground under pos: position, normal (raycast down, ignoring characters and effects)
function K.Ground(ctx, pos, up)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList(ctx)
	local hit = workspace:Raycast(pos + V3(0, up or 6, 0), V3(0, -(up or 6) - 12, 0), params)
	if hit then return hit.Position, hit.Normal, hit.Instance end
	return V3(pos.X, ctx.Base.Position.Y - .8, pos.Z), Vector3.yAxis, nil
end
-- a CFrame lying on the ground at pos (its UpVector is the ground normal), lifted a little
function K.GroundCF(ctx, pos, lift)
	local p, n = K.Ground(ctx, pos)
	local right = n:Cross(V3(0, 0, 1))
	if right.Magnitude < .05 then right = n:Cross(V3(1, 0, 0)) end
	right = right.Unit
	local fwd = right:Cross(n).Unit
	return CFrame.fromMatrix(p + n * (lift or .08), right, n, -fwd)
end
-- other players (not the celebrant) with a character within radius, nearest first
function K.NearbyPlayers(ctx, radius)
	local out = {}
	local me = Players:GetPlayerFromCharacter(ctx.Char)
	for _, pl in Players:GetPlayers() do
		if pl == me then continue end
		local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
		if hrp and (hrp.Position - ctx.Base.Position).Magnitude <= (radius or 40) then
			table.insert(out, {Part = hrp, Model = pl.Character, Kind = "player", Dist = (hrp.Position - ctx.Base.Position).Magnitude})
		end
	end
	table.sort(out, function(a, b) return a.Dist < b.Dist end)
	return out
end
-- herd animals (any Model with a HumanoidRootPart or PrimaryPart under the game's visuals folders, or any Model
-- with a Species / AnimalId attribute) within radius, nearest first. Other characters are excluded.
function K.NearbyAnimals(ctx, radius)
	local out, seen = {}, {}
	local centre = ctx.Base.Position
	local function consider(m)
		if seen[m] or m == ctx.Char or Players:GetPlayerFromCharacter(m) then return end
		local root = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Root") or m:FindFirstChildWhichIsA("BasePart")
		if not root then return end
		local d = (root.Position - centre).Magnitude
		if d > (radius or 30) then return end
		seen[m] = true
		table.insert(out, {Part = root, Model = m, Kind = "animal", Dist = d})
	end
	for _, n in {"FarmLassoVisuals", "FarmLassoLeashes", "FarmLassoAnimals", "Herds"} do
		local f = workspace:FindFirstChild(n)
		if f then
			for _, m in f:GetDescendants() do
				if m:IsA("Model") and (m:GetAttribute("Species") or m:GetAttribute("AnimalId") or m:GetAttribute("FootOffset") or m:FindFirstChildOfClass("Humanoid")) then consider(m) end
			end
		end
	end
	if #out == 0 then
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {ctx.Folder, workspace:FindFirstChild("CelebrationFX") or ctx.Folder}
		local ok, parts = pcall(workspace.GetPartBoundsInRadius, workspace, centre, radius or 30, params)
		if ok then
			for _, p in parts do
				local m = p:FindFirstAncestorOfClass("Model")
				if m and (m:GetAttribute("Species") or m:GetAttribute("AnimalId") or m:GetAttribute("FootOffset")) then consider(m) end
			end
		end
	end
	table.sort(out, function(a, b) return a.Dist < b.Dist end)
	return out
end
-- seek targets in priority order: other players, then animals, then free orbit points round the celebrant
function K.Targets(ctx, count, radius)
	local list = {}
	for _, t in K.NearbyPlayers(ctx, radius or 40) do table.insert(list, t) end
	for _, t in K.NearbyAnimals(ctx, (radius or 40) * .75) do table.insert(list, t) end
	local i = 0
	while #list < count do
		i += 1
		local a = i / count * TAU + rng:NextNumber(0, .6)
		local r = rng:NextNumber(9, 16)
		table.insert(list, {Pos = ctx.Base.Position + K.Polar(a, r, rng:NextNumber(2, 7)), Kind = "point"})
	end
	return list
end
local function targetPos(tg, y)
	if tg.Part and tg.Part.Parent then return tg.Part.Position + V3(0, y or 0, 0) end
	return tg.Pos or Vector3.zero
end
K.TargetPos = targetPos
-- anchored world parts within radius that read as "props": fence posts, lanterns, fountain pieces (tall, thin, not
-- terrain-sized). Used by chain lightning, light painting and shockwave flashes. Limited to n.
function K.NearbyProps(ctx, radius, n)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList(ctx)
	local ok, parts = pcall(workspace.GetPartBoundsInRadius, workspace, ctx.Base.Position + V3(0, 3, 0), radius or 15, params)
	if not ok then return {} end
	local out = {}
	for _, p in parts do
		if not p.Anchored or p.Transparency > .6 or p:IsA("Terrain") then continue end
		local s = p.Size
		local big = math.max(s.X, s.Y, s.Z)
		if big > 14 or big < .8 or s.X * s.Y * s.Z > 220 then continue end
		table.insert(out, p)
		if #out >= (n or 12) then break end
	end
	table.sort(out, function(a, b) return (a.Position - ctx.Base.Position).Magnitude < (b.Position - ctx.Base.Position).Magnitude end)
	return out
end

---------------------------------------------------------------- meshes
local function meshFolders()
	local root = ReplicatedStorage:FindFirstChild("FarmLasso")
	local fx = root and root:FindFirstChild("CelebrationFX")
	local v2 = fx and fx:FindFirstChild("AuraMeshes") or (root and root:FindFirstChild("AuraMeshes"))
	local prev = root and root:FindFirstChild("ClaudeCelebrationPreview")
	local v1 = (prev and prev:FindFirstChild("VFXMeshes")) or (root and root:FindFirstChild("VFXMeshes"))
	return v2, v1
end
local warned = {}
function K.HasMesh(name)
	local v2, v1 = meshFolders()
	return (v2 and (v2:FindFirstChild("VFX2_" .. name) or v2:FindFirstChild("VFX_" .. name))) ~= nil or (v1 and v1:FindFirstChild("VFX_" .. name)) ~= nil
end
-- a Neon mesh clone (or a stand-in Part) parented to the celebration folder. props are applied after setup.
function K.Mesh(ctx, name, props)
	local v2, v1 = meshFolders()
	local tpl = (v2 and (v2:FindFirstChild("VFX2_" .. name) or v2:FindFirstChild("VFX_" .. name) or v2:FindFirstChild(name)))
		or (v1 and (v1:FindFirstChild("VFX_" .. name) or v1:FindFirstChild("VFX2_" .. name)))
	local p
	if tpl and tpl:IsA("BasePart") then
		p = tpl:Clone()
		for _, d in p:GetChildren() do if not d:IsA("SurfaceAppearance") then d:Destroy() end end
	else
		if not warned[name] then warned[name] = true warn("[AuraKit] mesh VFX2_" .. name .. " not imported; using a Part") end
		p = Instance.new("Part")
		local fb = Data.Fallback and Data.Fallback[name]
		p.Size = fb and V3(fb[1], fb[2], fb[3]) or V3(1, 1, 1)
	end
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = W
	p.Transparency = 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p:SetAttribute("BaseSize", p.Size)
	p.CFrame = ctx.Base * CFrame.new(0, -50, 0)
	if props then for k, v in props do p[k] = v end end
	p.Parent = ctx.Folder
	return p
end
-- size the mesh by scale (number or Vector3) and put its authored origin at cf
function K.Place(p, cf, scale)
	local base = p:GetAttribute("BaseSize") or p.Size
	local s = typeof(scale) == "number" and Vector3.one * scale or (scale or Vector3.one)
	p.Size = V3(math.max(.01, base.X * s.X), math.max(.01, base.Y * s.Y), math.max(.01, base.Z * s.Z))
	local off = Data.Pivots[p.Name]
	if off then
		p.CFrame = cf * CFrame.new(off.X * s.X, off.Y * s.Y, off.Z * s.Z)
	else
		p.CFrame = cf
	end
end
-- a thin-lipped ring from the old CelebrationAssets unions (always available)
function K.Ring(ctx, kind, d, thick, color, tr) return ctx:Ring(kind or "RingThin", d or .1, thick or .3, color or W, tr or 0) end
function K.SetRing(r, d) r.Size = V3(r.Size.X, math.max(.1, d), math.max(.1, d)) end

---------------------------------------------------------------- lights and hits
function K.Light(ctx, where, color, range, bright)
	local att = typeof(where) == "Instance" and where or ctx:Att(where)
	return ctx:Light(att, color, range, bright)
end
-- FOV punch on your own camera (dt in, back out)
function K.FOV(ctx, delta, tIn, tOut, hold)
	if not ctx.Local then return end
	local cam = workspace.CurrentCamera
	if not cam then return end
	local base = cam.FieldOfView
	TweenService:Create(cam, TweenInfo.new(tIn or .08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = math.clamp(base + delta, 40, 110)}):Play()
	task.delay((tIn or .08) + (hold or 0), function()
		if cam.Parent then TweenService:Create(cam, TweenInfo.new(tOut or .4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {FieldOfView = base}):Play() end
	end)
end
-- the combined hard hit: flash, shake, impact frame, FOV punch, a shock ring and a radial starburst
function K.Hit(ctx, pos, o)
	o = o or {}
	local c1, c2 = o.Colors and o.Colors[1] or W, o.Colors and o.Colors[2] or W
	if o.Impact then ctx:ImpactFrame() else ctx:Flash(c1, o.Flash or .4, .35) end
	ctx:Shake(o.Shake or .4, .45)
	K.FOV(ctx, o.FOV or 10, .07, .45)
	ctx:Ripple(K.GroundCF(ctx, pos, .2), 2, o.Ring or 30, {W, c2}, .6, K.Tex.Ring)
	K.Starburst(ctx, pos, {Colors = {c1, c2}, Size = o.Burst or 16, Count = o.Lines or 36})
end
-- the anime starburst: radial streak lines flying out, a ring, a white core flash, all gone in a third of a second
function K.Starburst(ctx, pos, o)
	o = o or {}
	local c1, c2 = o.Colors and o.Colors[1] or W, o.Colors and o.Colors[2] or W
	local att = ctx:Att(pos - ctx.Base.Position)
	local size = o.Size or 14
	local lines = ctx:Emitter(att, {Texture = K.Tex.Streak, Color = {W, c2}, Size = {{0, size * .25}, {.4, size}, {1, size * .6}}, Transparency = {{0, 1}, {.06, 0}, {.6, .1}, {1, 1}},
		Lifetime = {.16, .3}, Speed = {size * 6, size * 10}, SpreadAngle = Vector2.new(180, 180), Orientation = Enum.ParticleOrientation.VelocityParallel,
		Squash = {{0, .6}, {1, .9}}, Brightness = 6, Drag = 6})
	lines:Emit(K.Count(ctx, o.Count or 36))
	local core = ctx:Emitter(att, {Texture = K.Tex.Glow, Color = {W, c1}, Size = {{0, size * .2}, {.25, size * 1.3}, {1, 0}}, Transparency = {{0, 0}, {.5, .2}, {1, 1}},
		Lifetime = .26, LockedToPart = true, Brightness = 8})
	core:Emit(1)
	local ring = ctx:Emitter(att, {Texture = K.Tex.Ring, Color = {W, c2}, Size = {{0, 1}, {1, size * 2.4}}, Transparency = {{0, 0}, {.7, .3}, {1, 1}},
		Lifetime = .3, LockedToPart = true, Brightness = 4, Rotation = {0, 360}})
	ring:Emit(1)
	task.delay(.6, function() att:Destroy() end)
	local l = ctx:Light(att, c1, size * 2.5, 8)
	FX.Tween(l, .3, {Brightness = 0})
end
-- a flat petal fan that pops open in two frames with overshoot (the ref9 petal burst). cf's UpVector is the fan
-- normal. Uses the 16-petal mesh when imported, else 16 single petal stand-ins.
function K.PetalFan(ctx, cf, o)
	o = o or {}
	local c1, c2, c3 = o.Colors and o.Colors[1] or W, o.Colors and o.Colors[2] or W, o.Colors and o.Colors[3] or W
	local radius, life = o.Radius or 9, o.Life or .55
	local fan = K.Mesh(ctx, "FlamePetalFan", {Color = c1})
	local petals = {}
	if fan:IsA("MeshPart") then
		petals[1] = {fan, 0}
	else
		fan:Destroy()
		local n = o.Petals or 16
		for i = 1, n do
			local p = K.Mesh(ctx, "FlamePetal", {Color = i % 2 == 0 and c1 or c2})
			if not p:IsA("MeshPart") then p.Size = V3(1.1, .06, 4.5) p:SetAttribute("BaseSize", p.Size) Data.Pivots.FlamePetal = Data.Pivots.FlamePetal or V3(0, 0, -2.25) end
			petals[i] = {p, (i - 1) / n * TAU}
		end
	end
	local glow = ctx:Att(cf.Position - ctx.Base.Position)
	ctx:Emitter(glow, {Texture = K.Tex.Glow, Color = {W, c2, c3}, Size = {{0, radius * .4}, {.3, radius * 2.2}, {1, radius * 1.4}}, Transparency = {{0, 0}, {.4, .35}, {1, 1}},
		Lifetime = life, LockedToPart = true, Brightness = 5}):Emit(1)
	local t0 = os.clock()
	ctx:Every(function()
		local u = (os.clock() - t0) / life
		if u >= 1 then for _, e in petals do e[1]:Destroy() end glow:Destroy() return true end
		local k = FX.back(u / .12) -- open in two frames with 12 % overshoot
		local fade = u > .55 and (1 - FX.ease((u - .55) / .45)) or 1
		local s = (radius / 4.5) * k
		for _, e in petals do
			local p, a = e[1], e[2]
			K.Place(p, cf * CFrame.Angles(0, a, 0), #petals == 1 and s or V3(s * .5, 1, s))
			p.Transparency = 1 - fade
			p.Color = c1:Lerp(c3, math.clamp((u - .2) / .6, 0, 1))
		end
	end)
end
-- an expanding shock ring mesh on a plane; cf's UpVector is the normal
function K.ShockRing(ctx, cf, d0, d1, color, life, thick)
	local r = ctx:Ring("RingThin", d0, thick or .4, color, 0)
	r.CFrame = cf * FLAT
	local t0 = os.clock()
	ctx:Every(function()
		if not r.Parent then return true end
		local u = (os.clock() - t0) / life
		if u >= 1 then r:Destroy() return true end
		local e = FX.ease(u)
		K.SetRing(r, d0 + (d1 - d0) * e)
		r.Size = V3((thick or .4) * (1 - u * .7), r.Size.Y, r.Size.Z)
		r.Transparency = u ^ 1.5
		r.CFrame = cf * FLAT
	end)
	return r
end

---------------------------------------------------------------- the performer (a client-side double of the character)
-- The real character keeps its physics, camera and gameplay; it is hidden locally and this double does the acting:
-- poses on Motor6D C0, flight paths, explosions. Works for your own character and for other players' (reduced shows).
local R15 = {Neck = "Head", Waist = "UpperTorso", RightShoulder = "RightUpperArm", LeftShoulder = "LeftUpperArm", RightElbow = "RightLowerArm",
	LeftElbow = "LeftLowerArm", RightHip = "RightUpperLeg", LeftHip = "LeftUpperLeg", RightKnee = "RightLowerLeg", LeftKnee = "LeftLowerLeg", Root = "LowerTorso"}
function K.Performer(ctx, o)
	o = o or {}
	if ctx.Performer and ctx.Performer.Alive then return ctx.Performer end
	local char = ctx.Char
	local old = char.Archivable
	char.Archivable = true
	local ok, ghost = pcall(function() return char:Clone() end)
	char.Archivable = old
	if not ok or not ghost then return nil end
	ghost.Name = "AuraPerformer"
	for _, v in ghost:GetDescendants() do
		if v:IsA("LuaSourceContainer") or v:IsA("Sound") or v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("BillboardGui")
			or v:IsA("Tool") or v:IsA("Highlight") or v:IsA("ForceField") or v:IsA("BodyMover") then v:Destroy()
		elseif v:IsA("BasePart") then
			v.CanCollide, v.CanTouch, v.CanQuery, v.CastShadow = false, false, false, false
			v.Anchored = v.Name == "HumanoidRootPart"
		end
	end
	local root = ghost:FindFirstChild("HumanoidRootPart")
	if not root then ghost:Destroy() return nil end
	local hum = ghost:FindFirstChildOfClass("Humanoid")
	if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None hum.AutoRotate = false hum.PlatformStand = true end
	local P = {Model = ghost, Root = root, Alive = true, Joints = {}, Base = {}, Parts = {}, Look = {}, Shown = false, Hidden = {}, Ctx = ctx}
	for _, v in ghost:GetDescendants() do
		if v:IsA("Motor6D") then
			local name = v.Name:gsub(" ", "")
			P.Joints[name] = v
			P.Base[name] = v.C0
		elseif v:IsA("BasePart") then
			table.insert(P.Parts, v)
			P.Look[v] = {v.Color, v.Material}
		end
	end
	function P:RestoreLook() for p, l in self.Look do if p.Parent then p.Color, p.Material = l[1], l[2] end end end
	function P:Silhouette() for _, p in self.Parts do p.Color = Color3.new() p.Material = Enum.Material.SmoothPlastic end end
	P.R15 = P.Joints.Waist ~= nil
	P.Torso = ghost:FindFirstChild("UpperTorso") or ghost:FindFirstChild("Torso") or root
	P.Head = ghost:FindFirstChild("Head")
	P.RightHand = ghost:FindFirstChild("RightHand") or ghost:FindFirstChild("Right Arm")
	P.LeftHand = ghost:FindFirstChild("LeftHand") or ghost:FindFirstChild("Left Arm")
	ghost.Parent = ctx.Folder
	root.CFrame = ctx.Hrp.CFrame
	-- hide the real character locally, show the double
	function P:Show()
		if self.Shown or not self.Alive then return end
		self.Shown = true
		for _, p in char:GetDescendants() do
			if p:IsA("BasePart") then self.Hidden[p] = p.LocalTransparencyModifier p.LocalTransparencyModifier = 1 end
		end
		for _, p in self.Parts do p.Transparency = self.PartTr and self.PartTr[p] or 0 end
	end
	function P:Hide()
		if not self.Shown then return end
		self.Shown = false
		for p, v in self.Hidden do if p.Parent then p.LocalTransparencyModifier = v end end
		self.Hidden = {}
		for _, p in self.Parts do p.Transparency = 1 end
	end
	-- the double follows the real character until a show takes over
	P.Follow = true
	function P:Pivot(cf) self.Follow = false self.Root.CFrame = cf end
	-- pose: a table of jointName -> CFrame offset (R15 names; R6 falls back to shoulders/hips/neck), blended by k
	function P:Pose(offsets, k)
		k = k or 1
		for name, off in offsets do
			local j = self.Joints[name]
			if not j and not self.R15 then
				local alias = ({RightShoulder = "RightShoulder", LeftShoulder = "LeftShoulder", RightHip = "RightHip", LeftHip = "LeftHip", Neck = "Neck", Waist = "RootJoint"})[name]
				j = alias and self.Joints[alias]
			end
			if j and self.Base[j.Name:gsub(" ", "")] then
				local base = self.Base[j.Name:gsub(" ", "")]
				j.C0 = base:Lerp(base * off, k)
			end
		end
	end
	function P:ResetPose() for name, j in self.Joints do j.C0 = self.Base[name] end end
	-- transparency for all parts (shards, dissolve); nil restores
	function P:SetTransparency(tr) for _, p in self.Parts do p.Transparency = tr or 0 end end
	function P:Visible(on) for _, p in self.Parts do p.Transparency = on and 0 or 1 end end
	function P:Release()
		if not self.Alive then return end
		self.Alive = false
		self:Hide()
		if ctx.Performer == self then ctx.Performer = nil end
		self.Model:Destroy()
	end
	ctx.Performer = P
	ctx.ReleaseAvatar = function() P:Release() end
	ctx:OnCleanup(function() P:Release() end)
	for _, p in P.Parts do p.Transparency = 1 end
	ctx:Every(function()
		if not P.Alive then return true end
		if not char.Parent or (ctx.Hum and ctx.Hum.Health <= 0) then P:Release() return true end
		if P.Follow then P.Root.CFrame = ctx.Hrp.CFrame end
	end)
	-- a pose library the shows share
	P.Poses = {
		Crouch = {Waist = CFrame.Angles(.35, 0, 0), Neck = CFrame.Angles(-.5, 0, 0), RightShoulder = CFrame.Angles(.2, 0, .15), LeftShoulder = CFrame.Angles(.2, 0, -.15),
			RightHip = CFrame.Angles(-.9, 0, .1), LeftHip = CFrame.Angles(-.9, 0, -.1), RightKnee = CFrame.Angles(1.2, 0, 0), LeftKnee = CFrame.Angles(1.2, 0, 0)},
		Star = {Waist = CFrame.Angles(-.15, 0, 0), Neck = CFrame.Angles(.35, 0, 0), RightShoulder = CFrame.Angles(0, 0, 1.9), LeftShoulder = CFrame.Angles(0, 0, -1.9),
			RightHip = CFrame.Angles(0, 0, .45), LeftHip = CFrame.Angles(0, 0, -.45)},
		Wide = {RightShoulder = CFrame.Angles(0, 0, 1.3), LeftShoulder = CFrame.Angles(0, 0, -1.3), Neck = CFrame.Angles(.25, 0, 0), Waist = CFrame.Angles(-.1, 0, 0)},
		FistUp = {RightShoulder = CFrame.Angles(0, 0, 2.9), RightElbow = CFrame.Angles(.4, 0, 0), LeftShoulder = CFrame.Angles(.3, 0, -.35), Waist = CFrame.Angles(-.2, 0, .1), Neck = CFrame.Angles(.4, 0, 0)},
		Fly = {Waist = CFrame.Angles(.9, 0, 0), Neck = CFrame.Angles(-.7, 0, 0), RightShoulder = CFrame.Angles(-.4, 0, .9), LeftShoulder = CFrame.Angles(-.4, 0, -.9),
			RightHip = CFrame.Angles(.25, 0, .08), LeftHip = CFrame.Angles(.25, 0, -.08), RightKnee = CFrame.Angles(.2, 0, 0), LeftKnee = CFrame.Angles(.2, 0, 0)},
		Kneel = {Waist = CFrame.Angles(.45, 0, 0), Neck = CFrame.Angles(-.3, 0, 0), RightShoulder = CFrame.Angles(.9, 0, .1), RightElbow = CFrame.Angles(.3, 0, 0),
			LeftShoulder = CFrame.Angles(-.3, 0, -.5), RightHip = CFrame.Angles(-1.5, 0, .1), RightKnee = CFrame.Angles(1.9, 0, 0), LeftHip = CFrame.Angles(.1, 0, -.3), LeftKnee = CFrame.Angles(1.4, 0, 0)},
		Hang = {Waist = CFrame.Angles(.2, 0, 0), Neck = CFrame.Angles(.3, 0, 0), RightShoulder = CFrame.Angles(0, 0, .6), LeftShoulder = CFrame.Angles(0, 0, -.6),
			RightHip = CFrame.Angles(0, 0, .25), LeftHip = CFrame.Angles(0, 0, -.25)},
		Pulled = {Waist = CFrame.Angles(-.35, 0, 0), Neck = CFrame.Angles(.3, 0, 0), RightShoulder = CFrame.Angles(-1.5, 0, .2), LeftShoulder = CFrame.Angles(-1.5, 0, -.2),
			RightElbow = CFrame.Angles(.3, 0, 0), LeftElbow = CFrame.Angles(.3, 0, 0)},
		Whirl = {RightShoulder = CFrame.Angles(0, 0, 2.95), RightElbow = CFrame.Angles(.6, 0, 0), Waist = CFrame.Angles(0, 0, -.15), LeftShoulder = CFrame.Angles(.2, 0, -.3)},
		Rider = {RightShoulder = CFrame.Angles(0, 0, 2.6), LeftShoulder = CFrame.Angles(.9, 0, -.2), LeftElbow = CFrame.Angles(.8, 0, 0), RightHip = CFrame.Angles(-1.2, 0, .6),
			LeftHip = CFrame.Angles(-1.2, 0, -.6), RightKnee = CFrame.Angles(1.3, 0, 0), LeftKnee = CFrame.Angles(1.3, 0, 0), Waist = CFrame.Angles(-.1, 0, 0), Neck = CFrame.Angles(.2, 0, 0)},
		Punch = {Waist = CFrame.Angles(.6, 0, 0), Neck = CFrame.Angles(-.3, 0, 0), RightShoulder = CFrame.Angles(1.1, 0, .25), RightElbow = CFrame.Angles(0, 0, 0),
			LeftShoulder = CFrame.Angles(-.8, 0, -.4), RightHip = CFrame.Angles(-1.4, 0, .2), RightKnee = CFrame.Angles(1.6, 0, 0), LeftHip = CFrame.Angles(.4, 0, -.4), LeftKnee = CFrame.Angles(.9, 0, 0)},
		Freeze = {RightShoulder = CFrame.Angles(0, 0, 2.4), LeftShoulder = CFrame.Angles(0, 0, -1.1), Neck = CFrame.Angles(.2, 0, .2), Waist = CFrame.Angles(-.1, 0, .12)},
	}
	-- blend toward a named pose with a smoothed weight; call every frame
	function P:Toward(name, k) self:Pose(self.Poses[name] or {}, math.clamp(k, 0, 1)) end
	return P
end
-- a flight path for the performer: path(u) -> world position for u 0..1 over [t0, t1]; heading follows the tangent,
-- bank follows the turn. pose is a pose name blended in while flying. onU(u, pos, tangent) runs every frame.
function K.Fly(ctx, P, o)
	local t0, t1 = o.T0 or 0, o.T1 or 2
	local path = o.Path
	local lastYaw
	ctx:Every(function(t)
		if not P.Alive then return true end
		if t < t0 then return end
		local u = (t - t0) / (t1 - t0)
		if u >= 1 then
			if o.OnDone then o.OnDone() end
			return true
		end
		local eu = o.EaseU and o.EaseU(u) or u
		local pos = path(eu)
		local ahead = path(math.min(1, eu + .01))
		local tangent = ahead - pos
		tangent = tangent.Magnitude > .001 and tangent.Unit or ctx.Hrp.CFrame.LookVector
		local flat = V3(tangent.X, 0, tangent.Z)
		flat = flat.Magnitude > .01 and flat.Unit or ctx.Hrp.CFrame.LookVector
		local yaw = math.atan2(-flat.X, -flat.Z)
		local turn = 0
		if lastYaw then turn = (yaw - lastYaw + math.pi) % TAU - math.pi end
		lastYaw = yaw
		local bank = math.clamp(turn * (o.Bank or 18), -.55, .55)
		local pitch = math.asin(math.clamp(tangent.Y, -1, 1)) * (o.Pitch or .6)
		local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, bank)
		P:Pivot(cf)
		if o.Pose then P:Toward(o.Pose, o.PoseK or 1) end
		if o.OnU then o.OnU(u, pos, tangent, cf) end
	end)
end
-- lift the performer: rises to height over `rise`, hovers with a slow bob and spin, comes down over `fall`
function K.Float(ctx, P, o)
	local t0, t1 = o.T0 or 0, o.T1 or 4
	local h = o.Height or 4
	local rise, fall = o.Rise or .7, o.Fall or .5
	local home = ctx.Hrp.CFrame
	ctx:Every(function(t)
		if not P.Alive then return true end
		if t < t0 then return end
		if t > t1 + .05 then if o.OnDone then o.OnDone() end return true end
		local up = FX.back((t - t0) / rise) * (1 - FX.ease((t - t1 + fall) / fall))
		local y = h * up + math.sin(t * 1.7) * .25 * up
		local spin = (o.Spin or 0) * (t - t0) * up
		local base = o.Anchor or home
		base = CFrame.new(ctx.Hrp.Position) * (base - base.Position)
		P:Pivot(base * CFrame.new(0, y, 0) * CFrame.Angles(0, spin, 0) * CFrame.Angles(math.sin(t * 1.1) * .04 * up, 0, math.cos(t * .9) * .04 * up))
		if o.Pose then P:Toward(o.Pose, up * (o.PoseK or 1)) end
		if o.OnK then o.OnK(up, t) end
	end)
end

---------------------------------------------------------------- shatter and reform
-- The body explodes into chunks with trails, the chunks fly out, then retrace their own paths to a point and the
-- body is revealed chest-first. P must be shown. o: At, Colors, Chunks, Spread, Reform (seconds after At), ReformCF
-- (where the body comes back; default: 4 studs up), OnExplode, OnReform.
function K.Shatter(ctx, P, o)
	local at = o.At or 0
	local c1, c2, c3 = o.Colors[1], o.Colors[2], o.Colors[3] or o.Colors[2]
	local count = K.Count(ctx, o.Chunks or 28)
	local reformAt = at + (o.Reform or .7)
	ctx:At(at, function()
		if not P.Alive then return end
		local origin = P.Torso.Position
		local parts = {}
		for i = 1, count do
			local big = i <= 6
			local m = K.Mesh(ctx, big and "ShardChunk" or "ShardSliver", {Color = W})
			if not m:IsA("MeshPart") then m.Size = big and V3(1, 1.2, .8) or V3(.2, 2, .5) m:SetAttribute("BaseSize", m.Size) end
			local dir = K.RandUnit()
			dir = (dir + V3(0, .35, 0)).Unit
			local speed = rng:NextNumber(14, 26) * (o.Spread or 1)
			local a0 = ctx:Att(V3(0, .3, 0), m)
			local a1 = ctx:Att(V3(0, -.3, 0), m)
			local tr = Instance.new("Trail")
			tr.Attachment0, tr.Attachment1 = a0, a1
			tr.LightEmission, tr.LightInfluence = 1, 0
			tr.Lifetime = .35
			tr.Texture = K.Tex.Streak
			tr.TextureMode = Enum.TextureMode.Stretch
			tr.Color = FX.cseq({W, c2, c3})
			tr.Transparency = FX.nseq({{0, 0}, {.6, .3}, {1, 1}})
			tr.WidthScale = FX.nseq({{0, 1}, {1, 0}})
			pcall(function() tr.Brightness = 3 end)
			tr.Parent = m
			parts[i] = {M = m, Dir = dir, Speed = speed, Spin = K.RandUnit() * rng:NextNumber(3, 9), Path = {}, Trail = tr, Scale = big and rng:NextNumber(.8, 1.2) or rng:NextNumber(.6, 1.1)}
			K.Place(m, CFrame.new(origin + dir * .5), parts[i].Scale)
		end
		-- the body goes: three frames of black silhouette, then gone
		P:Silhouette()
		task.delay(.05, function() if P.Alive then P:Visible(false) end end)
		ctx:Flash(c1, .5, .3)
		ctx:Shake(.5, .4)
		K.FOV(ctx, 12, .06, .35)
		K.Starburst(ctx, origin, {Colors = {c1, c2}, Size = 14, Count = 40})
		K.PetalFan(ctx, CFrame.new(origin) * CFrame.Angles(math.pi / 2, 0, 0), {Colors = {c1, c2, c3}, Radius = o.FanRadius or 9, Life = .55})
		K.ShockRing(ctx, K.GroundCF(ctx, origin, .15), 2, 26, W, .35, .5)
		K.ShockRing(ctx, K.GroundCF(ctx, origin, .2), 2, 32, c2, .55, .5)
		K.ShockRing(ctx, K.GroundCF(ctx, origin, .25), 2, 38, c3:Lerp(Color3.new(), .5), .8, .4)
		if o.OnExplode then o.OnExplode(origin) end
		local t0 = os.clock()
		local fly = o.Reform or .7
		local outT = fly * .5
		local gather = (o.ReformCF and o.ReformCF.Position) or (origin + V3(0, 4, 0))
		ctx:Every(function()
			local age = os.clock() - t0
			if age < outT then
				-- fly out, record the path
				local e = FX.ease(age / outT)
				for _, s in parts do
					local pos = origin + s.Dir * s.Speed * outT * (1 - (1 - e) ^ 2) * .9
					local cf = CFrame.new(pos) * CFrame.Angles(s.Spin.X * age, s.Spin.Y * age, s.Spin.Z * age)
					K.Place(s.M, cf, s.Scale)
					table.insert(s.Path, cf)
					s.M.Color = W:Lerp(c2, math.min(1, age / outT * 1.2))
				end
				return false
			end
			-- play the path back in reverse (1.5x) toward the gather point
			local u = (age - outT) / (fly - outT)
			if u >= 1 then
				for _, s in parts do s.M:Destroy() end
				return true
			end
			for _, s in parts do
				local n = #s.Path
				if n == 0 then continue end
				local idx = math.max(1, math.floor((1 - FX.ease(u)) * n + .5))
				local cf = s.Path[idx]
				local pull = FX.ease(u) ^ 2
				cf = cf:Lerp(CFrame.new(gather) * CFrame.Angles(s.Spin.X * age, s.Spin.Y * age, 0), pull)
				K.Place(s.M, cf, s.Scale * (1 - pull * .8))
				s.M.Color = c2:Lerp(W, pull)
				s.Trail.Color = FX.cseq({W, c1})
			end
		end)
	end)
	-- the reveal: chest first, then head, arms, legs over six frames, under a white highlight
	ctx:At(reformAt, function()
		if not P.Alive then return end
		if o.ReformCF then P:Pivot(o.ReformCF) end
		P:RestoreLook()
		local order = {"UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart", "Head", "RightUpperArm", "LeftUpperArm", "RightLowerArm", "LeftLowerArm", "RightHand", "LeftHand",
			"RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg", "RightFoot", "LeftFoot", "Right Arm", "Left Arm", "Right Leg", "Left Leg"}
		local rank = {}
		for i, n in order do rank[n] = i end
		for _, p in P.Parts do
			local r = rank[p.Name] or 10
			task.delay(r * .018, function() if P.Alive then p.Transparency = p.Name == "HumanoidRootPart" and 1 or 0 end end)
		end
		local hl = Instance.new("Highlight")
		hl.Adornee = P.Model
		hl.FillColor = W
		hl.OutlineColor = c2
		hl.FillTransparency, hl.OutlineTransparency = 0, .2
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = ctx.Folder
		FX.Tween(hl, .5, {FillTransparency = 1, OutlineTransparency = 1})
		task.delay(.6, function() hl:Destroy() end)
		K.Starburst(ctx, P.Torso.Position, {Colors = {W, c1}, Size = 8, Count = 20})
		local l = ctx:Light(ctx:Att(nil, P.Torso), c1, 30, 10)
		FX.Tween(l, .6, {Brightness = 2})
		if o.OnReform then o.OnReform() end
	end)
end

---------------------------------------------------------------- wings
-- Feathered or constellation wings on the performer. Returns the wing object; it updates itself every frame.
-- o: Span (studs tip to tip), Colors, Unfold (t), Fold (t), Flap (period s, 0 = still), Flame (ember shedding),
-- Style "feather" | "constellation", Scale.
function K.Wings(ctx, P, o)
	local c1, c2, c3 = o.Colors[1], o.Colors[2], o.Colors[3] or o.Colors[2]
	local span = o.Span or 14
	local style = o.Style or "feather"
	local Wg = {Sides = {}, Flap = 0, K = 0, Alive = true}
	for side = -1, 1, 2 do
		local S = {Side = side, Segs = {}}
		if style == "constellation" then
			S.Stars, S.Links = {}, {}
			local n = 7
			for i = 1, n do
				local s = K.Mesh(ctx, "StarPoint", {Color = i % 2 == 0 and c1 or c2})
				if not s:IsA("MeshPart") then s.Size = V3(1.2, 1.2, .1) s:SetAttribute("BaseSize", s.Size) end
				local a = ctx:Att(nil, s)
				S.Stars[i] = {M = s, A = a}
			end
			for i = 1, n - 1 do
				S.Links[i] = ctx:Beam(S.Stars[i].A, S.Stars[i + 1].A, {Color = {c1, c2}, Width0 = .12, Width1 = .12, Transparency = .1, Brightness = 2, Segments = 1})
			end
			S.Links[n] = ctx:Beam(S.Stars[n].A, S.Stars[2].A, {Color = {c2, c3}, Width0 = .08, Width1 = .08, Transparency = .3, Brightness = 2, Segments = 1})
			local fill = K.Mesh(ctx, "WingSilhouette", {Color = c3, Transparency = .75, Material = Enum.Material.ForceField})
			if not fill:IsA("MeshPart") then fill.Size = V3(7, 3.3, .1) fill:SetAttribute("BaseSize", fill.Size) end
			S.Fill = fill
		else
			for i, name in {"WingUpper", "WingFore", "WingPrimaries"} do
				local want = side < 0 and name .. "L" or name
				local m = K.HasMesh(want) and K.Mesh(ctx, want, {Color = c2}) or K.Mesh(ctx, name, {Color = c2})
				if not m:IsA("MeshPart") then
					m.Size = V3(4, .25, i == 3 and 2.4 or 1.4) m:SetAttribute("BaseSize", m.Size)
					Data.Pivots[m.Name] = Data.Pivots[m.Name] or V3(side * 2, 0, 0)
				end
				S.Segs[i] = m
			end
			S.Edge = {ctx:Att(), ctx:Att(), ctx:Att(), ctx:Att()}
			S.EdgeBeams = {}
			for i = 1, 3 do
				S.EdgeBeams[i] = ctx:Beam(S.Edge[i], S.Edge[i + 1], {Color = {W, c1, c2}, Width0 = .35, Width1 = .25, Transparency = {{0, .1}, {1, .4}}, Brightness = 4, Segments = 4})
			end
			-- tip trail
			local tipPart = ctx:Part({Transparency = 1, Size = Vector3.one * .2})
			local ta0, ta1 = ctx:Att(V3(0, .5, 0), tipPart), ctx:Att(V3(0, -.5, 0), tipPart)
			local tr = Instance.new("Trail")
			tr.Attachment0, tr.Attachment1 = ta0, ta1
			tr.LightEmission, tr.LightInfluence = 1, 0
			tr.Lifetime = .45
			tr.Texture = K.Tex.Streak
			tr.TextureMode = Enum.TextureMode.Stretch
			tr.Color = FX.cseq({W, c2, c3})
			tr.Transparency = FX.nseq({{0, .1}, {.7, .4}, {1, 1}})
			tr.WidthScale = FX.nseq({{0, 1}, {1, 0}})
			tr.Enabled = false
			pcall(function() tr.Brightness = 3 end)
			tr.Parent = tipPart
			S.Tip, S.Trail = tipPart, tr
			if o.Flame then
				S.Embers = ctx:Emitter(ta0, {Texture = K.Tex.Flame, Color = {W, c1, c2, c3}, Size = {{0, 1.2}, {.3, 1.8}, {1, 0}}, Transparency = {{0, .2}, {.6, .3}, {1, 1}},
					Lifetime = {.35, .7}, Speed = {2, 5}, SpreadAngle = Vector2.new(40, 40), Rate = 0, Drag = 2, Acceleration = V3(0, 5, 0), Brightness = 3,
					Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = {{0, .5}, {1, 1.2}}})
				S.Feathers = ctx:Emitter(ta0, {Texture = K.Tex.Petal, Color = {c1, c2}, Size = {.9, .6}, Transparency = {{0, .1}, {.8, .2}, {1, 1}}, Lifetime = {1.4, 2.4},
					Speed = {1, 3}, SpreadAngle = Vector2.new(180, 180), Rate = 0, Acceleration = V3(0, -7, 0), Drag = 3, RotSpeed = {-250, 250}, Rotation = {0, 360}, Brightness = 2})
			end
		end
		Wg.Sides[side] = S
	end
	local period = o.Flap or 0
	local flame = o.Flame
	ctx:Every(function(t)
		if not Wg.Alive or not P.Alive then return true end
		local k = K.Soft(t, o.Unfold or 0, o.Fold or 99, o.Rise or .45, o.Fall or .4)
		Wg.K = k
		local phase = period > 0 and K.Flap(t - (o.Unfold or 0), period) or .25
		Wg.Flap = phase
		local anchor = P.Torso.CFrame * CFrame.new(0, .45, .55)
		local scale = (span / 2) / 4 -- three 4-stud segments per side at scale 1 hold a 12-stud span
		scale *= .95 * k + .05
		for side, S in Wg.Sides do
			-- shoulder joint: unfold swings the wing out and back; the flap swings it up and down
			local unfold = k
			local lift = (1 - phase) * .9 - .35 -- +up at the top of the stroke
			local sweep = -.25 + phase * .35
			local root = anchor * CFrame.new(side * .55, .2, 0) * CFrame.Angles(0, side * (-.75 + unfold * .3) + sweep * side, 0) * CFrame.Angles(0, 0, side * lift)
			if style == "constellation" then
				local open = .2 + unfold * .8
				for i, st in S.Stars do
					local u = (i - 1) / 6
					local x = side * (1 + u * span * .5 * open)
					local y = (math.sin(u * math.pi * .9) * span * .22 - u * u * span * .12) * open + math.sin(t * 2 + i) * .12
					local z = -u * .6
					K.Place(st.M, anchor * CFrame.new(x, y, z) * CFrame.Angles(0, 0, t * .8 + i), .6 + .25 * math.sin(t * 3 + i))
					st.M.Transparency = 1 - k
				end
				for _, b in S.Links do b.Enabled = k > .05 end
				K.Place(S.Fill, anchor * CFrame.new(side * span * .25 * open, span * .08, -.4) * CFrame.Angles(0, side * -.15, side * .2), (span / 14) * open)
				S.Fill.Transparency = 1 - .3 * k
			else
				-- a three-segment chain: upper, fore, primaries, each bending a little more than the last
				local cf = root
				local bend = {.15 + phase * .25, .35 + phase * .4, .55 + phase * .5}
				local pts = {cf.Position}
				local fold = (1 - unfold) * 1.4
				for i, seg in S.Segs do
					-- each segment sweeps back a little more when folded and droops a little more down the stroke
					cf = cf * CFrame.Angles(0, side * -fold * (i == 1 and .6 or 1), side * -(bend[i] * (1 - fold * .5)) * .6)
					K.Place(seg, cf, scale)
					seg.Transparency = 1 - k * (i == 3 and .9 or 1)
					seg.Color = c2:Lerp(c1, phase * .6)
					cf = cf * CFrame.new(side * 4 * scale, 0, 0)
					table.insert(pts, cf.Position)
				end
				for i, a in S.Edge do a.WorldPosition = pts[math.min(i, #pts)] end
				for _, b in S.EdgeBeams do b.Enabled = k > .1 end
				S.Tip.CFrame = CFrame.new(pts[#pts])
				S.Trail.Enabled = k > .5 and period > 0
				if S.Embers then
					S.Embers.Rate = k > .3 and (12 + 30 * (1 - phase)) * (ctx.Quality or 1) or 0
					S.Feathers.Rate = k > .5 and 2.5 or 0
				end
			end
		end
	end)
	function Wg:Dissolve(dur)
		self.Alive = false
		for _, S in self.Sides do
			for _, seg in S.Segs do
				FX.Tween(seg, dur or .6, {Transparency = 1})
				local a = ctx:Att(nil, seg)
				ctx:Emitter(a, {Texture = K.Tex.Flame, Color = {W, c1, c2}, Size = {1.2, 0}, Lifetime = {.5, .9}, Speed = {4, 8}, SpreadAngle = Vector2.new(30, 30),
					Acceleration = V3(0, 8, 0), Brightness = 3, Orientation = Enum.ParticleOrientation.VelocityParallel}):Emit(K.Count(ctx, 18))
			end
			if S.Stars then for _, st in S.Stars do FX.Tween(st.M, dur or .6, {Transparency = 1}) end for _, b in S.Links do b.Enabled = false end FX.Tween(S.Fill, dur or .6, {Transparency = 1}) end
			if S.EdgeBeams then for _, b in S.EdgeBeams do b.Enabled = false end end
			if S.Trail then S.Trail.Enabled = false end
			if S.Embers then S.Embers.Rate = 0 S.Feathers.Rate = 0 end
		end
	end
	return Wg
end

---------------------------------------------------------------- seekers (things that go looking for everyone else)
-- Spawn `Count` seekers over time from `From` (a position or fn -> position) that each fly to a target (players,
-- then animals, then orbit points), circle its head once, phase through it with a flicker, dissolve and (Return)
-- streak back to the origin. o: Mesh (name) or Build(ctx) -> part, Scale, Colors, Count, Interval, Speed, Trail
-- (life), Light, Circle (seconds), OnTouch(target), OnSpawn(part), Radius, T0, Wobble, Targets (a list to use instead
-- of K.Targets, e.g. {{Part = ctx.Hrp, Model = ctx.Char, Kind = "self"}}).
function K.Seek(ctx, o)
	local c1, c2, c3 = o.Colors[1], o.Colors[2], o.Colors[3] or o.Colors[2]
	local count = K.Count(ctx, o.Count or 7)
	local targets = o.Targets or K.Targets(ctx, count, o.Radius or 40)
	if #targets == 0 then targets = K.Targets(ctx, count, o.Radius or 40) end
	local tracked = {}
	local Sk = {Parts = tracked, Done = 0}
	local function spawnOne(i)
		local tg = targets[(i - 1) % #targets + 1]
		local m = o.Build and o.Build(ctx, i) or K.Mesh(ctx, o.Mesh or "GhostWisp", {Color = c1, Material = Enum.Material.ForceField})
		if o.Mesh and not m:IsA("MeshPart") then m.Size = V3(1.2, 1.6, 2.4) m:SetAttribute("BaseSize", m.Size) end
		local scale = o.Scale or 1
		local from = typeof(o.From) == "function" and o.From(i) or (o.From or ctx.Base.Position + V3(0, 3, 0))
		K.Place(m, CFrame.new(from), scale * .3)
		local a0 = ctx:Att(V3(0, .5, 0), m)
		local a1 = ctx:Att(V3(0, -.5, 0), m)
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.LightEmission, tr.LightInfluence = 1, 0
		tr.Lifetime = o.Trail or 1
		tr.Texture = K.Tex.Streak
		tr.TextureMode = Enum.TextureMode.Stretch
		tr.Color = FX.cseq({W, c2, c3})
		tr.Transparency = FX.nseq({{0, .1}, {.5, .4}, {1, 1}})
		tr.WidthScale = FX.nseq({{0, 1}, {1, 0}})
		pcall(function() tr.Brightness = 2.5 end)
		tr.Parent = m
		local light = ctx:Light(a0, c2, o.Light or 14, 3)
		local dust = ctx:Emitter(a0, {Texture = K.Tex.Glow, Color = {W, c2}, Size = {.9, 0}, Lifetime = {.3, .6}, Rate = 10 * (ctx.Quality or 1), Speed = {.5, 1.5}, SpreadAngle = Vector2.new(180, 180), Brightness = 3})
		table.insert(tracked, m)
		if o.OnSpawn then o.OnSpawn(m, i) end
		local t0 = os.clock()
		local p0 = from
		local p1
		local goal = targetPos(tg, o.Height or 2.5)
		local ctrl = (p0 + goal) / 2 + V3(rng:NextNumber(-6, 6), rng:NextNumber(5, 10), rng:NextNumber(-6, 6))
		local speed = o.Speed or 14
		local dist = (goal - p0).Magnitude + 6
		local flyT = math.max(.5, dist / speed)
		local circleT = o.Circle or .6
		local phase = "fly"
		local touched = false
		local lastPos = p0
		ctx:Every(function()
			if not m.Parent then return true end
			local age = os.clock() - t0
			if phase == "fly" then
				local u = age / flyT
				goal = targetPos(tg, o.Height or 2.5)
				if u >= 1 then phase = "circle" t0 = os.clock() return false end
				local pos = K.Bezier(p0, ctrl, goal, FX.ease(u) ^ .8)
				pos += V3(0, math.sin(age * 7) * (o.Wobble or .4), 0)
				local look = pos - lastPos
				K.Place(m, look.Magnitude > .001 and CFrame.lookAt(pos, pos + look) or CFrame.new(pos), scale * math.min(1, .3 + u * 2))
				lastPos = pos
			elseif phase == "circle" then
				local u = age / circleT
				if u >= 1 then
					phase = "through"
					t0 = os.clock()
					if not touched then
						touched = true
						if tg.Model and tg.Kind ~= "point" then
							local hl = Instance.new("Highlight")
							hl.Adornee = tg.Model
							hl.FillColor, hl.OutlineColor = c2, c1
							hl.FillTransparency, hl.OutlineTransparency = .3, 0
							hl.DepthMode = Enum.HighlightDepthMode.Occluded
							hl.Parent = ctx.Folder
							FX.Tween(hl, .45, {FillTransparency = 1, OutlineTransparency = 1})
							task.delay(.5, function() hl:Destroy() end)
						end
						if o.OnTouch then o.OnTouch(tg, targetPos(tg, 0)) end
					end
					return false
				end
				local centre = targetPos(tg, o.Height or 2.5)
				local a = u * TAU + i
				local pos = centre + K.Polar(a, 2.6, math.sin(u * math.pi) * .8)
				local ahead = centre + K.Polar(a + .2, 2.6, 0)
				K.Place(m, CFrame.lookAt(pos, ahead), scale)
				lastPos = pos
			elseif phase == "through" then
				local u = age / .35
				if u >= 1 then
					-- dust, then streak home
					phase = "home"
					t0 = os.clock()
					local pos = m.Position
					ctx:Burst(pos, K.Count(ctx, 24), {Texture = K.Tex.Glow, Color = {W, c2}, Size = {.6, 0}, Lifetime = {.3, .6}, Speed = {4, 10}, SpreadAngle = Vector2.new(180, 180), Drag = 3, Brightness = 4})
					if not o.Return then m:Destroy() Sk.Done += 1 return true end
					m.Transparency = .6
					tr.Color = FX.cseq({c2, W})
					p1 = typeof(o.From) == "function" and o.From(i) or (o.From or ctx.Base.Position + V3(0, 3, 0))
					return false
				end
				local centre = targetPos(tg, o.Height or 2.5)
				local pos = centre + K.Polar(i, 2.6 * (1 - u * 2), 0)
				K.Place(m, CFrame.lookAt(pos, centre + K.Polar(i, -3, 0)), scale * (1 - u * .4))
				m.Transparency = u * .5
			else
				local u = age / .35
				if u >= 1 then m:Destroy() Sk.Done += 1 return true end
				local pos = lastPos:Lerp(p1, FX.ease(u) ^ 1.6)
				K.Place(m, CFrame.lookAt(pos, p1), scale * .5)
				m.Transparency = .6 + u * .4
			end
		end)
	end
	for i = 1, count do
		ctx:At((o.T0 or 0) + (i - 1) * (o.Interval or .25), function() spawnOne(i) end)
	end
	return Sk
end

---------------------------------------------------------------- echoes (past copies of the performer)
-- `Count` ForceField copies of the performer's parts replay its recorded CFrames `Delay` seconds apart.
function K.Echo(ctx, P, o)
	local c = o.Color or W
	local count, delay = o.Count or 3, o.Delay or .3
	local frames = {} -- ring of {time, {part -> cframe}}
	local copies = {}
	for e = 1, count do
		local set = {}
		for _, p in P.Parts do
			if p.Name == "HumanoidRootPart" then continue end
			local q = p:Clone()
			for _, d in q:GetChildren() do if not d:IsA("SpecialMesh") and not d:IsA("DataModelMesh") then d:Destroy() end end
			q.Material = Enum.Material.ForceField
			q.Color = c
			q.Transparency = o.Transparency or .55
			q.Anchored, q.CanCollide, q.CanQuery, q.CanTouch, q.CastShadow = true, false, false, false, false
			q.Parent = ctx.Folder
			set[p] = q
		end
		copies[e] = set
	end
	local t0, t1 = o.T0 or 0, o.T1 or 99
	ctx:Every(function(t)
		if not P.Alive then return true end
		local now = os.clock()
		local snap = {}
		for _, p in P.Parts do snap[p] = p.CFrame end
		table.insert(frames, {now, snap})
		while #frames > 0 and now - frames[1][1] > delay * count + .2 do table.remove(frames, 1) end
		local vis = K.Soft(t, t0, t1, .3, .4)
		for e, set in copies do
			local want = now - delay * e
			local f
			for i = #frames, 1, -1 do if frames[i][1] <= want then f = frames[i] break end end
			for p, q in set do
				local cf = f and f[2][p] or p.CFrame
				q.CFrame = cf
				q.Transparency = 1 - (1 - (o.Transparency or .55)) * vis * (1 - (e - 1) / count * .5)
			end
		end
		if t > t1 then for _, set in copies do for _, q in set do q:Destroy() end end return true end
	end)
end

---------------------------------------------------------------- herd and world reactions
-- Every herd animal within Radius reacts (local only): a Highlight blink in the theme colour, a small effect at its
-- feet, and a hop. Flavour: "flinch" (hop), "bolt" (hop away 3 studs), "freeze" (no hop, long highlight), "bounce"
-- (two hops), "lookup" (tiny lift). Runs at o.At. Returns the list it found.
function K.Herd(ctx, o)
	local list = K.NearbyAnimals(ctx, o.Radius or 14)
	local c = o.Color or W
	ctx:At(o.At or 0, function()
		for i, tg in list do
			if i > (o.Max or 10) then break end
			task.delay((i - 1) * (o.Stagger or .05), function()
				local m = tg.Model
				if not m.Parent then return end
				local hl = Instance.new("Highlight")
				hl.Adornee = m
				hl.FillColor, hl.OutlineColor = c, W
				hl.FillTransparency, hl.OutlineTransparency = .45, .1
				hl.DepthMode = Enum.HighlightDepthMode.Occluded
				hl.Parent = ctx.Folder
				local hold = o.Flavour == "freeze" and 1.4 or .35
				FX.Tween(hl, hold, {FillTransparency = 1, OutlineTransparency = 1})
				task.delay(hold + .05, function() hl:Destroy() end)
				if o.Effect then o.Effect(tg) end
				ctx:Ripple(K.GroundCF(ctx, tg.Part.Position, .15), 1, o.Ring or 6, {W, c}, .5, K.Tex.Ring)
				if o.Flavour == "freeze" then return end
				-- the hop (absolute from the pose sampled now; the game re-takes the animal when we stop)
				local base = m:GetPivot()
				local away = (base.Position - ctx.Base.Position)
				away = away.Magnitude > .1 and V3(away.X, 0, away.Z).Unit or Vector3.zAxis
				local dur = o.Flavour == "bounce" and .7 or .35
				local t0 = os.clock()
				ctx:Every(function()
					local u = (os.clock() - t0) / dur
					if u >= 1 or not m.Parent then return true end
					local hop = math.abs(math.sin(u * math.pi * (o.Flavour == "bounce" and 2 or 1))) * (o.Flavour == "lookup" and .3 or 1.2)
					local slide = o.Flavour == "bolt" and away * 3 * FX.ease(u) or Vector3.zero
					local tilt = o.Flavour == "lookup" and -.3 * math.sin(u * math.pi) or (o.Flavour == "flinch" and .25 * math.sin(u * math.pi) or 0)
					pcall(function() m:PivotTo(base * CFrame.new(0, hop, 0) * CFrame.Angles(tilt, 0, 0) + slide) end)
				end)
			end)
		end
	end)
	return list
end
-- ground cracks radiating from the centre: n crack meshes placed by raycast, grown along their length with staggered
-- starts, lit from inside; they fade after Life. o: At, Count, Len, Color, Life, Radius (start offset), Stagger.
function K.Cracks(ctx, o)
	local c = o.Color or W
	local n = K.Count(ctx, o.Count or 8)
	ctx:At(o.At or 0, function()
		local centre = ctx.Base.Position
		for i = 1, n do
			local a = i / n * TAU + rng:NextNumber(-.2, .2)
			local name = ({"CrackA", "CrackB", "CrackC"})[i % 3 + 1]
			local m = K.Mesh(ctx, name, {Color = c})
			if not m:IsA("MeshPart") then m.Size = V3(.3, .08, 6) m:SetAttribute("BaseSize", m.Size) Data.Pivots[name] = Data.Pivots[name] or V3(0, 0, -3) end
			local start = centre + K.Polar(a, o.Radius or 1.2, 0)
			local g = K.GroundCF(ctx, start, .06)
			-- the crack's +Y runs outward along the ground: rotate the ground frame so its up stays up and Y points out
			local out = K.Polar(a, 1, 0)
			-- the crack mesh runs along its -Z (authored along Blender +Y), so look outward along the ground
			local cf = CFrame.lookAt(g.Position, g.Position + out, g.UpVector)
			local len = (o.Len or 6) * rng:NextNumber(.8, 1.25)
			local t0 = os.clock() + (i - 1) * (o.Stagger or .04)
			local life = o.Life or 3
			local a0 = ctx:Att(V3(0, 0, 0), m)
			local glow = ctx:Emitter(a0, {Texture = K.Tex.Glow, Color = {W, c}, Size = {{0, 0}, {.3, 1.6}, {1, 0}}, Transparency = {{0, .3}, {1, 1}}, Lifetime = {.4, .8},
				Rate = 0, Speed = {.5, 2}, SpreadAngle = Vector2.new(20, 20), Brightness = 3, EmissionDirection = Enum.NormalId.Top})
			ctx:Every(function()
				local age = os.clock() - t0
				if age < 0 then return false end
				local gk = FX.ease(age / .22)
				local fade = age > life - .6 and (1 - FX.ease((age - life + .6) / .6)) or 1
				if age >= life then m:Destroy() return true end
				K.Place(m, cf, V3(1, 1, (len / 6) * gk))
				m.Transparency = 1 - fade
				glow.Rate = (6 + 10 * gk) * fade * (ctx.Quality or 1)
			end)
		end
	end)
end
-- loose ground props (cobbles, grass clumps, straw) that lift off the ground, orbit a point and drop with a bounce.
-- o: At, Count, Radius, Lift (height), Centre (fn -> world position, default the chest), Orbit (rad/s), Until (t),
-- Meshes (names), Color (nil keeps the mesh dark), Stretch (toward the centre, for the black hole).
function K.Debris(ctx, o)
	local n = K.Count(ctx, o.Count or 14)
	local names = o.Meshes or {"Cobble", "GrassClump", "HayStraw"}
	local items = {}
	ctx:At(o.At or 0, function()
		for i = 1, n do
			local name = names[(i - 1) % #names + 1]
			local m = K.Mesh(ctx, name, {Material = o.Color and Enum.Material.Neon or Enum.Material.SmoothPlastic, Color = o.Color or Color3.fromRGB(110, 96, 84)})
			if not m:IsA("MeshPart") then m.Size = name == "GrassClump" and V3(1, 1.2, 1) or V3(.9, .6, .8) m:SetAttribute("BaseSize", m.Size) end
			if name == "GrassClump" and not o.Color then m.Color = Color3.fromRGB(96, 150, 70) end
			local a = i / n * TAU + rng:NextNumber(-.3, .3)
			local r = (o.Radius or 6) * rng:NextNumber(.6, 1.1)
			local gp = K.Ground(ctx, ctx.Base.Position + K.Polar(a, r, 0))
			items[i] = {M = m, Home = gp, A = a, R = r, Spin = K.RandUnit() * rng:NextNumber(.5, 2), Delay = rng:NextNumber(0, .3), Scale = rng:NextNumber(.8, 1.2)}
			K.Place(m, CFrame.new(gp), items[i].Scale)
		end
		local t0 = os.clock()
		local dropAt = (o.Until or 3) - (o.At or 0)
		local falling = {}
		ctx:Every(function()
			local age = os.clock() - t0
			if age < dropAt then
				for _, it in items do
					local u = FX.ease((age - it.Delay) / .8)
					local lift = (o.Lift or 4) * u
					local centre = o.Centre and o.Centre() or (ctx.Base.Position + V3(0, 3, 0))
					local ang = it.A + age * (o.Orbit or .8) * u
					local pos = (centre + K.Polar(ang, it.R * (1 - .35 * u), 0)) * V3(1, 0, 1) + V3(0, it.Home.Y + lift + math.sin(age * 2 + it.A) * .3 * u, 0)
					local cf = CFrame.new(pos) * CFrame.Angles(it.Spin.X * age, it.Spin.Y * age, it.Spin.Z * age)
					if o.Stretch then
						local toward = centre - pos
						if toward.Magnitude > .1 then cf = CFrame.lookAt(pos, centre) * CFrame.Angles(0, 0, age * it.Spin.X) end
						K.Place(it.M, cf, V3(it.Scale * (1 - u * .4), it.Scale * (1 - u * .4), it.Scale * (1 + u * 2.5)))
					else
						K.Place(it.M, cf, it.Scale)
					end
				end
				return false
			end
			-- drop with gravity and one bounce, then fade
			if #falling == 0 then
				for _, it in items do table.insert(falling, {It = it, V = V3(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)), Pos = it.M.Position, Bounced = false}) end
			end
			local dt = 1 / 60
			local allDown = true
			for _, f in falling do
				if f.Done then continue end
				allDown = false
				f.V = f.V + V3(0, -55, 0) * dt
				f.Pos = f.Pos + f.V * dt
				local gy = f.It.Home.Y
				if f.Pos.Y <= gy then
					f.Pos = V3(f.Pos.X, gy, f.Pos.Z)
					if not f.Bounced and math.abs(f.V.Y) > 6 then f.V = V3(f.V.X * .6, -f.V.Y * .3, f.V.Z * .6) f.Bounced = true
					else f.Done = true FX.Tween(f.It.M, 1.2, {Transparency = 1}) task.delay(1.3, function() f.It.M:Destroy() end) end
				end
				f.It.M.CFrame = CFrame.new(f.Pos) * (f.It.M.CFrame - f.It.M.CFrame.Position) * CFrame.Angles(dt * 3, 0, 0)
			end
			return allDown
		end)
	end)
	return items
end
-- slow (or stop) every particle emitter and other characters' animations within Radius, locally. Scale 0..1,
-- between T0 and T1; everything is restored after. Your own show only.
function K.TimeScale(ctx, o)
	if not ctx.Local then return end
	local emitters, tracks = {}, {}
	ctx:At(o.T0 or 0, function()
		local centre = ctx.Base.Position
		local r = o.Radius or 30
		for _, d in workspace:GetDescendants() do
			if d:IsA("ParticleEmitter") and not d:IsDescendantOf(ctx.Folder) then
				local p = d.Parent
				local pos = p and (p:IsA("BasePart") and p.Position or (p:IsA("Attachment") and p.WorldPosition))
				if pos and (pos - centre).Magnitude <= r then emitters[d] = d.TimeScale d.TimeScale = o.Scale or .1 end
			end
		end
		for _, pl in Players:GetPlayers() do
			local ch = pl.Character
			if ch and ch ~= ctx.Char then
				local hum = ch:FindFirstChildOfClass("Humanoid")
				local an = hum and hum:FindFirstChildOfClass("Animator")
				if an and (ch:GetPivot().Position - centre).Magnitude <= r then
					for _, tr in an:GetPlayingAnimationTracks() do tracks[tr] = tr.Speed tr:AdjustSpeed((o.Scale or .1) * tr.Speed) end
				end
			end
		end
	end)
	local function restore()
		for e, v in emitters do if e.Parent then e.TimeScale = v end end
		for tr, v in tracks do pcall(function() tr:AdjustSpeed(v) end) end
		emitters, tracks = {}, {}
	end
	ctx:At(o.T1 or 2, restore)
	ctx:OnCleanup(restore)
end
-- every light within Radius swings to Color for Hold seconds (your own show only); props get a brief Highlight
function K.LightPaint(ctx, o)
	if not ctx.Local then return end
	ctx:At(o.At or 0, function()
		local centre, r = ctx.Base.Position, o.Radius or 40
		local saved = {}
		for _, d in workspace:GetDescendants() do
			if d:IsA("Light") and not d:IsDescendantOf(ctx.Folder) then
				local p = d.Parent
				local pos = p and (p:IsA("BasePart") and p.Position or (p:IsA("Attachment") and p.WorldPosition))
				if pos and (pos - centre).Magnitude <= r then saved[d] = {d.Color, d.Brightness} FX.Tween(d, .1, {Color = o.Color or W, Brightness = d.Brightness * (o.Boost or 2)}) end
			end
		end
		if o.Highlight ~= false then
			local n = 0
			for _, p in K.NearbyProps(ctx, math.min(r, 18), 8) do
				n += 1
				local hl = Instance.new("Highlight")
				hl.Adornee = p
				hl.FillColor, hl.OutlineColor = o.Color or W, o.Color or W
				hl.FillTransparency, hl.OutlineTransparency = .7, 0
				hl.DepthMode = Enum.HighlightDepthMode.Occluded
				hl.Parent = ctx.Folder
				FX.Tween(hl, o.Hold or .5, {FillTransparency = 1, OutlineTransparency = 1})
				task.delay((o.Hold or .5) + .05, function() hl:Destroy() end)
			end
		end
		task.delay(o.Hold or .5, function()
			for d, v in saved do if d.Parent then FX.Tween(d, .6, {Color = v[1], Brightness = v[2]}) end end
		end)
		ctx:OnCleanup(function() for d, v in saved do if d.Parent then d.Color, d.Brightness = v[1], v[2] end end end)
	end)
end
-- chain lightning from a point to the nearest props (fence posts, lanterns, the fountain), each struck part flashing
function K.Chain(ctx, o)
	local c = o.Color or W
	ctx:At(o.At or 0, function()
		local props = K.NearbyProps(ctx, o.Radius or 15, o.Count or 6)
		local from = o.From or (ctx.Base.Position + V3(0, 3, 0))
		for i, p in props do
			task.delay((i - 1) * (o.Stagger or .05), function()
				local to = p.Position + V3(0, p.Size.Y * .4, 0)
				local setC, core = ctx:Bolt(8, .22, W)
				local setG, glow = ctx:Bolt(8, .7, c)
				local jag = (to - from).Magnitude * .09
				setC(from, to, jag, 0) setG(from, to, jag, .35)
				task.delay(.06, function() setC(from, to, jag, .15) setG(from, to, jag, .5) end)
				task.delay(.12, function() setC(from, to, jag, 0) setG(from, to, jag, .35) end)
				task.delay(.2, function() for _, q in core do FX.Tween(q, .2, {Transparency = 1}) end for _, q in glow do FX.Tween(q, .2, {Transparency = 1}) end end)
				task.delay(.5, function() for _, q in core do q:Destroy() end for _, q in glow do q:Destroy() end end)
				local hl = Instance.new("Highlight")
				hl.Adornee = p
				hl.FillColor, hl.OutlineColor = W, c
				hl.FillTransparency, hl.OutlineTransparency = .2, 0
				hl.DepthMode = Enum.HighlightDepthMode.Occluded
				hl.Parent = ctx.Folder
				FX.Tween(hl, .35, {FillTransparency = 1, OutlineTransparency = 1})
				task.delay(.4, function() hl:Destroy() end)
				ctx:Burst(to, K.Count(ctx, 16), {Texture = K.Tex.Star, Color = {W, c}, Size = {.6, 0}, Lifetime = {.2, .5}, Speed = {6, 14}, SpreadAngle = Vector2.new(180, 180), Drag = 4, Brightness = 5})
			end)
		end
	end)
end
-- a ground stamp (scorch ring, frost print, flower ring) placed on the ground at pos
function K.Stamp(ctx, pos, o)
	local m = K.Mesh(ctx, o.Mesh or "ScorchRing", {Color = o.Color or W, Material = o.Material or Enum.Material.Neon})
	if not m:IsA("MeshPart") then m.Size = V3(6.4, .08, 6.4) m:SetAttribute("BaseSize", m.Size) end
	local g = K.GroundCF(ctx, pos, o.Lift or .07)
	local cf = g * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
	local s = o.Scale or 1
	K.Place(m, cf, s * .2)
	local t0 = os.clock()
	local life = o.Life or 3
	ctx:Every(function()
		local age = os.clock() - t0
		if age >= life then m:Destroy() return true end
		local gk = FX.back(age / (o.Rise or .25))
		local fade = age > life - .7 and (1 - FX.ease((age - life + .7) / .7)) or 1
		K.Place(m, cf, s * (.2 + .8 * gk))
		m.Transparency = (o.Transparency or 0) + (1 - fade) * (1 - (o.Transparency or 0))
		if o.OnAge then o.OnAge(m, age) end
	end)
	return m
end

---------------------------------------------------------------- skin, sheets, sweeps, cage, monument, charge-up
-- plasma skin: a Highlight fill flicker, thin Beams crawling up the limbs, and a lightning flipbook on the torso
function K.Skin(ctx, o)
	local c = o.Color or W
	local target = (ctx.Performer and ctx.Performer.Alive) and ctx.Performer.Model or ctx.Char
	local hl = Instance.new("Highlight")
	hl.Adornee = target
	hl.FillColor, hl.OutlineColor = c, W
	hl.FillTransparency, hl.OutlineTransparency = 1, 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = ctx.Folder
	local torso = target:FindFirstChild("UpperTorso") or target:FindFirstChild("Torso") or target:FindFirstChild("HumanoidRootPart")
	local bolts
	if o.Lightning and torso then
		bolts = ctx:Emitter(torso, {Texture = K.Tex.Lightning, Color = {W, c}, Size = {3.2, 3.6}, Transparency = {{0, 1}, {.1, 0}, {.8, 0}, {1, 1}}, Lifetime = {.2, .35},
			Rate = 0, Speed = 0, Rotation = {0, 360}, ZOffset = .6, Brightness = 4, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface})
		K.Flipbook(bolts, "Lightning", Enum.ParticleFlipbookMode.Loop, 24)
	end
	local limbs = {}
	for _, n in {"LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "Left Arm", "Right Arm", "Left Leg", "Right Leg"} do
		local p = target:FindFirstChild(n)
		if p then
			local a0 = ctx:Att(V3(0, -p.Size.Y * .5, 0), p)
			local a1 = ctx:Att(V3(0, p.Size.Y * .5, 0), p)
			local b = ctx:Beam(a0, a1, {Color = {c, W}, Width0 = .12, Width1 = .08, Transparency = .2, Brightness = 3, CurveSize0 = .6, CurveSize1 = -.6, Segments = 6,
				Texture = K.Tex.Streak, TextureSpeed = 2, TextureLength = 1})
			b.Enabled = false
			table.insert(limbs, {b, a0, a1})
			ctx:OnCleanup(function() a0:Destroy() a1:Destroy() end)
		end
	end
	local t0, t1 = o.T0 or 0, o.T1 or 99
	ctx:Every(function(t)
		local k = K.Soft(t, t0, t1, .3, .4)
		hl.FillTransparency = 1 - k * (.35 + .25 * math.abs(math.sin(t * 17 + math.sin(t * 5))))
		hl.OutlineTransparency = 1 - k * .15
		for _, l in limbs do l[1].Enabled = k > .1 l[1].CurveSize0 = math.sin(t * 9) * .8 l[1].CurveSize1 = math.cos(t * 7) * .8 end
		if bolts then bolts.Rate = k > .1 and 9 * (ctx.Quality or 1) or 0 end
		if t > t1 then hl:Destroy() return true end
	end)
	return hl
end
-- tall flame sheets on the body: three VelocityParallel sheet emitters on a follower part, white core to colour
function K.Sheets(ctx, o)
	local c1, c2, c3 = o.Colors[1], o.Colors[2], o.Colors[3] or o.Colors[2]
	local body = ctx:Part({Transparency = 1, Size = V3(2.6, .6, 2.6)})
	local sheet = ctx:Emitter(body, {Texture = K.Tex.Flame, Color = {W, c1, c2, c3}, Size = {{0, 1.6}, {.4, 2.6}, {1, .4}}, Transparency = {{0, 1}, {.08, .1}, {.7, .3}, {1, 1}},
		Lifetime = {.5, .9}, Speed = {5, 9}, SpreadAngle = Vector2.new(12, 12), EmissionDirection = Enum.NormalId.Top, Rate = 0, Brightness = 4,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = {{0, .6}, {1, 1.4}}, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface})
	local dark = ctx:Emitter(body, {Texture = K.Tex.Smoke, Color = {c3:Lerp(Color3.new(), .6), Color3.new()}, Size = {{0, 1.5}, {1, 4}}, Transparency = {{0, 1}, {.2, .55}, {1, 1}},
		Lifetime = {.9, 1.4}, Speed = {2, 4}, SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Top, Rate = 0, LightEmission = 0, Brightness = 1,
		RotSpeed = {-40, 40}, ZOffset = -1})
	K.Flipbook(dark, "Smoke", Enum.ParticleFlipbookMode.OneShot)
	local sparks = ctx:Emitter(body, {Texture = K.Tex.Star, Color = {W, c2}, Size = {.3, 0}, Lifetime = {1.2, 2}, Speed = {3, 6}, SpreadAngle = Vector2.new(30, 30),
		EmissionDirection = Enum.NormalId.Top, Rate = 0, Brightness = 5, Acceleration = V3(0, 2, 0)})
	local t0, t1 = o.T0 or 0, o.T1 or 99
	ctx:Every(function(t)
		body.CFrame = (ctx.Performer and ctx.Performer.Alive and ctx.Performer.Root.CFrame or ctx.Hrp.CFrame) * CFrame.new(0, -2.2, 0)
		local k = K.Soft(t, t0, t1, .3, .5)
		sheet.Rate = (o.Rate or 34) * k * (ctx.Quality or 1)
		dark.Rate = 10 * k * (ctx.Quality or 1)
		sparks.Rate = 22 * k * (ctx.Quality or 1)
		if t > t1 + 1 then return true end
	end)
end
-- arc sweeps: streaks that orbit the body and then peel off and fly out of frame (the ref1 arcs). One every Period.
function K.Sweeps(ctx, o)
	local c1, c2 = o.Colors[1], o.Colors[2]
	local R, H = o.Radius or 5, o.Height or 3
	ctx:Repeat(o.T0 or 0, o.T1 or 3, o.Period or .22, function(i)
		local a0 = rng:NextNumber(0, TAU)
		local dirn = i % 2 == 0 and 1 or -1
		local h0 = H + rng:NextNumber(-1.5, 1.5)
		local tilt = rng:NextNumber(-.5, .5)
		local centre = ctx.Base.Position
		ctx:Streak(function(u)
			local orbit = math.min(1, u / .6)
			local a = a0 + dirn * orbit * math.pi * 1.3
			local out = math.max(0, (u - .6) / .4)
			local r = R * (1 + out * out * 6)
			local y = h0 + math.sin(orbit * math.pi) * 2 * tilt + out * out * (o.Climb or 7)
			return centre + K.Polar(a, r, y)
		end, o.Dur or .55, {W, c1, c2}, o.Width or .7, o.Life or .32)
	end)
end
-- a vertical cage of streaks round the body with a translucent column inside (the pickup_b cylinder of light)
function K.Cage(ctx, o)
	local c1, c2 = o.Colors[1], o.Colors[2]
	local R, H = o.Radius or 3.2, o.Height or 9
	local base = ctx:Part({Transparency = 1, Size = V3(R * 2, .4, R * 2)})
	local streaks = ctx:Emitter(base, {Texture = K.Tex.Streak, Color = {W, c1, c2}, Size = {{0, 2.4}, {.5, 3.6}, {1, 1}}, Transparency = {{0, 1}, {.06, 0}, {.7, .2}, {1, 1}},
		Lifetime = {.45, .7}, Speed = {H * 1.6, H * 2.2}, SpreadAngle = Vector2.new(2, 2), EmissionDirection = Enum.NormalId.Top, Rate = 0, Brightness = 5,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = {{0, 1.6}, {1, 2.2}}, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface})
	local column = ctx:Part({Shape = Enum.PartType.Cylinder, Material = Enum.Material.Glass, Color = c2, Transparency = 1, Size = V3(.1, .1, .1)})
	local tex = Instance.new("Texture")
	tex.Texture = K.Tex.Nebula
	tex.Color3 = c1
	tex.Transparency = .5
	tex.StudsPerTileU, tex.StudsPerTileV = 6, 6
	tex.Face = Enum.NormalId.Right
	tex.Parent = column
	local core = ctx:Part({Shape = Enum.PartType.Cylinder, Color = c1, Transparency = 1, Size = V3(.1, .1, .1)})
	local top = ctx:Att(V3(0, H, 0))
	local topRing = ctx:Emitter(top, {Texture = K.Tex.Ring, Color = {W, c2}, Size = {{0, R * 2}, {1, R * 2.6}}, Transparency = {{0, .2}, {1, 1}}, Lifetime = .9, Rate = 0,
		LockedToPart = true, Rotation = {0, 360}, Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Speed = .02, EmissionDirection = Enum.NormalId.Top, Brightness = 3})
	local t0, t1 = o.T0 or 0, o.T1 or 3
	ctx:Every(function(t)
		local root = ctx.Performer and ctx.Performer.Alive and ctx.Performer.Root.CFrame or ctx.Hrp.CFrame
		local feet = CFrame.new(root.Position) * CFrame.new(0, -2.6, 0)
		base.CFrame = feet
		local k = K.Soft(t, t0, t1, .25, .4)
		streaks.Rate = (o.Rate or 60) * k * (ctx.Quality or 1)
		topRing.Rate = k > .5 and 2 or 0
		local mid = feet * CFrame.new(0, H * k / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		column.Size = V3(math.max(.1, H * k), R * 2 * k + .01, R * 2 * k + .01)
		column.CFrame = mid * CFrame.Angles(t * .4, 0, 0)
		column.Transparency = 1 - .35 * k
		core.Size = V3(math.max(.1, H * k), R * .5 * k + .01, R * .5 * k + .01)
		core.CFrame = mid
		core.Transparency = 1 - .5 * k
		tex.OffsetStudsV = (tex.OffsetStudsV + .12) % 6
		if t > t1 + 1 then return true end
	end)
	return {Burst = function()
		ctx:Burst(base.Position + V3(0, H * .5, 0), K.Count(ctx, 50), {Texture = K.Tex.Streak, Color = {W, c1, c2}, Size = {{0, 2}, {1, 4}}, Lifetime = {.3, .5}, Speed = {30, 60},
			SpreadAngle = Vector2.new(90, 90), Orientation = Enum.ParticleOrientation.VelocityParallel, Brightness = 5, Drag = 3})
		K.ShockRing(ctx, K.GroundCF(ctx, base.Position, .2), 4, 34, c2, .5, .5)
	end}
end
-- a big mesh in the sky: irises in at In, hangs at Height (tilted or facing the camera), leaves at Out.
-- o: Mesh, Height, Tilt (radians, 0 = flat), Face ("camera"), Scale, Color, In, Out, Spin, Material, Transparency,
-- Behind (studs away from the camera direction), Rise (seconds). Returns the part plus a Pos() reader.
function K.Monument(ctx, o)
	local m = K.Mesh(ctx, o.Mesh, {Color = o.Color or W, Material = o.Material or Enum.Material.Neon, Transparency = 1})
	if not m:IsA("MeshPart") then m.Size = o.FallbackSize or V3(16, .2, 16) m:SetAttribute("BaseSize", m.Size) end
	local back = K.Behind(ctx)
	local glowAtt = ctx:Att(V3(0, o.Height or 12, 0))
	local glow = ctx:Emitter(glowAtt, {Texture = K.Tex.Glow, Color = {W, o.Color or W}, Size = (o.Scale or 1) * 22, Transparency = {{0, 1}, {.1, .55}, {.9, .6}, {1, 1}},
		Lifetime = 1.2, Rate = 0, LockedToPart = true, Brightness = 2})
	local light = ctx:Light(glowAtt, o.Color or W, 40, 0)
	local M = {Part = m}
	function M.Pos() return m.Position end
	ctx:Every(function(t)
		local k = K.Env(t, o.In or 0, o.Out or 99, o.Rise or .35, o.Fall or .5)
		local centre = ctx.Base.Position + back * (o.Behind or 0) + V3(0, (o.Height or 12) + math.sin(t * 1.3) * .3, 0)
		glowAtt.WorldPosition = centre
		local cf
		if o.Face == "camera" then
			local cam = workspace.CurrentCamera
			local eye = cam and cam.CFrame.Position or (centre + back)
			cf = CFrame.lookAt(centre, eye) * CFrame.Angles(math.pi / 2, 0, 0) -- mesh Y up faces the camera
		else
			cf = CFrame.new(centre) * CFrame.Angles(o.Tilt or 0, (o.Spin or .2) * t, 0)
		end
		if o.Spin and o.Face == "camera" then cf = cf * CFrame.Angles(0, o.Spin * t, 0) end
		K.Place(m, cf, (o.Scale or 1) * math.max(.02, k))
		m.Transparency = k > .02 and (o.Transparency or 0) or 1
		glow.Rate = k > .3 and 1.5 or 0
		light.Brightness = (o.Light or 4) * k
		if t > (o.Out or 99) + .1 then m:Destroy() return true end
	end)
	return M
end
-- the shared charge-up before t = 0 (ctx.Pre seconds long): the double crouches, a dark sigil irises open underfoot,
-- ambient dust is sucked in to the chest, the lights dim, FOV narrows. No colour: t = 0 is the detonation.
function K.ChargeUp(ctx, P, o)
	o = o or {}
	local pre = ctx.Pre or 0
	if pre <= 0 then return end
	local c1, c2, c3, dark = K.Palette(ctx.Def)
	local sig = K.Mesh(ctx, o.Sigil or "TickSigil", {Color = dark, Material = Enum.Material.SmoothPlastic})
	if not sig:IsA("MeshPart") then sig.Size = V3(12, .06, 12) sig:SetAttribute("BaseSize", sig.Size) end
	-- dust spawns on a box shell round the body and flies inward to the chest (the inhale)
	local shell = ctx:Part({Transparency = 1, Size = V3(16, 10, 16)})
	local suck2 = ctx:Emitter(shell, {Texture = K.Tex.Star, Color = {c3, c1, W}, Size = {{0, .35}, {1, .05}}, Transparency = {{0, 1}, {.15, .1}, {1, 0}}, Lifetime = pre * .8,
		Speed = {9 / math.max(.5, pre), 13 / math.max(.5, pre)}, Rate = 0, Brightness = 3, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Drag = -1.5})
	local ground = K.GroundCF(ctx, ctx.Base.Position, .06)
	local dim = ctx.Local and ctx:Grade({Brightness = -.12, Saturation = -.25, Contrast = .12}, pre * .6, pre * .4, .35)
	K.FOV(ctx, -4, pre * .7, .25)
	ctx:Every(function(t)
		if t >= 0 then sig:Destroy() shell:Destroy() return true end
		local u = 1 + t / pre
		local k = FX.ease(u / .5)
		K.Place(sig, ground * CFrame.Angles(0, u * .4, 0), (o.SigilScale or 1) * k)
		sig.Transparency = .15 + .25 * (1 - k)
		shell.CFrame = ctx.Hrp.CFrame * CFrame.new(0, 1, 0)
		suck2.Rate = 60 * k * (ctx.Quality or 1)
		if P then P:Toward(o.Pose or "Crouch", FX.ease(u / .7) * (o.PoseK or .9)) end
	end)
	ctx:At(-pre + .05, function() if P then P:Show() end end)
	return sig
end
-- the ember-gather / glitch title: wraps ctx:Title and adds a burst at the letters
function K.Title(ctx, at, style, height)
	ctx:Title(at, height)
	ctx:At(at + .05, function()
		local bb = ctx.TitleGui
		local a = bb and bb.Adornee
		if not a then return end
		local c1, c2 = K.Palette(ctx.Def)
		local e = ctx:Emitter(a, {Texture = style == "glitch" and K.Tex.Streak or K.Tex.Flame, Color = {W, c1, c2}, Size = {{0, .5}, {.3, 1}, {1, 0}}, Transparency = {{0, .2}, {1, 1}},
			Lifetime = {.5, .9}, Speed = {3, 7}, SpreadAngle = Vector2.new(style == "glitch" and 90 or 30, 20), EmissionDirection = Enum.NormalId.Top, Rate = 0, Brightness = 3,
			Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume})
		e:Emit(K.Count(ctx, 40))
	end)
end

---------------------------------------------------------------- rewind buffer (Chrono)
-- Track parts' CFrame + Transparency every frame; Play() runs everything backward at Speed and calls OnDone.
function K.Rewind(ctx)
	local R = {Tracked = {}, Frames = {}, Playing = false}
	function R:Track(part) if part and part:IsA("BasePart") then table.insert(self.Tracked, part) end end
	function R:TrackAll(list) for _, p in list do self:Track(p) end end
	ctx:Every(function()
		if R.Playing then return true end
		local snap = {}
		for _, p in R.Tracked do if p.Parent then snap[p] = {p.CFrame, p.Transparency} end end
		table.insert(R.Frames, snap)
		if #R.Frames > 600 then table.remove(R.Frames, 1) end
	end)
	function R:Play(speed, onDone)
		self.Playing = true
		local i = #self.Frames
		-- freeze every emitter we own
		for _, d in ctx.Folder:GetDescendants() do if d:IsA("ParticleEmitter") then d.TimeScale = 0 end end
		ctx:Every(function()
			i -= math.max(1, math.floor(speed or 3))
			if i < 1 then
				for _, p in self.Tracked do if p.Parent then p.Transparency = 1 end end
				for _, d in ctx.Folder:GetDescendants() do if d:IsA("ParticleEmitter") then d.TimeScale = 1 end end
				if onDone then onDone() end
				return true
			end
			local snap = self.Frames[i]
			for p, v in snap do if p.Parent then p.CFrame = v[1] p.Transparency = v[2] end end
			return false
		end)
	end
	return R
end

---------------------------------------------------------------- chest window guard
-- the chest window: a 3 x 4 stud box on the torso that persistent effects stay out of. k(pos) returns how much a
-- thing at pos should fade (0 inside the window, 1 outside) so orbiters can dip as they cross the front.
function K.Window(ctx)
	return function(pos)
		local cam = workspace.CurrentCamera
		local torso = (ctx.Performer and ctx.Performer.Alive and ctx.Performer.Torso or ctx.Hrp).Position
		if not cam then return 1 end
		local eye = cam.CFrame.Position
		local toT = torso - eye
		local toP = pos - eye
		if toP.Magnitude > toT.Magnitude + .5 then return 1 end -- behind the body
		local proj = toP:Dot(toT.Unit)
		if proj <= 0 then return 1 end
		local lateral = (toP - toT.Unit * proj).Magnitude * (toT.Magnitude / proj)
		return math.clamp((lateral - 1.5) / 1.5, 0, 1)
	end
end

return K
