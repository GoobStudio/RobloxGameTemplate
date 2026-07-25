--Full-screen celebration: FOV punch, camera shake, saturation surge, confetti,
--and a big rainbow banner (spun by the RainbowGradient controller). Trigger it
--from any controller for milestone moments (rebirths, jackpots, big purchases):
--  Celebration:Play("Rebirth 50!", {
--      Tier = "big",              --"small" (default) | "medium" | "big"
--      SubText = "Spend your tokens to raise upgrade caps!", --optional hint line
--      Sound = someSoundInstance, --optional one-shot, played via PlaySound
--  })
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local PlaySound = require(ReplicatedStorage.Components.Effects.PlaySound)

local LocalPlayer = Players.LocalPlayer

local Celebration = {}

local FOV_PUNCH = 18
local SHAKE_TIME = 0.7
local SHAKE_INTENSITY = 0.035 --radians at full strength
local CONFETTI_GRAVITY = 1100 --px/s^2

--Duration (s), confetti pieces per pulse, pulse count.
local TIERS = {
	small = {Duration = 1.8, Confetti = 35, Pulses = 1},
	medium = {Duration = 2.6, Confetti = 80, Pulses = 1},
	big = {Duration = 5.2, Confetti = 110, Pulses = 3},
}

--Token for the running celebration; a new one mid-show cancels it and starts
--fresh. Every delayed step checks its token before acting.
local active

local function cancelActive()
	local token = active
	if not token then
		return
	end
	active = nil
	RunService:UnbindFromRenderStep("Celebration")
	token.ColorCorrection:Destroy()
	token.Gui:Destroy()
	--Snap the FOV home; the next celebration's punch masks the snap.
	workspace.CurrentCamera.FieldOfView = token.BaseFOV
end

--Pseudo-3D confetti: flat frames that spin (Rotation) while their width
--squashes on a cosine and their color darkens whenever the "back" would face
--the camera — reads as tumbling 3D cards. Burst-launched from the bottom
--center, then gravity takes over.
local function launchConfetti(gui, pieceCount, lifetime)
	local viewport = workspace.CurrentCamera.ViewportSize
	local pieces = {}

	for _ = 1, pieceCount do
		local hue = math.random()
		local color = Color3.fromHSV(hue, 0.75, 1)
		local width = 8 + math.random() * 8
		local height = 10 + math.random() * 10

		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = color
		frame.Size = UDim2.fromOffset(width, height)
		frame.Parent = gui

		table.insert(pieces, {
			Frame = frame,
			Width = width,
			Height = height,
			Color = color,
			Dark = Color3.new(color.R * 0.5, color.G * 0.5, color.B * 0.5),
			X = viewport.X * 0.5 + (math.random() - 0.5) * viewport.X * 0.2,
			Y = viewport.Y + 20,
			VX = (math.random() - 0.5) * 2 * viewport.X * 0.35,
			VY = -(viewport.Y * (0.8 + math.random() * 0.7)),
			Rot = math.random() * 360,
			Spin = (math.random() - 0.5) * 720,
			Phase = math.random() * math.pi * 2,
			FlipSpeed = 4 + math.random() * 8,
			Life = lifetime * (0.7 + math.random() * 0.3),
		})
	end

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		for index = #pieces, 1, -1 do
			local piece = pieces[index]
			piece.Life -= dt
			piece.VY += CONFETTI_GRAVITY * dt
			piece.X += piece.VX * dt
			piece.Y += piece.VY * dt
			piece.Rot += piece.Spin * dt
			piece.Phase += piece.FlipSpeed * dt

			if piece.Life <= 0 or piece.Y > viewport.Y + 60 then
				piece.Frame:Destroy()
				table.remove(pieces, index)
			else
				local flip = math.cos(piece.Phase)
				piece.Frame.Position = UDim2.fromOffset(piece.X, piece.Y)
				piece.Frame.Rotation = piece.Rot
				piece.Frame.Size = UDim2.fromOffset(math.max(piece.Width * math.abs(flip), 1.5), piece.Height)
				piece.Frame.BackgroundColor3 = flip >= 0 and piece.Color or piece.Dark
			end
		end
		if #pieces == 0 then
			connection:Disconnect()
		end
	end)
end

function Celebration:Play(bannerText, options)
	options = options or {}
	local tier = TIERS[options.Tier or "small"] or TIERS.small
	local subText = options.SubText
	local duration = tier.Duration

	cancelActive() --restart mid-show rather than skipping the new one
	local token = {}
	active = token

	local camera = workspace.CurrentCamera

	if options.Sound then
		PlaySound.locally(options.Sound, SoundService)
	end

	--Saturation surge, then ease back to normal.
	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Saturation = 0
	colorCorrection.Contrast = 0
	colorCorrection.Parent = Lighting
	token.ColorCorrection = colorCorrection
	TweenService:Create(colorCorrection, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Saturation = 0.6,
		Contrast = 0.15,
	}):Play()
	task.delay(duration - 0.8, function()
		if active ~= token then
			return
		end
		TweenService:Create(colorCorrection, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Saturation = 0,
			Contrast = 0,
		}):Play()
	end)

	--FOV punch out, Back-ease home.
	local baseFOV = camera.FieldOfView
	token.BaseFOV = baseFOV
	TweenService:Create(camera, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = baseFOV + FOV_PUNCH,
	}):Play()
	task.delay(0.15, function()
		if active ~= token then
			return
		end
		TweenService:Create(camera, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			FieldOfView = baseFOV,
		}):Play()
	end)

	--Decaying camera shake, applied after the camera controller writes its
	--CFrame each frame.
	local elapsed = 0
	RunService:BindToRenderStep("Celebration", Enum.RenderPriority.Camera.Value + 1, function(dt)
		elapsed += dt
		if elapsed < SHAKE_TIME then
			local strength = SHAKE_INTENSITY * (1 - elapsed / SHAKE_TIME)
			camera.CFrame = camera.CFrame * CFrame.Angles(
				(math.random() - 0.5) * 2 * strength,
				(math.random() - 0.5) * 2 * strength,
				(math.random() - 0.5) * 2 * strength
			)
		end
	end)

	--Big rainbow banner.
	local gui = Instance.new("ScreenGui")
	gui.Name = "Celebration"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	token.Gui = gui

	for pulse = 0, tier.Pulses - 1 do
		task.delay(pulse * 0.9, function()
			if gui.Parent then --celebration may already be torn down
				launchConfetti(gui, tier.Confetti, 2.5)
			end
		end)
	end

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.4)
	label.Size = UDim2.fromScale(0.7, 0.18)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = bannerText
	label.Rotation = -6
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(30, 30, 30)
	stroke.Parent = label

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0.7, 1)),
		ColorSequenceKeypoint.new(0.2, Color3.fromHSV(0.2, 0.7, 1)),
		ColorSequenceKeypoint.new(0.4, Color3.fromHSV(0.4, 0.7, 1)),
		ColorSequenceKeypoint.new(0.6, Color3.fromHSV(0.6, 0.7, 1)),
		ColorSequenceKeypoint.new(0.8, Color3.fromHSV(0.8, 0.7, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 0.7, 1)),
	})
	gradient:AddTag("RainbowGradient") --spun by the RainbowGradient controller
	gradient.Parent = label

	--Pop in with overshoot, settle level, then punch out.
	local scale = Instance.new("UIScale")
	scale.Scale = 0.1
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
		Rotation = 0,
	}):Play()
	--Secondary hint line, popping in under the banner once it has landed.
	local subLabel, subStroke, subScale
	if subText then
		subLabel = Instance.new("TextLabel")
		subLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		subLabel.Position = UDim2.fromScale(0.5, 0.53)
		subLabel.Size = UDim2.fromScale(0.55, 0.06)
		subLabel.BackgroundTransparency = 1
		subLabel.Font = Enum.Font.GothamBold
		subLabel.TextScaled = true
		subLabel.TextColor3 = Color3.new(1, 1, 1)
		subLabel.Text = subText
		subLabel.Visible = false
		subLabel.Parent = gui

		subStroke = Instance.new("UIStroke")
		subStroke.Thickness = 3
		subStroke.Color = Color3.fromRGB(30, 30, 30)
		subStroke.Parent = subLabel

		subScale = Instance.new("UIScale")
		subScale.Scale = 0.2
		subScale.Parent = subLabel

		task.delay(0.55, function()
			if active ~= token then
				return
			end
			subLabel.Visible = true
			TweenService:Create(subScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end)
	end

	task.delay(duration - 0.5, function()
		if active ~= token then
			return
		end
		local exitInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Scale = 0.05,
		}):Play()
		TweenService:Create(label, exitInfo, {TextTransparency = 1}):Play()
		TweenService:Create(stroke, exitInfo, {Transparency = 1}):Play()
	end)

	--The hint outlives the banner by a few seconds before making its own exit.
	if subLabel then
		task.delay(duration + 2.5, function()
			if active ~= token then
				return
			end
			local exitInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(subScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Scale = 0.05,
			}):Play()
			TweenService:Create(subLabel, exitInfo, {TextTransparency = 1}):Play()
			TweenService:Create(subStroke, exitInfo, {Transparency = 1}):Play()
		end)
	end

	--Teardown (confetti finishes falling inside the grace window; destroying
	--the gui sweeps any stragglers). The hint's extended stay pushes it out.
	task.delay(subText and duration + 3.2 or duration + 1.2, function()
		if active == token then
			cancelActive()
		end
	end)
end

return Celebration
