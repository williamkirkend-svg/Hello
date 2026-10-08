-- Cursed Dodgeball animation compositor. Pure: turns movement state into a final pose every frame.
-- Used by the Roblox animator (one instance per character) and by the preview renderer.
--
-- input = {
--   state    "Ground" | "Air" | "WallRun" | "Slide" | "Dash" | "Mantle"
--   speed    horizontal speed, studs/s
--   vy       vertical speed, studs/s
--   yawRate  turn rate, rad/s (+ = turning left)
--   accel    forward acceleration, studs/s^2
--   wallSide +1 wall on the right, -1 on the left (wall run and wall jump)
--   dashX, dashZ  dash direction in character space
--   events   list of one-shots this frame: "Jump", "DoubleJump", "WallJump", "Land:Light|Medium|Heavy|Roll"
-- }
--
-- Smoothness comes from springs on the inputs and layer weights, not on the joints, so the run cycle
-- never lags or loses amplitude. A light output filter removes any remaining hard edges.
local Poses = if script then require(script.Parent.Poses) else require("./Poses")

local AnimState = {}
AnimState.__index = AnimState

local STATES = { "Ground", "Air", "WallRun", "Slide", "Dash", "Mantle" }
local RATE = { Ground = 12, Air = 14, WallRun = 16, Slide = 18, Dash = 28, Mantle = 22 }
local OUTPUT_K = 40
local TAU = 2 * math.pi

local function alpha(k, dt) return 1 - math.exp(-k * dt) end
local function smoothstep(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end

-- Envelope: rises over `attack`, holds until `hold`, falls back to 0 at `dur`.
local function envelope(t, attack, hold, dur)
	if t < 0 or t >= dur then return 0 end
	if t < attack then return smoothstep(t / attack) end
	if t < hold then return 1 end
	return 1 - smoothstep((t - hold) / (dur - hold))
end

-- rig: optional leg measurements from the real character (see Poses.DEFAULT_RIG).
function AnimState.new(C, rig)
	local self = setmetatable({}, AnimState)
	self.C = C
	self.rig = rig or Poses.DEFAULT_RIG
	self.t = 0
	self.phase = 0
	self.speed = 0
	self.vy = 0
	self.bank = 0
	self.accelLean = 0
	self.side = 1
	self.dashX, self.dashZ = 0, -1
	self.lead = true
	self.w = { Ground = 1, Air = 0, WallRun = 0, Slide = 0, Dash = 0, Mantle = 0 }
	self.land = nil -- { kind, t, dur }
	self.tuckT = math.huge
	self.kickT = math.huge
	self.kickSide = 1
	self.rollT = math.huge
	self.flipT = math.huge
	self.mantleT = 0
	self.out = Poses.idle(0)
	return self
end

function AnimState:event(name)
	local C = self.C
	if name == "Jump" then
		self.lead = math.sin(self.phase * TAU) > 0
	elseif name == "DoubleJump" then
		self.tuckT = 0
		if C.DoubleJumpFlip then self.flipT = 0 end
	elseif name == "WallJump" then
		self.kickT = 0
		self.kickSide = self.side
	else
		local kind = string.match(name, "^Land:(%a+)$")
		if kind == "Roll" then
			self.rollT = 0
			self.land = nil
		elseif kind then
			local dur = (kind == "Heavy" and C.LandHeavyTime) or (kind == "Medium" and C.LandMediumTime) or C.LandLightTime
			self.land = { kind = kind, t = 0, dur = dur + 0.12 }
			-- a landing does not cut the tuck or kick (the air layer fades them out); a flip still in
			-- progress is finished to the nearest upright in 0.12 s instead of popping
			if self.flipT < C.DoubleJumpFlipTime then
				self.flipSettle = { from = self.lastSpin or 0, t = 0 }
				self.flipT = math.huge
			end
		end
	end
end

function AnimState:update(dt, input)
	local C = self.C
	if input.events then
		for _, e in input.events do self:event(e) end
	end
	self.t += dt
	local state = input.state or "Ground"

	-- smoothed inputs
	self.speed += ((input.speed or 0) - self.speed) * alpha(10, dt)
	self.vy += ((input.vy or 0) - self.vy) * alpha(14, dt)
	local s01 = math.clamp(self.speed / C.HardCap, 0, 1)
	local bankTarget = math.clamp((input.yawRate or 0) * 0.07 * s01, -C.BankMax, C.BankMax)
	self.bank += (bankTarget - self.bank) * alpha(8, dt)
	local leanTarget = math.clamp((input.accel or 0) / C.GroundAccel, -1, 1) * 0.12
	self.accelLean += (leanTarget - self.accelLean) * alpha(6, dt)
	if input.wallSide and input.wallSide ~= 0 then self.side = input.wallSide end
	if state == "Dash" then
		local l = math.sqrt((input.dashX or 0) ^ 2 + (input.dashZ or 0) ^ 2)
		if l > 0.01 then
			self.dashX += ((input.dashX / l) - self.dashX) * alpha(30, dt)
			self.dashZ += ((input.dashZ / l) - self.dashZ) * alpha(30, dt)
		end
	end
	self.mantleT = (state == "Mantle") and (self.mantleT + dt) or 0

	-- run phase: stride frequency follows speed; quicker feet on a wall
	local freq = (state == "WallRun") and 2.8 or (0.9 + 1.7 * s01)
	self.phase = (self.phase + freq * dt) % 1

	-- layer weights
	for _, st in STATES do
		local target = (st == state) and 1 or 0
		self.w[st] += (target - self.w[st]) * alpha(RATE[st], dt)
	end

	-- layers
	local list = {}
	local w = self.w
	local plant = 0 -- how strongly the feet are pinned to the floor this frame
	if w.Ground > 0.001 then
		local gait = math.clamp(self.speed / 6, 0, 1)
		local ground = Poses.lerp(Poses.idle(self.t), Poses.run(self.phase, s01), smoothstep(gait))
		ground.Root.z += self.bank
		ground.Waist.x -= self.accelLean
		table.insert(list, { ground, w.Ground })
		plant = w.Ground * (1 - smoothstep(gait))
	end
	if w.Air > 0.001 then
		local air = Poses.air(self.vy / 40, self.lead)
		local tuckDur = C.DoubleJumpFlip and C.DoubleJumpFlipTime + 0.08 or 0.32
		local tuck = envelope(self.tuckT, 0.07, tuckDur * 0.55, tuckDur)
		if tuck > 0 then air = Poses.lerp(air, Poses.tuck(), tuck) end
		local kick = envelope(self.kickT, 0.04, 0.1, 0.3)
		if kick > 0 then air = Poses.lerp(air, Poses.wallKick(self.kickSide), kick) end
		air.Root.z += self.bank * 0.5
		table.insert(list, { air, w.Air })
	end
	if w.WallRun > 0.001 then table.insert(list, { Poses.wallRun(self.phase, self.side), w.WallRun }) end
	if w.Slide > 0.001 then table.insert(list, { Poses.slide(), w.Slide }) end
	if w.Dash > 0.001 then table.insert(list, { Poses.dash(self.dashX, self.dashZ), w.Dash }) end
	if w.Mantle > 0.001 then table.insert(list, { Poses.mantle(self.mantleT / C.MantleTime), w.Mantle }) end
	local pose = Poses.blend(list)

	-- one-shots
	self.tuckT += dt
	self.kickT += dt
	if self.land then
		local L = self.land
		local k = envelope(L.t, 0.06, 0.06 + (L.dur - 0.12) * 0.35, L.dur)
		if L.kind == "Heavy" then
			pose = Poses.lerp(pose, Poses.land("Heavy", 1), k)
		else
			local add = Poses.land(L.kind, k)
			for _, j in Poses.JOINTS do
				pose[j].x += add[j].x
				pose[j].y += add[j].y
				pose[j].z += add[j].z
			end
			pose.RootPos.y += add.RootPos.y
			pose.RKnee.x = math.max(pose.RKnee.x, -2.6)
			pose.LKnee.x = math.max(pose.LKnee.x, -2.6)
		end
		L.t += dt
		if L.t >= L.dur then self.land = nil end
		plant = math.max(plant, k * w.Ground)
	end
	-- feet: never sink into the floor while grounded, and stay planted while standing or landing
	local grounded = w.Ground + w.Slide + w.Dash
	if grounded > 0.01 then
		local low = Poses.lowestFoot(pose, self.rig)
		if low < 0 then
			pose.RootPos.y -= low * math.min(1, grounded)
		elseif plant > 0 then
			pose.RootPos.y -= low * math.min(1, plant)
		end
	end
	local spin = 0
	if self.flipSettle then
		local fs = self.flipSettle
		local target = math.floor(fs.from / TAU + 0.5) * TAU
		local u = math.min(1, fs.t / 0.12)
		spin = fs.from + (target - fs.from) * smoothstep(u)
		fs.t += dt
		if u >= 1 then self.flipSettle = nil spin = 0 end
	elseif self.flipT < C.DoubleJumpFlipTime then
		spin = -TAU * smoothstep(self.flipT / C.DoubleJumpFlipTime)
		self.flipT += dt
	end
	if self.rollT < C.LandRollTime then
		local u = self.rollT / C.LandRollTime
		local rp = Poses.roll(u)
		local edge = math.min(1, self.rollT / 0.05, (C.LandRollTime - self.rollT) / 0.08)
		pose = Poses.lerp(pose, rp, math.max(0, edge))
		spin = rp.RootSpin.x
		self.rollT += dt
	end

	-- output filter (RootSpin bypasses it so a roll is exact)
	local out = self.out
	local a = alpha(OUTPUT_K, dt)
	for _, j in Poses.JOINTS do
		local o, p = out[j], pose[j]
		o.x += (p.x - o.x) * a
		o.y += (p.y - o.y) * a
		o.z += (p.z - o.z) * a
	end
	out.RootPos.x += (pose.RootPos.x - out.RootPos.x) * a
	out.RootPos.y += (pose.RootPos.y - out.RootPos.y) * a
	out.RootPos.z += (pose.RootPos.z - out.RootPos.z) * a
	self.lastSpin = spin
	out.RootSpin.x, out.RootSpin.y, out.RootSpin.z = spin, 0, 0
	return out
end

return AnimState
