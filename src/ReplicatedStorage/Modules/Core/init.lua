--Central core module, easy access to helper modules, packages, etc with one require.
--Big benefit of this setup is that we can change these paths later and edit them all in one central place.
local Core = {}
Core.UID = require(script.UID) --Unique ID generation module
--Core.MainUI_Manager = nil --Set in UIManager.client.lua

function Core.GetPlayersInRange(Position,Range)
    local Players = game.Players:GetPlayers()
    local PlayersInRange = {}
    for _,Player in pairs(Players) do
        if Player.Character and Player.Character.PrimaryPart then
            local Distance = (Player.Character.PrimaryPart.Position - Position).Magnitude
            if Distance <= Range then
                table.insert(PlayersInRange, Player)
            end
        end
    end
    return PlayersInRange
end
return Core