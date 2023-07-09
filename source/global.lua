-- Game constants

-- States
STATE_TITLE = 1
STATE_STAGE_PLAY = 2
STATE_STAGE_INTERMISSION = 3
STATE_LEVEL_SELECT = 4
STATE_HISCORE = 5
STATE_SETTINGS = 6
STATE_GAME_CLEAR = 7

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


-- Global High Score Calculation
-- =============================

-- Need to do this, as score is saved only as a uint32 and
-- will be displayed as is on Catalog scores page
-- https://help.play.date/catalog-developer/scoreboard-api/

-- Example: Andy | stage 37 | 4:08.724 | 3 lives used
-- 37 * 1,000 + 37 * 15 - 249
-- 37,000 + 555 - 249
-- 37,306 * 1000  + 3
-- 37,306,003

-- Avg. *Bonus* Time Per Stage | Score (seconds per stage)
-- 5  | 84,420,000 (10 sps)
-- 6  | 84,504,000 (9 sps) <
-- 7  | 84,588,000 (8 sps) < Estimated max score around here
-- 8  | 84,672,000 (7 sps) <
-- 9  | 84,756,000 (6 sps)
-- 10 | 84,840,000 (5 sps)
-- 11 | 84,924,000 (4 sps) < Should be impossible
-- 12 | 85,004,000 (3 sps)
-- Using lives will cost time, which ends up being 1000s of points lost
-- It seems very unlikely anyone will score higher than this without cheating
-- If every stage was cleared in 0 seconds, the score would be 85,260,000


function calculateScore(stagesCleared, totalTime, livesUsed)
	local score = stagesCleared * 1000
	score = score + stagesCleared * 15 - math.ceil(totalTime)
	score = score * 1000 + math.min(999, livesUsed)
	score = math.max(0, score)
	return score
end


-- If player's total time is over 15s per stage cleared, this will not work
-- bonus would be zero and so totalTime will max out at stagesCleared * 15
function getStageTimeLivesFromScore(originalScore)
	local stagesCleared = math.floor(originalScore / 1000000)
	local livesUsed = originalScore % 1000
	local bonus = ((originalScore - livesUsed) / 1000) % 1000
	local totalTime = stagesCleared * 15 - bonus
	return stagesCleared, totalTime, livesUsed
end


-- Useful for formating scores. Found on Stack Overflow:
-- https://stackoverflow.com/questions/10989788/format-integer-in-lua
function format_int(number)
  local i, j, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')

  -- reverse the int-string and append a comma to all blocks of 3 digits
  int = int:reverse():gsub("(%d%d%d)", "%1,")

  -- reverse the int-string back remove an optional comma and put the 
  -- optional minus and fractional part back
  return minus .. int:reverse():gsub("^,", "") .. fraction
end