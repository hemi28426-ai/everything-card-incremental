-- Formats big numbers the way incremental games do: 1532 -> "1.53K", 2.4e9 -> "2.4B"

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function format(n: number): string
	n = math.floor(n + 0.5)
	if n < 0 then
		return "-" .. format(-n)
	end
	if n < 1000 then
		return tostring(n)
	end

	local index = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (index * 3)

	local text
	if scaled >= 100 then
		text = string.format("%.0f", scaled)
	elseif scaled >= 10 then
		text = string.format("%.1f", scaled)
	else
		text = string.format("%.2f", scaled)
	end

	-- trim trailing zeros: "1.50" -> "1.5", "2.00" -> "2"
	text = text:gsub("%.0+$", ""):gsub("(%.%d-)0+$", "%1")

	return text .. SUFFIXES[index + 1]
end

return format
