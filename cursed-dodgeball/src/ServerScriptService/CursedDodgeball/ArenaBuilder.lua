-- Cursed Dodgeball grey-box arena. Builds the sunken pit, Ghost ring, stands, tunnels and jumbotron from
-- Config so Phase 1 needs no meshes. Everything is anchored Parts under workspace.CursedArena.
-- Coordinates: the pit floor's top surface is Y = 0, the court centre is the origin, X runs along the
-- long side (Length) and Z along the short side (Width).
local ArenaBuilder = {}

local FREE_ZONE = 4 -- studs of floor between the round 1 kerb and the pit wall

local function part(parent, name, size, cframe, colour, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function ArenaBuilder.build(config)
	local court = config.Court
	local r1 = court.Rounds[1]
	local pitL = r1.Length + FREE_ZONE * 2
	local pitW = r1.Width + FREE_ZONE * 2
	local depth = court.PitDepth
	local ringW = court.RingWidth

	local model = Instance.new("Model")
	model.Name = "CursedArena"

	local arena = { Model = model, FloorY = 0, RingY = depth, Centre = Vector3.new(0, 0, 0), Kerbs = {}, FloodParts = {} }
	arena.PitHalfLength = pitL / 2
	arena.PitHalfWidth = pitW / 2

	-- Floor
	arena.Floor = part(model, "Floor", Vector3.new(pitL + 2, 1, pitW + 2), CFrame.new(0, -0.5, 0), Color3.fromRGB(60, 60, 66), Enum.Material.Asphalt)

	-- Centre circle marker and ball hatch
	local circle = part(model, "CentreCircle", Vector3.new(court.CentreCircle, 0.1, court.CentreCircle), CFrame.new(0, 0.05, 0), Color3.fromRGB(255, 230, 90))
	circle.Shape = Enum.PartType.Cylinder
	circle.CFrame = CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90))
	arena.Hatch = Vector3.new(0, 2.5, 0)

	-- Pit walls (4), with a tunnel gap in each short wall
	local wallT = 1
	local walls = Instance.new("Folder")
	walls.Name = "PitWalls"
	walls.Parent = model
	local wallColour = Color3.fromRGB(120, 125, 140)
	part(walls, "WallNorth", Vector3.new(pitL + 2 * wallT, depth, wallT), CFrame.new(0, depth / 2, -(pitW / 2 + wallT / 2)), wallColour, Enum.Material.Concrete)
	part(walls, "WallSouth", Vector3.new(pitL + 2 * wallT, depth, wallT), CFrame.new(0, depth / 2, (pitW / 2 + wallT / 2)), wallColour, Enum.Material.Concrete)
	local gap = 8
	for _, sgn in { -1, 1 } do
		local x = sgn * (pitL / 2 + wallT / 2)
		local segW = (pitW - gap) / 2
		part(walls, "WallEnd" .. sgn .. "A", Vector3.new(wallT, depth, segW), CFrame.new(x, depth / 2, -(gap / 2 + segW / 2)), wallColour, Enum.Material.Concrete)
		part(walls, "WallEnd" .. sgn .. "B", Vector3.new(wallT, depth, segW), CFrame.new(x, depth / 2, (gap / 2 + segW / 2)), wallColour, Enum.Material.Concrete)
	end
	arena.PitWalls = walls

	-- Ghost ring: walkway at the top of the wall, all the way round, with a glass rail on the inner edge
	local ring = Instance.new("Folder")
	ring.Name = "Ring"
	ring.Parent = model
	local ringColour = Color3.fromRGB(200, 200, 210)
	local outerL = pitL + 2 * wallT + 2 * ringW
	local outerW = pitW + 2 * wallT + 2 * ringW
	local y = depth - 0.5
	part(ring, "RingNorth", Vector3.new(outerL, 1, ringW), CFrame.new(0, y, -(pitW / 2 + wallT + ringW / 2)), ringColour)
	part(ring, "RingSouth", Vector3.new(outerL, 1, ringW), CFrame.new(0, y, (pitW / 2 + wallT + ringW / 2)), ringColour)
	part(ring, "RingEast", Vector3.new(ringW, 1, pitW + 2 * wallT), CFrame.new((pitL / 2 + wallT + ringW / 2), y, 0), ringColour)
	part(ring, "RingWest", Vector3.new(ringW, 1, pitW + 2 * wallT), CFrame.new(-(pitL / 2 + wallT + ringW / 2), y, 0), ringColour)
	local railH = 3
	local glass = Color3.fromRGB(170, 220, 255)
	local function rail(name, size, cf)
		local g = part(ring, name, size, cf, glass, Enum.Material.Glass)
		g.Transparency = 0.5
		return g
	end
	rail("RailNorth", Vector3.new(pitL + 2 * wallT, railH, 0.3), CFrame.new(0, depth + railH / 2, -(pitW / 2 + wallT + 0.15)))
	rail("RailSouth", Vector3.new(pitL + 2 * wallT, railH, 0.3), CFrame.new(0, depth + railH / 2, (pitW / 2 + wallT + 0.15)))
	rail("RailEast", Vector3.new(0.3, railH, pitW + 2 * wallT), CFrame.new((pitL / 2 + wallT + 0.15), depth + railH / 2, 0))
	rail("RailWest", Vector3.new(0.3, railH, pitW + 2 * wallT), CFrame.new(-(pitL / 2 + wallT + 0.15), depth + railH / 2, 0))
	arena.Ring = ring
	arena.RingHalfLength = outerL / 2 - ringW / 2
	arena.RingHalfWidth = outerW / 2 - ringW / 2

	-- Stands: rows on all four sides rising outward from the ring
	local stands = Instance.new("Folder")
	stands.Name = "Stands"
	stands.Parent = model
	local rowColours = { Color3.fromRGB(80, 120, 200), Color3.fromRGB(230, 120, 60) }
	arena.SeatCFrames = {}
	for row = 1, court.StandRows do
		local inset = ringW + (row - 1) * court.RowDepth + court.RowDepth / 2
		local top = depth + row * court.RowRise
		local colour = rowColours[(row % 2) + 1]
		local lenL = pitL + 2 * wallT + 2 * (ringW + row * court.RowDepth)
		local halfZ = pitW / 2 + wallT + inset
		local halfX = pitL / 2 + wallT + inset
		part(stands, "RowN" .. row, Vector3.new(lenL, court.RowRise, court.RowDepth), CFrame.new(0, top - court.RowRise / 2, -halfZ), colour)
		part(stands, "RowS" .. row, Vector3.new(lenL, court.RowRise, court.RowDepth), CFrame.new(0, top - court.RowRise / 2, halfZ), colour)
		local lenW = pitW + 2 * wallT + 2 * (ringW + (row - 1) * court.RowDepth)
		part(stands, "RowE" .. row, Vector3.new(court.RowDepth, court.RowRise, lenW), CFrame.new(halfX, top - court.RowRise / 2, 0), colour)
		part(stands, "RowW" .. row, Vector3.new(court.RowDepth, court.RowRise, lenW), CFrame.new(-halfX, top - court.RowRise / 2, 0), colour)
		-- seat positions: every 4 studs along the long sides, facing the court
		for x = -math.floor(lenL / 2) + 4, math.floor(lenL / 2) - 4, 4 do
			table.insert(arena.SeatCFrames, CFrame.new(x, top + 3, -halfZ) * CFrame.Angles(0, math.pi, 0))
			table.insert(arena.SeatCFrames, CFrame.new(x, top + 3, halfZ))
		end
	end
	arena.Stands = stands

	-- Tunnels: ramps from ring level down through the gaps in the short walls
	local tunnels = Instance.new("Folder")
	tunnels.Name = "Tunnels"
	tunnels.Parent = model
	arena.Gates = {}
	local rampLen = 16
	for _, sgn in { -1, 1 } do
		local x0 = sgn * (pitL / 2 + wallT) -- wall face, floor level
		local x1 = sgn * (pitL / 2 + wallT + rampLen) -- ring level
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Ramp" .. sgn
		wedge.Anchored = true
		wedge.Size = Vector3.new(gap, depth, rampLen)
		wedge.Color = Color3.fromRGB(150, 150, 160)
		-- WedgePart slopes up along +Z of its local frame; rotate so the high end is at x1
		local mid = Vector3.new((x0 + x1) / 2, depth / 2, 0)
		wedge.CFrame = CFrame.lookAt(mid, mid + Vector3.new(sgn, 0, 0)) * CFrame.Angles(0, math.pi, 0)
		wedge.Parent = tunnels
		local gate = part(tunnels, "Gate" .. sgn, Vector3.new(0.5, depth, gap), CFrame.new(x0 - sgn * 0.5, depth / 2, 0), Color3.fromRGB(255, 80, 80))
		gate.Transparency = 0.6
		gate.CanCollide = false
		table.insert(arena.Gates, gate)
	end
	arena.Tunnels = tunnels

	-- Kerbs per round (thin painted bands) and flood slabs
	local kerbs = Instance.new("Folder")
	kerbs.Name = "Kerbs"
	kerbs.Parent = model
	local kerbColours = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 90, 90) }
	for i, rc in court.Rounds do
		local f = Instance.new("Folder")
		f.Name = "Round" .. i
		f.Parent = kerbs
		local hl, hw = rc.Length / 2, rc.Width / 2
		local kh = court.KerbHeight
		local c = kerbColours[i]
		part(f, "N", Vector3.new(rc.Length + 1, kh, 0.5), CFrame.new(0, kh / 2, -hw), c)
		part(f, "S", Vector3.new(rc.Length + 1, kh, 0.5), CFrame.new(0, kh / 2, hw), c)
		part(f, "E", Vector3.new(0.5, kh, rc.Width + 1), CFrame.new(hl, kh / 2, 0), c)
		part(f, "W", Vector3.new(0.5, kh, rc.Width + 1), CFrame.new(-hl, kh / 2, 0), c)
		for _, p in f:GetChildren() do p.CanCollide = false end
		arena.Kerbs[i] = f
		f.Parent = nil
	end
	local flood = Instance.new("Folder")
	flood.Name = "Flood"
	flood.Parent = model
	local pink = Color3.fromRGB(255, 105, 180)
	for _, n in { "N", "S", "E", "W" } do
		local p = part(flood, n, Vector3.new(1, 0.2, 1), CFrame.new(0, -5, 0), pink, Enum.Material.Neon)
		p.CanCollide = false
		arena.FloodParts[n] = p
	end

	-- Jumbotron at the +X short end above the stands
	local jx = pitL / 2 + wallT + ringW + court.StandRows * court.RowDepth + 4
	local jy = depth + court.StandRows * court.RowRise + 14
	local jumbo = part(model, "Jumbotron", Vector3.new(1, 12, 24), CFrame.new(jx, jy, 0), Color3.fromRGB(20, 20, 25))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = jumbo
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Text = "CURSED DODGEBALL"
	label.Parent = gui
	part(model, "JumboPole", Vector3.new(1, jy - 6, 1), CFrame.new(jx, (jy - 6) / 2, 0), Color3.fromRGB(90, 90, 95))
	arena.Jumbotron = jumbo
	arena.JumboText = label

	model.Parent = workspace

	function arena:setRound(round)
		for i, f in self.Kerbs do
			f.Parent = (i == round) and model or nil
		end
		self.Round = round
	end

	function arena:setGates(closed)
		for _, g in self.Gates do
			g.CanCollide = closed
			g.Transparency = closed and 0.3 or 0.9
		end
	end

	-- Hides the flood slabs
	function arena:clearFlood()
		for _, p in self.FloodParts do
			p.CFrame = CFrame.new(0, -5, 0)
			p.Size = Vector3.new(1, 0.2, 1)
		end
	end

	-- Places four slabs covering the band between the current kerb and `inset` studs inward.
	function arena:setFlood(round, inset)
		local rc = config.Court.Rounds[round]
		local hl, hw = rc.Length / 2, rc.Width / 2
		inset = math.min(inset, math.min(hl, hw))
		local y = 0.15
		self.FloodParts.N.Size = Vector3.new(rc.Length, 0.2, inset)
		self.FloodParts.N.CFrame = CFrame.new(0, y, -hw + inset / 2)
		self.FloodParts.S.Size = Vector3.new(rc.Length, 0.2, inset)
		self.FloodParts.S.CFrame = CFrame.new(0, y, hw - inset / 2)
		self.FloodParts.E.Size = Vector3.new(inset, 0.2, rc.Width)
		self.FloodParts.E.CFrame = CFrame.new(hl - inset / 2, y, 0)
		self.FloodParts.W.Size = Vector3.new(inset, 0.2, rc.Width)
		self.FloodParts.W.CFrame = CFrame.new(-hl + inset / 2, y, 0)
	end

	-- n points spread on an ellipse inside the round's court, facing the centre
	function arena:spawnPointsCourt(n, round)
		local rc = config.Court.Rounds[round or 1]
		local out = {}
		for i = 1, n do
			local a = (i - 1) / n * math.pi * 2
			local pos = Vector3.new(math.cos(a) * rc.Length * 0.38, 3, math.sin(a) * rc.Width * 0.38)
			out[i] = CFrame.lookAt(pos, Vector3.new(0, 3, 0))
		end
		return out
	end

	-- n points around the Ghost ring walkway, facing the pit
	function arena:spawnPointsRing(n)
		local out = {}
		local hl, hw = self.RingHalfLength, self.RingHalfWidth
		local y = self.RingY + 3
		for i = 1, n do
			local a = (i - 1) / n * math.pi * 2
			local pos = Vector3.new(math.cos(a) * hl, y, math.sin(a) * hw)
			out[i] = CFrame.lookAt(pos, Vector3.new(0, y, 0))
		end
		return out
	end

	function arena:spawnPointsStands(n)
		local out = {}
		local seats = self.SeatCFrames
		for i = 1, n do
			out[i] = seats[((i - 1) % #seats) + 1]
		end
		return out
	end

	arena:setRound(1)
	arena:setGates(false)
	arena:clearFlood()
	return arena
end

return ArenaBuilder
