local SyncedTablesHolder = game.Players.LocalPlayer.PlayerGui:WaitForChild("SyncedTables")
local Serializer = require(game.ReplicatedStorage.Modules.Serializer)

local SyncedTables = {}

SyncedTables.Tables = {}

function AddedTable(FrameInstance)
    local UID = FrameInstance.Name
    local Data = FrameInstance:GetAttribute("Data")

    local Entry = {}
    Entry.UID = UID
    Entry.Data = Data and Serializer.Decode(Data) or {}
    Entry.Changed = Instance.new("BindableEvent")
    Entry.Instance = FrameInstance

    Entry.Changed:Fire(Entry.Data)
    FrameInstance:GetAttributeChangedSignal("Data"):Connect(function()
        local NewData = FrameInstance:GetAttribute("Data")
        if NewData then
            Entry.Data = Serializer.Decode(NewData)
            --Possibly expensive because we decode the data every time it changes.
            --Consider optimizing if this becomes a performance issue.
        else
            Entry.Data = {}
        end
        Entry.Changed:Fire(Entry.Data)
    end)


    FrameInstance.AncestryChanged:Connect(function(_, NewParent)
        -- Only drop the entry if the registry still points at THIS instance.
        -- Tables recreated with the same UID (e.g. Favorites on respawn) can
        -- have the new instance register before the old one's destruction
        -- handler runs (deferred signals, LIFO) — an unguarded nil here wipes
        -- the fresh entry and every WaitForTable for that UID stalls forever.
        if not NewParent and SyncedTables.Tables[UID] == Entry then
            SyncedTables.Tables[UID] = nil
        end
    end)

    SyncedTables.Tables[UID] = Entry
end

SyncedTablesHolder.DescendantAdded:Connect(function(FrameInstance)
    if FrameInstance:IsA("Configuration") then
        AddedTable(FrameInstance)
    end
end)

local Existing = SyncedTablesHolder:GetDescendants()
for _,FrameInstance in pairs(Existing) do
     if FrameInstance:IsA("Configuration") then
        AddedTable(FrameInstance)
     end
end

function SyncedTables.GetTable(UID)
    UID = tostring(UID)
    return SyncedTables.Tables[UID]
end

function SyncedTables.WaitForTable(UID,retry)
    UID = tostring(UID)
    -- Iterative, not recursive — long waits (e.g. tables that never replicate
    -- in the lobby place) must not grow the stack unboundedly.
    while not SyncedTables.Tables[UID] do
        task.wait(0.1)
    end
    return SyncedTables.Tables[UID]
end

return SyncedTables