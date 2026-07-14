--Server entry point.
--Requires every ModuleScript in ServerScriptService.Services, then runs the
--optional lifecycle on each: :Init() (in load order), then :Start() (spawned).
local Services = {}

for _, child in ipairs(script.Parent.Services:GetChildren()) do
	if child:IsA("ModuleScript") then
		Services[child.Name] = require(child)
	end
end

for _, service in pairs(Services) do
	if type(service) == "table" and type(service.Init) == "function" then
		service:Init()
	end
end

for _, service in pairs(Services) do
	if type(service) == "table" and type(service.Start) == "function" then
		task.spawn(service.Start, service)
	end
end

print("[Server] All services loaded")
