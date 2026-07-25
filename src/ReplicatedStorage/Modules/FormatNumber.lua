--Abbreviates large numbers for UI: 1500 -> "1.5K", 2000000 -> "2M".
--Whole results drop the decimal ("2K", not "2.0K"); below 1000 the plain
--integer is returned.
local function FormatNumber(amount)
	amount = math.floor(amount)
	local absAmount = math.abs(amount)
	for _, suffix in ipairs({{1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"}}) do
		if absAmount >= suffix[1] then
			local value = math.floor(amount / suffix[1] * 10 + 0.5) / 10
			if value % 1 == 0 then
				return string.format("%d%s", value, suffix[2])
			end
			return string.format("%.1f%s", value, suffix[2])
		end
	end
	return tostring(amount)
end

return FormatNumber
