-- Playdate SDK
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"

-- Pulse
import "global"
import "stage" -- need constants from here
import "userData"

local gfx <const> = playdate.graphics

intermission = {}
intermission.__index = intermission


function intermission.drawToImage(image, font, fontSmall, playData)
	image:clear(gfx.kColorBlack)
	gfx.lockFocus(image)

	-- Total elapsed time
	local xp, yp = 200, 14
	local stageRecord = userData.getStageTimeRecord(playData.currentStage)
	local tu = getTimeUnits(playData.totalTime)
	local timeString = string.format("%.2d:%.2d.%.3d", tu.minutes, tu.seconds, tu.milliseconds)
	local text = string.format("TIME: %s", timeString)
	local numStages = stage.getNumStages()

	if playData.gameMode ~= MODE_STANDARD then
		text = "PRACTICE MODE"
	end

	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	font:drawTextAligned(text, xp, yp, kTextAlignment.center)

	yp = 60

	-- Previous stage
	if playData.startStage < playData.currentStage then
		gfx.setColor(gfx.kColorWhite)
		gfx.fillRect(15, yp, 370, 85)
		gfx.setImageDrawMode(gfx.kDrawModeFillBlack)

		tu = getTimeUnits(playData.stageTime)
		timeString = string.format("%.2d.%.3d", tu.seconds, tu.milliseconds)
		tu = getTimeUnits(playData.stageTime - playData.prevRecord)
		local timeDiffString = string.format("%s%d.%.3d", tu.sign, tu.seconds, tu.milliseconds)
		local newRecordString = ""
		if playData.stageTime - playData.prevRecord < 0 then
			newRecordString = "\nNEW STAGE RECORD!"
		end
		text = string.format("STAGE %.2d CLEAR", playData.currentStage - 1)
		font:drawTextAligned(text, xp, yp + 4, kTextAlignment.center)
		text = string.format("%s (%s)%s", timeString, timeDiffString, newRecordString)
		fontSmall:drawTextAligned(text, xp, yp + 37, kTextAlignment.center)
		yp += 105
	end

	-- Current stage
	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	if playData.gameMode == MODE_STANDARD and playData.gameClear then
		text = "All stages clear. You win!"
		font:drawTextAligned(text, xp, yp + 10, kTextAlignment.center)
	elseif playData.gameMode ~= MODE_PRACTICE and playData.currentStage <= numStages then
		tu = getTimeUnits(stageRecord.time)
		timeString = string.format("%.2d.%.3d", tu.seconds, tu.milliseconds)
		text = string.format("ENTERING STAGE %.2d", playData.currentStage)
		font:drawTextAligned(text, xp, yp, kTextAlignment.center)
		text = string.format("Record: %s  -  %s", timeString, stageRecord.name)
		fontSmall:drawTextAligned(text, xp, yp + 40, kTextAlignment.center)
	end

	gfx.unlockFocus()
end


function intermission.drawGameClear(image, font, fontSmall, playData)
	image:clear(gfx.kColorBlack)
	gfx.lockFocus(image)

	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)

	-- Total elapsed time
	local xp, yp = 200, 10
	local stageRecord = userData.getStageTimeRecord(playData.currentStage)
	local tu = getTimeUnits(playData.totalTime)
	local timeString = string.format("%.2d:%.2d.%.3d", tu.minutes, tu.seconds, tu.milliseconds)

	local text = "CONGRATULATIONS!"
	if playData.livesUsed == 0 then
		text = "YOU'RE UNSTOPPABLE!"
	end
	font:drawTextAligned(text, xp, yp, kTextAlignment.center)

	yp = 50
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(50, yp - 4, 300, 28)
	gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
	text = string.format("CLEAR TIME: %s", timeString)
	fontSmall:drawTextAligned(text, xp, yp, kTextAlignment.center)

	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	fontSmall:drawTextAligned("Thanks for playing Pulse!\nI hope you enjoyed the game,\nand that your D-pad survived.", xp, 100, kTextAlignment.center)
	fontSmall:drawTextAligned("For more games, check mrflamey.itch.io", xp, 205, kTextAlignment.center)

	gfx.unlockFocus()
end