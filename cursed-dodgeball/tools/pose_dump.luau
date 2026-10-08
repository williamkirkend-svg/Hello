-- Runs the real AnimState through scripted scenes and prints one JSON object per frame.
-- Usage (from cursed-dodgeball/): luau tools/pose_dump.luau > out.jsonl
-- The scenes move a point through the world with simple kinematics that mirror the controller, so the
-- preview shows the poses travelling the way they will in game.
local AnimState = require("../src/ReplicatedStorage/CursedDodgeball/Movement/AnimState")
local Poses = require("../src/ReplicatedStorage/CursedDodgeball/Movement/Poses")
local C = require("../src/ReplicatedStorage/CursedDodgeball/Movement/MovementConfig")

local DT = 1 / 60
local OUT_EVERY = 2 -- 30 fps output
local GROUND_Y = 3.0
local G = C.Gravity
local JUMP_V = math.sqrt(2 * G * C.JumpHeight)

local function fmt(n) return string.format("%.4f", n) end

local function emit(scene, frame, sim, pose, extra)
	local parts = {}
	for _, j in Poses.JOINTS do
		local v = pose[j]
		table.insert(parts, string.format('"%s":[%s,%s,%s]', j, fmt(v.x), fmt(v.y), fmt(v.z)))
	end
	table.insert(parts, string.format('"RootPos":[%s,%s,%s]', fmt(pose.RootPos.x), fmt(pose.RootPos.y), fmt(pose.RootPos.z)))
	table.insert(parts, string.format('"RootSpin":[%s,%s,%s]', fmt(pose.RootSpin.x), fmt(pose.RootSpin.y), fmt(pose.RootSpin.z)))
	print(string.format('{"scene":"%s","frame":%d,"pos":[%s,%s,%s],"yaw":%s,"state":"%s","speed":%s,"label":"%s","pose":{%s}%s}',
		scene, frame, fmt(sim.x), fmt(sim.y), fmt(sim.z), fmt(sim.yaw), sim.state, fmt(sim.speed), extra or "", table.concat(parts, ","),
		sim.wall and string.format(',"wall":%s', sim.wall) or ""))
end

-- sim = { x, y, z, yaw, speed, vy, state, hipDrop }
local function newSim() return { x = 0, y = GROUND_Y, z = 0, yaw = 0, speed = 0, vy = 0, state = "Ground", hipDrop = 0 } end

local function run(scene, steps)
	local anim = AnimState.new(C)
	local sim = newSim()
	local frame = 0
	local n = 0
	local prevSpeed = 0
	for _, step in steps do
		local t = 0
		local first = true
		while t < step.dur - 1e-9 do
			local events = nil
			if first and step.events then events = step.events end
			first = false
			if step.update then step.update(sim, t, DT) end
			-- kinematics
			local fx, fz = -math.sin(sim.yaw), -math.cos(sim.yaw)
			local mx, mz = fx, fz
			if sim.moveDir then mx, mz = sim.moveDir[1], sim.moveDir[2] end
			sim.x += mx * sim.speed * DT
			sim.z += mz * sim.speed * DT
			if sim.state == "Air" then
				local g = sim.vy < 0 and G * C.FallGravityMult or G
				sim.vy -= g * DT
				sim.y += sim.vy * DT
				if sim.y <= GROUND_Y and sim.vy < 0 then sim.y = GROUND_Y end
			elseif sim.state == "WallRun" then
				sim.vy = math.max(-C.WallRunMaxSink, sim.vy - G * C.WallRunGravity * DT)
				sim.y += sim.vy * DT
			else
				sim.vy = 0
				sim.y = GROUND_Y - sim.hipDrop
			end
			local accel = (sim.speed - prevSpeed) / DT
			prevSpeed = sim.speed
			local pose = anim:update(DT, {
				state = sim.state, speed = sim.speed, vy = sim.vy, yawRate = sim.yawRate or 0, accel = accel,
				wallSide = sim.wallSide or 0, dashX = sim.dashX, dashZ = sim.dashZ, events = events,
			})
			if n % OUT_EVERY == 0 then
				frame += 1
				emit(scene, frame, sim, pose, step.label)
			end
			n += 1
			t += DT
		end
	end
end

local function ramp(field, from, to)
	return function(sim, t, _dt, dur) sim[field] = from + (to - from) * t end
end

-- Scene 1: idle, accelerate to sprint, bank through a turn, stop.
run("run", {
	{ dur = 0.8, label = "idle", update = function(s) s.speed = 0 s.state = "Ground" end },
	{ dur = 0.6, label = "jog up", update = function(s, t) s.speed = math.min(C.JogSpeed, t / 0.6 * C.JogSpeed) end },
	{ dur = 0.6, label = "sprint ramp", update = function(s, t) s.speed = C.JogSpeed + (C.SprintSpeed - C.JogSpeed) * math.min(1, t / 0.6) end },
	{ dur = 1.2, label = "sprint", update = function(s) s.speed = C.SprintSpeed end },
	{ dur = 1.2, label = "turning left", update = function(s) s.yawRate = 1.6 s.yaw += 1.6 / 60 end },
	{ dur = 0.6, label = "boosted, top speed", update = function(s) s.yawRate = 0 s.speed = C.HardCap end },
	{ dur = 0.5, label = "stop", update = function(s, t) s.speed = math.max(0, C.HardCap - C.GroundDecel * t) end },
	{ dur = 0.8, label = "idle", update = function(s) s.speed = 0 end },
})

-- Scene 2: running jump, double jump, medium landing, run on; then a standing heavy landing.
run("jump", {
	{ dur = 0.8, label = "sprint", update = function(s) s.speed = C.SprintSpeed s.state = "Ground" end },
	{ dur = 0.35, label = "jump", events = { "Jump" }, update = function(s, t) if t == 0 then s.state = "Air" s.vy = JUMP_V end end },
	{ dur = 0.6, label = "double jump", events = { "DoubleJump" }, update = function(s, t) if t == 0 then s.vy = JUMP_V * C.DoubleJumpScale end end },
	{ dur = 0.5, label = "falling", update = function(s) if s.y <= GROUND_Y + 0.01 and s.vy <= 0 then s.y = GROUND_Y end end },
	{ dur = 0.6, label = "medium landing", events = { "Land:Medium" }, update = function(s) s.state = "Ground" s.vy = 0 end },
	{ dur = 0.6, label = "run on", update = function(s) s.speed = C.SprintSpeed end },
	{ dur = 0.5, label = "stop", update = function(s, t) s.speed = math.max(0, C.SprintSpeed - C.GroundDecel * t) end },
	{ dur = 0.3, label = "drop from a rail", update = function(s, t) if t == 0 then s.state = "Air" s.y = 12 s.vy = 0 s.speed = 0 end end },
	{ dur = 0.25, label = "falling", update = function() end },
	{ dur = 0.8, label = "heavy landing", events = { "Land:Heavy" }, update = function(s) s.state = "Ground" s.vy = 0 end },
	{ dur = 0.6, label = "idle", update = function(s) s.speed = 0 end },
})

-- Scene 3: wall run on a wall to the right, wall jump away, roll landing.
run("wallrun", {
	{ dur = 0.7, label = "sprint", update = function(s) s.speed = C.SprintSpeed s.state = "Ground" s.wall = 2.6 end },
	{ dur = 0.2, label = "jump", events = { "Jump" }, update = function(s, t) if t == 0 then s.state = "Air" s.vy = JUMP_V * 0.7 end end },
	{ dur = 1.0, label = "wall run", update = function(s, t) if s.state ~= "WallRun" then s.state = "WallRun" s.vy = math.max(s.vy, C.WallRunLift) end s.wallSide = 1 s.speed = C.SprintSpeed + C.BoostWallRun end },
	{ dur = 0.25, label = "wall jump", events = { "WallJump" }, update = function(s, t) if t == 0 then s.state = "Air" s.vy = C.WallJumpUp s.yaw += 0.6 s.speed = C.SprintSpeed * C.WallJumpKeep + 4 end end },
	{ dur = 0.6, label = "air", update = function() end },
	{ dur = 0.5, label = "roll landing", events = { "Land:Roll" }, update = function(s) s.state = "Ground" s.vy = 0 s.wallSide = 0 end },
	{ dur = 0.7, label = "run on", update = function(s) s.speed = C.SprintSpeed end },
})

-- Scene 4: slide, slide jump, light landing, dash right, dash forward.
run("slide", {
	{ dur = 0.8, label = "sprint", update = function(s) s.speed = C.SprintSpeed s.state = "Ground" end },
	{ dur = 0.9, label = "slide", update = function(s, t) s.state = "Slide" s.hipDrop = C.SlideHipDrop s.speed = math.max(C.SlideEndSpeed, C.SprintSpeed + C.BoostSlide - C.SlideFriction * t) end },
	{ dur = 0.55, label = "slide jump", events = { "Jump" }, update = function(s, t) if t == 0 then s.hipDrop = 0 s.state = "Air" s.vy = JUMP_V end end },
	{ dur = 0.4, label = "light landing", events = { "Land:Light" }, update = function(s) s.state = "Ground" s.vy = 0 end },
	{ dur = 0.5, label = "run", update = function(s) s.speed = C.SprintSpeed end },
	{ dur = 0.22, label = "dash right", update = function(s) s.state = "Dash" s.dashX, s.dashZ = 1, 0 s.moveDir = { math.cos(s.yaw), -math.sin(s.yaw) } s.speed = C.DashDistance / C.DashSeconds end },
	{ dur = 0.5, label = "run", update = function(s) s.state = "Ground" s.moveDir = nil s.speed = C.SprintSpeed end },
	{ dur = 0.22, label = "dash forward", update = function(s) s.state = "Dash" s.dashX, s.dashZ = 0, -1 s.speed = C.DashDistance / C.DashSeconds end },
	{ dur = 0.8, label = "run", update = function(s) s.state = "Ground" s.speed = C.SprintSpeed end },
})
