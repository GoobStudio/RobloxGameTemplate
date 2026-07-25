--Registers all refx effect classes and starts the client receiver, so effects
--constructed on the server (e.g. MyEffect.new(...):WithinRange(pos, range))
--render on this client. Effect classes live in ReplicatedStorage.Components.
--Effects; the server needs no bootstrap — it just requires an effect module
--and constructs it. Client-only effects use MyEffect.locally(...).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local refx = require(ReplicatedStorage.Packages.refx)

local RefxBootstrap = {}

function RefxBootstrap:Init()
	refx.Register(ReplicatedStorage.Components.Effects)
	refx.Start()
end

return RefxBootstrap
