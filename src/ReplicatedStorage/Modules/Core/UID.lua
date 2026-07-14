local UID = {}

local CurrentUID = 0

local CurrentUIDDomains = {} --Reduce the digits for most UIDs by restricting uniqueness to a specific domain

function UID.GetUID(Domain) --Domain is entirely optional
	if not Domain then
		CurrentUID +=1 
		return "_"..CurrentUID
	else
		if not CurrentUIDDomains[Domain] then
			CurrentUIDDomains[Domain] = 0
		end
		CurrentUIDDomains[Domain] += 1
		return "_"..CurrentUIDDomains[Domain]
	end
end

return UID