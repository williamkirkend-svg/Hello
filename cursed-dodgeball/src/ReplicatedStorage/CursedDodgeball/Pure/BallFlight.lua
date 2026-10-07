-- Cursed Dodgeball flight math. Pure: vectors are {x, y, z} tables, no Roblox requires.
-- The server steps every live ball with these functions; clients use the same math to predict.
local BallFlight = {}

local function sub(a, b) return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z } end
local function dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
local function len(a) return math.sqrt(dot(a, a)) end

-- Straight-line aim at where the target's chest is right now. No lead, no steering.
function BallFlight.aim(origin, targetChest, charge01, config)
	local d = sub(targetChest, origin)
	local l = len(d)
	local dir = (l > 1e-6) and { x = d.x / l, y = d.y / l, z = d.z / l } or { x = 0, y = 0, z = 1 }
	local c = math.clamp(charge01, 0, 1)
	local speed = config.Throw.QuickSpeed + (config.Throw.ChargedSpeed - config.Throw.QuickSpeed) * c
	return { dir = dir, speed = speed }
end

-- Long throws arc under gravity so a lob over a crowd is readable; short ones fly flat.
function BallFlight.usesGravity(distance, config)
	return (distance > config.Throw.LobDistance) and config.Throw.Gravity or 0
end

-- Advances a position by speed along dir for dt seconds; gravity (studs/s^2) pulls y down.
function BallFlight.step(pos, dir, speed, dt, gravity)
	return {
		x = pos.x + dir.x * speed * dt,
		y = pos.y + dir.y * speed * dt - 0.5 * gravity * dt * dt,
		z = pos.z + dir.z * speed * dt,
	}
end

-- True if the segment p0->p1 passes within radius of centre.
function BallFlight.segmentHitsSphere(p0, p1, centre, radius)
	local d = sub(p1, p0)
	local f = sub(p0, centre)
	local dd = dot(d, d)
	local tt
	if dd < 1e-9 then
		tt = 0
	else
		tt = math.clamp(-dot(f, d) / dd, 0, 1)
	end
	local closest = { x = p0.x + d.x * tt, y = p0.y + d.y * tt, z = p0.z + d.z * tt }
	return len(sub(closest, centre)) <= radius
end

function BallFlight.catchWindow(charge01, config)
	local c = math.clamp(charge01, 0, 1)
	return config.Catch.QuickWindow + (config.Catch.ChargedWindow - config.Catch.QuickWindow) * c
end

-- The client's claimed throw origin must be near where the server has that player.
function BallFlight.validateThrow(claimedOrigin, serverPos, maxDist)
	return len(sub(claimedOrigin, serverPos)) <= maxDist
end

function BallFlight.timeToReach(from, to, speed)
	return len(sub(to, from)) / speed
end

return BallFlight
