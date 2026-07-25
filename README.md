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
- **MonetizationService** — receipt-safe dev product / game pass pipeline with one handler module per product or pass
- **refx** ([ffrostfall](https://github.com/ffrostfall/refx)) for server-triggered client effects, pre-wired with example effects
- **UI polish kit** — `Celebration` (confetti + rainbow banner + camera punch), `TextPopup` (floating world-space text), tag-driven `RainbowGradient` and `UIButtonHover`, and a `FormatNumber` abbreviator (1.5K/2M/...)
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

Every synced container sets `$ignoreUnknownInstances: true`, so instances created
directly in Studio (folders, assets, UI) are left alone instead of being deleted
on the next sync — only the files Rojo manages are overwritten.

## Structure

```
src/
├── ReplicatedStorage/
│   ├── Components/
│   │   └── Effects/        -- refx effect classes (BasicParticle, PlaySound, TextPopup)
│   ├── Controllers/        -- Client-side controllers (auto-loaded by Main.client.lua)
│   │   ├── Celebration.lua     -- Full-screen milestone celebration (confetti, banner)
│   │   ├── RainbowGradient.lua -- Spins any UI tagged "RainbowGradient"
│   │   ├── RefxBootstrap.lua   -- Registers effect classes + starts the refx client
│   │   ├── SyncedTables.lua    -- Client mirror of server SyncedTables
│   │   └── UIButtonHover.lua   -- Hover scale for any GuiObject tagged "UIButton"
│   ├── Modules/            -- Shared modules
│   │   ├── Core/               -- Helper hub (UID generation etc.)
│   │   ├── FormatNumber.lua    -- 1500 -> "1.5K" abbreviation for UI
│   │   ├── GameSettings.lua    -- Central registry of product/pass ids
│   │   └── Serializer.lua      -- JSON serializer used by SyncedTables
│   └── Packages/
│       └── refx/           -- ffrostfall/refx (server-triggered client effects)
├── ServerScriptService/
│   ├── Main.server.lua     -- Server entry point, loads Services/
│   ├── ProfileStore.luau   -- MadStudioRoblox/ProfileStore (data persistence)
│   ├── Monetization/
│   │   ├── Passes/         -- One handler per game pass (VIP.lua example)
│   │   └── Products/       -- One handler per dev product (Cash1000.lua example)
│   └── Services/           -- Server-side services (auto-loaded by Main.server.lua)
│       ├── DataService.lua     -- Player profiles + replication
│       └── MonetizationService.lua -- Receipt processing + pass application
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

## Monetization

Product and pass ids live in `ReplicatedStorage/Modules/GameSettings.lua` — the
single source of truth for both the client (prompting purchases) and the server
(resolving receipts). Every name in `GameSettings.Products` / `GameSettings.Passes`
must have a matching handler ModuleScript in
`ServerScriptService/Monetization/Products` or `.../Passes`.

- **Product handlers** implement `:Process(player, receiptInfo)` — grant the
  purchase; throw to have Roblox retry the receipt later. `MonetizationService`
  records processed `PurchaseId`s in the player's profile
  (`Data.Monetization.Receipts`), so a retried receipt is acknowledged without
  granting twice.
- **Pass handlers** implement `:OnOwned(player)` — applied on join for owners
  and immediately after an in-game purchase; must be idempotent.

To add a product: create the dev product on the Roblox dashboard, put its id in
`GameSettings.Products`, and drop a handler module with the same name into
`Monetization/Products/`. `Cash1000.lua` (product) and `VIP.lua` (pass) are
working examples.

## Effects (refx)

[refx](https://github.com/ffrostfall/refx) lets the server construct visual/audio
effects that render on clients. Effect classes live in
`ReplicatedStorage/Components/Effects`; `RefxBootstrap` registers them and starts
the client receiver — the server needs no bootstrap, it just requires an effect
module and constructs it:

```lua
local PlaySound = require(game.ReplicatedStorage.Components.Effects.PlaySound)
PlaySound.new(soundInstance, position):WithinRange(position, 100)
```

Client-only effects use `MyEffect.locally(...)`. `BasicParticle` (clone an
attachment's emitters, emit, clean up), `PlaySound` (positional/parented
one-shot sounds with variance), and `TextPopup` (floating world-space text)
are included as starting points.

## UI polish kit

- **Celebration** — full-screen milestone moment: FOV punch, camera shake,
  saturation surge, confetti bursts, and a big rainbow banner with an optional
  hint line. Call it from any controller:

  ```lua
  local Celebration = require(game.ReplicatedStorage.Controllers.Celebration)
  Celebration:Play("Rebirth 50!", {
      Tier = "big",     -- "small" (default) | "medium" | "big"
      SubText = "Spend your tokens to raise upgrade caps!",
      Sound = someSound, -- optional Sound instance
  })
  ```

- **TextPopup** — floating "+$X"-style text at a world position, self-contained
  (no asset template needed): `TextPopup.locally("+$" .. FormatNumber(n), pos)`.
- **RainbowGradient** — tag any UI instance (typically a `UIGradient`)
  `"RainbowGradient"` and its `Rotation` spins forever; optional `SpinSpeed`
  attribute overrides degrees/second. The Celebration banner uses this tag.
- **UIButtonHover** — tag any GuiObject `"UIButton"` for a subtle scale-up on
  hover via an injected `UIScale` (authored layout untouched).
- **FormatNumber** — `require(ReplicatedStorage.Modules.FormatNumber)(1500)`
  returns `"1.5K"` (K/M/B/T suffixes, one decimal, whole values drop it).
