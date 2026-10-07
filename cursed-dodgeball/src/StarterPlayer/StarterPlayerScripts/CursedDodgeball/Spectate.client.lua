-- Cursed Dodgeball spectator cameras for Ghosts and Spectators: seat, broadcast, follow-ball, player cam.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedDodgeball")
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local ballState = Remotes.get("BallState")

local MODES = { "Seat", "Broadcast", "Ball", "Player" }
local mode = 1
local lastBall = nil
local watchIndex = 1

ballState.OnClientEvent:Connect(function(e)
	if e.state == "Flight" then
		local arena = workspace:FindFirstChild("CursedArena")
		local folder = arena and arena:FindFirstChild("Balls")
		lastBall = folder and folder:FindFirstChild(e.name) or lastBall
	end
end)

local function liveHumanoids()
	local out = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and p:GetAttribute("Role") == "Live" then
			local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if h then out[#out + 1] = h end
		end
	end
	return out
end

local function resetToSelf()
	camera.CameraType = Enum.CameraType.Custom
	local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if h then camera.CameraSubject = h end
end

local function cycle()
	local role = player:GetAttribute("Role")
	if role == "Live" then return end
	mode = (mode % #MODES) + 1
	if MODES[mode] == "Player" then watchIndex += 1 end
end

ContextActionService:BindAction("CD_Spectate", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then cycle() end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.C, Enum.KeyCode.ButtonB)
ContextActionService:SetTitle("CD_Spectate", "CAM")

local lastRole = nil
RunService.RenderStepped:Connect(function()
	local role = player:GetAttribute("Role")
	if role == "Live" or role == nil then
		local myHum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if role ~= lastRole or camera.CameraType ~= Enum.CameraType.Custom or (myHum and camera.CameraSubject ~= myHum) then
			resetToSelf()
		end
		lastRole = role
		mode = 1
		return
	end
	lastRole = role
	local m = MODES[mode]
	if m == "Seat" then
		if camera.CameraType ~= Enum.CameraType.Custom then resetToSelf() end
	elseif m == "Broadcast" then
		camera.CameraType = Enum.CameraType.Scriptable
		local eye = Vector3.new(0, 25, 46)
		camera.CFrame = CFrame.lookAt(eye, Vector3.new(0, 2, 0))
	elseif m == "Ball" then
		if lastBall and lastBall.Parent then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = lastBall
		else
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 25, 46), Vector3.new(0, 2, 0))
		end
	elseif m == "Player" then
		local hums = liveHumanoids()
		if #hums == 0 then
			mode = 2
		else
			local h = hums[((watchIndex - 1) % #hums) + 1]
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = h
		end
	end
end)
