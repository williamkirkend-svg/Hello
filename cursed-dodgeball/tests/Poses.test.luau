return function(t)
	local P = require("../src/ReplicatedStorage/CursedDodgeball/Movement/Poses")
	local A = require("../src/ReplicatedStorage/CursedDodgeball/Movement/AnimState")
	local C = require("../src/ReplicatedStorage/CursedDodgeball/Movement/MovementConfig")
	local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-4) end
	local function finite(p)
		for _, j in P.JOINTS do
			local v = p[j]
			if not v then return false, j .. " missing" end
			for _, c in { v.x, v.y, v.z } do
				if c ~= c or math.abs(c) > 10 then return false, j end
			end
		end
		for _, k in { "RootPos", "RootSpin" } do
			for _, c in { p[k].x, p[k].y, p[k].z } do
				if c ~= c then return false, k end
			end
		end
		return true
	end

	-- every pose builder returns a complete finite pose
	local builders = {
		idle = P.idle(1.3),
		run = P.run(0.3, 0.8),
		airUp = P.air(1, false),
		airDown = P.air(-1, true),
		tuck = P.tuck(),
		wallRun = P.wallRun(0.2, 1),
		wallKick = P.wallKick(-1),
		slide = P.slide(),
		dashF = P.dash(0, -1),
		dashR = P.dash(1, 0),
		landL = P.land("Light", 1),
		landM = P.land("Medium", 1),
		landH = P.land("Heavy", 1),
		roll = P.roll(0.5),
		mantle = P.mantle(0.5),
	}
	for name, p in builders do
		local ok, bad = finite(p)
		t.ok(ok, name .. " pose complete and finite (" .. tostring(bad) .. ")")
	end
	t.eq(#P.JOINTS, 15, "15 R15 joints")

	-- run: legs alternate, amplitude grows with speed, lean grows with speed
	do
		local a = P.run(0.25, 1)
		t.ok(a.RHip.x > 0.5 and a.LHip.x < 0, "right leg forward while left back at quarter phase")
		local b = P.run(0.75, 1)
		t.ok(b.LHip.x > 0.5 and b.RHip.x < 0, "and the other way half a cycle later")
		local slow = P.run(0.25, 0.3)
		t.ok(a.RHip.x - a.LHip.x > slow.RHip.x - slow.LHip.x, "longer stride at speed")
		t.ok(a.Waist.x + a.Root.x < slow.Waist.x + slow.Root.x, "leans further forward at speed")
		t.ok(a.RShoulder.x < 0 and a.LShoulder.x > 0, "arms swing opposite to legs")
		t.ok(a.RElbow.x > 0.8 and a.LElbow.x > 0.8, "elbows bent while running")
		local knees = 0
		for i = 0, 19 do local p = P.run(i / 20, 1) knees = math.min(knees, p.RKnee.x) end
		t.ok(knees < -1.5, "sprint knee kicks high: " .. knees)
		for i = 0, 19 do
			local p = P.run(i / 20, 1)
			t.ok(p.RKnee.x <= 0 and p.LKnee.x <= 0, "knees never hyperextend")
		end
	end

	-- mirror swaps sides and flips sideways rotations
	do
		local p = P.wallRun(0.1, 1)
		local m = P.mirror(p)
		t.ok(near(m.LShoulder.x, p.RShoulder.x) and near(m.LShoulder.z, -p.RShoulder.z), "mirror swaps arms")
		t.ok(near(m.Root.z, -p.Root.z) and near(m.RootPos.x, -p.RootPos.x), "mirror flips roll and side offset")
		local w = P.wallRun(0.1, -1)
		t.ok(near(w.Root.z, m.Root.z, 1e-6), "wall on the left is the mirror of wall on the right")
	end

	-- wall run tilts the feet toward the wall and reaches with the wall-side arm
	do
		local r = P.wallRun(0.1, 1) -- wall on the right
		t.ok(r.Root.z > 0.2, "body rolls so the head tips away from a right wall")
		t.ok(r.RootPos.x > 0, "hips shift toward the wall")
		t.ok(r.RShoulder.x > 1.4, "wall-side arm reaches forward and up")
		t.ok(r.LShoulder.x < 0, "outer arm back for balance")
	end

	-- slide matches the reference: lead leg out, back leg folded, torso back, body low
	do
		local s = P.slide()
		t.ok(s.Root.x > 0.6, "torso leaned back")
		t.ok(s.Root.x + s.RHip.x > 1.3, "lead leg near horizontal in world")
		t.ok(s.LKnee.x < -1.8, "back leg folded")
		t.ok(s.RootPos.y < -0.6, "body low")
	end

	-- landings deepen with severity
	do
		local l, m, h = P.land("Light", 1), P.land("Medium", 1), P.land("Heavy", 1)
		t.ok(l.RootPos.y > m.RootPos.y and m.RootPos.y > h.RootPos.y, "deeper crouch with harder landings")
		local z = P.land("Medium", 0)
		t.ok(near(z.RootPos.y, 0) and near(z.RKnee.x, 0), "zero depth is neutral")
	end

	-- roll spins one full forward turn
	t.ok(near(P.roll(0).RootSpin.x, 0), "roll starts upright")
	t.ok(near(P.roll(1).RootSpin.x, -2 * math.pi), "roll ends after one forward turn")
	t.ok(P.roll(0.5).RootSpin.x < -2, "rolling forward mid-way")

	-- lerp
	do
		local a, b = P.idle(0), P.slide()
		local h = P.lerp(a, b, 0.5)
		t.ok(near(h.Root.x, (a.Root.x + b.Root.x) / 2), "lerp halfway")
		local z = P.lerp(a, b, 0)
		t.ok(near(z.LKnee.x, a.LKnee.x), "lerp 0 is a")
	end

	-- AnimState: smooth, complete, reacts to events
	do
		local s = A.new(C)
		local maxStep = 0
		local prev
		local function frame(input)
			local p = s:update(1 / 60, input)
			local ok, bad = finite(p)
			if not ok then t.ok(false, "AnimState produced a bad pose at " .. tostring(bad)) end
			if prev then
				for _, j in P.JOINTS do
					for _, c in { "x", "y", "z" } do
						maxStep = math.max(maxStep, math.abs(p[j][c] - prev[j][c]))
					end
				end
			end
			prev = { }
			for _, j in P.JOINTS do prev[j] = { x = p[j].x, y = p[j].y, z = p[j].z } end
			return p
		end
		for _ = 1, 30 do frame({ state = "Ground", speed = 0, vy = 0 }) end
		for i = 1, 60 do frame({ state = "Ground", speed = math.min(28, i), vy = 0 }) end
		-- jump
		frame({ state = "Air", speed = 25, vy = 40, events = { "Jump" } })
		for v = 40, -40, -4 do frame({ state = "Air", speed = 25, vy = v }) end
		frame({ state = "Air", speed = 25, vy = 20, events = { "DoubleJump" } })
		for v = 20, -50, -5 do frame({ state = "Air", speed = 25, vy = v }) end
		-- land medium then keep running
		local landed = frame({ state = "Ground", speed = 24, vy = 0, events = { "Land:Medium" } })
		for _ = 1, 5 do landed = frame({ state = "Ground", speed = 24, vy = 0 }) end
		t.ok(landed.RootPos.y < -0.3, "landing crouch shows a few frames after touchdown: " .. landed.RootPos.y)
		for _ = 1, 40 do frame({ state = "Ground", speed = 24, vy = 0 }) end
		-- wall run, kick, slide, dash, roll
		for _ = 1, 30 do frame({ state = "WallRun", speed = 24, vy = 2, wallSide = 1 }) end
		frame({ state = "Air", speed = 24, vy = 40, events = { "WallJump" }, wallSide = 1 })
		for _ = 1, 30 do frame({ state = "Air", speed = 24, vy = 10 }) end
		for _ = 1, 30 do frame({ state = "Slide", speed = 24, vy = 0 }) end
		for _ = 1, 12 do frame({ state = "Dash", speed = 24, vy = 0, dashX = 1, dashZ = 0 }) end
		local roll = frame({ state = "Ground", speed = 24, vy = 0, events = { "Land:Roll" } })
		local spun = roll.RootSpin.x
		for _ = 1, 10 do spun = math.min(spun, frame({ state = "Ground", speed = 24, vy = 0 }).RootSpin.x) end
		t.ok(spun < -1, "roll spins the body")
		local after
		for _ = 1, 40 do after = frame({ state = "Ground", speed = 24, vy = 0 }) end
		t.ok(near(after.RootSpin.x, 0), "roll finishes upright")
		t.ok(maxStep < 0.45, "no joint snaps more than 0.45 rad in one frame: " .. maxStep)
	end
end
