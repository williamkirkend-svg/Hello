-- Cursed Dodgeball show state machine. Pure: no Roblox requires, no clocks of its own.
-- Phases: Intermission -> Round (1..n) -> Replay -> Round ... -> Crowning -> Intermission.
-- Roles: Waiting (in the stands, will play next show), Live (on the court), Ghost (on the ring with
-- throws left), Spectator (in the stands for the rest of this show).
-- In Studio `script` exists and the sibling ModuleScript is required; under the luau CLI `script` is nil
-- and the file next to this one is required by path.
local Balls = if script then require(script.Parent.Balls) else require("./Balls")

local ShowState = {}
ShowState.__index = ShowState

function ShowState.new(config, rng)
	local self = setmetatable({}, ShowState)
	self.config = config
	self.rng = rng
	self.players = {} -- id -> { role, shieldUntil, throwsLeft, ghostThrowUsed }
	self.phase = "Intermission"
	self.round = 0
	self.rounds = config.Show.Rounds
	self.timer = config.Show.Intermission
	self.flood = false
	self.now = 0
	self.lastOut = nil
	self.winner = nil
	return self
end

local function push(events, e) events[#events + 1] = e end

function ShowState:roleOf(id)
	local p = self.players[id]
	return p and p.role or nil
end

function ShowState:liveCount()
	local n = 0
	for _, p in self.players do if p.role == "Live" then n += 1 end end
	return n
end

function ShowState:playerCount()
	local n = 0
	for _ in self.players do n += 1 end
	return n
end

function ShowState:liveIds()
	local ids = {}
	for id, p in self.players do if p.role == "Live" then ids[#ids + 1] = id end end
	table.sort(ids)
	return ids
end

function ShowState:isFinal()
	return self.round == #self.rounds
end

function ShowState:addPlayer(id)
	local role = (self.phase == "Intermission") and "Waiting" or "Spectator"
	self.players[id] = { role = role, shieldUntil = nil, throwsLeft = 0, ghostThrowUsed = false }
	return {}
end

function ShowState:removePlayer(id)
	local events = {}
	local p = self.players[id]
	if not p then return events end
	local wasLive = p.role == "Live"
	self.players[id] = nil
	if wasLive and self.phase == "Round" then
		self.lastOut = self.lastOut or id
		self:checkCut(events)
	end
	return events
end

function ShowState:startRound(roundIndex, events)
	self.round = roundIndex
	self.phase = "Round"
	self.flood = false
	self.timer = self.rounds[roundIndex].Cap
	-- Ghosts who did not get back in watch from the stands from here on.
	for _, p in self.players do
		if p.role == "Ghost" then p.role = "Spectator" end
		p.throwsLeft = 0
		p.ghostThrowUsed = false
	end
	push(events, { type = "PhaseChanged", phase = "Round", round = roundIndex })
	local drawRound = math.min(roundIndex, #self.config.Balls.Rounds)
	if #self.rounds == 2 and roundIndex == 2 then drawRound = 3 end
	push(events, { type = "BallsDrawn", round = roundIndex, ids = Balls.draw(drawRound, self.rng, self.config) })
end

function ShowState:startShow(events)
	local n = self:playerCount()
	self.rounds = (n < self.config.Players.SmallShowBelow) and self.config.Show.SmallRounds or self.config.Show.Rounds
	self.winner = nil
	self.lastOut = nil
	for _, p in self.players do
		p.role = "Live"
		p.shieldUntil = nil
	end
	self:startRound(1, events)
end

function ShowState:step(dt)
	local events = {}
	self.now += dt
	self.timer -= dt
	-- shields
	for id, p in self.players do
		if p.shieldUntil and self.now >= p.shieldUntil then
			p.shieldUntil = nil
			push(events, { type = "ShieldExpired", id = id })
		end
	end
	if self.phase == "Intermission" then
		if self.timer <= 0 then
			if self:playerCount() >= self.config.Players.Min then
				self:startShow(events)
			else
				self.timer = self.config.Show.Intermission
			end
		end
	elseif self.phase == "Round" then
		if self.timer <= 0 and not self.flood then
			self.flood = true
			push(events, { type = "FloodStarted", round = self.round })
		end
	elseif self.phase == "Replay" then
		if self.timer <= 0 then self:startRound(self.round + 1, events) end
	elseif self.phase == "Crowning" then
		if self.timer <= 0 then
			self.phase = "Intermission"
			self.timer = self.config.Show.Intermission
			self.round = 0
			for _, p in self.players do
				p.role = "Waiting"
				p.shieldUntil = nil
			end
			push(events, { type = "PhaseChanged", phase = "Intermission", round = 0 })
		end
	end
	return events
end

-- Moves a Live player off the court. In the final they go straight to the stands; otherwise they
-- become a Ghost with one throw unless they already used this round's ghost throw.
function ShowState:eliminate(id, by, events)
	local p = self.players[id]
	self.lastOut = id
	if self:isFinal() or p.ghostThrowUsed then
		p.role = "Spectator"
		p.throwsLeft = 0
	else
		p.role = "Ghost"
		p.throwsLeft = self.config.Show.GhostThrows
	end
	p.shieldUntil = nil
	push(events, { type = "Eliminated", id = id, by = by })
end

function ShowState:checkCut(events)
	if self.phase ~= "Round" then return end
	local spec = self.rounds[self.round]
	local live = self:liveCount()
	if live > spec.CutTo then return end
	if self:isFinal() then
		local ids = self:liveIds()
		self.winner = ids[1] or self.lastOut
		self.phase = "Crowning"
		self.timer = self.config.Show.Crowning
		self.flood = false
		if #ids == 0 and self.winner and self.players[self.winner] then
			self.players[self.winner].role = "Live"
		end
		push(events, { type = "Winner", id = self.winner })
		push(events, { type = "PhaseChanged", phase = "Crowning", round = self.round })
	else
		self.phase = "Replay"
		self.timer = self.config.Show.Replay
		self.flood = false
		push(events, { type = "Cut", round = self.round, survivors = self:liveIds() })
		push(events, { type = "PhaseChanged", phase = "Replay", round = self.round })
	end
end

function ShowState:hit(victimId, throwerId, stamp)
	local events = {}
	local v = self.players[victimId]
	if self.phase ~= "Round" or not v or v.role ~= "Live" then return events end
	if v.shieldUntil then
		v.shieldUntil = nil
		push(events, { type = "ShieldBroken", id = victimId, by = throwerId, stamp = stamp })
		return events
	end
	self:eliminate(victimId, throwerId, events)
	self:checkCut(events)
	return events
end

function ShowState:catch(catcherId, throwerId)
	local events = {}
	local c = self.players[catcherId]
	local th = self.players[throwerId]
	if self.phase ~= "Round" or not c or c.role ~= "Live" then return events end
	if th and th.role == "Live" then
		self:eliminate(throwerId, catcherId, events)
	end
	c.shieldUntil = self.now + self.config.Catch.ShieldSeconds
	push(events, { type = "ShieldGained", id = catcherId })
	self:checkCut(events)
	return events
end

function ShowState:ghostThrowHit(ghostId, victimId)
	local events = {}
	local g = self.players[ghostId]
	local v = self.players[victimId]
	if self.phase ~= "Round" or not g or g.role ~= "Ghost" or g.throwsLeft < 1 then return events end
	if not v or v.role ~= "Live" then return events end
	g.role = "Live"
	g.throwsLeft = 0
	g.ghostThrowUsed = true
	g.shieldUntil = nil
	self:eliminate(victimId, ghostId, events)
	-- the elimination above is a swap, not progress toward the cut: no checkCut here
	push(events, { type = "GhostReturned", ghost = ghostId, victim = victimId })
	return events
end

function ShowState:ghostThrowSpent(ghostId)
	local events = {}
	local g = self.players[ghostId]
	if not g or g.role ~= "Ghost" then return events end
	g.role = "Spectator"
	g.throwsLeft = 0
	g.ghostThrowUsed = true
	push(events, { type = "GhostSpent", id = ghostId })
	return events
end

return ShowState
