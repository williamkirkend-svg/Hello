-- Cursed Dodgeball show driver. Owns the ShowState, steps it on Heartbeat, moves characters when roles
-- change, runs the Flood and the out-of-bounds check, mirrors state to clients, and hands ball-related
-- events to BallServer through a callback. Only this module and BallServer touch ShowState.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedDodgeball")
local Config = require(Shared:WaitForChild("Config"))
local ShowState = require(Shared:WaitForChild("Pure"):WaitForChild("ShowState"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ShowServer = {}
ShowServer.listeners = {}

local state
local arena
local stateFolder
local showEvent
local floodTime = 0
local lastRoles = {}

-- Court dimensions index: a two-round (small) show plays its final on the final court.
local function courtIndex()
	if #state.rounds == 2 and state.round == 2 then return 3 end
	return math.max(1, state.round)
end

local function playerFromId(id)
	return Players:GetPlayerByUserId(id)
end

local function rootOf(player)
	local ch = player.Character
	return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function placeAt(player, cf)
	local hrp = rootOf(player)
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = cf
	end
end

-- Spreads a set of players across spawn points, deterministic by user id so clients can predict seats.
local function placeAll(playersList, points)
	table.sort(playersList, function(a, b) return a.UserId < b.UserId end)
	for i, p in playersList do
		placeAt(p, points[((i - 1) % #points) + 1])
	end
end

local function playersWithRole(role)
	local out = {}
	for _, p in Players:GetPlayers() do
		if state:roleOf(p.UserId) == role then table.insert(out, p) end
	end
	return out
end

local function applyRoles(force)
	local live, ghosts, stands = {}, {}, {}
	for _, p in Players:GetPlayers() do
		local role = state:roleOf(p.UserId)
		p:SetAttribute("Role", role)
		local rec = state.players[p.UserId]
		p:SetAttribute("GhostThrows", rec and rec.throwsLeft or 0)
		if force or lastRoles[p.UserId] ~= role then
			if role == "Live" then table.insert(live, p)
			elseif role == "Ghost" then table.insert(ghosts, p)
			else table.insert(stands, p) end
		end
		lastRoles[p.UserId] = role
	end
	if #live > 0 then placeAll(live, arena:spawnPointsCourt(math.max(#live, 8), courtIndex())) end
	if #ghosts > 0 then placeAll(ghosts, arena:spawnPointsRing(math.max(#ghosts, 12))) end
	if #stands > 0 then placeAll(stands, arena:spawnPointsStands(#stands)) end
end

local function mirror()
	stateFolder:SetAttribute("Phase", state.phase)
	stateFolder:SetAttribute("Round", state.round)
	stateFolder:SetAttribute("Rounds", #state.rounds)
	stateFolder:SetAttribute("Timer", math.max(0, state.timer))
	stateFolder:SetAttribute("Live", state:liveCount())
	stateFolder:SetAttribute("Flood", state.flood)
	stateFolder:SetAttribute("FloodInset", state.flood and floodTime * Config.Show.FloodSpeed or 0)
	stateFolder:SetAttribute("Winner", state.winner or 0)
	local text
	if state.phase == "Intermission" then
		local n = #Players:GetPlayers()
		text = n >= Config.Players.Min and ("NEXT SHOW IN " .. math.ceil(math.max(0, state.timer)))
			or ("NEED " .. Config.Players.Min .. " PLAYERS (" .. n .. ")")
	elseif state.phase == "Round" then
		text = ("ROUND %d   %d LEFT   %d"):format(state.round, state:liveCount(), math.ceil(math.max(0, state.timer)))
		if state.flood then text = "FLOOD!  " .. text end
	elseif state.phase == "Replay" then
		text = "CUT!  " .. state:liveCount() .. " SURVIVE"
	else
		local w = state.winner and playerFromId(state.winner)
		text = "WINNER: " .. (w and w.DisplayName or "nobody")
	end
	arena.JumboText.Text = text
end

ShowServer.courtIndex = courtIndex

function ShowServer.handleEvents(events)
	for _, e in events do
		showEvent:FireAllClients(e)
		for _, fn in ShowServer.listeners do fn(e) end
		if e.type == "PhaseChanged" then
			if e.phase == "Round" then
				arena:setRound(courtIndex())
				arena:setGates(true)
				arena:clearFlood()
				floodTime = 0
			elseif e.phase == "Intermission" then
				arena:setRound(1)
				arena:setGates(false)
				arena:clearFlood()
			elseif e.phase == "Replay" or e.phase == "Crowning" then
				arena:clearFlood()
			end
			applyRoles(e.phase == "Round" or e.phase == "Intermission")
		elseif e.type == "Eliminated" or e.type == "GhostReturned" or e.type == "GhostSpent" or e.type == "Winner" then
			applyRoles(false)
		elseif e.type == "FloodStarted" then
			floodTime = 0
		end
	end
end

function ShowServer.onEvent(fn)
	table.insert(ShowServer.listeners, fn)
end

-- Live players outside the current kerb (or inside the flood band) are out. No Touched events.
local function boundsCheck()
	if state.phase ~= "Round" then return end
	local rc = Config.Court.Rounds[courtIndex()]
	local hl, hw = rc.Length / 2, rc.Width / 2
	local inset = state.flood and floodTime * Config.Show.FloodSpeed or 0
	local batch = {}
	for _, p in playersWithRole("Live") do
		local hrp = rootOf(p)
		if hrp then
			local x, z = math.abs(hrp.Position.X), math.abs(hrp.Position.Z)
			if x > hl or z > hw then
				table.insert(batch, { id = p.UserId, by = "OutOfBounds" })
			elseif inset > 0 and (x > hl - inset or z > hw - inset) then
				table.insert(batch, { id = p.UserId, by = "Flood" })
			end
		end
	end
	for _, h in batch do
		ShowServer.handleEvents(state:hit(h.id, h.by, os.clock()))
	end
end

function ShowServer.start(config, builtArena)
	arena = builtArena
	state = ShowState.new(config, math.random)
	ShowServer.state = state
	ShowServer.arena = arena
	stateFolder = Remotes.stateFolder()
	showEvent = Remotes.get("ShowEvent")
	for _, n in Remotes.Names do Remotes.get(n) end

	local function onPlayer(p)
		ShowServer.handleEvents(state:addPlayer(p.UserId))
		p.CharacterAdded:Connect(function(ch)
			local hum = ch:WaitForChild("Humanoid")
			hum.BreakJointsOnDeath = false
			task.defer(function()
				lastRoles[p.UserId] = nil
				applyRoles(false)
			end)
		end)
		if p.Character then
			lastRoles[p.UserId] = nil
			applyRoles(false)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do onPlayer(p) end
	Players.PlayerRemoving:Connect(function(p)
		lastRoles[p.UserId] = nil
		ShowServer.handleEvents(state:removePlayer(p.UserId))
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		if state.flood then floodTime += dt end
		ShowServer.handleEvents(state:step(dt))
		if state.flood then
			arena:setFlood(courtIndex(), floodTime * Config.Show.FloodSpeed)
		end
		boundsCheck()
		acc += dt
		if acc >= 0.2 then
			acc = 0
			mirror()
		end
	end)
	mirror()
end

return ShowServer
