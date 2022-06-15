-- Playdate SDK
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"

-- Pulse
import "stage" -- need constants from here

local gfx <const> = playdate.graphics

levelSelect = {}
levelSelect.__index = levelSelect


-- draw selection cursor over the menu. Give simple version of player logic for selection
-- rerender only the selection sprite on selection change


function levelSelect.drawToImage(image, font)
	image:clear(gfx.kColorWhite)
	gfx.lockFocus(image)

	-- get constants from stage
	local numCells = stage.kNumCells
	local width, height, size = stage.kWidth, stage.kHeight, stage.kCellSize
	local xOffset, yOffset = stage.kScreenOffset + size // 2, stage.kScreenOffset + 10
	local tileImages = stage.tileImages

	local numStages = clamp(stage.getNumStages(), 0, numCells)

	gfx.setColor(gfx.kColorWhite)
	gfx.setLineWidth(4)
	gfx.setLineCapStyle(gfx.kLineCapStyleSquare)

	gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
	-- gfx.drawTextAligned("Press Ⓐ to begin\nⒷ for options", 200, 140, kTextAlignment.center)

	for i = 1, numStages + 1 do
		local x, y = i2xy0(i, width)
		local xp = x * size + xOffset
		local yp = y * size + yOffset
		-- tileImages:drawImage(1, xp, yp)
		local text = string.format("%d", i)
		if i > numStages then text = "+" end
		font:drawTextAligned(text, xp, yp, kTextAlignment.center)
	end

	gfx.unlockFocus()
end