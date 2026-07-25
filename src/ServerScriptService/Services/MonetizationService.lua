--Monetization pipeline. Ids live centrally in ReplicatedStorage.Modules.
--GameSettings; each product/pass has its own handler ModuleScript under
--ServerScriptService.Monetization.{Products,Passes} whose name matches the
--GameSettings key.
--
--Product handlers: :Process(player, receiptInfo) — grant the purchase; error
--to have the receipt retried later.
--Pass handlers: :OnOwned(player) — applied on join for owners and right after
--an in-game purchase; must be idempotent.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameSettings = require(ReplicatedStorage.Modules.GameSettings)
local DataService = require(ServerScriptService.Services.DataService)

local MAX_SAVED_RECEIPTS = 50

local MonetizationService = {}

local productHandlers = {} --[name] = module
local passHandlers = {} --[name] = module

local function loadHandlers(folder, handlers)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("ModuleScript") then
			handlers[child.Name] = require(child)
		end
	end
end

local function waitForProfile(player)
	while DataService:GetProfile(player) == nil and player.Parent == Players do
		task.wait(0.1)
	end
	return DataService:GetProfile(player)
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productName = GameSettings.GetProductName(receiptInfo.ProductId)
	local handler = productName and productHandlers[productName]
	if not handler then
		warn("[MonetizationService] No handler for product id " .. receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = waitForProfile(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	--Already granted (receipt retried after a crash/timeout): just acknowledge.
	local receipts = profile.Data.Monetization.Receipts
	if table.find(receipts, receiptInfo.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local ok, err = pcall(handler.Process, handler, player, receiptInfo)
	if not ok then
		warn("[MonetizationService] " .. productName .. " failed: " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(receipts, receiptInfo.PurchaseId)
	while #receipts > MAX_SAVED_RECEIPTS do
		table.remove(receipts, 1)
	end
	DataService:Sync(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--Apply every owned pass to a player (join-time sweep).
local function applyOwnedPasses(player)
	for passName, passId in pairs(GameSettings.Passes) do
		local handler = passHandlers[passName]
		if handler and passId ~= 0 then
			task.spawn(function()
				local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
				if ok and owns then
					handler:OnOwned(player)
				end
			end)
		end
	end
end

function MonetizationService:Init()
	local monetizationFolder = ServerScriptService:WaitForChild("Monetization")
	loadHandlers(monetizationFolder.Products, productHandlers)
	loadHandlers(monetizationFolder.Passes, passHandlers)

	MarketplaceService.ProcessReceipt = processReceipt

	Players.PlayerAdded:Connect(applyOwnedPasses)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(applyOwnedPasses, player)
	end

	--In-game pass purchases apply immediately, no rejoin needed.
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local passName = GameSettings.GetPassName(passId)
		local handler = passName and passHandlers[passName]
		if handler then
			handler:OnOwned(player)
		end
	end)
end

return MonetizationService
