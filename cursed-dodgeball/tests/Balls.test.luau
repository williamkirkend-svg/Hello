return function(t)
	local Balls = require("../src/ReplicatedStorage/CursedDodgeball/Pure/Balls")
	local Config = require("../src/ReplicatedStorage/CursedDodgeball/Config")

	local cursed = 0
	for id, def in Balls.Defs do
		t.eq(def.id, id, "def id matches key " .. id)
		if id ~= "Plain" then cursed += 1 end
	end
	t.eq(cursed, 12, "twelve cursed balls")
	t.ok(Balls.Defs.Plain, "plain exists")
	t.eq(Balls.Defs.Paint.finalPool, false, "paint not in final pool")
	t.eq(Balls.Defs.Fuse.consumable, true, "fuse consumable")
	t.eq(Balls.Defs.Eye.family, "Flight", "eye family")

	local function seeded(seed)
		local s = seed
		return function()
			s = (s * 1103515245 + 12345) % 2147483648
			return s / 2147483648
		end
	end

	local r1 = Balls.draw(1, seeded(1), Config)
	t.eq(#r1, 7, "round 1 draws 7 (3 cursed + 4 plain, wildcard added later)")
	local plain, seen, dup = 0, {}, false
	for _, id in r1 do
		if id == "Plain" then plain += 1 else
			if seen[id] then dup = true end
			seen[id] = true
		end
	end
	t.eq(plain, 4, "round 1 has 4 plain")
	t.ok(not dup, "no duplicate cursed in round 1")

	local r2 = Balls.draw(2, seeded(2), Config)
	t.eq(#r2, 6, "round 2 draws 6")
	plain = 0
	for _, id in r2 do if id == "Plain" then plain += 1 end end
	t.eq(plain, 1, "round 2 has 1 plain")

	local r3 = Balls.draw(3, seeded(3), Config)
	t.eq(#r3, 4, "final draws 4")
	for _, id in r3 do
		t.ok(id ~= "Plain", "final has no plain")
		t.ok(id ~= "Paint", "final has no paint")
	end

	local ex = Balls.draw(2, seeded(9), Config, { "Eye", "Fuse", "Giant", "Glue", "Swap", "Moon", "Decoy" })
	for _, id in ex do
		t.ok(id ~= "Eye" and id ~= "Fuse" and id ~= "Giant", "excluded ids absent: " .. id)
	end

	local a = table.concat(Balls.draw(1, seeded(42), Config), ",")
	local b = table.concat(Balls.draw(1, seeded(42), Config), ",")
	t.eq(a, b, "seeded draw is deterministic")
	t.ok(Balls.addWildcard(r1, "Boomerang") == 8 or #r1 == 8, "wildcard appends")
end
