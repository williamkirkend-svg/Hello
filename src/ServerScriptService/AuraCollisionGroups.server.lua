-- AuraCollisionGroups: registers the "AuraPerformer" collision group so the celebration double (a client-side clone of
-- the character that stands on top of the real body while it acts) can never collide with anything. Clients set the
-- group on the clone's parts; the group itself must exist on the server for live games. Studio registers it client-side
-- as a fallback. One Script, no RemoteEvents, nothing else. (Oct 6 2026)
local PhysicsService = game:GetService("PhysicsService")
local GROUP = "AuraPerformer"
local ok, err = pcall(function()
	local have = false
	for _, g in PhysicsService:GetRegisteredCollisionGroups() do if g.name == GROUP then have = true end end
	if not have then PhysicsService:RegisterCollisionGroup(GROUP) end
	for _, g in PhysicsService:GetRegisteredCollisionGroups() do
		PhysicsService:CollisionGroupSetCollidable(GROUP, g.name, false)
	end
end)
if not ok then warn("[AuraCollisionGroups] " .. tostring(err)) end
