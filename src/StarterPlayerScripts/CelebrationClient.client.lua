--!strict
-- CelebrationClient: plays the celebration aura for any player on the server.
--
-- The local player gets the full version: float, pose, cinematic camera orbit,
-- flash, bolts. Everyone else sees a reduced aura on that player so the plaza
-- stays readable. Driven by the CelebrationBroadcast RemoteEvent, which
-- CelebrationServer fires with { UserId, Tier, Mult, Animal }.
--
-- Studio test keys (Studio only): hold Left Ctrl and press 7 / 8 / 9 / 0 to
-- play copper / silver / gold / rainbow on yourself without the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local farm = ReplicatedStorage:WaitForChild("FarmLasso")
local vfxFolder = farm:WaitForChild("VFX")
local FX = require(vfxFolder:WaitForChild("CelebrationFX"))
local Float = require(vfxFolder:WaitForChild("CelebrationFloat"))
local Camera = require(vfxFolder:WaitForChild("CelebrationCamera"))
local Assets = require(vfxFolder:WaitForChild("VFXAssets"))

local localPlayer = Players.LocalPlayer

type Active = {
	Fx: FX.Handle?,
	Float: Float.Handle?,
	Cam: Camera.Handle?,
	Token: number,
}

local active: { [Player]: Active } = {}
local token = 0

local function stopFor(player: Player)
	local a = active[player]
	if not a then
		return
	end
	active[player] = nil
	if a.Fx then
		a.Fx:Stop()
	end
	if a.Float then
		a.Float:Stop()
	end
	if a.Cam then
		a.Cam:Stop()
	end
end

local function play(player: Player, tier: number, mult: number?, animal: string?)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	tier = math.clamp(math.floor(tier), 1, 4)
	stopFor(player)

	local isMe = player == localPlayer
	local duration = Assets.Durations[tier]
	token += 1
	local a: Active = { Fx = nil, Float = nil, Cam = nil, Token = token }
	active[player] = a

	local subtitle: string? = nil
	if mult and animal then
		subtitle = ("x%s  %s"):format(tostring(mult), animal)
	elseif mult then
		subtitle = ("x%s THROW"):format(tostring(mult))
	end

	if isMe then
		a.Float = Float.Start(character, duration, tier)
		if tier >= 3 then
			a.Cam = Camera.Start(character, {
				Duration = duration,
				PeakAt = duration * 0.3,
				Distance = if tier >= 4 then 16 else 13,
				Height = if tier >= 4 then 5 else 3.5,
				Sweep = if tier >= 4 then math.rad(95) else math.rad(70),
			})
		end
	end

	a.Fx = FX.Play(character, tier, {
		Reduced = not isMe,
		Subtitle = subtitle,
		OnPeak = function()
			if a.Cam then
				a.Cam:Peak()
			end
		end,
	})

	task.delay(duration, function()
		if active[player] == a then
			active[player] = nil
			if a.Float then
				a.Float:Stop()
			end
			if a.Cam then
				a.Cam:Stop()
			end
			-- the aura scene finishes its own implosion and self-destructs
		end
	end)
end

-- ---------------------------------------------------------------- server hook
task.spawn(function()
	local remote = ReplicatedStorage:WaitForChild("CelebrationBroadcast", 30)
	if not remote or not remote:IsA("RemoteEvent") then
		warn("[CelebrationClient] CelebrationBroadcast RemoteEvent not found; only Studio test keys will work")
		return
	end
	remote.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		local player = if typeof(payload.UserId) == "number" then Players:GetPlayerByUserId(payload.UserId) else nil
		local tier = if typeof(payload.Tier) == "number" then payload.Tier else nil
		if player and tier then
			play(player, tier, payload.Mult, payload.Animal)
		end
	end)
end)

Players.PlayerRemoving:Connect(stopFor)

-- ---------------------------------------------------------------- studio keys
if RunService:IsStudio() then
	local keys = {
		[Enum.KeyCode.Seven] = 1,
		[Enum.KeyCode.Eight] = 2,
		[Enum.KeyCode.Nine] = 3,
		[Enum.KeyCode.Zero] = 4,
	}
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local tier = keys[input.KeyCode]
		if tier and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			play(localPlayer, tier, ({ 2, 4, 10, 10 })[tier], "TEST")
		end
	end)
end
