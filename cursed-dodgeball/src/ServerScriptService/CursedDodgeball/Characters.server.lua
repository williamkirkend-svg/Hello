-- Cursed Dodgeball characters.
--  * Every player is spawned as R15, whatever the place's avatar setting.
--  * Each player keeps their clothing, colours, face and accessories on the default R15 body at a fixed
--    scale, so every body and hitbox is identical.
--  * Accessories never affect physics or hit tests.
--  * Relays each client's movement state to everyone else so every client can animate every character.
--  * Corrects sustained impossible speeds.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedDodgeball")
local Remotes = require(Shared:WaitForChild("Remotes"))
local C = require(Shared:WaitForChild("Movement"):WaitForChild("MovementConfig"))

local moveState = Remotes.getUnreliable("MoveState")
local moveFX = Remotes.get("MoveFX")

local STATES = { "Ground", "Air", "WallRun", "Slide", "Dash", "Mantle" }
local FX = {
	Jump = true, DoubleJump = true, WallJump = true, Dash = true, SlideStart = true, Mantle = true,
	["Land:Light"] = true, ["Land:Medium"] = true, ["Land:Heavy"] = true, ["Land:Roll"] = true,
}

Players.CharacterAutoLoads = false

local descriptions = {} -- userId -> HumanoidDescription (standardised)

local function standardDescription(userId)
	local desc
	if userId > 0 then
		local ok, result = pcall(function() return Players:GetHumanoidDescriptionFromUserId(userId) end)
		if ok then desc = result end
	end
	desc = desc or Instance.new("HumanoidDescription")
	-- default R15 body parts: identical shape for everyone
	desc.Head, desc.Torso = 0, 0
	desc.LeftArm, desc.RightArm, desc.LeftLeg, desc.RightLeg = 0, 0, 0, 0
	-- fixed scale: identical size for everyone
	desc.HeightScale, desc.WidthScale, desc.DepthScale, desc.HeadScale = 1, 1, 1, 1
	desc.BodyTypeScale, desc.ProportionScale = 0, 0
	-- no keyframe animation packs; animation is procedural
	desc.IdleAnimation, desc.WalkAnimation, desc.RunAnimation = 0, 0, 0
	desc.JumpAnimation, desc.FallAnimation, desc.ClimbAnimation, desc.SwimAnimation = 0, 0, 0, 0
	return desc
end

local function neutraliseAccessories(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:FindFirstAncestorOfClass("Accessory") then
			d.Massless = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
end

local function spawnPoint()
	local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation then return spawnLocation.CFrame + Vector3.new(0, 4, 0) end
	return CFrame.new(0, 20, 0)
end

local spawnCharacter

spawnCharacter = function(player)
	if not player.Parent then return end
	local desc = descriptions[player.UserId]
	if not desc then
		desc = standardDescription(player.UserId)
		descriptions[player.UserId] = desc
	end
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = player.Name
	local default = model:FindFirstChild("Animate")
	if default then default:Destroy() end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = player.DisplayName
	humanoid.BreakJointsOnDeath = false
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = C.JumpHeight
	humanoid.WalkSpeed = C.JogSpeed
	neutraliseAccessories(model)
	model.DescendantAdded:Connect(function(d)
		if d:IsA("Accessory") then task.defer(neutraliseAccessories, model) end
	end)
	model:PivotTo(spawnPoint())
	player.Character = model
	model.Parent = workspace
	humanoid.Died:Connect(function()
		task.delay(Players.RespawnTime, function()
			if player.Parent and player.Character == model then spawnCharacter(player) end
		end)
	end)
end

Players.PlayerAdded:Connect(spawnCharacter)
for _, p in Players:GetPlayers() do task.spawn(spawnCharacter, p) end
Players.PlayerRemoving:Connect(function(p) descriptions[p.UserId] = nil end)

-- ------------------------------------------------------------------ movement state relay
-- MoveState (unreliable, ~15/s): (stateIndex, wallSide, dashX, dashZ)
local lastState = {}
moveState.OnServerEvent:Connect(function(player, stateIndex, wallSide, dashX, dashZ)
	local now = os.clock()
	if lastState[player] and now - lastState[player] < 1 / 30 then return end
	lastState[player] = now
	local ch = player.Character
	if not ch then return end
	if typeof(stateIndex) ~= "number" or not STATES[stateIndex] then return end
	if typeof(wallSide) ~= "number" or (wallSide ~= -1 and wallSide ~= 0 and wallSide ~= 1) then return end
	ch:SetAttribute("MState", STATES[stateIndex])
	ch:SetAttribute("MWall", wallSide)
	if typeof(dashX) == "number" and typeof(dashZ) == "number" and dashX == dashX and dashZ == dashZ then
		ch:SetAttribute("MDashX", math.clamp(dashX, -1, 1))
		ch:SetAttribute("MDashZ", math.clamp(dashZ, -1, 1))
	end
end)

-- MoveFX (reliable, one-shots): forwarded to every other client for their animation and VFX.
local fxTimes = {}
moveFX.OnServerEvent:Connect(function(player, kind)
	if typeof(kind) ~= "string" or not FX[kind] then return end
	local t = fxTimes[player] or {}
	fxTimes[player] = t
	local now = os.clock()
	while #t > 0 and now - t[1] > 1 do table.remove(t, 1) end
	if #t >= 12 then return end
	table.insert(t, now)
	for _, other in Players:GetPlayers() do
		if other ~= player then moveFX:FireClient(other, player.UserId, kind) end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	lastState[p] = nil
	fxTimes[p] = nil
end)

-- ------------------------------------------------------------------ speed sanity
-- Dashes reach 40 studs/s for 0.2 s; anything faster than the limit for a full second is corrected by
-- moving the character back to its last good position.
local tracking = {} -- player -> { overSince, lastGood }
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.2 then return end
	acc = 0
	local now = os.clock()
	for _, p in Players:GetPlayers() do
		local ch = p.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
		if hrp then
			local v = hrp.AssemblyLinearVelocity
			local horiz = Vector3.new(v.X, 0, v.Z).Magnitude
			local rec = tracking[p] or {}
			tracking[p] = rec
			if horiz > C.ServerSpeedLimit then
				rec.overSince = rec.overSince or now
				if now - rec.overSince > 1 and rec.lastGood then
					hrp.AssemblyLinearVelocity = Vector3.zero
					hrp.CFrame = rec.lastGood
					rec.overSince = nil
				end
			else
				rec.overSince = nil
				rec.lastGood = hrp.CFrame
			end
		end
	end
end)
Players.PlayerRemoving:Connect(function(p) tracking[p] = nil end)
