return function(t)
	local BF = require("../src/ReplicatedStorage/CursedDodgeball/Pure/BallFlight")
	local Config = require("../src/ReplicatedStorage/CursedDodgeball/Config")
	local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

	local aim = BF.aim({ x = 0, y = 5, z = 0 }, { x = 10, y = 5, z = 0 }, 0, Config)
	t.ok(near(aim.dir.x, 1) and near(aim.dir.y, 0) and near(aim.dir.z, 0), "unit dir toward target")
	t.eq(aim.speed, 60, "quick speed at charge 0")
	t.eq(BF.aim({ x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 3 }, 1, Config).speed, 110, "charged speed at charge 1")
	t.eq(BF.aim({ x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 3 }, 0.5, Config).speed, 85, "speed lerps")
	local diag = BF.aim({ x = 0, y = 0, z = 0 }, { x = 3, y = 4, z = 0 }, 0, Config).dir
	t.ok(near(diag.x, 0.6) and near(diag.y, 0.8), "normalised")

	local p = BF.step({ x = 0, y = 0, z = 0 }, { x = 1, y = 0, z = 0 }, 60, 0.5, 0)
	t.eq(p.x, 30, "moves speed*dt")
	local g = BF.step({ x = 0, y = 10, z = 0 }, { x = 1, y = 0, z = 0 }, 60, 1, 12)
	t.ok(near(g.y, 10 - 6), "gravity drops by half g t^2")

	t.eq(BF.segmentHitsSphere({ x = 0, y = 0, z = 0 }, { x = 10, y = 0, z = 0 }, { x = 5, y = 1, z = 0 }, 2.5), true, "segment through sphere")
	t.eq(BF.segmentHitsSphere({ x = 0, y = 0, z = 0 }, { x = 10, y = 0, z = 0 }, { x = 5, y = 4, z = 0 }, 2.5), false, "segment misses sphere")
	t.eq(BF.segmentHitsSphere({ x = 0, y = 0, z = 0 }, { x = 1, y = 0, z = 0 }, { x = 20, y = 0, z = 0 }, 2.5), false, "sphere beyond segment end")
	t.eq(BF.segmentHitsSphere({ x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 0 }, { x = 1, y = 0, z = 0 }, 2.5), true, "zero-length segment inside sphere")

	t.eq(BF.catchWindow(0, Config), 0.25, "quick window")
	t.eq(BF.catchWindow(1, Config), 0.15, "charged window")

	t.eq(BF.validateThrow({ x = 0, y = 0, z = 0 }, { x = 3, y = 0, z = 0 }, 6), true, "origin within tolerance")
	t.eq(BF.validateThrow({ x = 0, y = 0, z = 0 }, { x = 7, y = 0, z = 0 }, 6), false, "origin too far")

	t.eq(BF.usesGravity(10, Config), 0, "short throw flat")
	t.eq(BF.usesGravity(40, Config), 12, "long throw arcs")
	-- timeToReach: distance / speed
	t.ok(near(BF.timeToReach({ x = 0, y = 0, z = 0 }, { x = 30, y = 0, z = 0 }, 60), 0.5), "time to reach")
end
