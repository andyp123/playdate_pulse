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

local maxRunsToShow = 6

local iconTable = gfx.imagetable.new("images/menu_icons")

function hiscore.drawToImage(image, font, fontSmall)
	image:clear(gfx.kColorBlack)
	gfx.lockFocus(image)

	-- Header
	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	font:drawTextAligned("BEST RUNS", 200, 10, kTextAlignment.center)

	local y = 54
	local runRecords = userData.runRecords

	local lastRank = userData.lastRunRank -- math.random(1, maxRunsToShow)
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
		local text = string.format("%.2d:%.2d.%.3d", tu.minutes, tu.seconds, tu.milliseconds)
		fontSmall:drawText(text, x_time, y)

		-- Retries
		x_retries = 360
		fontSmall:drawText(record.livesUsed, x_retries, y)

		-- Icons
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		if record.stagesCleared == 84 then
			iconTable:drawImage(1, x_stage - 22, y + 1)
		end
		iconTable:drawImage(2, x_time - 22, y + 1)
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