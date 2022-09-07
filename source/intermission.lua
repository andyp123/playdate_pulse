-- Playdate SDK
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"

-- Pulse
import "global"
import "stage" -- need constants from here
import "sound"
import "userData"

local gfx <const> = playdate.graphics

intermission = {}
intermission.__index = intermission


function intermission.drawToImage(image, font, fontSmall, playData)
	image:clear(gfx.kColorWhite)
	gfx.lockFocus(image)

	-- Total elapsed time
	local xp, yp = 200, 10
	local stageRecord = userData.getStageTimeRecord(playData.currentStage)
	local tu = getTimeUnits(playData.totalTime)
	local timeString = string.format("%.2d:%.2d.%.3d", tu.minutes, tu.seconds, tu.milliseconds)
	local text = string.format("TIME: %s", timeString)

	if playData.gameMode ~= MODE_STANDARD then
		text = "PRACTICE MODE"
	end

	gfx.fillRect(0, 0, 400, 50)
	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	font:drawTextAligned(text, xp, yp, kTextAlignment.center)

	yp = 65
	gfx.setImageDrawMode(gfx.kDrawModeFillBlack)

	-- Previous stage
	if playData.startStage < playData.currentStage then
		gfx.setLineWidth(3)
		gfx.drawRect(15, yp, 370, 80)
		tu = getTimeUnits(playData.stageTime)
		timeString = string.format("%.2d.%.3d", tu.seconds, tu.milliseconds)
		tu = getTimeUnits(playData.stageTime - playData.prevRecord)
		local timeDiffString = string.format("%s%d.%.3d", tu.sign, tu.seconds, tu.milliseconds)
		local newRecordString = ""
		if playData.stageTime - playData.prevRecord < 0 then
			newRecordString = "\n> NEW STAGE RECORD <"
		end
		text = string.format("STAGE %.2d CLEAR\n%s (%s)%s", playData.currentStage - 1, timeString, timeDiffString, newRecordString)
		fontSmall:drawTextAligned(text, xp, yp + 10, kTextAlignment.center)
		yp += 100
	end

	-- Current stage
	if playData.gameMode ~= MODE_PRACTICE then
		tu = getTimeUnits(stageRecord.time)
		timeString = string.format("%.2d.%.3d", tu.seconds, tu.milliseconds)
		text = string.format("ENTERING STAGE %.2d", playData.currentStage)
		font:drawTextAligned(text, xp, yp, kTextAlignment.center)
		text = string.format("Record: %s  -  %s", timeString, stageRecord.name)
		fontSmall:drawTextAligned(text, xp, yp + 40, kTextAlignment.center)
	end

	gfx.unlockFocus()
end

