--Client entry point.
--Requires every ModuleScript in ReplicatedStorage.Controllers, then runs the
--optional lifecycle on each: :Init() (in load order), then :Start() (spawned).
--Controllers that self-initialize at require time (like SyncedTables) may
--yield, so each require is spawned to keep one controller from blocking the rest.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controllers = {}
local controllerFolder = ReplicatedStorage:WaitForChild("Controllers")

local loading = 0
for _, child in ipairs(controllerFolder:GetChildren()) do
	if child:IsA("ModuleScript") then
		loading += 1
		task.spawn(function()
			Controllers[child.Name] = require(child)
			loading -= 1
		end)
	end
end

while loading > 0 do
	task.wait()
end

for _, controller in pairs(Controllers) do
	if type(controller) == "table" and type(controller.Init) == "function" then
		controller:Init()
	end
end

for _, controller in pairs(Controllers) do
	if type(controller) == "table" and type(controller.Start) == "function" then
		task.spawn(controller.Start, controller)
	end
end

print("[Client] All controllers loaded")
