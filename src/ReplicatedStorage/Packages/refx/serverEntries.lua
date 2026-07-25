--[[
	refx serverEntries

	The server never kept a registry of effects — server-side effects are
	fire-and-forget remote broadcasts (see serverProxy). This module adds a
	lightweight, read-only tracker for debug/admin tooling.

	It records:
		- a cumulative count of effects broadcast this session (TotalCreated)
		- a per-name cumulative breakdown (CreatedByName)
		- an APPROXIMATE "currently live" set (ActiveByName / ActiveCount)

	"Currently live" is approximate because most server effects are never
	explicitly :Destroy()'d server-side — they self-destruct on the client. To
	stop this registry from leaking, entries auto-expire after DEFAULT_TTL, so
	the live set is really "effects broadcast within the last ~TTL seconds that
	weren't explicitly destroyed." Explicit :Destroy() removes them immediately.

	Purely additive; nothing here changes effect behavior.
]]

local RunService = game:GetService("RunService")

local serverEntries = {}

local DEFAULT_TTL = 30 -- seconds an un-destroyed entry lingers before expiring
local CLEANUP_INTERVAL = 1
local GRACE = 0

local registry = {} -- [id] = { Name = string, Start = number, TTL = number }
local totalCreated = 0
local perNameCreated = {} -- [name] = cumulative count

local cleanupConnection
local lastCleanup = 0

local function ensureCleanup()
	if cleanupConnection then
		return
	end
	cleanupConnection = RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - lastCleanup < CLEANUP_INTERVAL then
			return
		end
		lastCleanup = now
		for id, entry in registry do
			if (now - entry.Start) > (entry.TTL + GRACE) then
				registry[id] = nil
			end
		end
	end)
end

function serverEntries.register(id, name, ttl)
	registry[id] = {
		Name = name,
		Start = tick(),
		TTL = ttl or DEFAULT_TTL,
	}
	totalCreated += 1
	perNameCreated[name] = (perNameCreated[name] or 0) + 1
	ensureCleanup()
end

function serverEntries.unregister(id)
	registry[id] = nil
end

-- Read-only stats snapshot consumed by admin tooling.
function serverEntries.getStats()
	local activeByName = {}
	local activeCount = 0
	for _, entry in registry do
		activeCount += 1
		activeByName[entry.Name] = (activeByName[entry.Name] or 0) + 1
	end
	return {
		ActiveCount = activeCount,
		ActiveByName = activeByName,
		TotalCreated = totalCreated,
		CreatedByName = perNameCreated,
	}
end

return serverEntries
