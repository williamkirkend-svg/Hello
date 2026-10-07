-- CelebrationFX.AuraSound: the show-side wrapper round SoundKit (Oct 7 2026).
-- Shows get it with  local S = require(script.Parent.Parent.AuraSound)  and schedule cues on the show's timeline:
--   S.Cue(ctx, .35, "CelDetonate")                       -- at t = .35, 3D at the player's feet
--   S.Cue(ctx, 1.2, "StarTwinkle", {At = part})          -- rides a seeker (the Sound moves with the part)
--   S.Cue(ctx, 2, "WingFlap", {At = function() return P.Torso end})
--   local h = S.Loop(ctx, 0, 4.4, "CosmicHum")  h:Set(k)  -- a loop between two beats, stopped with the show
--   S.Hit(ctx, 0, "L")                                   -- the shared three-layer hit (S / M / L)
--   S.Bed(ctx, .4, LEN - .8)                             -- CelBed under Set 3 (own show only)
--   S.Duck(ctx, 0, LEN)                                  -- Music and Ambience down for the show (own show only)
--
-- Rules (docs/sound-pitch.md section 4): volume scales by ctx.Quality; other players' shows skip the "air" cues
-- (Air = true: shimmers, tails, beds, titles, the charge-up); only your own show ducks; only one remote show keeps
-- loops; o.MinSet skips a cue below that set; o.Local = true plays only for your own show. Every live sound follows
-- ctx.TimeRate (AuraKit.TimeScale publishes it: 1 normally, .1 during a slow-down) and dies with the show.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local okKit, Kit = pcall(function()
	local fl = script.Parent.Parent
	return require(fl:FindFirstChild("SoundKit") or ReplicatedStorage:WaitForChild("FarmLasso"):WaitForChild("SoundKit", 5))
end)
if not okKit or type(Kit) ~= "table" then
	warn("[AuraSound] SoundKit not found; celebrations play silent")
	Kit = {Play = function() end, Loop = function() end, Duck = function() end, DuckHold = function() return function() end end, Has = function() return false end}
end

local S = {}
S.Kit = Kit
local AIR = {CelShimmer = true, CelBed = true, CelTitle = true, CelChargeUp = true, CelRiser = true, PetalShimmer = true,
	EmberSparkle = true, StarMapResolve = true, CosmicHum = true}
local remoteLoopOwner = nil -- the one remote ctx allowed loops

local function book(ctx)
	if ctx.Sounds then return ctx.Sounds end
	local list = {}
	ctx.Sounds = list
	ctx.TimeRate = ctx.TimeRate or 1
	local lastRate = 1
	ctx:Every(function()
		if not ctx.Alive then return true end
		local r = ctx.TimeRate or 1
		if r ~= lastRate then
			lastRate = r
			for _, h in list do if not h.Done and not h.FixedRate then h:SetRate(r) end end
		end
	end)
	ctx:OnCleanup(function()
		for _, h in list do if not h.Done then h:Stop(.25) end end
		if remoteLoopOwner == ctx then remoteLoopOwner = nil end
	end)
	-- Stop() runs the cleanups 1.6 s after the fade; loops should die with the visuals, so hook the stop too
	local stop = ctx.Stop
	ctx.Stop = function(self, fast)
		for _, h in list do if h.Loop and not h.Done then h:Stop(fast and .1 or .4) end end
		return stop(self, fast)
	end
	return list
end
local function allowed(ctx, name, o)
	o = o or {}
	if o.Local and not ctx.Local then return false end
	if o.MinSet and (ctx.Set or 3) < o.MinSet then return false end
	-- tails, beds, the title and the charge-up are for your own show only (other players hear the hits and signatures)
	if not ctx.Local and (o.Air or AIR[name]) then return false end
	if o.Chance and math.random() > o.Chance then return false end
	return true
end
local function where(ctx, at)
	if type(at) == "function" then at = at() end
	if at == nil then return ctx.Anchor or ctx.Hrp end
	return at
end
local function opts(ctx, o)
	o = o or {}
	return {At = where(ctx, o.At), Volume = (o.Volume or 1) * (ctx.Quality or 1), Pitch = o.Pitch, Rate = o.Rate or ctx.TimeRate or 1,
		Group = o.Group or "Celebration", Cooldown = o.Cooldown}
end
-- o.Rate pins a sound's rate (it ignores ctx.TimeRate: the stutter ticks inside a freeze)
local function keep(list, h, o)
	if h then
		if o and o.Rate then h.FixedRate = true end
		table.insert(list, h)
	end
	return h
end

-- a one-shot at time t (negative t is the charge-up). o: At, Volume, Pitch, Rate (pinned), Air, Local, MinSet, Chance, Cooldown.
function S.Cue(ctx, t, name, o)
	if not allowed(ctx, name, o) then return end
	local list = book(ctx)
	ctx:At(t, function()
		if not ctx.Alive then return end
		keep(list, Kit.Play(name, opts(ctx, o)), o)
	end)
end
-- play now (from inside a callback such as OnExplode / OnU)
function S.Now(ctx, name, o)
	if not allowed(ctx, name, o) or not ctx.Alive then return nil end
	return keep(book(ctx), Kit.Play(name, opts(ctx, o)), o)
end
-- a loop from t0 to t1 (nil t1 = until the show ends). Returns a proxy: :Set(k) works before the loop starts.
function S.Loop(ctx, t0, t1, name, o)
	o = o or {}
	local proxy = {K = o.K or 0, Done = false}
	function proxy:Set(k) self.K = k if self.H then self.H:Set(k) end end
	function proxy:SetRate(r) self.R = r if self.H then self.H:SetRate(r) end end
	function proxy:Stop(fade) self.Done = true if self.H then self.H:Stop(fade or .3) end end
	if not allowed(ctx, name, o) then return proxy end
	if not ctx.Local then
		if remoteLoopOwner and remoteLoopOwner ~= ctx and remoteLoopOwner.Alive then return proxy end
		remoteLoopOwner = ctx
	end
	local list = book(ctx)
	ctx:At(t0 or 0, function()
		if not ctx.Alive or proxy.Done then return end
		local po = opts(ctx, o)
		po.K = proxy.K
		po.FadeIn = o.FadeIn
		if proxy.R then po.Rate = proxy.R end
		local h = keep(list, Kit.Loop(name, po), o)
		if h then
			proxy.H = h
			h.Loop = true
		end
	end)
	if t1 then ctx:At(t1, function() proxy:Stop(o.Fade or .35) end) end
	return proxy
end
-- the shared hit: "S" CelImpact, "M" CelDetonate, "L" CelDetonate + CelShockwave + CelShimmer
function S.Hit(ctx, t, size, o)
	size = size or "M"
	if size == "S" then
		S.Cue(ctx, t, "CelImpact", o)
	elseif size == "M" then
		S.Cue(ctx, t, "CelDetonate", o)
	else
		S.Cue(ctx, t, "CelDetonate", o)
		S.Cue(ctx, t + .05, "CelShockwave", o)
		S.Cue(ctx, t + .2, "CelShimmer", o)
	end
end
-- the airy pad under a Set 3 (own show only, skipped far away). Returns the loop proxy.
function S.Bed(ctx, t0, t1, o)
	o = o and table.clone(o) or {}
	o.Local = true
	o.K = o.K or .6
	return S.Loop(ctx, t0, t1, "CelBed", o)
end
-- Music and Ambience down for the show (own show only). Levels default .3 and .4 (Set 3) / .6 (Set 2).
function S.Duck(ctx, t0, t1, music, ambience)
	if not ctx.Local then return end
	ctx:At(t0 or 0, function()
		-- ctx.Length is only known after the builder returns, so read it here, at the beat
		local dur = math.max(.5, (t1 or ctx.Length or 5) - (t0 or 0))
		Kit.Duck("Music", music or .3, dur, .8)
		Kit.Duck("Ambience", ambience or ((ctx.Set or 3) >= 3 and .4 or .6), dur, .8)
	end)
end
-- the Set 3 charge-up inhale ending exactly at t = 0 (own show only)
function S.ChargeUp(ctx, o)
	local pre = ctx.Pre or 0
	if pre <= 0 then return end
	S.Cue(ctx, -pre, "CelChargeUp", {Local = true, Pitch = o and o.Pitch})
end
return S
