-- Celebrations: the special celebration catalog (shared by server and client).
-- A special celebration is a huge glowing VFX show round your character. The one you equip plays on top of
-- the usual party whenever a throw lands gold or rainbow (final luck x4 or more, Config.Celebrations tier 3+),
-- and when you tame a pet at that tier. Everyone nearby sees it.
-- Kinds:
--   "Unlock": earned in game (Oct 5 2026 progression), one of two ways (Earn):
--             Earn = "Shop":  bought for Coins on the Lasso Shop shelf, after the 12 lassos.
--             Earn = "Quest": a celebration quest chain (Quest = {Name, Need = best lasso luck, Steps}). It starts by
--                            itself once your best lasso is lucky enough; steps go in order and show in the Quests
--                            window. SkipPassId / SkipPrice: an optional Robux game pass in the STORE that gives it
--                            straight away (SkipPassId 0 = not created yet: Studio grants it, live shows SOON).
--             Grant one from any server script with ServerStorage.CelebrationAdmin:Invoke(player, "grant", id).
--             Set FreeForAll = true on one to give it to every player.
--   "Robux":  a game pass each. PassId 0 = not created yet (Studio grants it for the session; a live server
--             shows it as SOON). Price is only the label shown on the button; the real price is the pass's.
-- Effects live in FarmLasso.CelebrationFX (one builder per Id). Saved state: DataStore "FarmLassoCelebrations_v1".
local M = {}
local rgb = Color3.fromRGB

M.MinTier = 3 -- 3 = gold (x4 luck), 4 = rainbow (x10)
M.Cooldown = 5 -- seconds between two plays for one player (server-checked)
M.ViewRange = 320 -- other players see it within this many studs
-- Rarity sets (Oct 5 2026): after a gold or rainbow catch, the caught animal's rarity picks how big the show is.
-- Set 1: Common, Uncommon, Rare (short accent). Set 2: Epic, Legendary (mid show). Set 3: Mythic, Secret (full).
M.SetByRarity = {1, 1, 1, 2, 2, 3, 3}
M.Set1MinTier = 4 -- Set 1 only plays on rainbow throws (final luck x10+); Sets 2 and 3 on gold or rainbow (Will, Oct 5)
function M.SetFor(rarity) return M.SetByRarity[math.clamp(math.floor(tonumber(rarity) or 1), 1, 7)] or 1 end

-- Quest step kinds (FarmLassoCelebrations counts them from GuildQuests.Advance events):
--   Throw2 = throws at x2 or better, Throw4 = x4 throws, Catch = any animal, Rarity = an animal of rarity >= R
--   (3 Rare, 4 Epic, 5 Legendary, 6 Mythic), Earn = coins earned at your ranch, Guild = guild quests finished in total.
M.StepText = {
	Throw2 = "Land %s throws at x2 or better", Throw4 = "Land %s x4 throws", Catch = "Rope %s animals",
	Rarity = "Rope %s %s animals", Earn = "Earn %s coins at your ranch", Guild = "Finish %s guild quests (all time)",
}
M.RarityWord = {[3] = "Rare or better", [4] = "Epic or better", [5] = "Legendary or better", [6] = "Mythic or Secret"}

M.List = {
	{Id = "StarfallHalo", Name = "Starfall Halo", Kind = "Unlock", FreeForAll = false, Order = 1, Earn = "Shop", Coins = 5000000,
		Text = "A halo opens in the sky and pours a pillar of starlight on you.",
		Colors = {rgb(200, 245, 255), rgb(90, 200, 255), rgb(255, 120, 190)}},
	{Id = "ThunderStampede", Name = "Thunder Stampede", Kind = "Unlock", FreeForAll = false, Order = 2, Earn = "Shop", Coins = 15000000,
		Text = "Blue lightning crawls the ground and bolts slam down all round you.",
		Colors = {rgb(220, 235, 255), rgb(80, 140, 255), rgb(40, 50, 170)}},
	{Id = "GoldenTornado", Name = "Golden Tornado", Kind = "Unlock", FreeForAll = false, Order = 3, Earn = "Shop", Coins = 50000000,
		Text = "Rune rings stack in a golden storm, then a beam slams down on you.",
		Colors = {rgb(255, 246, 200), rgb(255, 196, 60), rgb(255, 120, 150)}},
	{Id = "GalaxyLasso", Name = "Galaxy Lasso", Kind = "Unlock", FreeForAll = false, Order = 4, Earn = "Quest",
		Quest = {Name = "Stargazer", Need = 1.5, Steps = {{"Throw2", 15}, {"Rarity", 5, 3}, {"Throw4", 3}}},
		Text = "A spiral galaxy spins at your feet under a glowing star sigil.",
		Colors = {rgb(210, 250, 255), rgb(110, 175, 240), rgb(70, 60, 200)}},
	{Id = "BlossomBurst", Name = "Blossom Burst", Kind = "Unlock", FreeForAll = false, Order = 5, Earn = "Quest",
		Quest = {Name = "Blossom Trail", Need = 2.05, Steps = {{"Throw2", 60}, {"Rarity", 10, 4}, {"Throw4", 15}, {"Guild", 15}}},
		Text = "Pink god-rays, star flares and plasma orbs burst out of you.",
		Colors = {rgb(255, 225, 240), rgb(246, 153, 194), rgb(150, 108, 214)}},
	{Id = "EventHorizon", Name = "Event Horizon", Kind = "Robux", PassId = 0, Price = 399, Order = 6,
		Text = "A black hole tears open above you, swallows the sky and goes supernova.",
		Colors = {rgb(255, 239, 223), rgb(255, 150, 110), rgb(140, 36, 30)}},
	{Id = "SpiritStampede", Name = "Spirit Stampede", Kind = "Robux", PassId = 0, Price = 799, Order = 7,
		Text = "A portal opens and a herd of ghost animals gallops round you into the sky.",
		Colors = {rgb(242, 228, 249), rgb(160, 110, 255), rgb(255, 210, 110)}},
	{Id = "PrismSupernova", Name = "Prism Supernova", Kind = "Robux", PassId = 0, Price = 1499, Order = 8,
		Text = "Time freezes, a star explodes in every colour and crowns you in light.",
		Colors = {rgb(255, 255, 255), rgb(255, 90, 220), rgb(60, 200, 255)}},
	{Id = "Stormbreaker", Name = "Stormbreaker", Kind = "Unlock", FreeForAll = false, Order = 9, Icon = "Clover", Earn = "Quest",
		Quest = {Name = "Storm Chaser", Need = 1.85, Steps = {{"Throw2", 40}, {"Rarity", 5, 4}, {"Throw4", 10}, {"Guild", 10}}},
		Text = "A thunder crown splits the sky. Braided lightning crashes into an electric shockwave.",
		Colors = {rgb(230,255,255), rgb(40,190,255), rgb(45,40,170)}},
	{Id = "PhoenixRebirth", Name = "Phoenix Rebirth", Kind = "Unlock", FreeForAll = false, Order = 10, Icon = "Star", Earn = "Quest", SkipPassId = 0, SkipPrice = 1999,
		Quest = {Name = "Rise of the Phoenix", Need = 2.85, Steps = {{"Throw4", 60}, {"Rarity", 10, 5}, {"Earn", 2000000}, {"Guild", 35}, {"Catch", 600}}},
		Text = "Immense flame wings unfurl, launch a phoenix spiral, then explode into golden embers.",
		Colors = {rgb(255,246,190), rgb(255,125,30), rgb(170,20,55)}},
	{Id = "AstralAscension", Name = "Astral Ascension", Kind = "Unlock", FreeForAll = false, Order = 11, Icon = "Star", Earn = "Quest",
		Quest = {Name = "Star Shepherd", Need = 2.3, Steps = {{"Catch", 200}, {"Rarity", 3, 5}, {"Throw4", 25}, {"Guild", 20}}},
		Text = "Celestial wings, orbiting stars and a radiant halo lift a constellation into the sky.",
		Colors = {rgb(235,255,255), rgb(110,170,255), rgb(130,45,220)}},
	{Id = "ChronoRift", Name = "Chrono Rift", Kind = "Unlock", FreeForAll = false, Order = 12, Icon = "Lasso", Earn = "Quest", SkipPassId = 0, SkipPrice = 2499,
		Quest = {Name = "Time Rancher", Need = 3.2, Steps = {{"Throw4", 120}, {"Rarity", 25, 5}, {"Earn", 10000000}, {"Guild", 60}, {"Catch", 1500}}},
		Text = "A giant time sigil freezes its shards, reverses their orbit, and shatters into a rift.",
		Colors = {rgb(210,255,225), rgb(45,255,175), rgb(35,80,130)}},
}
M.ById = {}
for _, c in M.List do M.ById[c.Id] = c end

-- "Land 15 throws at x2 or better" for a step {Kind, Goal, Rarity}
function M.StepLabel(step)
	local kind, goal = step[1], step[2]
	local n = tostring(goal):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	if kind == "Rarity" then
		if goal == 1 and step[3] == 6 then return "Rope a Mythic or Secret animal" end
		return string.format(M.StepText.Rarity, n, M.RarityWord[step[3]] or "rare")
	end
	return string.format(M.StepText[kind] or "%s", n)
end
-- the order the shop / quests sort them in: cheapest and shortest first
function M.ShopList()
	local t = {}
	for _, c in M.List do if c.Earn == "Shop" then table.insert(t, c) end end
	table.sort(t, function(a, b) return a.Coins < b.Coins end)
	return t
end

return M

