-- Cursed Dodgeball throwing: target picker with bracket, hold-to-charge throw, catch press.
-- The ball always flies at where the bracketed player is at release; nothing here steers it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedDodgeball")
local Config = require(Shared:WaitForChild("Config"))
local Targeting = require(Shared:WaitForChild("Pure"):WaitForChild("Targeting"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local throwRequest = Remotes.get("ThrowRequest")
local catchRequest = Remotes.get("CatchRequest")

local targetId = nil
local lockedId = nil
local chargeStart = nil

-- Bracket above the target's head
local bracket = Instance.new("BillboardGui")
bracket.Name = "TargetBracket"
bracket.Size = UDim2.fromOffset(60, 60)
bracket.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
bracket.AlwaysOnTop = true
bracket.Enabled = false
local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(1, 1)
frame.BackgroundTransparency = 1
local stroke = Instance.new("UIStroke")
stroke.Thickness = 4
stroke.Color = Color3.fromRGB(255, 70, 70)
stroke.Parent = frame
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.2, 0)
corner.Parent = frame
frame.Parent = bracket
bracket.Parent = player:WaitForChild("PlayerGui")

local function tv(v) return { x = v.X, y = v.Y, z = v.Z } end

local function candidates()
	local out = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and p:GetAttribute("Role") == "Live" then
			local ch = p.Character
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
			if hrp then out[#out + 1] = { id = p.UserId, pos = tv(hrp.Position), player = p } end
		end
	end
	return out
end

local function cycleTarget()
	local order = Targeting.order(tv(camera.CFrame.Position), tv(camera.CFrame.LookVector), candidates(), Config.Targeting.MaxRange, Config.Targeting.MaxAngle)
	lockedId = Targeting.cycle(lockedId or targetId, order)
end

local function myRole()
	return player:GetAttribute("Role")
end

local function heldBall()
	local n = player:GetAttribute("HeldBall")
	return (n and n ~= "") and n or nil
end

local function beginThrow()
	if not heldBall() then return end
	if myRole() ~= "Live" and myRole() ~= "Ghost" then return end
	chargeStart = os.clock()
	if player.Character then player.Character:SetAttribute("Charging", true) end
end

local function endThrow()
	if not chargeStart then return end
	local charge = math.clamp((os.clock() - chargeStart) / Config.Throw.ChargeTime, 0, 1)
	chargeStart = nil
	if player.Character then player.Character:SetAttribute("Charging", false) end
	local ball = heldBall()
	if not ball then return end
	throwRequest:FireServer(ball, targetId or 0, charge, workspace:GetServerTimeNow())
end

local function pressCatch()
	if myRole() ~= "Live" then return end
	catchRequest:FireServer()
end

ContextActionService:BindAction("CD_Throw", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then beginThrow() elseif inputState == Enum.UserInputState.End then endThrow() end
	return Enum.ContextActionResult.Sink
end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
ContextActionService:SetTitle("CD_Throw", "THROW")

ContextActionService:BindAction("CD_Catch", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then pressCatch() end
	return Enum.ContextActionResult.Sink
end, true, Enum.UserInputType.MouseButton2, Enum.KeyCode.F, Enum.KeyCode.ButtonR1)
ContextActionService:SetTitle("CD_Catch", "CATCH")

ContextActionService:BindAction("CD_Cycle", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then cycleTarget() end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.Tab, Enum.KeyCode.ButtonY)

if UserInputService.TouchEnabled then
	ContextActionService:SetPosition("CD_Throw", UDim2.new(0.84, 0, 0.62, 0))
	ContextActionService:SetPosition("CD_Catch", UDim2.new(0.84, 0, 0.8, 0))
	-- swipe on the right half of the screen cycles the target
	UserInputService.TouchSwipe:Connect(function(dir, _, processed)
		if processed then return end
		if dir == Enum.SwipeDirection.Left or dir == Enum.SwipeDirection.Right then cycleTarget() end
	end)
end

RunService.RenderStepped:Connect(function()
	local role = myRole()
	if role ~= "Live" and role ~= "Ghost" then
		targetId = nil
		lockedId = nil
		bracket.Enabled = false
		return
	end
	local cands = candidates()
	local camPos, camDir = tv(camera.CFrame.Position), tv(camera.CFrame.LookVector)
	local order = Targeting.order(camPos, camDir, cands, Config.Targeting.MaxRange, Config.Targeting.MaxAngle)
	if lockedId then
		local still = false
		for _, id in order do if id == lockedId then still = true end end
		if not still then lockedId = nil end
	end
	targetId = lockedId or order[1]
	local tp = targetId and Players:GetPlayerByUserId(targetId)
	local head = tp and tp.Character and tp.Character:FindFirstChild("Head")
	if head then
		bracket.Adornee = head
		bracket.Enabled = true
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local dist = hrp and (head.Position - hrp.Position).Magnitude or math.huge
		stroke.Color = dist <= Config.Targeting.MaxRange and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(160, 160, 160)
		player:SetAttribute("TargetId", targetId)
	else
		bracket.Enabled = false
		player:SetAttribute("TargetId", 0)
	end
end)
