--Dev product: grants 1,000 cash. Called by MonetizationService.ProcessReceipt
--after idempotency checks; throwing here means the receipt is retried later,
--so only error when the grant genuinely failed.
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Services.DataService)

local Cash1000 = {}

Cash1000.Amount = 1000

function Cash1000:Process(player, _receiptInfo)
	local profile = DataService:GetProfile(player)
	assert(profile, "profile not loaded")
	profile.Data.Cash += self.Amount
	DataService:Sync(player)
end

return Cash1000
