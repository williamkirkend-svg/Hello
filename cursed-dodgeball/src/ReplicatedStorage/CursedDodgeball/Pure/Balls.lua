-- Cursed Dodgeball ball catalog and per-round draws. Pure: no Roblox requires.
-- Behaviour numbers here are the ones the server flight code reads; the full design is in balls.md.
local Balls = {}

local function def(id, name, family, extra)
	local d = {
		id = id,
		name = name,
		family = family,
		consumable = false,
		finalPool = true,
		speedMul = 1,
		colour = { 1, 1, 1 },
		size = 2, -- diameter in studs
	}
	if extra then for k, v in extra do d[k] = v end end
	return d
end

Balls.Defs = {
	Plain = def("Plain", "Dodgeball", "Plain", { colour = { 0.85, 0.15, 0.15 } }),
	-- Flight family: how it moves
	Eye = def("Eye", "Eye Ball", "Flight", { colour = { 0.9, 0.1, 0.1 }, speedMul = 0.8, homingTurnRate = math.rad(25), homingCone = math.rad(30) }),
	Boomerang = def("Boomerang", "Boomerang", "Flight", { colour = { 1, 0.85, 0.1 }, returns = true }),
	Shadow = def("Shadow", "Shadow Ball", "Flight", { colour = { 0.6, 0.8, 1 }, invisibleInFlight = true }),
	Bouncy = def("Bouncy", "Bouncy", "Flight", { colour = { 1, 0.5, 0.1 }, bounces = 3, bounceKeep = 0.9 }),
	-- Impact family: what the hit does
	Giant = def("Giant", "Giant", "Impact", { colour = { 0.1, 0.2, 0.7 }, size = 4, speedMul = 0.6, piercing = true, twoPlayerCatch = true, holderSlow = 0.35 }),
	Glue = def("Glue", "Glue", "Impact", { colour = { 0.2, 0.8, 0.2 }, hitEffect = "Glue", glueSeconds = 3 }),
	Swap = def("Swap", "Swap", "Impact", { colour = { 0.6, 0.2, 0.8 }, hitEffect = "Swap", swapImmunity = 1 }),
	-- Chaos family: timers and lies
	Fuse = def("Fuse", "Fuse", "Chaos", { colour = { 0.1, 0.1, 0.1 }, consumable = true, fuseSeconds = 4, blastRadius = 7 }),
	Moon = def("Moon", "Moon", "Chaos", { colour = { 0.8, 0.8, 0.85 }, speedMul = 0.7, holderGravity = 1 / 3, launchHeight = 20 }),
	Decoy = def("Decoy", "Decoy", "Chaos", { colour = { 1, 1, 1 }, consumable = true, fanCount = 3, fanAngle = math.rad(15) }),
	-- Field family: changes the court
	BlackHole = def("BlackHole", "Black Hole", "Field", { colour = { 0.15, 0.05, 0.25 }, consumable = true, vortexSeconds = 3, vortexRadius = 10 }),
	Paint = def("Paint", "Paint", "Field", { colour = { 1, 0.4, 0.75 }, consumable = true, finalPool = false, splatRadius = 6 }),
}

local function cursedIds(round, exclude)
	local ex = {}
	if exclude then for _, id in exclude do ex[id] = true end end
	local ids = {}
	for id, d in Balls.Defs do
		if id ~= "Plain" and not ex[id] and (round ~= 3 or d.finalPool) then
			table.insert(ids, id)
		end
	end
	table.sort(ids) -- stable order so seeded draws are deterministic
	return ids
end

-- Returns an array of ball ids for the round. Round 1 leaves one slot free for the spectator Wildcard.
function Balls.draw(round, rng, config, exclude)
	local spec = config.Balls.Rounds[round]
	local wantCursed = spec.Cursed
	if round == 1 then wantCursed -= 1 end
	local pool = cursedIds(round, exclude)
	local out = {}
	for _ = 1, spec.Plain do table.insert(out, "Plain") end
	for _ = 1, math.min(wantCursed, #pool) do
		local i = math.floor(rng() * #pool) + 1
		table.insert(out, table.remove(pool, i))
	end
	return out
end

-- Appends the spectator-voted Wildcard to a draw. Returns the new count.
function Balls.addWildcard(draw, id)
	table.insert(draw, id)
	return #draw
end

return Balls
