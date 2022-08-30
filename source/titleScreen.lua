-- Playdate SDK
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"

-- Pulse
import "stage" -- need constants from here

local gfx <const> = playdate.graphics

titleScreen = {}
titleScreen.__index = titleScreen

-- logo characters (x, y positions exported from blender. each letter is 3x3)
-- offset should be 8 + multiple of 8
-- scale should be multiple of 8. 24 is good. scale y should be inverted
-- screen width: scale 24, offset per letter 80
-- drawLogo(200, 48, 72, 8, jitterScale, 4) <- this fits the logo perfectly across the top of the screen
local LOGO_P <const> = { 0, 0, 1, 0, 2, 0, 2.38, -0.0761, 2.71, -0.293, 2.92, -0.617, 3, -1, 2.92, -1.38, 2.71, -1.71, 2.38, -1.92, 2, -2, 1, -2, 1, -3, 0, -3, 0, -2, 0, -1 }
local LOGO_U <const>  = { 0, -1, 0, -2, 0.0761, -2.38, 0.293, -2.71, 0.617, -2.92, 1, -3, 2, -3, 2.38, -2.92, 2.71, -2.71, 2.92, -2.38, 3, -2, 3, -1, 3, 0, 2, 0, 2, -1, 2, -2, 1, -2, 1, -1, 1, 0, 0, 0 }
local LOGO_L <const>  = { 0, -1, 0, -2, 0, -3, 1, -3, 2, -3, 3, -3, 3, -2, 2, -2, 1, -2, 1, -1, 1, 0, 0, 0 }
local LOGO_S <const>  = { 1, -3, 2, -3, 2.38, -2.92, 2.71, -2.71, 2.92, -2.38, 3, -2, 2.92, -1.62, 2.71, -1.29, 2.38, -1.08, 2, -1, 1, -1, 2, -1, 3, -1, 3, 0, 2, 0, 1, 0, 0.617, -0.0761, 0.293, -0.293, 0.0761, -0.617, 0, -1, 0.0761, -1.38, 0.293, -1.71, 0.617, -1.92, 1, -2, 2, -2, 1, -2, 0, -2, 0, -3 }
local LOGO_E <const>  = { 0, 0, 1, 0, 2, 0, 3, 0, 3, -1, 2, -1, 1, -1, 2, -1, 2, -2, 1, -2, 2, -2, 3, -2, 3, -3, 2, -3, 1, -3, 0, -3, 0, -2, 0, -1 }


-- Logo drawing
function titleScreen.drawLineLoop(lineData, x, y, xScale, yScale, jitter, jitterScale)
	local jx, jy = jitter:get(jitterScale)
	local cnt = table.getsize(lineData)
	local p1x = x + jx + lineData[1] * xScale
	local p1y = y + jy + lineData[2] * yScale
	local sx, sy = p1x, p1y
	for i=3, cnt-1, 2 do
		jx, jy = jitter:get(jitterScale)
		local p2x = x + jx + lineData[i] * xScale
		local p2y = y + jy + lineData[i+1] * yScale
		gfx.drawLine(p1x, p1y, p2x, p2y)
		p1x, p1y = p2x, p2y
	end
	-- draw line back to start of loop
	gfx.drawLine(p1x, p1y, sx, sy)
end


function titleScreen.drawLogo(cx, cy, letterSize, letterSpacing, jitter, jitterScale)
	local sampleIndex = jitter.nextSampleIdx

	local drawLineLoop = titleScreen.drawLineLoop
	local letterScale = letterSize / 3
	local totalWidth = letterSize * 5 + letterSpacing * 4
	local x, y = cx - totalWidth * 0.5, cy - letterSize * 0.5

	drawLineLoop(LOGO_P, x, y, letterScale, -letterScale, jitter, jitterScale)
	x += letterSize + letterSpacing
	drawLineLoop(LOGO_U, x, y, letterScale, -letterScale, jitter, jitterScale)
	x += letterSize + letterSpacing
	drawLineLoop(LOGO_L, x, y, letterScale, -letterScale, jitter, jitterScale)
	x += letterSize + letterSpacing
	drawLineLoop(LOGO_S, x, y, letterScale, -letterScale, jitter, jitterScale)
	x += letterSize + letterSpacing
	drawLineLoop(LOGO_E, x, y, letterScale, -letterScale, jitter, jitterScale)

	-- Make sure to reset the sample index for the next frame!
	jitter.nextSampleIdx = sampleIndex
end


function titleScreen.drawToImage(image, jitter, jitterScale)
	image:clear(gfx.kColorBlack)
	gfx.lockFocus(image)

	-- get constants from stage
	local numCells = stage.kNumCells
	local width, height = stage.kWidth, stage.kHeight
	local size, offset = stage.kCellSize, stage.kScreenOffset
	local tileImages = stage.tileImages

	gfx.setColor(gfx.kColorWhite)
	gfx.setLineWidth(4)
	gfx.setLineCapStyle(gfx.kLineCapStyleRound)
	-- cx, cy, letterSize, letterSpacing, jitterScale, lineWidth
	-- titleScreen.drawLogo(200, 48, 72, 8, jitter, jitterScale)
	titleScreen.drawLogo(200, 48, 68, 8, jitter, jitterScale)

	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	gfx.drawTextAligned("Press Ⓐ to begin\nⒷ for menu", 200, 130, kTextAlignment.center)

	gfx.unlockFocus()
end