-- CelebrationFX.Shows: the aura shows, one child ModuleScript per celebration Id (Oct 6 2026).
-- Each child returns {Set1 = fn(ctx, def), Set2 = fn(ctx, def), Set3 = fn(ctx, def), Pre = seconds} where every
-- builder sets up its timeline on ctx and returns its length in seconds. Pre is Set 3's charge-up before t = 0
-- (AuraKit.ChargeUp draws it). A celebration with no child here keeps playing its old Free / Premium / Spectacle
-- builders, so the shows can be installed one at a time.
local M = {}
for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") then
		local ok, show = pcall(require, child)
		if ok and type(show) == "table" and (show.Set3 or show.Set2 or show.Set1) then
			M[child.Name] = show
		else
			warn("[CelebrationFX.Shows] " .. child.Name .. ": " .. tostring(show))
		end
	end
end
return M
