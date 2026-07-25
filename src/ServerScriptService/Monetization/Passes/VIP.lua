--Game pass: VIP. OnOwned runs once per session for owners (on join, and again
--immediately after an in-game purchase) — keep it idempotent. Placeholder
--perk: a VIP attribute for UI/chat flair; wire real perks here later.
local VIP = {}

function VIP:OnOwned(player)
	player:SetAttribute("VIP", true)
end

return VIP
