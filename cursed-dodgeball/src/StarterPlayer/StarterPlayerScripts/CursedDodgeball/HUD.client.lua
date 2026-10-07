-- Cursed Dodgeball HUD: phase, timer, live count, round, role, stamina bar, hold timer ring, ghost throws.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedDodgeball")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local stateFolder = Remotes.stateFolder()
local showEvent = Remotes.get("ShowEvent")

local gui = Instance.new("ScreenGui")
gui.Name = "CursedDodgeballHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function label(name, pos, size, textSize, align)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.3
	l.Font = Enum.Font.FredokaOne
	l.TextSize = textSize
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.Text = ""
	l.Parent = gui
	return l
end

local top = label("Top", UDim2.new(0.5, -200, 0, 12), UDim2.fromOffset(400, 40), 32)
local sub = label("Sub", UDim2.new(0.5, -200, 0, 52), UDim2.fromOffset(400, 28), 20)
local role = label("Role", UDim2.new(0, 16, 1, -70), UDim2.fromOffset(300, 26), 20, Enum.TextXAlignment.Left)
local toast = label("Toast", UDim2.new(0.5, -250, 0.3, 0), UDim2.fromOffset(500, 60), 44)

local staminaBack = Instance.new("Frame")
staminaBack.Name = "StaminaBack"
staminaBack.Position = UDim2.new(0, 16, 1, -40)
staminaBack.Size = UDim2.fromOffset(220, 14)
staminaBack.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
staminaBack.BorderSizePixel = 0
staminaBack.Parent = gui
local staminaFill = Instance.new("Frame")
staminaFill.Size = UDim2.fromScale(1, 1)
staminaFill.BackgroundColor3 = Color3.fromRGB(90, 220, 120)
staminaFill.BorderSizePixel = 0
staminaFill.Parent = staminaBack

local holdBack = Instance.new("Frame")
holdBack.Name = "HoldBack"
holdBack.Position = UDim2.new(0.5, -60, 1, -60)
holdBack.Size = UDim2.fromOffset(120, 10)
holdBack.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
holdBack.BorderSizePixel = 0
holdBack.Visible = false
holdBack.Parent = gui
local holdFill = Instance.new("Frame")
holdFill.Size = UDim2.fromScale(1, 1)
holdFill.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
holdFill.BorderSizePixel = 0
holdFill.Parent = holdBack

local toastUntil = 0
local function showToast(text, seconds)
	toast.Text = text
	toastUntil = os.clock() + (seconds or 2)
end

showEvent.OnClientEvent:Connect(function(e)
	if e.type == "PhaseChanged" then
		if e.phase == "Round" then showToast("ROUND " .. e.round .. (e.round == stateFolder:GetAttribute("Rounds") and "  THE FINAL" or ""), 2.5)
		elseif e.phase == "Replay" then showToast("CUT!", 2)
		end
	elseif e.type == "Eliminated" and e.id == player.UserId then
		showToast("OUT!", 2)
	elseif e.type == "ShieldGained" and e.id == player.UserId then
		showToast("CAUGHT! SHIELD " .. Config.Catch.ShieldSeconds .. "s", 1.5)
	elseif e.type == "GhostReturned" and e.ghost == player.UserId then
		showToast("BACK IN!", 2)
	elseif e.type == "FloodStarted" then
		showToast("FLOOD!", 2)
	elseif e.type == "Winner" then
		local w = Players:GetPlayerByUserId(e.id)
		showToast((w and w.DisplayName or "?") .. " WINS", 4)
	end
end)

RunService.RenderStepped:Connect(function()
	local phase = stateFolder:GetAttribute("Phase") or "Intermission"
	local timer = math.ceil(stateFolder:GetAttribute("Timer") or 0)
	local live = stateFolder:GetAttribute("Live") or 0
	local round = stateFolder:GetAttribute("Round") or 0
	if phase == "Intermission" then
		top.Text = "NEXT SHOW " .. timer
		sub.Text = #Players:GetPlayers() .. " / " .. Config.Players.Max .. " in the stands"
	elseif phase == "Round" then
		top.Text = live .. " LEFT   " .. timer
		sub.Text = (stateFolder:GetAttribute("Flood") and "FLOOD  " or "") .. "ROUND " .. round
	elseif phase == "Replay" then
		top.Text = "CUT"
		sub.Text = live .. " survive"
	else
		top.Text = "CROWNING"
		sub.Text = ""
	end
	local r = player:GetAttribute("Role") or "Waiting"
	if r == "Ghost" then
		role.Text = "GHOST  throws left: " .. tostring(player:GetAttribute("GhostThrows") or 0)
	else
		role.Text = r:upper()
	end
	local ch = player.Character
	local st = ch and ch:GetAttribute("Stamina") or 1
	staminaFill.Size = UDim2.fromScale(math.clamp(st, 0, 1), 1)
	staminaFill.BackgroundColor3 = st < Config.Movement.DodgeCost and Color3.fromRGB(230, 90, 90) or Color3.fromRGB(90, 220, 120)
	local heldSince = player:GetAttribute("HeldSince") or 0
	local heldName = player:GetAttribute("HeldBall")
	if heldName and heldName ~= "" and heldSince > 0 and r == "Live" then
		holdBack.Visible = true
		local left = Config.Throw.HoldLimit - (workspace:GetServerTimeNow() - heldSince)
		holdFill.Size = UDim2.fromScale(math.clamp(left / Config.Throw.HoldLimit, 0, 1), 1)
	else
		holdBack.Visible = false
	end
	toast.Visible = os.clock() < toastUntil
end)
