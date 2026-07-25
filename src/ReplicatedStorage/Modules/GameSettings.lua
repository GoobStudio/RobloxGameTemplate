--Central registry for monetization ids (and future game-wide settings).
--Replicated so client UI can prompt purchases from the same source of truth:
--  MarketplaceService:PromptProductPurchase(player, GameSettings.Products.Cash1000)
--Each name here must have a matching handler ModuleScript:
--  Products -> ServerScriptService.Monetization.Products.<Name>
--  Passes   -> ServerScriptService.Monetization.Passes.<Name>
local GameSettings = {}

--Developer product ids (TODO: replace 0s with real ids from the dashboard).
GameSettings.Products = {
	Cash1000 = 0,
}

--Game pass ids (TODO: replace 0s with real ids from the dashboard).
GameSettings.Passes = {
	VIP = 0,
}

function GameSettings.GetProductName(productId)
	for name, id in pairs(GameSettings.Products) do
		if id == productId then
			return name
		end
	end
	return nil
end

function GameSettings.GetPassName(passId)
	for name, id in pairs(GameSettings.Passes) do
		if id == passId then
			return name
		end
	end
	return nil
end

return GameSettings
