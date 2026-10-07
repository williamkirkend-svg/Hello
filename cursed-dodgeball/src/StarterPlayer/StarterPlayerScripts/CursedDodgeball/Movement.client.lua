-- Cursed Dodgeball movement kit: sprint, omnidirectional dodge, one air dodge per jump, stamina.
-- Numbers come from Config.Movement. Stamina lives on the character as the attribute "Stamina" (0..1).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("CursedDodgeball"):WaitForChild("Config"))
local M = Config.Movement

local player = Players.LocalPlayer
local stamina = 1
local sprintHeld = false
local dodgeUntil = 0
local lastDodge = -math.huge
local airDodgesLeft = M.AirDodgesPerJump
local character, humanoid, root

local function bind(ch)
	character = ch
	humanoid = ch:WaitForChild("Humanoid")
	root = ch:WaitForChild("HumanoidRootPart")
	humanoid.WalkSpeed = M.RunSpeed
	ch:SetAttribute("Stamina", 1)
	stamina = 1
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			airDodgesLeft = M.AirDodgesPerJump
		end
	end)
end

local function grounded()
	if not humanoid then return false end
	local s = humanoid:GetState()
	return s ~= Enum.HumanoidStateType.Freefall and s ~= Enum.HumanoidStateType.Jumping
end

local function tryDodge()
	if not root or not humanoid or humanoid.Health <= 0 then return end
	local now = os.clock()
	if now - lastDodge < M.DodgeCooldown then return end
	if stamina < M.DodgeCost then return end
	if not grounded() then
		if airDodgesLeft <= 0 then return end
		airDodgesLeft -= 1
	end
	local dir = humanoid.MoveDirection
	if dir.Magnitude < 0.1 then dir = root.CFrame.LookVector end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	stamina = math.max(0, stamina - M.DodgeCost)
	lastDodge = now
	dodgeUntil = now + M.DodgeSeconds
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Dodge"
	lv.MaxForce = math.huge
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.VectorVelocity = dir * (M.DodgeDistance / M.DodgeSeconds) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	local att = root:FindFirstChild("RootAttachment") or Instance.new("Attachment", root)
	lv.Attachment0 = att
	lv.Parent = root
	task.delay(M.DodgeSeconds, function()
		if lv then lv:Destroy() end
	end)
	character:SetAttribute("Dodging", true)
	task.delay(M.DodgeSeconds, function() if character then character:SetAttribute("Dodging", false) end end)
end

ContextActionService:BindAction("CD_Sprint", function(_, inputState)
	sprintHeld = inputState == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL2)
ContextActionService:SetTitle("CD_Sprint", "RUN")

ContextActionService:BindAction("CD_Dodge", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then tryDodge() end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
ContextActionService:SetTitle("CD_Dodge", "DODGE")

if UserInputService.TouchEnabled then
	ContextActionService:SetPosition("CD_Sprint", UDim2.new(0.72, 0, 0.62, 0))
	ContextActionService:SetPosition("CD_Dodge", UDim2.new(0.6, 0, 0.78, 0))
end

RunService.RenderStepped:Connect(function(dt)
	if not humanoid or not character then return end
	local charging = character:GetAttribute("Charging") == true
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	local sprinting = sprintHeld and moving and stamina > 0 and not charging
	if sprinting then
		stamina = math.max(0, stamina - dt / M.StaminaDrainSeconds)
	else
		stamina = math.min(1, stamina + dt / M.StaminaRefillSeconds)
	end
	local base = M.RunSpeed
	if charging then base = M.RunSpeed * 0.6 end
	humanoid.WalkSpeed = sprinting and base * M.SprintMultiplier or base
	character:SetAttribute("Stamina", stamina)
	character:SetAttribute("Sprinting", sprinting)
end)

if player.Character then bind(player.Character) end
player.CharacterAdded:Connect(bind)
