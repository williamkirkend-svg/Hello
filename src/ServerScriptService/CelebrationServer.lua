--!strict
-- CelebrationServer (ModuleScript): the one server-side piece.
-- Creates the CelebrationBroadcast RemoteEvent and offers Fire(), which
-- FarmLassoServer calls where it already decides the throw's Tier.
--
--   local Celebration = require(game.ServerScriptService.CelebrationServer)
--   Celebration.Fire(player, tier, { Mult = mult, Animal = animalName })
--
-- Tier is the same 1..4 value sent with the Throw event (copper .. rainbow).
-- The payload is tiny and sent once per throw, so the network stays quiet.
-- Everything visual happens on the clients.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Celebration = {}

local remote = ReplicatedStorage:FindFirstChild("CelebrationBroadcast")
if not remote then
	local r = Instance.new("RemoteEvent")
	r.Name = "CelebrationBroadcast"
	r.Parent = ReplicatedStorage
	remote = r
end
local broadcast = remote :: RemoteEvent

export type Info = {
	Mult: number?,
	Animal: string?,
}

local lastFire: { [number]: number } = {}
local MIN_GAP = 1.5 -- seconds; a player cannot trigger two celebrations faster than this

function Celebration.Fire(player: Player, tier: number, info: Info?)
	if typeof(tier) ~= "number" then
		return
	end
	tier = math.clamp(math.floor(tier), 1, 4)
	local now = os.clock()
	local last = lastFire[player.UserId]
	if last and now - last < MIN_GAP then
		return
	end
	lastFire[player.UserId] = now

	local i: Info = info or {}
	broadcast:FireAllClients({
		UserId = player.UserId,
		Tier = tier,
		Mult = i.Mult,
		Animal = i.Animal,
	})
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastFire[player.UserId] = nil
end)

return Celebration
