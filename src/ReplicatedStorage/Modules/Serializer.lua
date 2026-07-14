local HttpService = game:GetService("HttpService")

local Serializer = {}

-- Helper to convert Instance to compact path
local function toPath(inst: Instance, root: Instance?): string
	root = root or game
	if inst == root then return "" end
	
	local path = {}
	local current = inst
	while current and current ~= root and current ~= game do
		table.insert(path, 1, current.Name)
		current = current.Parent
	end
	
	if current ~= root then
		return inst:GetFullName() -- Fallback to full path if not under root
	end
	return table.concat(path, ".")
end

-- Helper to resolve path to Instance
local function fromPath(root: Instance, path: string): Instance?
	if path == "" then return root end
	
	local current = root
	for segment in string.gmatch(path, "[^%.]+") do
		current = current:FindFirstChild(segment)
		if not current then return nil end
	end
	return current
end

-- Recursive encoder
local function encodeValue(value, root, seen)
	local valueType = typeof(value)
	
	if valueType == "Instance" then
		return { __isInstance = true, path = toPath(value, root) }
	elseif valueType == "table" then
		if seen[value] then error("Cannot encode circular references", 0) end
		seen[value] = true
		local out = {}
		for k, v in pairs(value) do
			if typeof(k) ~= "string" then
				k = "[" .. tostring(k) .. "]"
			end
			out[k] = encodeValue(v, root, seen)
		end
		seen[value] = nil
		return out
	end
	return value
end

-- Recursive decoder
local function decodeValue(value, root)
	if typeof(value) == "table" and value.__isInstance then
		return fromPath(root, value.path)
	elseif typeof(value) == "table" then
		local out = {}
		for k, v in pairs(value) do
			local decodedKey = k
			if typeof(k) == "string" then
				local num = string.match(k, "^%[(%d+)%]$")
				if num then decodedKey = tonumber(num) end
			end
			out[decodedKey] = decodeValue(v, root)
		end
		return out
	end
	return value
end

-- Public API: Encode to JSON
function Serializer.Encode(data: any, root: Instance?): string
	local packed = encodeValue(data, root or game, {})
	return HttpService:JSONEncode(packed)
end

-- Public API: Decode from JSON
function Serializer.Decode(json: string, root: Instance?): any
	local decoded = HttpService:JSONDecode(json)
	return decodeValue(decoded, root or game)
end

return Serializer