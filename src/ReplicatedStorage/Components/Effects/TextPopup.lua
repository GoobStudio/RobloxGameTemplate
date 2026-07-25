--One-shot floating text billboard: pops in at a world position, rises, fades,
--and destroys itself. Self-contained (builds its own billboard), so no asset
--template is required. Typical use, locally per pickup/press:
--  TextPopup.locally("+$" .. FormatNumber(amount), position)
--Optional third argument overrides the text color.
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local REFX = require(ReplicatedStorage.Packages.refx)
local TextPopup = REFX.CreateEffect("TextPopup")

local RISE_STUDS = 3
local RISE_TIME = 1.5
local BASE_OFFSET = Vector3.new(0, 1, 0)

function TextPopup:OnConstruct(text, position, color)
	self.DestroyOnEnd = true
	self.MaxLifetime = 3
	self.Text = text
	self.Position = position
	self.Color = color or Color3.fromRGB(120, 255, 120)
end

function TextPopup:OnStart()
	if not self.Position then
		return
	end

	self.Holder = Instance.new("Part")
	self.Holder.Anchored = true
	self.Holder.CanCollide = false
	self.Holder.CanQuery = false
	self.Holder.Transparency = 1
	self.Holder.Size = Vector3.new(0.1, 0.1, 0.1)
	self.Holder.CFrame = CFrame.new(self.Position)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(4, 1.2)
	gui.StudsOffset = BASE_OFFSET
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	gui.Parent = self.Holder

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = self.Color
	label.Text = self.Text
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(30, 30, 30)
	stroke.Parent = label

	--Pop in with a little overshoot.
	local scale = Instance.new("UIScale")
	scale.Scale = 0.5
	scale.Parent = gui
	TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	self.Holder.Parent = workspace

	TweenService:Create(gui, TweenInfo.new(RISE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = BASE_OFFSET + Vector3.new(0, RISE_STUDS, 0),
	}):Play()

	--Fade over the back half of the rise.
	local fadeInfo = TweenInfo.new(RISE_TIME * 0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, RISE_TIME * 0.5)
	TweenService:Create(label, fadeInfo, {TextTransparency = 1}):Play()
	TweenService:Create(stroke, fadeInfo, {Transparency = 1}):Play()

	task.wait(RISE_TIME + 0.1)
end

function TextPopup:OnDestroy()
	if self.Holder then
		self.Holder:Destroy()
	end
end

return TextPopup
