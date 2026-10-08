return function(t)
	local M = require("../src/ReplicatedStorage/CursedDodgeball/Movement/MoveMath")
	local C = require("../src/ReplicatedStorage/CursedDodgeball/Movement/MovementConfig")
	local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-4) end

	-- config sanity: arena values from movement-design.md
	t.eq(C.JogSpeed, 16, "jog")
	t.eq(C.SprintSpeed, 26, "sprint")
	t.eq(C.HardCap, 36, "cap")
	t.ok(C.HardCap < 60, "top speed well under a quick throw")
	t.eq(C.WallRunMaxTime, 1.6, "wall run length")

	-- momentum: sprint ramps up over about 0.6 s and stops at the sprint target
	do
		local m = C.JogSpeed
		local o = { sprinting = true, stamina = 1, grounded = true }
		for _ = 1, 30 do m = M.stepMomentum(m, o, 1 / 60, C) end -- 0.5 s
		t.ok(m > 22 and m < 26, "sprint ramp after 0.5 s is past jog but under target: " .. m)
		for _ = 1, 60 do m = M.stepMomentum(m, o, 1 / 60, C) end
		t.eq(m, C.SprintSpeed, "settles at sprint target")
		-- release sprint: falls back toward jog
		o.sprinting = false
		for _ = 1, 120 do m = M.stepMomentum(m, o, 1 / 60, C) end
		t.eq(m, C.JogSpeed, "falls back to jog")
		-- no stamina: cannot sprint
		o.sprinting, o.stamina = true, 0
		t.eq(M.stepMomentum(C.JogSpeed, o, 0.1, C), C.JogSpeed, "no stamina, no sprint")
	end

	-- boosts stack to the cap and decay at the right rate per surface
	do
		t.eq(M.boost(34, 5, C), C.HardCap, "boost capped")
		local o = { sprinting = true, stamina = 1, grounded = true }
		local g = M.stepMomentum(32, o, 0.1, C)
		t.ok(near(g, 32 - C.OverspeedDecayGround * 0.1), "ground overspeed decay")
		o.grounded = false
		local a = M.stepMomentum(32, o, 0.1, C)
		t.ok(near(a, 32 - C.OverspeedDecayAir * 0.1), "air overspeed decay")
		o.wallRunning = true
		t.eq(M.stepMomentum(32, o, 0.1, C), 32, "wall run keeps overspeed")
	end

	-- planar acceleration on the ground: snappy but not instant
	do
		local vx, vz = M.stepPlanar(0, 0, 1, 0, 23, true, 1 / 60, C)
		t.ok(near(vx, C.GroundAccel / 60) and near(vz, 0), "one frame of accel")
		vx, vz = 0, 0
		for _ = 1, 30 do vx, vz = M.stepPlanar(vx, vz, 1, 0, 23, true, 1 / 60, C) end
		t.ok(near(vx, 23), "reaches max within half a second")
		-- no input: decelerates, does not snap
		local sx = M.stepPlanar(23, 0, 0, 0, 23, true, 1 / 60, C)
		t.ok(sx < 23 and sx > 20, "decel not instant: " .. sx)
	end

	-- air: steering only, never adds speed beyond what you carried (or jog)
	do
		local vx, vz = 20, 0
		for _ = 1, 60 do vx, vz = M.stepPlanar(vx, vz, 0, 1, 28, false, 1 / 60, C) end
		local sp = math.sqrt(vx * vx + vz * vz)
		t.ok(sp <= 20 + 1e-3, "air never gains speed: " .. sp)
		t.ok(vz > 5, "air steering turns you")
		local nx, nz = M.stepPlanar(20, 0, 0, 0, 28, false, 1 / 60, C)
		t.ok(near(nx, 20) and near(nz, 0), "no input in air keeps momentum")
		local jx = M.stepPlanar(0, 0, 1, 0, 28, false, 1, C)
		t.ok(jx <= C.JogSpeed + 1e-3, "standing jump can steer up to jog speed: " .. jx)
	end

	-- hard turn detection
	t.eq(M.isHardTurn(20, 0, -1, 0, C), true, "reverse is a hard turn")
	t.eq(M.isHardTurn(20, 0, 0, 1, C), false, "90 degrees is not")
	t.eq(M.isHardTurn(3, 0, -1, 0, C), false, "slow reverse is not")

	-- wall run check
	do
		local base = { grounded = false, vx = 20, vz = -2, nx = 0, nz = 1, wallHeight = 8, forward = true, lockedOut = false }
		local ok, tx, tz = M.wallRunCheck(base, C)
		t.eq(ok, true, "parallel fast airborne run along a tall wall engages")
		t.ok(near(tx, 1) and near(tz, 0), "tangent along the wall in travel direction")
		local function with(k, v) local c = table.clone(base) c[k] = v return c end
		t.eq((M.wallRunCheck(with("grounded", true), C)), false, "not on the ground")
		t.eq((M.wallRunCheck(with("vx", 8), C)), false, "too slow")
		t.eq((M.wallRunCheck(with("wallHeight", 4), C)), false, "wall too short")
		t.eq((M.wallRunCheck(with("forward", false), C)), false, "must hold forward")
		t.eq((M.wallRunCheck(with("lockedOut", true), C)), false, "same wall lockout")
		local head = with("vx", 0)
		head.vz = -20 -- running straight into the wall (normal +z means wall faces +z, we move -z)
		t.eq((M.wallRunCheck(head, C)), false, "head-on is not a wall run")
		local neg = with("vx", -20)
		local _, ntx = M.wallRunCheck(neg, C)
		t.ok(near(ntx, -1), "tangent follows travel direction")
	end

	-- wall run vertical arc: lift, then a slow sink, clamped
	do
		local vy = M.wallRunEntryVy(-10, C)
		t.eq(vy, C.WallRunLift, "entry lifts a falling player")
		t.eq(M.wallRunEntryVy(30, C), 30, "entry keeps a rising player's lift")
		local v = C.WallRunLift
		for _ = 1, 60 do v = M.stepWallRunVy(v, 1 / 60, C) end
		t.ok(v < C.WallRunLift and v >= -C.WallRunMaxSink, "sinks slowly over a second: " .. v)
	end

	-- wall jump
	do
		local vx, vy, vz = M.wallJumpVelocity(0, 1, 1, 0, 20, C)
		t.ok(near(vy, C.WallJumpUp), "wall jump up")
		t.ok(near(vz, C.WallJumpAway), "pushed away along the wall normal")
		t.ok(near(vx, 20 * C.WallJumpKeep), "keeps some speed along the wall")
	end

	-- landing kinds
	t.eq(M.landingKind(20, 0, C), "Light", "light")
	t.eq(M.landingKind(45, 0, C), "Medium", "medium")
	t.eq(M.landingKind(80, 20, C), "Roll", "fast heavy landing rolls")
	t.eq(M.landingKind(80, 5, C), "Heavy", "slow heavy landing")

	-- stamina
	do
		local s = 1
		for _ = 1, 60 do s = M.stepStamina(s, true, 0, 1 / 60, C) end
		t.ok(near(s, 1 - 1 / C.StaminaDrainSeconds, 1e-3), "drains a quarter per second")
		t.eq(M.stepStamina(0.5, false, 0.1, 1, C), 0.5, "refill waits after use")
		t.ok(near(M.stepStamina(0.5, false, 1, 0.3, C), 0.6, 1e-3), "refills in 3 s")
		t.eq(M.stepStamina(0.99, false, 1, 1, C), 1, "clamped at 1")
	end

	-- slide
	t.eq(M.slideCanStart(true, 20, C), true, "slide at sprint speed")
	t.eq(M.slideCanStart(true, 15, C), false, "not at jog")
	t.eq(M.slideCanStart(false, 25, C), false, "not in the air")
	do
		local sp, done = M.stepSlide(25, 0.1, 0.1, C)
		t.ok(near(sp, 25 - C.SlideFriction * 0.1) and not done, "slide friction")
		local _, ended = M.stepSlide(20, C.SlideMaxTime + 0.01, 0.01, C)
		t.eq(ended, true, "slide ends at max time")
		local _, slow = M.stepSlide(C.SlideEndSpeed - 1, 0.2, 0.01, C)
		t.eq(slow, true, "slide ends when slow")
	end

	-- extra gravity: falls faster, short hops when jump released
	t.ok(near(M.extraGravity(-10, true, C), (C.FallGravityMult - 1) * C.Gravity), "fall gravity")
	t.ok(near(M.extraGravity(10, false, C), (C.JumpCutMult - 1) * C.Gravity), "jump cut")
	t.eq(M.extraGravity(10, true, C), 0, "holding jump on the way up: normal gravity")

	-- camera and fov
	t.eq(M.fovTarget(C.JogSpeed, C), C.FovBase, "fov at jog")
	t.eq(M.fovTarget(C.HardCap, C), C.FovMax, "fov at cap")
	t.ok(M.fovTarget(50, C) == C.FovMax, "fov clamped")
	t.eq(M.shoulderX(0, C), C.ShoulderX, "right shoulder by default")
	t.eq(M.shoulderX(1, C), -C.ShoulderX, "wall on the right swaps to the left shoulder")
	t.eq(M.shoulderX(-1, C), C.ShoulderX, "wall on the left keeps the right shoulder")
	t.eq(M.speedLinesAlpha(C.JogSpeed, C), 0, "no speed lines at jog")
	t.ok(near(M.speedLinesAlpha(C.HardCap, C), C.SpeedLinesMaxAlpha), "faint lines at cap")

	-- turning
	t.ok(near(M.turnToward(0, math.pi / 2, math.rad(720), 1 / 60), math.rad(12)), "turn rate limit")
	t.ok(near(M.turnToward(math.rad(170), math.rad(-170), math.rad(720), 1), math.rad(-170)), "wraps the short way")
	t.ok(near(M.angleDelta(math.rad(170), math.rad(-170)), math.rad(20)), "angle delta wraps")
	t.eq(M.canJumpCoyote(0.1, C), true, "coyote time")
	t.eq(M.canJumpCoyote(0.2, C), false, "coyote expired")
end
