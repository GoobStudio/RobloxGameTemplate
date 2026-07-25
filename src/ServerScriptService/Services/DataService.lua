--Player data: ProfileStore for persistence, SyncedTable for replication.
--Each player's profile data is pushed to their client through a SyncedTable
--with the UID "PlayerData_<UserId>". On the client, read it with:
--  SyncedTables.WaitForTable("PlayerData_" .. Players.LocalPlayer.UserId)
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local ProfileStore = require(ServerScriptService.ProfileStore)
local SyncedTable = require(ServerStorage.Components.SyncedTable)

local DATA_TEMPLATE = {
	Cash = 0,
	Monetization = {
		Receipts = {}, --recent processed PurchaseIds, so retried receipts never double-grant
	},
}

local PlayerStore = ProfileStore.New("PlayerData", DATA_TEMPLATE)

local DataService = {}
DataService.Profiles = {} --[player] = ProfileStore profile
DataService.Tables = {} --[player] = SyncedTable replicating that profile's Data

local function onPlayerAdded(player)
	local profile = PlayerStore:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		player:Kick("Data failed to load, please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		DataService.Profiles[player] = nil
		local syncedTable = DataService.Tables[player]
		if syncedTable then
			syncedTable:Destroy()
			DataService.Tables[player] = nil
		end
		player:Kick("Data session ended, please rejoin.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	DataService.Profiles[player] = profile

	local syncedTable = SyncedTable.new(profile.Data, "PlayerData_" .. player.UserId, "PlayerData")
	syncedTable:Subscribe(player)
	DataService.Tables[player] = syncedTable
end

function DataService:GetProfile(player)
	return self.Profiles[player]
end

--Mutate a single key in a player's data and replicate it to their client.
--For multi-key edits, write to profile.Data directly then call :Sync(player).
function DataService:SetValue(player, key, value)
	local profile = self.Profiles[player]
	if not profile then
		return
	end
	profile.Data[key] = value
	self:Sync(player)
end

function DataService:Sync(player)
	local syncedTable = self.Tables[player]
	if syncedTable then
		syncedTable:Serialize()
	end
end

function DataService:Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = self.Profiles[player]
		if profile then
			profile:EndSession()
		end
	end)
end

return DataService
