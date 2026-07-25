local REFX = require(game.ReplicatedStorage.Packages.refx)
local PlaySound = REFX.CreateEffect("PlaySound")

-- Settings (optional): { PlaybackSpeed, PlaybackSpeedVariance, Volume }
-- Variance is a ± fraction applied per play so repeated combat sounds don't
-- sound stamped from the same mold.
function PlaySound:OnConstruct(SoundOrFolder, ParentOrPosition, SoundGroup, Settings)

	self.DestroyOnEnd = true
	if SoundOrFolder:IsA("Sound") then
		self.Sound = SoundOrFolder
	else
		local Sounds = SoundOrFolder:GetChildren()
		self.Sound = Sounds[math.random(1, #Sounds)] -- Randomly select a sound from the folder
	end

	if typeof(ParentOrPosition) == "Instance" then
		self.Parent = ParentOrPosition
	else
		self.Position = ParentOrPosition -- Assume it's a Vector3 position
	end

	self.SoundGroup = SoundGroup or nil
	self.Settings = Settings or nil
end

function PlaySound:OnStart()
	self.SoundInstance = self.Sound:Clone()
	if self.Settings then
		if self.Settings.PlaybackSpeed then
			self.SoundInstance.PlaybackSpeed = self.Settings.PlaybackSpeed
		end
		if self.Settings.PlaybackSpeedVariance then
			local variance = self.Settings.PlaybackSpeedVariance
			self.SoundInstance.PlaybackSpeed *= 1 + (math.random() - 0.5) * 2 * variance
		end
		if self.Settings.Volume then
			self.SoundInstance.Volume = self.Settings.Volume
		end
	end
	if self.SoundGroup then
		self.SoundInstance.SoundGroup = self.SoundGroup
	elseif not self.SoundInstance.SoundGroup then
		--Optional default group; this game may not define one.
		self.SoundInstance.SoundGroup = game:GetService("SoundService"):FindFirstChild("Effects")
	end
	if self.Parent then
		self.SoundInstance.Parent = self.Parent
	else
		self.Holder = Instance.new("Part")
		self.Holder.Position = self.Position or Vector3.new(0, 0, 0)
		self.Holder.Anchored = true
		self.Holder.CanCollide = false
		self.Holder.CanQuery = false
		self.Holder.Transparency = 1
		self.Holder.Parent = game.Workspace
		self.SoundInstance.Parent = self.Holder
	end
	-- TimeLength is 0 until the asset is loaded. In the live game the sound
	-- often isn't cached on first play, so without this wait we'd read a
	-- length of 0, finish OnStart immediately, and destroy the sound before
	-- it ever became audible.
	if not self.SoundInstance.IsLoaded then
		local loaded = false
		self.SoundInstance.Loaded:Once(function()
			loaded = true
		end)
		-- Bail out after 5s so a bad/failed asset id can't hang the effect.
		local elapsed = 0
		while not loaded and elapsed < 5 do
			elapsed += task.wait()
		end
	end

	-- The effect may have been destroyed while we waited (Destroy locks Parent to nil).
	if self.SoundInstance.Parent == nil then
		return
	end

	self.SoundInstance:Play()
	task.wait(self.SoundInstance.TimeLength / math.max(self.SoundInstance.PlaybackSpeed, 0.1))
end


function PlaySound:OnDestroy()
	if self.Parent then
		self.SoundInstance:Destroy()
	else
		if self.Holder then
			self.Holder:Destroy() -- Clean up the holder if it was created
		end
	end
end

return PlaySound
