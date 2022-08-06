-- Playdate SDK
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"

-- Pulse
import "global"
import "stage" -- need constants from here
import "sound"

local gfx <const> = playdate.graphics

intermission = {}
intermission.__index = intermission


function intermission.getTimeString(time)
	local minutes = math.floor(time / 60)
	local seconds = math.floor(time - (minutes * 60))
	local milliseconds = math.floor((time - math.floor(time)) * 1000)
	return string.format("%.2d:%.2d.%.3d", minutes, seconds, milliseconds)
end


function intermission.drawToImage(image, font, playData)
	image:clear(gfx.kColorWhite)
	gfx.lockFocus(image)

	local totalTime = intermission.getTimeString(playData.totalTime)
	local text = string.format("STAGE %.2d\n\nTIME: %s", playData.currentStage, totalTime)
	local xp, yp = 200, 50
	gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
	font:drawTextAligned(text, xp, yp, kTextAlignment.center)

	gfx.unlockFocus()
end

