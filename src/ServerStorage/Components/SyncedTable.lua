-- SyncedTable.lua
local Players    = game:GetService("Players")
local Core       = require(game.ReplicatedStorage.Modules.Core)
local Serializer = require(game.ReplicatedStorage.Modules.Serializer)

local SyncedTable = {}
SyncedTable.__index = SyncedTable

-- Weak-keyed registry of every live SyncedTable, for debug/admin tooling only.
-- Weak keys mean tables that are dropped without :Destroy() simply fall out on
-- GC rather than leaking here, so the count stays honest with no upkeep.
local registry = setmetatable({}, { __mode = "k" })

-- Read-only snapshot: how many synced tables are live on the server, how many
-- of those currently have zero subscribers, and a per-type breakdown.
function SyncedTable.GetRegistryStats()
    local total = 0
    local noSubscribers = 0
    local byType = {}
    local noSubByType = {}
    for st in pairs(registry) do
        total += 1
        local typeName = st.TypeString or "SyncedTable"
        byType[typeName] = (byType[typeName] or 0) + 1

        local hasSubscriber = false
        if st.Subscribers then
            for _ in pairs(st.Subscribers) do
                hasSubscriber = true
                break
            end
        end
        if not hasSubscriber then
            noSubscribers += 1
            noSubByType[typeName] = (noSubByType[typeName] or 0) + 1
        end
    end
    return {
        Total = total,
        NoSubscribers = noSubscribers,
        ByType = byType,
        NoSubscribersByType = noSubByType,
    }
end

local function ensureHolder(player)
    local pg = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
    if not pg then return end
    if pg:FindFirstChild("SyncedTables") then return end
    local holder = Instance.new("ScreenGui")
    holder.Name           = "SyncedTables"
    holder.ResetOnSpawn   = false
    holder.IgnoreGuiInset = true
    holder.Parent         = pg
end

Players.PlayerAdded:Connect(ensureHolder)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(ensureHolder, p)
end

---------------------------------------------------------------------
--  CONSTRUCTOR
---------------------------------------------------------------------
function SyncedTable.new(DataTable, UID, TypeString)
    local self   = setmetatable({}, SyncedTable)
    self.UID     = UID or Core.UID.GetUID()
    self.Data    = DataTable or {}
    self.Subscribers = {}
    self.TypeString  = TypeString or "SyncedTable"
    self.ClientSubscribed = Instance.new("BindableEvent")
    self.ClientUnsubscribed = Instance.new("BindableEvent")
    self.Changed = Instance.new("BindableEvent")
    registry[self] = true
    return self
end

---------------------------------------------------------------------
--  SUBSCRIBE / UNSUBSCRIBE
---------------------------------------------------------------------
function SyncedTable:Subscribe(client)
    if not self.Subscribers[client] then
        self.Subscribers[client] = true
        self:UpdateInstance(client)
        self.ClientSubscribed:Fire(client)
    end
end

function SyncedTable:Unsubscribe(client)
    self.Subscribers[client] = nil
    self.ClientUnsubscribed:Fire(client)
	if client and client:FindFirstChild("PlayerGui") then
    --Erase the instance from the player's GUI
    local holder = client.PlayerGui:FindFirstChild("SyncedTables")
    if holder then
        local typeFolder = holder:FindFirstChild(self.TypeString)
        if typeFolder then
            local frame = typeFolder:FindFirstChild(self.UID)
            if frame then
                frame:Destroy()  -- Remove the frame from the GUI
            end
        end
	end
	end
end

---------------------------------------------------------------------
--  INTERNAL: CREATE / UPDATE THE UI INSTANCE FOR A CLIENT
---------------------------------------------------------------------
function SyncedTable:UpdateInstance(client, encoded)
    -- 1) Ensure the ScreenGui exists
    if not client:FindFirstChild("PlayerGui") then
        --Player probably left
        --warn("SyncedTable:UpdateInstance - PlayerGui not found for player:", client.Name)
        return
    end
    local holder = client.PlayerGui:FindFirstChild("SyncedTables")
    if not holder then
        holder                 = Instance.new("ScreenGui")
        holder.Name            = "SyncedTables"
        holder.ResetOnSpawn    = false
        holder.IgnoreGuiInset  = true
        holder.Parent          = client.PlayerGui
    end

    -- 2) Ensure a Folder exists for this TypeString
    local typeFolder = holder:FindFirstChild(self.TypeString)
    if not typeFolder then
        typeFolder      = Instance.new("Folder")
        typeFolder.Name = self.TypeString
        typeFolder.Parent = holder
    end

    -- 3) Ensure the Frame representing this table exists inside the folder
    local frame = typeFolder:FindFirstChild(self.UID)
    if not frame then
        frame      = Instance.new("Configuration")
        frame.Name = self.UID
        frame.Parent = typeFolder
    elseif frame.Parent ~= typeFolder then
        frame.Parent = typeFolder      -- in case it was moved elsewhere
    end

    -- 4) Push the (re)‑serialized data into the attribute
    frame:SetAttribute("Data", encoded or Serializer.Encode(self.Data))
end

---------------------------------------------------------------------
--  PROPAGATE CHANGES TO ALL SUBSCRIBERS
---------------------------------------------------------------------
function SyncedTable:Serialize()
    if next(self.Subscribers) ~= nil then
        -- Encode once and share the string across subscribers
        local encoded = Serializer.Encode(self.Data)
        for client in pairs(self.Subscribers) do
            self:UpdateInstance(client, encoded)
        end
    end
    self.Changed:Fire() --For any server listeners
end

function SyncedTable:Destroy()
    registry[self] = nil
    self.ClientSubscribed:Destroy()
    self.ClientUnsubscribed:Destroy()
    self.Changed:Destroy()

    --For each subscriber, remove their instance
    for client in pairs(self.Subscribers) do
        self:Unsubscribe(client)
    end
    self.Subscribers = {}
    
end

return SyncedTable
