--Spins the Rotation of any UI instance tagged "RainbowGradient" (typically a
--UIGradient) in a smooth endless loop. Optional per-instance "SpinSpeed"
--attribute overrides the default degrees/second.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local RainbowGradient = {}

local TAG = "RainbowGradient"
local DEFAULT_SPEED = 45 --degrees per second

local tagged = {} --[instance] = true

function RainbowGradient:Start()
	for _, instance in ipairs(CollectionService:GetTagged(TAG)) do
		tagged[instance] = true
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance)
		tagged[instance] = true
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
		tagged[instance] = nil
	end)

	RunService.RenderStepped:Connect(function(dt)
		for instance in pairs(tagged) do
			local speed = instance:GetAttribute("SpinSpeed") or DEFAULT_SPEED
			instance.Rotation = (instance.Rotation + speed * dt) % 360
		end
	end)
end

return RainbowGradient
