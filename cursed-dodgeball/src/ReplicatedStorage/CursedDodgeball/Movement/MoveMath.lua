-- Cursed Dodgeball movement maths. Pure: plain numbers in, plain numbers out, no Roblox requires.
-- The client controller calls these every frame; the tests drive them headless.
local MoveMath = {}

local function clamp(x, a, b) return math.max(a, math.min(b, x)) end

-- Momentum: the speed ceiling the player is currently allowed. Ramps toward the sprint target while
-- sprinting with stamina, back toward jog otherwise; boosts above the sprint target decay by surface.
-- opts = { sprinting, stamina, grounded, wallRunning }
function MoveMath.stepMomentum(m, opts, dt, C)
	local sprinting = opts.sprinting and (opts.stamina or 0) > 0
	local target = sprinting and C.SprintSpeed or C.JogSpeed
	if m < target then
		return math.min(target, m + C.SprintRamp * dt)
	end
	if m > C.SprintSpeed then
		local rate = opts.wallRunning and 0 or (opts.grounded and C.OverspeedDecayGround or C.OverspeedDecayAir)
		return math.max(target, m - rate * dt)
	end
	if m > target then
		return math.max(target, m - C.SprintRelease * dt)
	end
	return m
end

function MoveMath.boost(m, amount, C)
	return math.min(C.HardCap, m + amount)
end

-- Planar velocity. wish is the input direction with magnitude 0..1 (stick tilt).
-- Ground: accelerate toward wish * maxSpeed, decelerate without input.
-- Air: steer only; speed never exceeds what was carried in (or jog, for standing jumps).
function MoveMath.stepPlanar(vx, vz, wx, wz, maxSpeed, grounded, dt, C)
	local mag = math.min(1, math.sqrt(wx * wx + wz * wz))
	local dx, dz = wx * maxSpeed, wz * maxSpeed
	local rate
	if grounded then
		rate = (mag > 0.01) and C.GroundAccel or C.GroundDecel
	else
		if mag <= 0.01 then return vx, vz end
		rate = C.AirAccel
	end
	local ex, ez = dx - vx, dz - vz
	local el = math.sqrt(ex * ex + ez * ez)
	local stepLen = rate * dt
	if el > stepLen and el > 0 then
		ex, ez = ex / el * stepLen, ez / el * stepLen
	end
	local nx, nz = vx + ex, vz + ez
	if not grounded then
		local before = math.sqrt(vx * vx + vz * vz)
		local limit = math.max(before, C.JogSpeed * mag)
		local after = math.sqrt(nx * nx + nz * nz)
		if after > limit and after > 0 then
			nx, nz = nx / after * limit, nz / after * limit
		end
	end
	return nx, nz
end

function MoveMath.isHardTurn(vx, vz, wx, wz, C)
	local sp = math.sqrt(vx * vx + vz * vz)
	local wl = math.sqrt(wx * wx + wz * wz)
	if sp < C.HardTurnMinSpeed or wl < 0.01 then return false end
	local dot = (vx * wx + vz * wz) / (sp * wl)
	return dot < math.cos(math.rad(C.HardTurnAngle))
end

-- Wall run eligibility. p = { grounded, vx, vz, nx, nz (wall normal, horizontal), wallHeight, forward, lockedOut }
-- Returns ok, tx, tz (unit tangent along the wall in the direction of travel).
function MoveMath.wallRunCheck(p, C)
	if p.grounded or p.lockedOut or not p.forward then return false end
	if (p.wallHeight or 0) < C.WallRunMinHeight then return false end
	local sp = math.sqrt(p.vx * p.vx + p.vz * p.vz)
	if sp < C.WallRunMinSpeed then return false end
	local nl = math.sqrt(p.nx * p.nx + p.nz * p.nz)
	if nl < 1e-6 then return false end
	local nx, nz = p.nx / nl, p.nz / nl
	local along = p.vx * nx + p.vz * nz
	local tx, tz = p.vx - along * nx, p.vz - along * nz
	local tl = math.sqrt(tx * tx + tz * tz)
	if tl < 1e-6 then return false end
	if tl / sp < math.cos(math.rad(C.WallRunMaxAngle)) then return false end
	return true, tx / tl, tz / tl
end

function MoveMath.wallRunEntryVy(vy, C)
	return math.max(vy, C.WallRunLift)
end

function MoveMath.stepWallRunVy(vy, dt, C)
	return math.max(-C.WallRunMaxSink, vy - C.Gravity * C.WallRunGravity * dt)
end

-- Launch off a wall: away along the normal, up, and part of the speed along the wall.
function MoveMath.wallJumpVelocity(nx, nz, tx, tz, alongSpeed, C)
	local keep = alongSpeed * C.WallJumpKeep
	return nx * C.WallJumpAway + tx * keep, C.WallJumpUp, nz * C.WallJumpAway + tz * keep
end

function MoveMath.landingKind(fallSpeed, horizSpeed, C)
	if fallSpeed < C.LandMedium then return "Light" end
	if fallSpeed < C.LandHeavy then return "Medium" end
	if horizSpeed >= C.LandRollMinSpeed then return "Roll" end
	return "Heavy"
end

-- Stamina 0..1. draining: sprinting or wall running this frame. sinceUse: seconds since it last drained.
function MoveMath.stepStamina(s, draining, sinceUse, dt, C)
	if draining then
		return math.max(0, s - dt / C.StaminaDrainSeconds)
	end
	if sinceUse < C.StaminaRefillDelay then return s end
	return math.min(1, s + dt / C.StaminaRefillSeconds)
end

function MoveMath.slideCanStart(grounded, speed, C)
	return grounded and speed >= C.SlideMinSpeed
end

-- Returns the new speed and whether the slide is over.
function MoveMath.stepSlide(speed, elapsed, dt, C)
	local s = speed - C.SlideFriction * dt
	local done = elapsed >= C.SlideMaxTime or s <= C.SlideEndSpeed
	return s, done
end

-- Extra downward acceleration on top of normal gravity: heavier falls, and short hops when jump is
-- released early while rising.
function MoveMath.extraGravity(vy, jumpHeld, C)
	if vy < 0 then return (C.FallGravityMult - 1) * C.Gravity end
	if vy > 0 and not jumpHeld then return (C.JumpCutMult - 1) * C.Gravity end
	return 0
end

function MoveMath.jumpVelocity(C)
	return math.sqrt(2 * C.Gravity * C.JumpHeight)
end

function MoveMath.fovTarget(speed, C)
	local k = clamp((speed - C.JogSpeed) / (C.HardCap - C.JogSpeed), 0, 1)
	return C.FovBase + (C.FovMax - C.FovBase) * k
end

-- wallSide: +1 wall on the right, -1 wall on the left, 0 none. A wall on the right would block a
-- right-shoulder camera, so swap to the left shoulder.
function MoveMath.shoulderX(wallSide, C)
	if wallSide == 1 then return -C.ShoulderX end
	return C.ShoulderX
end

function MoveMath.speedLinesAlpha(speed, C)
	local k = clamp((speed - C.SpeedLinesStart) / (C.HardCap - C.SpeedLinesStart), 0, 1)
	return k * C.SpeedLinesMaxAlpha
end

function MoveMath.angleDelta(from, to)
	local d = (to - from) % (2 * math.pi)
	if d > math.pi then d -= 2 * math.pi end
	return d
end

-- Rotate yaw toward target by at most maxRate * dt, the short way round.
function MoveMath.turnToward(yaw, target, maxRate, dt)
	local d = MoveMath.angleDelta(yaw, target)
	local step = maxRate * dt
	if math.abs(d) <= step then return target end
	return yaw + (d > 0 and step or -step)
end

function MoveMath.canJumpCoyote(sinceGrounded, C)
	return sinceGrounded <= C.CoyoteTime
end

-- Exponential smoothing factor for a spring-like follow at rate k per second.
function MoveMath.smoothAlpha(k, dt)
	return 1 - math.exp(-k * dt)
end

return MoveMath
