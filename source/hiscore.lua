-- Playdate SDK
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"

-- Pulse
import "global"
import "userData"

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

	for i, record in ipairs(runRecords) do
		if i > maxRunsToShow then break end

		gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
		
		-- Name
		fontSmall:drawTextAligned(record.name, 110, y, kTextAlignment.right)

		-- Stage cleared
		local x_stage = 160
		fontSmall:drawText(string.format("%d", record.stagesCleared), x_stage, y)

		-- Time
		local x_time = 230
		local tu = getTimeUnits(record.totalTime)
		local text = string.format("%.2d:%.2d.%.3d", tu.minutes, tu.seconds, tu.milliseconds)
		fontSmall:drawText(text, x_time, y)

		-- Retries
		x_retries = 365
		fontSmall:drawText(record.livesUsed, x_retries, y)

		-- Icons
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		if record.stagesCleared == 84 then
			iconTable:drawImage(1, x_stage - 22, y + 1)
		end
		iconTable:drawImage(2, x_time - 22, y + 1)
		iconTable:drawImage(3, x_retries - 22, y + 1)

		y += 30
	end

	gfx.unlockFocus()
end