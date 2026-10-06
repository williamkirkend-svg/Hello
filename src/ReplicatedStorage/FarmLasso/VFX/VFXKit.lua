--!strict
-- VFXKit: small, allocation-light building blocks for code-driven effects.
-- A Scene owns everything an effect spawns (parts, emitters, connections,
-- per-frame updaters) and tears it all down in one call. Effects never touch
-- the server; everything here is client-side and lives under the camera so
-- it never replicates.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(script.Parent.VFXAssets)

local Kit = {}

-- --------------------------------------------------------------- easing
-- Small curve library so timelines read as motion, not as numbers.
Kit.Ease = {}

function Kit.Ease.OutBack(t: number, s: number?): number
	local k = s or 1.70158
	t = t - 1
	return t * t * ((k + 1) * t + k) + 1
end

function Kit.Ease.OutCubic(t: number): number
	t = 1 - t
	return 1 - t * t * t
end

function Kit.Ease.InCubic(t: number): number
	return t * t * t
end

function Kit.Ease.OutExpo(t: number): number
	return if t >= 1 then 1 else 1 - 2 ^ (-10 * t)
end

function Kit.Ease.InOutSine(t: number): number
	return -(math.cos(math.pi * t) - 1) / 2
end

function Kit.Ease.OutElastic(t: number): number
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	local c4 = (2 * math.pi) / 3
	return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * c4) + 1
end

-- Remap x from [a, b] to [0, 1], clamped. The workhorse of every timeline.
function Kit.Span(x: number, a: number, b: number): number
	if b <= a then
		return if x >= b then 1 else 0
	end
	return math.clamp((x - a) / (b - a), 0, 1)
end

function Kit.Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- --------------------------------------------------------------- mesh lookup
local meshFolder: Folder? = nil

local function findMeshFolder(): Folder?
	if meshFolder and meshFolder.Parent then
		return meshFolder
	end
	local node: Instance? = ReplicatedStorage
	for _, name in ipairs(Assets.MeshFolderPath) do
		node = if node then node:FindFirstChild(name) else nil
	end
	if node and node:IsA("Folder") then
		meshFolder = node
		return node
	end
	return nil
end

local warned: { [string]: boolean } = {}

-- Returns a fresh anchored, non-colliding MeshPart clone of the named template,
-- or a plain Part stand-in so the effect still runs before the pack is imported.
function Kit.Mesh(key: string, color: Color3?, parent: Instance?): BasePart
	local templateName = Assets.Meshes[key]
	local folder = findMeshFolder()
	local template = if folder and templateName then folder:FindFirstChild(templateName) else nil
	local part: BasePart
	if template and template:IsA("BasePart") then
		part = template:Clone()
	else
		if templateName and not warned[templateName] then
			warned[templateName] = true
			warn(("[VFXKit] mesh %s missing, using a stand-in part"):format(templateName))
		end
		local p = Instance.new("Part")
		p.Size = Vector3.new(1, 1, 1)
		part = p
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Material = Enum.Material.Neon
	part.Color = color or Color3.new(1, 1, 1)
	if part:IsA("MeshPart") then
		part.DoubleSided = true
	end
	part.Parent = parent or workspace.CurrentCamera
	return part
end

-- Base (unit) size of a template so callers can scale proportionally.
function Kit.MeshBaseSize(key: string): Vector3
	local templateName = Assets.Meshes[key]
	local folder = findMeshFolder()
	local template = if folder and templateName then folder:FindFirstChild(templateName) else nil
	if template and template:IsA("BasePart") then
		return template.Size
	end
	return Vector3.new(1, 1, 1)
end

-- --------------------------------------------------------------- scene
export type Updater = (t: number, dt: number) -> ()

export type Scene = {
	Root: Folder,
	Alive: boolean,
	T: number,
	Add: (self: Scene, inst: Instance) -> Instance,
	OnStep: (self: Scene, fn: Updater) -> (),
	Delay: (self: Scene, at: number, fn: () -> ()) -> (),
	Tween: (self: Scene, inst: Instance, info: TweenInfo, goal: { [string]: any }) -> Tween,
	Destroy: (self: Scene) -> (),
}

local SceneMT = {}
SceneMT.__index = SceneMT

function Kit.NewScene(name: string?): Scene
	local root = Instance.new("Folder")
	root.Name = name or "VFXScene"
	root.Parent = workspace.CurrentCamera

	local self = setmetatable({
		Root = root,
		Alive = true,
		T = 0,
		_updaters = {} :: { Updater },
		_timers = {} :: { { at: number, fn: () -> (), done: boolean } },
		_tweens = {} :: { Tween },
		_conn = nil :: RBXScriptConnection?,
	}, SceneMT)

	self._conn = RunService.RenderStepped:Connect(function(dt: number)
		if not self.Alive then
			return
		end
		self.T += dt
		for _, timer in ipairs(self._timers) do
			if not timer.done and self.T >= timer.at then
				timer.done = true
				timer.fn()
			end
		end
		for _, fn in ipairs(self._updaters) do
			fn(self.T, dt)
		end
	end)

	return (self :: any) :: Scene
end

function SceneMT.Add(self: any, inst: Instance): Instance
	inst.Parent = self.Root
	return inst
end

function SceneMT.OnStep(self: any, fn: Updater)
	table.insert(self._updaters, fn)
end

function SceneMT.Delay(self: any, at: number, fn: () -> ())
	table.insert(self._timers, { at = at, fn = fn, done = false })
end

function SceneMT.Tween(self: any, inst: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local tw = TweenService:Create(inst, info, goal)
	table.insert(self._tweens, tw)
	tw:Play()
	return tw
end

function SceneMT.Destroy(self: any)
	if not self.Alive then
		return
	end
	self.Alive = false
	if self._conn then
		self._conn:Disconnect()
	end
	for _, tw in ipairs(self._tweens) do
		tw:Cancel()
	end
	table.clear(self._updaters)
	table.clear(self._timers)
	self.Root:Destroy()
end

-- --------------------------------------------------------------- emitters
export type EmitterSpec = {
	Texture: string?,
	Color: ColorSequence | Color3,
	Size: NumberSequence | number,
	Transparency: NumberSequence?,
	Lifetime: NumberRange?,
	Speed: NumberRange?,
	Rate: number?,
	Spread: Vector2?,
	Acceleration: Vector3?,
	Drag: number?,
	Rotation: NumberRange?,
	RotSpeed: NumberRange?,
	LightEmission: number?,
	Brightness: number?,
	Orientation: Enum.ParticleOrientation?,
	Shape: Enum.ParticleEmitterShape?,
	ShapeInOut: Enum.ParticleEmitterShapeInOut?,
	ZOffset: number?,
}

local function toColorSeq(c: ColorSequence | Color3): ColorSequence
	if typeof(c) == "Color3" then
		return ColorSequence.new(c)
	end
	return c :: ColorSequence
end

local function toNumSeq(n: NumberSequence | number): NumberSequence
	if typeof(n) == "number" then
		return NumberSequence.new(n :: number)
	end
	return n :: NumberSequence
end

function Kit.Emitter(parent: Instance, spec: EmitterSpec): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = spec.Texture or Assets.Textures.Sparkle
	e.Color = toColorSeq(spec.Color)
	e.Size = toNumSeq(spec.Size)
	e.Transparency = spec.Transparency or NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.7, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = spec.Lifetime or NumberRange.new(0.6, 1.2)
	e.Speed = spec.Speed or NumberRange.new(4, 9)
	e.Rate = spec.Rate or 0
	e.SpreadAngle = spec.Spread or Vector2.new(180, 180)
	e.Acceleration = spec.Acceleration or Vector3.zero
	e.Drag = spec.Drag or 2
	e.Rotation = spec.Rotation or NumberRange.new(0, 360)
	e.RotSpeed = spec.RotSpeed or NumberRange.new(-90, 90)
	e.LightEmission = spec.LightEmission or 1
	e.LightInfluence = 0
	e.Brightness = spec.Brightness or 2
	e.Orientation = spec.Orientation or Enum.ParticleOrientation.FacingCamera
	e.Shape = spec.Shape or Enum.ParticleEmitterShape.Sphere
	e.ShapeInOut = spec.ShapeInOut or Enum.ParticleEmitterShapeInOut.Outward
	e.ZOffset = spec.ZOffset or 0
	e.Parent = parent
	return e
end

-- A tiny invisible part that carries attachments/emitters/lights at a point.
function Kit.Anchor(parent: Instance, cf: CFrame): BasePart
	local p = Instance.new("Part")
	p.Name = "VFXAnchor"
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = cf
	p.Parent = parent
	return p
end

function Kit.Light(parent: BasePart, color: Color3, range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

-- --------------------------------------------------------------- colour
function Kit.HueShift(base: Color3, phase: number, sat: number?, val: number?): Color3
	local h, s, v = base:ToHSV()
	return Color3.fromHSV((h + phase) % 1, sat or s, val or v)
end

function Kit.Rainbow(t: number, offset: number?, sat: number?): Color3
	return Color3.fromHSV((t * 0.22 + (offset or 0)) % 1, sat or 0.72, 1)
end

-- --------------------------------------------------------------- shake
-- Deterministic, decaying, multi-frequency shake used by the camera module.
function Kit.Shake(t: number, life: number, amp: number): (Vector3, number)
	if t < 0 or t > life then
		return Vector3.zero, 0
	end
	local k = (1 - t / life)
	k = k * k
	local x = math.sin(t * 71.3) * 0.6 + math.sin(t * 37.1) * 0.4
	local y = math.sin(t * 89.7 + 1.3) * 0.5 + math.sin(t * 43.9 + 0.7) * 0.5
	local roll = math.sin(t * 53.1 + 2.1)
	return Vector3.new(x, y, 0) * amp * k, roll * amp * 0.6 * k
end

return Kit
