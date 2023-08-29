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

local maxRunsToShow = 6

local iconTable = gfx.imagetable.new("images/menu_icons")


function hiscore.drawToImage(image, font, fontSmall)
	image:clear(gfx.kColorBlack)
	gfx.lockFocus(image)

	-- Header
	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	local titleText = "LOCAL RANKING"
	if hiscore.showOnlineRanking then titleText = "ONLINE RANKING" end
	font:drawTextAligned(titleText, 200, 10, kTextAlignment.center)

	local y = 54
	local runRecords
	if hiscore.showOnlineRanking then
		runRecords = userData.onlineRunRecords
	else
		runRecords = userData.runRecords
	end

	local lastRank = userData.lastRunRank
	if lastRank > 0 and lastRank <= maxRunsToShow then
		sound.play("HISCORE_ENTRY")
		userData.lastRunRank = 0 -- reset to avoid playing sound every time
	end

	for i, record in ipairs(runRecords) do
		if i > maxRunsToShow then break end

		gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
		
		-- Name
		fontSmall:drawTextAligned(record.name, 110, y, kTextAlignment.right)

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

	gfx.unlockFocus()
end

