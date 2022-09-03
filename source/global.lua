-- Game constants

-- States
STATE_TITLE = 1
STATE_STAGE_PLAY = 2
STATE_STAGE_INTERMISSION = 3
STATE_LEVEL_SELECT = 4
STATE_HISCORE = 5
STATE_SETTINGS = 6

-- Modes
MODE_STANDARD = 1
MODE_PRACTICE = 2
MODE_PRACTICE_MULTI = 3


-- Global helper functions

-- https://stackoverflow.com/questions/2705793/how-to-get-number-of-entries-in-a-lua-table
-- Playdate's table.getsize appears to not work reliably for stage data (array of {})
function tablelength(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end


function i2xy(i, w)
	i -= 1
	local x = i % w
	local y = math.floor((i - x) / w)
	return x + 1, y + 1
end


function i2xy0(i, w)
	i -= 1
	local x = i % w
	local y = math.floor((i - x) / w)
	return x, y
end


function xy2i(x, y, w)
	local i = (y - 1) * w + x
	return i
end


function clamp(value, min, max)
	if value < min then return min end
	if max ~= nil and value > max then return max end
	return value
end


function getTimeUnits(time)
	local sign = "+"
	if time < 0 then sign = "-" end
	time = math.abs(time)
	local minutes = math.floor(time / 60)
	return {
		sign = sign,
		minutes = minutes,
		seconds = math.floor(time - (minutes * 60)),
		milliseconds = math.floor((time - math.floor(time)) * 1000)
	}
end
