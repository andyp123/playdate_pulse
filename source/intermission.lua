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


function intermission.getTimeString(time, showMinutes)
	local minutes = math.floor(time / 60)
	local seconds = math.floor(time - (minutes * 60))
	local milliseconds = math.floor((time - math.floor(time)) * 1000)
	if showMinutes == true then
		return string.format("%.2d:%.2d.%.3d", minutes, seconds, milliseconds)
	else
		return string.format("%.2d.%.3d", seconds, milliseconds)
	end
end


function intermission.drawToImage(image, font, playData)
	image:clear(gfx.kColorWhite)
	gfx.lockFocus(image)

	local xp, yp = 200, 20
	local timeString = intermission.getTimeString(playData.totalTime, true)
	local text = string.format("STAGE %.2d\n\nTIME: %s", playData.currentStage, timeString)
	gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
	font:drawTextAligned(text, xp, yp, kTextAlignment.center)

	yp = 150
	local stageRecord = userData.getStageTimeRecord(playData.currentStage)
	local timeString = intermission.getTimeString(stageRecord.time, false)
	local text = string.format("Best Time\n%s  -  %s", stageRecord.name, timeString)
	font:drawTextAligned(text, xp, yp, kTextAlignment.center)

	gfx.unlockFocus()
end

