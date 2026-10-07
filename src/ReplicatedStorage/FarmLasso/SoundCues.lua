-- FarmLasso.SoundCues: every cue the game plays, by name (Oct 7 2026). See docs/sound-pitch.md section 3.1.
-- Fields: File (pack file stem; default is the snake_case of the name; variants <stem>_1.. are found automatically),
-- Volume (0..1 base), Pitch ({lo, hi} random spread, or a number), Group (Music / SFX / UI / Celebration / Ambience),
-- Cooldown (s; a cue can't start twice inside it), Min / Max (3D rolloff studs when played with At), Loop = true with
-- Curve = {Pitch = {lo, hi}, Volume = {lo, hi}} for handle:Set(intensity), FadeIn (s), RandomStart (loops; default true).
local function oneShot(file, vol, pitch, extra)
	local d = {File = file, Volume = vol, Pitch = pitch or {.95, 1.05}}
	if extra then for k, v in extra do d[k] = v end end
	return d
end
local function loop(file, vol, curve, extra)
	local d = {File = file, Volume = vol, Loop = true, Curve = curve, Pitch = 1}
	if extra then for k, v in extra do d[k] = v end end
	return d
end
local UI = {Group = "UI", Cooldown = .03}
local CEL = {Group = "Celebration", Min = 10, Max = 140}
local CELL = {Group = "Celebration", Min = 10, Max = 140, Loop = true}
local STEP = {Min = 4, Max = 25, Cooldown = .08}
local ANIMAL = {Min = 8, Max = 70, Cooldown = .15}

local M = {
	---------------------------------------------------------------- music and ambience
	MusicCountry = loop("music_countryside", 1, nil, {Group = "Music", FadeIn = 2, RandomStart = false}),
	AmbBirds = loop("amb_birds", .8, nil, {Group = "Ambience", FadeIn = 3}),
	AmbWind = loop("amb_wind", .6, {Volume = {.5, 1}}, {Group = "Ambience", FadeIn = 3}),
	AmbFountain = loop("amb_fountain", 1, nil, {Group = "Ambience", FadeIn = 2, Min = 12, Max = 70}),

	---------------------------------------------------------------- the lasso loop
	LassoCharge = loop("lasso_charge_loop", .9, {Pitch = {.8, 1.6}, Volume = {.3, 1}}, {FadeIn = .12}),
	MeterGood = oneShot("meter_good", .55, {.98, 1.02}),
	MeterPerfect = oneShot("meter_perfect", .65, {.98, 1.02}),
	MeterMega = oneShot("meter_mega", .75, {.98, 1.02}),
	StingGood = oneShot("sting_good", .7, 1),
	StingPerfect = oneShot("sting_perfect", .8, 1),
	StingMega = oneShot("sting_mega", .9, 1),
	Throw = oneShot("throw_whoosh", .8, {.92, 1.08}),
	ThrowBig = oneShot("throw_big", .8, {.95, 1.05}),
	RopeLand = oneShot("rope_land", .8, {.9, 1.1}, {Min = 6, Max = 60}),
	LuckTick = oneShot("luck_tick", .6, 1, {Cooldown = .03}),
	LuckImpact1 = oneShot("luck_impact_1", .8, 1),
	LuckImpact2 = oneShot("luck_impact_2", .85, 1),
	LuckImpact3 = oneShot("luck_impact_3", .9, 1),
	LuckImpact4 = oneShot("luck_impact_4", 1, 1),
	Fanfare1 = oneShot("fanfare_1", .75, 1),
	Fanfare2 = oneShot("fanfare_2", .8, 1),
	Fanfare3 = oneShot("fanfare_3", .9, 1),
	Fanfare4 = oneShot("fanfare_4", 1, 1),
	Hooked = oneShot("hooked", .9, {.95, 1.05}, {Min = 6, Max = 60}),
	TugLoop = loop("tug_loop", .8, {Pitch = {.9, 1.3}, Volume = {.4, 1}}, {FadeIn = .15}),
	TugTick = oneShot("tug_tick", .6, {.9, 1.15}, {Cooldown = .06}),
	TugDanger = oneShot("tug_danger", .7, {.97, 1.03}, {Cooldown = .5}),
	CatchPop = oneShot("catch_pop", .9, {.95, 1.05}),
	CatchChime = oneShot("catch_chime", .85, 1),
	RareReveal1 = oneShot("rare_reveal_1", .7, 1),
	RareReveal2 = oneShot("rare_reveal_2", .75, 1),
	RareReveal3 = oneShot("rare_reveal_3", .8, 1),
	RareReveal4 = oneShot("rare_reveal_4", .85, 1),
	RareReveal5 = oneShot("rare_reveal_5", .9, 1),
	RareReveal6 = oneShot("rare_reveal_6", .95, 1),
	RareReveal7 = oneShot("rare_reveal_7", 1, 1),
	Escape = oneShot("rope_slip", .8, {.95, 1.05}),
	BagFull = oneShot("bag_full", .7, 1, {Cooldown = .8}),
	SellShower = oneShot("coin_shower", .9, 1),
	SellDing = oneShot("register_ding", .9, 1),
	Buy = oneShot("purchase_chime", .8, 1, UI),
	Equip = oneShot("equip_click", .7, {.95, 1.05}, UI),
	NoCoins = oneShot("error_buzz", .6, 1, {Group = "UI", Cooldown = .3}),
	QuestAccept = oneShot("quest_accept", .75, 1, UI),
	QuestTick = oneShot("quest_tick", .6, {.98, 1.04}, {Group = "UI", Cooldown = .15}),
	QuestComplete = oneShot("quest_complete", .9, 1, UI),
	HerdJoin = oneShot("herd_join", .8, {.95, 1.05}),

	---------------------------------------------------------------- menus
	UIHover = oneShot("ui_hover", .25, {.97, 1.03}, {Group = "UI", Cooldown = .05}),
	UIClick = oneShot("ui_click", .6, {.96, 1.04}, UI),
	PanelOpen = oneShot("panel_open", .6, {.97, 1.03}, {Group = "UI", Cooldown = .12}),
	PanelClose = oneShot("panel_close", .6, {.97, 1.03}, {Group = "UI", Cooldown = .12}),
	TabSwitch = oneShot("tab_switch", .55, {.97, 1.03}, UI),

	---------------------------------------------------------------- footsteps (3D at the feet)
	StepGrass = oneShot("step_grass", .25, {.9, 1.1}, STEP),
	StepDirt = oneShot("step_dirt", .25, {.9, 1.1}, STEP),
	StepStone = oneShot("step_stone", .25, {.9, 1.1}, STEP),
	StepWood = oneShot("step_wood", .25, {.9, 1.1}, STEP),

	---------------------------------------------------------------- celebrations, shared (3D at the player)
	CelChargeUp = oneShot("cel_charge_up", .8, 1, CEL),
	CelDetonate = oneShot("cel_detonate", 1, {.97, 1.03}, CEL),
	CelShockwave = oneShot("cel_shockwave", .8, {.95, 1.05}, CEL),
	CelWhooshS = oneShot("cel_whoosh_s", .6, {.9, 1.1}, CEL),
	CelWhooshL = oneShot("cel_whoosh_l", .75, {.95, 1.05}, CEL),
	CelImpact = oneShot("cel_impact", .9, {.97, 1.03}, CEL),
	CelShimmer = oneShot("cel_shimmer", .6, {.97, 1.03}, CEL),
	CelRiser = oneShot("cel_riser", .7, 1, CEL),
	CelLand = oneShot("cel_land", .85, {.95, 1.05}, CEL),
	CelTitle = oneShot("cel_title", .7, 1, CEL),
	CelBed = loop("cel_bed", .45, {Volume = {.4, 1}, Pitch = {1, 1.06}}, {Group = "Celebration", Min = 10, Max = 140, FadeIn = .8}),

	---------------------------------------------------------------- celebrations, signatures
	StarChime = oneShot("star_chime", .8, 1, CEL),
	StarTwinkle = oneShot("star_twinkle", .5, {.9, 1.2}, {Group = "Celebration", Min = 6, Max = 90, Cooldown = .05}),
	HaloLand = oneShot("halo_land", .85, 1, CEL),
	ThunderCrack = oneShot("thunder_crack", 1, {.95, 1.05}, CEL),
	ArcCrackle = loop("arc_crackle", .55, {Volume = {.3, 1}}, CELL),
	BullCharge = oneShot("bull_charge", .8, {.9, 1.1}, {Group = "Celebration", Min = 8, Max = 110, Cooldown = .12}),
	WindFunnel = loop("wind_funnel", .7, {Pitch = {.85, 1.25}, Volume = {.3, 1}}, CELL),
	CoinSpiral = oneShot("coin_spiral", .8, 1, CEL),
	CoinRain = loop("coin_rain", .6, {Volume = {.2, 1}}, CELL),
	TornadoSlam = oneShot("tornado_slam", 1, 1, CEL),
	RopeWhirl = loop("rope_whirl", .7, {Pitch = {.8, 1.4}, Volume = {.4, 1}}, CELL),
	CosmicHum = loop("cosmic_hum", .55, {Volume = {.3, 1}, Pitch = {.95, 1.1}}, CELL),
	ConstellationPull = oneShot("constellation_pull", .8, 1, CEL),
	TreeGrow = oneShot("tree_grow", .8, {.95, 1.05}, CEL),
	PetalShimmer = loop("petal_shimmer", .5, {Volume = {.2, 1}}, CELL),
	LotusBloom = oneShot("lotus_bloom", .8, 1, CEL),
	SuckDrone = loop("suck_drone", .9, {Pitch = {1, .45}, Volume = {.5, 1}}, CELL),
	Supernova = oneShot("supernova", 1, 1, {Group = "Celebration", Min = 14, Max = 200}),
	PortalOpen = oneShot("portal_open", .85, 1, CEL),
	GhostHooves = loop("ghost_hooves", .7, {Volume = {.3, 1}, Pitch = {.95, 1.15}}, CELL),
	SpiritBellow = oneShot("spirit_bellow", .9, {.95, 1.05}, CEL),
	GlassShatter = oneShot("glass_shatter", .9, {.95, 1.05}, CEL),
	LighthouseSweep = oneShot("lighthouse_sweep", .65, 1, {Group = "Celebration", Min = 10, Max = 140, Cooldown = .08}),
	GemCrown = oneShot("gem_crown", .85, 1, CEL),
	StormRoll = loop("storm_roll", .7, {Volume = {.3, 1}, Pitch = {.9, 1.05}}, CELL),
	IceCrack = oneShot("ice_crack", .85, {.95, 1.05}, CEL),
	ThunderPunch = oneShot("thunder_punch", 1, 1, CEL),
	FireWhoosh = oneShot("fire_whoosh", .85, {.95, 1.05}, CEL),
	CharCrackle = loop("char_crackle", .55, {Volume = {.3, 1}}, CELL),
	WingFlap = oneShot("wing_flap", .7, {.9, 1.1}, {Group = "Celebration", Min = 8, Max = 110, Cooldown = .1}),
	SunDive = oneShot("sun_dive", .9, 1, CEL),
	EmberSparkle = oneShot("ember_sparkle", .75, 1, CEL),
	StepChime = oneShot("step_chime", .75, 1, {Group = "Celebration", Min = 8, Max = 110, Cooldown = .05}),
	StarMapResolve = oneShot("star_map_resolve", .85, 1, CEL),
	FeatherLand = oneShot("feather_land", .7, 1, CEL),
	ClockTick = loop("clock_tick", .6, {Volume = {.4, 1}}, {Group = "Celebration", Min = 10, Max = 140, Loop = true, RandomStart = false}),
	ReverseWhoosh = oneShot("reverse_whoosh", .8, 1, CEL),
	Rewind = oneShot("rewind", .85, 1, CEL),
	GlassBreak = oneShot("glass_break", .9, {.95, 1.05}, CEL),
}

-- the 24 roster animals (3D, two variants each in the pack) and the fallback
M.Species = {"Chick", "PuddleDuck", "Pig", "Bunny", "WoollySheep", "BillyGoat", "DairyCow", "Llama", "ChestnutHorse",
	"HighlandBull", "GoldenRooster", "UnicornPony", "Hen", "BarnCat", "Goose", "Sheepdog", "Turkey", "Donkey", "BarnOwl",
	"Peacock", "Reindeer", "RedFox", "Bison", "Ostrich"}
for _, sp in M.Species do
	M["Animal" .. sp] = oneShot(nil, .7, {.93, 1.07}, ANIMAL) -- File defaults to animal_<snake>
end
M.AnimalGeneric = oneShot("animal_generic", .6, {.9, 1.1}, ANIMAL)

return M
