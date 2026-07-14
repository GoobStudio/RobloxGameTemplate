# RobloxGameTemplate

Roblox game managed with [Rojo](https://rojo.space/) 7.

<!-- TEMPLATE:START -->
## Starting a new game from this template

1. Create a new **empty** repo on GitHub (no README or .gitignore).
2. Double-click `New-RobloxGame.bat` (keep a copy anywhere — it always fetches
   the latest template) and paste the repo URL when prompted. The project
   folder is created next to the .bat.

The .bat downloads and runs the latest `New-RobloxGame.ps1`, which clones the
template, stamps the project name into `default.project.json` and the README,
starts a fresh git history, and pushes it to the new repo.

PowerShell alternative — supports `-Name` to override the project name and
`-Path` to create the folder somewhere other than the current directory:

```powershell
irm https://raw.githubusercontent.com/GoobStudio/RobloxGameTemplate/main/New-RobloxGame.ps1 -OutFile New-RobloxGame.ps1
.\New-RobloxGame.ps1 -RepoUrl https://github.com/GoobStudio/MyNewGame
```

## What's included

- **ProfileStore** ([MadStudioRoblox](https://github.com/MadStudioRoblox/ProfileStore)) for player data persistence
- **SyncedTables** (server `SyncedTable` component + client `SyncedTables` controller) for replicating data to clients
- **DataService** wiring ProfileStore profiles into per-player SyncedTables
- Minimal **service/controller loader** (one server entry script, one client entry script)
<!-- TEMPLATE:END -->

## Getting started

```bash
rojo serve
```

Then connect from the Rojo plugin in Roblox Studio. To build a place file:

```bash
rojo build -o RobloxGameTemplate.rbxlx
```

## Structure

```
src/
├── ReplicatedStorage/
│   ├── Controllers/        -- Client-side controllers (auto-loaded by Main.client.lua)
│   │   └── SyncedTables.lua    -- Client mirror of server SyncedTables
│   └── Modules/            -- Shared modules
│       ├── Core/               -- Helper hub (UID generation etc.)
│       └── Serializer.lua      -- JSON serializer used by SyncedTables
├── ServerScriptService/
│   ├── Main.server.lua     -- Server entry point, loads Services/
│   ├── ProfileStore.luau   -- MadStudioRoblox/ProfileStore (data persistence)
│   └── Services/           -- Server-side services (auto-loaded by Main.server.lua)
│       └── DataService.lua     -- Player profiles + replication
├── ServerStorage/
│   └── Components/
│       └── SyncedTable.lua     -- Server-side synced table component
└── StarterPlayerScripts/
    └── Main.client.lua     -- Client entry point, loads Controllers/
```

## Service / Controller lifecycle

`Main.server.lua` requires every ModuleScript in `ServerScriptService/Services`;
`Main.client.lua` requires every ModuleScript in `ReplicatedStorage/Controllers`.
Both then call the optional `:Init()` on each module (in load order) followed by
`:Start()` (spawned in its own thread). Plain modules without those methods are
simply required.

## Player data flow

1. `DataService` starts a ProfileStore session per player (template in
   `DATA_TEMPLATE`) and wraps `profile.Data` in a server `SyncedTable` with the
   UID `PlayerData_<UserId>`, subscribed to that player.
2. Server code mutates data via `DataService:SetValue(player, key, value)` or by
   editing `profile.Data` directly and calling `DataService:Sync(player)`.
3. The client reads it through the `SyncedTables` controller:

```lua
local Players = game:GetService("Players")
local SyncedTables = require(game.ReplicatedStorage.Controllers.SyncedTables)

local entry = SyncedTables.WaitForTable("PlayerData_" .. Players.LocalPlayer.UserId)
print(entry.Data.Cash)
entry.Changed.Event:Connect(function(newData)
	print("Data updated:", newData.Cash)
end)
```
