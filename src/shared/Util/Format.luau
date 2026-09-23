--!strict
-- Number and time formatting for UI.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 999 -> "999", 1234 -> "1.23K", 15300000 -> "15.3M"
function Format.abbreviate(value: number): string
	if value ~= value then
		return "0"
	end
	local negative = value < 0
	local n = math.abs(value)
	if n < 1000 then
		local s = tostring(math.floor(n))
		return if negative then "-" .. s else s
	end
	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (tier * 3)
	local text: string
	if scaled >= 100 then
		text = string.format("%d", math.floor(scaled))
	elseif scaled >= 10 then
		text = string.format("%.1f", math.floor(scaled * 10) / 10)
	else
		text = string.format("%.2f", math.floor(scaled * 100) / 100)
	end
	-- trim trailing zeros ("1.50" -> "1.5", "2.00" -> "2")
	if string.find(text, "%.") then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	text ..= SUFFIXES[tier + 1]
	return if negative then "-" .. text else text
end

-- 1234567 -> "1,234,567"
function Format.commas(value: number): string
	local s = tostring(math.floor(math.abs(value)))
	local formatted = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	formatted = string.gsub(formatted, "^,", "")
	return if value < 0 then "-" .. formatted else formatted
end

-- 75 -> "1:15", 3725 -> "1:02:05"
function Format.time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

function Format.percent(fraction: number): string
	return string.format("%d%%", math.floor(math.clamp(fraction, 0, 1) * 100 + 0.5))
end

return Format
