-- Cursed Dodgeball ball driver. Spawns balls, handles pickup, validates throws, steps every flight on the
-- server with segment-sphere tests (no Touched, no physics in flight), resolves hits and catches
-- through ShowState, and keeps Ghost throws to one plain quick throw. Phase 1 flies every ball as a
-- plain ball; the Balls.Defs behaviour fields are read in Phase 3.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedDodgeball")
local Pure = Shared:WaitForChild("Pure")
local Balls = require(Pure:WaitForChild("Balls"))
local BallFlight = require(Pure:WaitForChild("BallFlight"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local BallServer = {}

local Config
local Show
local state
local arena
local ballFolder
local balls = {} -- name -> record
local held = {} -- userId -> ball name
local lastThrow = {} -- userId -> os.clock()
local catchPressed = {} -- userId -> os.clock()
local counter = 0

local throwRequest, catchRequest, ballSpawn, ballState

local function v3(t) return Vector3.new(t.x, t.y, t.z) end
local function tv(v) return { x = v.X, y = v.Y, z = v.Z } end

local function rootOf(player)
	local ch = player.Character
	return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function chestOf(player)
	local hrp = rootOf(player)
	return hrp and hrp.Position
end

local function courtRect()
	local rc = Config.Court.Rounds[Show.courtIndex()]
	return rc.Length / 2, rc.Width / 2
end

local function makeBall(id)
	local def = Balls.Defs[id] or Balls.Defs.Plain
	counter += 1
	local p = Instance.new("Part")
	p.Name = "Ball_" .. counter
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(def.size, def.size, def.size)
	p.Color = Color3.new(def.colour[1], def.colour[2], def.colour[3])
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = true
	p:SetAttribute("BallId", id)
	p:SetAttribute("State", "Idle")
	p.Parent = ballFolder
	local rec = { part = p, id = id, def = def, state = "Idle", holder = nil, heldSince = 0, outsideSince = nil }
	balls[p.Name] = rec
	return rec
end

local function setIdle(rec, pos)
	rec.state = "Idle"
	rec.holder = nil
	rec.flight = nil
	rec.part.Anchored = true
	local r = rec.def.size / 2
	rec.part.CFrame = CFrame.new(pos.X, r, pos.Z)
	rec.part:SetAttribute("State", "Idle")
	rec.part:SetAttribute("Holder", 0)
	ballState:FireAllClients({ name = rec.part.Name, state = "Idle", pos = rec.part.Position })
end

local function clearBalls()
	for name, rec in balls do
		rec.part:Destroy()
		balls[name] = nil
	end
	held = {}
end

local function spawnRound(ids)
	clearBalls()
	local n = #ids
	local radius = Config.Court.CentreCircle / 2 - 1
	for i, id in ids do
		local a = (i - 1) / n * math.pi * 2
		local rec = makeBall(id)
		setIdle(rec, Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius))
		ballSpawn:FireAllClients({ name = rec.part.Name, id = id, pos = rec.part.Position })
	end
end

local function hold(rec, player)
	rec.state = "Held"
	rec.holder = player.UserId
	rec.heldSince = os.clock()
	held[player.UserId] = rec.part.Name
	rec.part:SetAttribute("State", "Held")
	rec.part:SetAttribute("Holder", player.UserId)
	player:SetAttribute("HeldBall", rec.part.Name)
	player:SetAttribute("HeldSince", workspace:GetServerTimeNow())
end

local function release(rec)
	if rec.holder then
		local p = Players:GetPlayerByUserId(rec.holder)
		if p then
			p:SetAttribute("HeldBall", "")
			p:SetAttribute("HeldSince", 0)
		end
		held[rec.holder] = nil
	end
	rec.holder = nil
end

local function dropAtFeet(rec)
	local p = rec.holder and Players:GetPlayerByUserId(rec.holder)
	local hrp = p and rootOf(p)
	local pos = hrp and (hrp.Position + hrp.CFrame.LookVector * 2) or rec.part.Position
	release(rec)
	setIdle(rec, pos)
end

local function canPick(player)
	local role = state:roleOf(player.UserId)
	if held[player.UserId] then return false end
	if state.phase ~= "Round" then return false end
	if role == "Live" then return true end
	if role == "Ghost" then
		local rec = state.players[player.UserId]
		return rec ~= nil and rec.throwsLeft > 0
	end
	return false
end

-- Ghosts get a plain ball handed to them on the ring; it only exists while they hold it.
local function handGhostBall(player)
	local rec = makeBall("Plain")
	rec.ghostBall = true
	hold(rec, player)
end

local function launch(rec, player, targetPlayer, charge01)
	local hrp = rootOf(player)
	if not hrp then return end
	local origin = hrp.Position + Vector3.new(0, 1.5, 0) + hrp.CFrame.LookVector * 1.5
	local target = targetPlayer and chestOf(targetPlayer)
	local aimTo = target or (origin + hrp.CFrame.LookVector * 40)
	local aim = BallFlight.aim(tv(origin), tv(aimTo), charge01, Config)
	local dist = (aimTo - origin).Magnitude
	release(rec)
	rec.state = "Flight"
	rec.part.Anchored = true
	rec.part:SetAttribute("State", "Flight")
	rec.flight = {
		pos = tv(origin),
		dir = aim.dir,
		speed = aim.speed * rec.def.speedMul,
		gravity = BallFlight.usesGravity(dist, Config),
		thrower = player.UserId,
		throwerRole = state:roleOf(player.UserId),
		charge = charge01,
		started = os.clock(),
		window = BallFlight.catchWindow(charge01, Config),
		hitIds = {},
	}
	rec.part.CFrame = CFrame.new(origin)
	ballState:FireAllClients({
		name = rec.part.Name, state = "Flight", pos = origin, dir = v3(aim.dir), speed = rec.flight.speed,
		gravity = rec.flight.gravity, thrower = player.UserId, target = targetPlayer and targetPlayer.UserId or 0,
		charge = charge01,
	})
end

local function onThrow(player, ballName, targetUserId, charge01, clientStamp)
	local rec = balls[ballName]
	if not rec or rec.holder ~= player.UserId or rec.state ~= "Held" then return end
	if state.phase ~= "Round" then return end
	local now = os.clock()
	if lastThrow[player.UserId] and now - lastThrow[player.UserId] < Config.Throw.Cooldown then return end
	local hrp = rootOf(player)
	if not hrp then return end
	local role = state:roleOf(player.UserId)
	charge01 = tonumber(charge01) or 0
	charge01 = math.clamp(charge01, 0, 1)
	if role == "Ghost" then
		charge01 = 0
		local srec = state.players[player.UserId]
		if not srec or srec.throwsLeft < 1 or rec.id ~= "Plain" then return end
	elseif role ~= "Live" then
		return
	end
	local target = targetUserId and targetUserId ~= 0 and Players:GetPlayerByUserId(targetUserId) or nil
	if target and (target == player or state:roleOf(target.UserId) ~= "Live") then target = nil end
	lastThrow[player.UserId] = now
	launch(rec, player, target, charge01)
end

local function onCatch(player)
	catchPressed[player.UserId] = os.clock()
end

local function finishGhostThrow(rec, hitVictim)
	local ghostId = rec.flight and rec.flight.thrower
	if not ghostId or rec.flight.throwerRole ~= "Ghost" then return end
	if hitVictim then
		Show.handleEvents(state:ghostThrowHit(ghostId, hitVictim))
	else
		Show.handleEvents(state:ghostThrowSpent(ghostId))
	end
end

local function land(rec, pos)
	local wasGhost = rec.flight and rec.flight.throwerRole == "Ghost"
	local ghostBall = rec.ghostBall
	finishGhostThrow(rec, nil)
	if ghostBall or wasGhost then
		rec.part:Destroy()
		balls[rec.part.Name] = nil
		return
	end
	setIdle(rec, v3(pos))
end

-- One Heartbeat of flight for every ball in the air. Hits are collected, sorted by time along the
-- path, then applied so the earliest contact wins when two balls land in the same frame.
local function stepFlights(dt)
	local hits = {}
	local hl, hw = arena.PitHalfLength, arena.PitHalfWidth
	for _, rec in balls do
		if rec.state == "Flight" then
			local f = rec.flight
			local p0 = f.pos
			local p1 = BallFlight.step(p0, f.dir, f.speed, dt, f.gravity)
			if f.gravity > 0 then
				-- keep dir pointing along the actual (arcing) motion for the next step
				local seg = { x = p1.x - p0.x, y = p1.y - p0.y, z = p1.z - p0.z }
				local l = math.sqrt(seg.x ^ 2 + seg.y ^ 2 + seg.z ^ 2)
				if l > 1e-6 then f.dir = { x = seg.x / l, y = seg.y / l, z = seg.z / l } end
			end
			local radius = rec.def.size / 2
			local hitThisStep = false
			for _, p in Players:GetPlayers() do
				if p.UserId ~= f.thrower and state:roleOf(p.UserId) == "Live" and not f.hitIds[p.UserId] then
					local c = chestOf(p)
					if c and BallFlight.segmentHitsSphere(p0, p1, tv(c), Config.Throw.HitRadius + radius) then
						local t = (Vector3.new(p0.x, p0.y, p0.z) - c).Magnitude / math.max(f.speed, 1)
						table.insert(hits, { rec = rec, victim = p, at = f.started + t })
						f.hitIds[p.UserId] = true
						hitThisStep = true
						break
					end
				end
			end
			if not hitThisStep then
				local floorHit = p1.y <= radius
				local wallHit = math.abs(p1.x) > hl - radius or math.abs(p1.z) > hw - radius
				if floorHit or wallHit then
					local lx = math.clamp(p1.x, -(hl - radius), hl - radius)
					local lz = math.clamp(p1.z, -(hw - radius), hw - radius)
					land(rec, { x = lx, y = radius, z = lz })
				else
					f.pos = p1
					rec.part.CFrame = CFrame.new(p1.x, p1.y, p1.z)
				end
			end
		end
	end
	table.sort(hits, function(a, b) return a.at < b.at end)
	local now = os.clock()
	for _, h in hits do
		local rec, victim, f = h.rec, h.victim, h.rec.flight
		if rec.state ~= "Flight" then continue end
		local pressed = catchPressed[victim.UserId]
		local caught = pressed ~= nil and (now - pressed) <= f.window
		if caught then
			catchPressed[victim.UserId] = nil
			local thrower = Players:GetPlayerByUserId(f.thrower)
			local evs = state:catch(victim.UserId, f.thrower)
			Show.handleEvents(evs)
			if f.throwerRole == "Ghost" then
				finishGhostThrow(rec, nil)
				rec.part:Destroy()
				balls[rec.part.Name] = nil
			else
				rec.state = "Idle"
				rec.flight = nil
				hold(rec, victim)
				rec.part:SetAttribute("State", "Held")
				ballState:FireAllClients({ name = rec.part.Name, state = "Caught", by = victim.UserId, thrower = thrower and thrower.UserId or 0 })
			end
		else
			if f.throwerRole == "Ghost" then
				finishGhostThrow(rec, victim.UserId)
				rec.part:Destroy()
				balls[rec.part.Name] = nil
			else
				Show.handleEvents(state:hit(victim.UserId, f.thrower, h.at))
				ballState:FireAllClients({ name = rec.part.Name, state = "Hit", victim = victim.UserId, thrower = f.thrower })
				local c = chestOf(victim) or v3(f.pos)
				setIdle(rec, c + Vector3.new(0, 0, 0))
			end
		end
	end
end

local function stepIdleAndHeld(dt)
	local now = os.clock()
	local hl, hw = courtRect()
	for _, rec in balls do
		if rec.state == "Held" then
			local p = rec.holder and Players:GetPlayerByUserId(rec.holder)
			local hrp = p and rootOf(p)
			if not p or not hrp or (state:roleOf(p.UserId) ~= "Live" and state:roleOf(p.UserId) ~= "Ghost") then
				if rec.ghostBall then
					release(rec)
					rec.part:Destroy()
					balls[rec.part.Name] = nil
				else
					dropAtFeet(rec)
				end
			else
				rec.part.CFrame = hrp.CFrame * CFrame.new(1.6, 0.5, -0.5)
				if now - rec.heldSince > Config.Throw.HoldLimit and not rec.ghostBall then
					dropAtFeet(rec)
				end
			end
		elseif rec.state == "Idle" then
			local pos = rec.part.Position
			-- roll back in if outside the current kerb
			if math.abs(pos.X) > hl or math.abs(pos.Z) > hw then
				rec.outsideSince = rec.outsideSince or now
				if now - rec.outsideSince > Config.Court.BallRollBack then
					rec.outsideSince = nil
					setIdle(rec, Vector3.new(math.clamp(pos.X, -hl + 3, hl - 3), 0, math.clamp(pos.Z, -hw + 3, hw - 3)))
				end
			else
				rec.outsideSince = nil
				for _, p in Players:GetPlayers() do
					if state:roleOf(p.UserId) == "Live" and canPick(p) then
						local hrp = rootOf(p)
						if hrp and (hrp.Position - pos).Magnitude <= Config.Throw.PickupRadius then
							hold(rec, p)
							ballState:FireAllClients({ name = rec.part.Name, state = "Held", by = p.UserId })
							break
						end
					end
				end
			end
		end
	end
	-- Ghosts with a throw left and empty hands get their plain ball
	for _, p in Players:GetPlayers() do
		if state:roleOf(p.UserId) == "Ghost" and canPick(p) and rootOf(p) then
			handGhostBall(p)
		end
	end
end

function BallServer.start(config, showServer)
	Config = config
	Show = showServer
	state = showServer.state
	arena = showServer.arena
	ballFolder = Instance.new("Folder")
	ballFolder.Name = "Balls"
	ballFolder.Parent = arena.Model
	throwRequest = Remotes.get("ThrowRequest")
	catchRequest = Remotes.get("CatchRequest")
	ballSpawn = Remotes.get("BallSpawn")
	ballState = Remotes.get("BallState")

	throwRequest.OnServerEvent:Connect(function(player, ballName, targetUserId, charge01, clientStamp)
		if typeof(ballName) ~= "string" then return end
		onThrow(player, ballName, tonumber(targetUserId), charge01, clientStamp)
	end)
	catchRequest.OnServerEvent:Connect(onCatch)

	Show.onEvent(function(e)
		if e.type == "BallsDrawn" then
			spawnRound(e.ids)
		elseif e.type == "PhaseChanged" and (e.phase == "Intermission" or e.phase == "Crowning") then
			clearBalls()
		elseif e.type == "Eliminated" then
			local name = held[e.id]
			local rec = name and balls[name]
			if rec then
				if rec.ghostBall then
					release(rec)
					rec.part:Destroy()
					balls[name] = nil
				else
					dropAtFeet(rec)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		local name = held[p.UserId]
		local rec = name and balls[name]
		if rec then
			release(rec)
			if rec.ghostBall then rec.part:Destroy(); balls[name] = nil else setIdle(rec, rec.part.Position) end
		end
		catchPressed[p.UserId] = nil
		lastThrow[p.UserId] = nil
	end)

	RunService.Heartbeat:Connect(function(dt)
		if state.phase == "Round" then
			stepFlights(dt)
			stepIdleAndHeld(dt)
		end
	end)
end

return BallServer
