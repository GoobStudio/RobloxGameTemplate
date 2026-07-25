--Hover feel for any GuiObject tagged "UIButton": fast, subtle scale grow on
--mouse enter and shrink back on leave, via an injected UIScale so the
--element's authored size/layout is untouched.
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local UIButtonHover = {}

local TAG = "UIButton"
local HOVER_SCALE = 1.06
local TWEEN_INFO = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local setups = {} --[instance] = {Scale, Connections}

local function tweenScale(scale, target)
	TweenService:Create(scale, TWEEN_INFO, {Scale = target}):Play()
end

local function setup(instance)
	if setups[instance] or not instance:IsA("GuiObject") then
		return
	end

	local scale = instance:FindFirstChild("HoverScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "HoverScale"
		scale.Parent = instance
	end

	local entry = {Scale = scale, Connections = {}}
	setups[instance] = entry

	--Frames scale as a whole but listen on their inner "TextButton" (frames
	--often cover more area than the clickable part). Resolved async since the
	--child may not have replicated yet.
	task.spawn(function()
		local target = instance
		if instance:IsA("Frame") then
			target = instance:WaitForChild("TextButton", 10) or instance
		end
		if setups[instance] ~= entry then
			return --untagged while waiting
		end
		table.insert(entry.Connections, target.MouseEnter:Connect(function()
			tweenScale(scale, HOVER_SCALE)
		end))
		table.insert(entry.Connections, target.MouseLeave:Connect(function()
			tweenScale(scale, 1)
		end))
	end)
end

local function cleanup(instance)
	local entry = setups[instance]
	if entry then
		setups[instance] = nil
		for _, connection in ipairs(entry.Connections) do
			connection:Disconnect()
		end
		entry.Scale:Destroy()
	end
end

function UIButtonHover:Start()
	for _, instance in ipairs(CollectionService:GetTagged(TAG)) do
		setup(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(setup)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(cleanup)
end

return UIButtonHover
