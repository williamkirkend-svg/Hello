--!strict
-- VFXAssets: every external-looking thing the celebration needs lives here.
-- Mesh templates: import VFX_Pack.glb into ReplicatedStorage.FarmLasso.VFXMeshes.
-- Textures: Roblox built-ins only, so nothing here needs an upload to work.
-- Swap any entry for your own asset id later without touching the effect code.

local Assets = {}

Assets.MeshFolderPath = { "FarmLasso", "VFXMeshes" } -- under ReplicatedStorage

-- Names must match the objects in VFX_Pack.glb (MeshPart names after import).
Assets.Meshes = {
	GalaxyArm = "VFX_GalaxyArm",
	GalaxyCore = "VFX_GalaxyCore",
	AccretionRing = "VFX_AccretionRing",
	ShockRing = "VFX_ShockRing",
	HaloRing = "VFX_HaloRing",
	RuneRing = "VFX_RuneRing",
	Sigil = "VFX_Sigil",
	ShardA = "VFX_ShardA",
	ShardB = "VFX_ShardB",
	ShardC = "VFX_ShardC",
	OrbitCrystal = "VFX_OrbitCrystal",
	Slash = "VFX_Slash",
	BoltA = "VFX_BoltA",
	BoltB = "VFX_BoltB",
	StarShard = "VFX_StarShard",
	GodRay = "VFX_GodRay",
	BeamColumn = "VFX_BeamColumn",
	Swirl = "VFX_Swirl",
	Wing = "VFX_Wing",
	SpikeHalo = "VFX_SpikeHalo",
}

-- Roblox centres every imported mesh on its bounding box, so a mesh whose
-- natural pivot is elsewhere (a wing root, a spiral centre) needs this offset
-- added back. Values are "bounding-box centre minus pivot" in template units,
-- Roblox axes; multiply by the same scale you apply to Size.
Assets.PivotOffsets = {
	GalaxyArm = Vector3.new(0.636, 0, 1.607),
	Wing = Vector3.new(3.38, 1.458, 0),
	BoltA = Vector3.new(-0.205, -4.969, 0),
	BoltB = Vector3.new(-0.184, -4.923, 0.062),
	BeamColumn = Vector3.new(0, 0.5, 0),
	GodRay = Vector3.new(0, 0.5, 0),
	Slash = Vector3.new(0, 0, 0.676),
	ShardA = Vector3.new(0, 0.6, 0),
	ShardB = Vector3.new(0, 0.25, 0),
}

-- Built-in particle textures that ship with every Roblox client.
Assets.Textures = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Implosion = "rbxasset://textures/particles/explosion01_implosion_main.dds",
}

export type Palette = {
	Name: string,
	Primary: Color3, -- rings, shards
	Secondary: Color3, -- mist, floor
	Accent: Color3, -- bolts, stars, flash tint
	Hot: Color3, -- core / peak flash
	HueCycle: boolean, -- rainbow tier shifts hue over time
}

-- Keyed by celebration tier (1 copper, 2 silver, 3 gold, 4 rainbow). Keep the
-- tier colours apart from the meter-zone colours (aqua / hot pink / lime).
Assets.Palettes = {
	[1] = {
		Name = "Copper",
		Primary = Color3.fromRGB(214, 118, 60),
		Secondary = Color3.fromRGB(120, 62, 30),
		Accent = Color3.fromRGB(255, 170, 90),
		Hot = Color3.fromRGB(255, 230, 190),
		HueCycle = false,
	} :: Palette,
	[2] = {
		Name = "Silver",
		Primary = Color3.fromRGB(205, 220, 240),
		Secondary = Color3.fromRGB(110, 130, 170),
		Accent = Color3.fromRGB(150, 200, 255),
		Hot = Color3.fromRGB(255, 255, 255),
		HueCycle = false,
	} :: Palette,
	[3] = {
		Name = "Gold",
		Primary = Color3.fromRGB(255, 200, 60),
		Secondary = Color3.fromRGB(200, 120, 20),
		Accent = Color3.fromRGB(255, 240, 170),
		Hot = Color3.fromRGB(255, 255, 220),
		HueCycle = false,
	} :: Palette,
	[4] = {
		Name = "Rainbow",
		Primary = Color3.fromRGB(170, 90, 255),
		Secondary = Color3.fromRGB(40, 20, 90),
		Accent = Color3.fromRGB(120, 230, 255),
		Hot = Color3.fromRGB(255, 255, 255),
		HueCycle = true,
	} :: Palette,
}

-- Reveal hold per tier, matching Config.Celebrations / s.FlightEnd in the game.
Assets.Durations = { [1] = 2.6, [2] = 3.3, [3] = 3.8, [4] = 4.2 }

Assets.Titles = {
	[1] = { "NICE!", "x2 THROW" },
	[2] = { "SILVER!", "x4 THROW" },
	[3] = { "GOLDEN!", "x10 THROW" },
	[4] = { "LEGENDARY!!!", "SERVER WIDE" },
}

Assets.Fonts = {
	Title = Enum.Font.LuckiestGuy,
	Body = Enum.Font.FredokaOne,
}

return Assets
