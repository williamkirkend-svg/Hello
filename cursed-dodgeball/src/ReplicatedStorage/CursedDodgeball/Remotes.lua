-- Cursed Dodgeball remotes. The server creates them under ReplicatedStorage.CursedDodgeball.Remotes;
-- clients wait for them. Names are the only contract between the two sides.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}
Remotes.Names = { "ShowEvent", "ThrowRequest", "CatchRequest", "BallSpawn", "BallState", "TargetSync", "Dodge", "MoveFX" }
-- High-rate, loss-tolerant traffic (movement state) uses UnreliableRemoteEvents.
Remotes.UnreliableNames = { "MoveState" }

local function root()
	return ReplicatedStorage:WaitForChild("CursedDodgeball")
end

local function folder()
	local r = root()
	local f = r:FindFirstChild("Remotes")
	if not f then
		if RunService:IsServer() then
			f = Instance.new("Folder")
			f.Name = "Remotes"
			f.Parent = r
		else
			f = r:WaitForChild("Remotes")
		end
	end
	return f
end

function Remotes.get(name, className)
	local f = folder()
	local ev = f:FindFirstChild(name)
	if not ev then
		if RunService:IsServer() then
			ev = Instance.new(className or "RemoteEvent")
			ev.Name = name
			ev.Parent = f
		else
			ev = f:WaitForChild(name)
		end
	end
	return ev
end

function Remotes.getUnreliable(name)
	return Remotes.get(name, "UnreliableRemoteEvent")
end

-- A Folder whose attributes mirror the show (Phase, Round, Timer, Live, Flood, FloodInset) to every client.
function Remotes.stateFolder()
	local r = root()
	local s = r:FindFirstChild("State")
	if not s then
		if RunService:IsServer() then
			s = Instance.new("Folder")
			s.Name = "State"
			s.Parent = r
		else
			s = r:WaitForChild("State")
		end
	end
	return s
end

return Remotes
