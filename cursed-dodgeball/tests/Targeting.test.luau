return function(t)
	local T = require("../src/ReplicatedStorage/CursedDodgeball/Pure/Targeting")
	local cam = { x = 0, y = 5, z = 0 }
	local dir = { x = 0, y = 0, z = 1 }
	local cands = {
		{ id = "near_off", pos = { x = 8, y = 5, z = 5 } }, -- nearer but 58 degrees off axis
		{ id = "centred", pos = { x = 1, y = 5, z = 30 } }, -- further, almost dead ahead
		{ id = "behind", pos = { x = 0, y = 5, z = -10 } },
		{ id = "far", pos = { x = 0, y = 5, z = 200 } },
	}
	t.eq(T.pick(cam, dir, cands, 90, math.rad(60)), "centred", "picks the centred candidate")
	t.eq(T.pick(cam, dir, { cands[4] }, 90, math.rad(60)), nil, "out of range excluded")
	t.eq(T.pick(cam, dir, { cands[3] }, 90, math.rad(60)), nil, "behind the camera excluded")
	t.eq(T.pick(cam, dir, {}, 90, math.rad(60)), nil, "no candidates")

	local order = T.order(cam, dir, cands, 90, math.rad(60))
	t.eq(#order, 2, "order keeps only in-range, in-cone ids")
	t.eq(order[1], "centred", "order sorted by angle")
	t.eq(order[2], "near_off", "second by angle")

	t.eq(T.cycle("centred", order), "near_off", "cycle advances")
	t.eq(T.cycle("near_off", order), "centred", "cycle wraps")
	t.eq(T.cycle("missing", order), "centred", "unknown current starts at first")
	t.eq(T.cycle("x", {}), nil, "empty order gives nil")
end
