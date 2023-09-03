-- Playdate SDK
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"

-- Pulse
import "global"
import "userData"
import "sound"

local gfx <const> = playdate.graphics

hiscore = {}
hiscore.__index = hiscore

hiscore.showTimes = true
hiscore.showOnlineRanking = false

local iconTable = gfx.imagetable.new("images/menu_icons")

local maxRunsToShow <const> = 6


function hiscore.drawToImage(image, font, fontSmall)
	image:clear(gfx.kColorBlack)
	gfx.lockFocus(image)

	-- usually only occurs when entering hiscores after completing a run
	local lastRank = userData.lastRunRank
	if lastRank > 0 and lastRank <= maxRunsToShow then
		sound.play("HISCORE_ENTRY")
		userData.lastRunRank = 0 -- reset to avoid playing sound every time

		-- Reset to local data after achieving local high score
		hiscore.showOnlineRanking = false
		hiscore.showTimes = true
	end

	if hiscore.showOnlineRanking == true then
		hiscore.drawOnlineScores(font, fontSmall)
	else
		hiscore.drawLocalScores(font, fontSmall, lastRank)
	end

	gfx.unlockFocus()
end


-- Local scores: local name, max stage reached, time/score, lives used
function hiscore.drawLocalScores(font, fontSmall, lastRank)
	local y = 54
	local runRecords = userData.runRecords
	local onlineRank = userData.onlineRank.rank

	-- Header
	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	font:drawTextAligned("LOCAL RANKING", 200, 10, kTextAlignment.center)

	-- Scoreboard body
	for i, record in ipairs(runRecords) do
		if i > maxRunsToShow then break end

		gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
		
		-- Name
		fontSmall:drawTextAligned(record.name, 115, y, kTextAlignment.right)

		-- Stage cleared
		local x_stage = 158
		fontSmall:drawText(string.format("%d", record.stagesCleared), x_stage, y)

		-- Time
		local x_time = 225
		local tu = getTimeUnits(record.totalTime)
		if hiscore.showTimes then
			local text = string.format("%.2d:%.2d.%.3d", tu.minutes, tu.seconds, tu.milliseconds)
			fontSmall:drawText(text, x_time, y)
		else
			local score = calculateScore(record.stagesCleared, record.totalTime, record.livesUsed)
			local text = format_int(score)
			fontSmall:drawText(text, x_time - 20, y)
		end

		-- Retries
		x_retries = 360
		fontSmall:drawText(record.livesUsed, x_retries, y)

		-- Icons
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		if record.stagesCleared == 84 then
			iconTable:drawImage(1, x_stage - 22, y + 1)
		end
		if hiscore.showTimes then
			iconTable:drawImage(2, x_time - 22, y + 1)
		end
		iconTable:drawImage(3, x_retries - 22, y + 1)

		-- highlight row
		if i == lastRank then
			gfx.setColor(gfx.kColorXOR)
			gfx.fillRect(5, y-4, 390, 26)
		end

		y += 30
	end
end


-- Online scores: rank, name, time/score
-- Online names can be much wider than local ones...
function hiscore.drawOnlineScores(font, fontSmall)
	local y = 54
	local maxRunsToShowOnline = maxRunsToShow
	local runRecords = userData.onlineRunRecords
	local onlineRank = userData.onlineRank.rank

	-- draw rank at the bottom of the score table if it doesn't fit on
	if onlineRank ~= nil and onlineRank > 6 then
		maxRunsToShowOnline = 5
	end

	-- Header
	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	font:drawTextAligned("ONLINE RANKING", 200, 10, kTextAlignment.center)

	-- Scoreboard body
	for i, record in ipairs(runRecords) do
		if i > maxRunsToShowOnline then break end

		gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
		
		-- Name
		fontSmall:drawTextAligned(i, 10, y, kTextAlignment.left)
		fontSmall:drawTextAligned(record.name, 40, y, kTextAlignment.left)

		-- Stage cleared
		local x_stage = 220
		fontSmall:drawText(string.format("%d", record.stagesCleared), x_stage, y)

		-- Time
		local x_time = 290
		local tu = getTimeUnits(record.totalTime)
		if hiscore.showTimes then
			local text = string.format("%.2d:%.2d.%.3d", tu.minutes, tu.seconds, tu.milliseconds)
			fontSmall:drawText(text, x_time, y)
		else
			local score = calculateScore(record.stagesCleared, record.totalTime, record.livesUsed)
			local text = format_int(score)
			fontSmall:drawText(text, x_time - 20, y)
		end

		-- Icons
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		if record.stagesCleared == 84 then
			iconTable:drawImage(1, x_stage - 22, y + 1)
		end
		if hiscore.showTimes then
			iconTable:drawImage(2, x_time - 22, y + 1)
		end

		y += 30
	end

	-- Online rank Footer
	-- draw online rank only if not already visible on high scores
	if onlineRank ~= nil and onlineRank > maxRunsToShowOnline then
		-- draw separator line
		gfx.setColor(gfx.kColorWhite)
		gfx.setLineWidth(3)
		gfx.drawLine(40, 205, 360, 205)

		-- your current rank and time/score (no name)
		gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
		local rankText = string.format("your current rank: %d", onlineRank)
		fontSmall:drawTextAligned(rankText, 200, 214, kTextAlignment.center)
	end
end


-- result is a playdate.scoreboards result {player, value, rank}
function hiscore.drawRankNotification(image, font, fontSmall, result)
	image:clear(gfx.kColorBlack)
	gfx.lockFocus(image)

	

	gfx.unlockFocus()
end