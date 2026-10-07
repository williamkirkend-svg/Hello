-- Cursed Dodgeball target picker. Pure: vectors are {x, y, z} tables, no Roblox requires.
-- The picked target is whoever is closest to the centre of the camera, inside range and the cone.
local Targeting = {}

local function angleTo(camPos, camDir, pos)
	local dx, dy, dz = pos.x - camPos.x, pos.y - camPos.y, pos.z - camPos.z
	local l = math.sqrt(dx * dx + dy * dy + dz * dz)
	if l < 1e-6 then return 0, 0 end
	local c = (dx * camDir.x + dy * camDir.y + dz * camDir.z) / l
	return math.acos(math.clamp(c, -1, 1)), l
end

-- Candidates sorted by angle from the camera axis, keeping only those in range and inside maxAngle.
function Targeting.order(camPos, camDir, candidates, maxRange, maxAngle)
	local scored = {}
	for _, c in candidates do
		local a, dist = angleTo(camPos, camDir, c.pos)
		if dist <= maxRange and a <= maxAngle then
			scored[#scored + 1] = { id = c.id, a = a }
		end
	end
	table.sort(scored, function(p, q) return p.a < q.a end)
	local ids = {}
	for i, s in scored do ids[i] = s.id end
	return ids
end

function Targeting.pick(camPos, camDir, candidates, maxRange, maxAngle)
	return Targeting.order(camPos, camDir, candidates, maxRange, maxAngle)[1]
end

-- Next id after currentId in orderedIds, wrapping; unknown current starts from the first.
function Targeting.cycle(currentId, orderedIds)
	if #orderedIds == 0 then return nil end
	for i, id in orderedIds do
		if id == currentId then
			return orderedIds[(i % #orderedIds) + 1]
		end
	end
	return orderedIds[1]
end

return Targeting
