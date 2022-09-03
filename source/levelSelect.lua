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

levelSelect = {}
levelSelect.__index = levelSelect

levelSelect.isEditorEnabled = false


function levelSelect.init()
	local size = stage.kCellSize
	local img = gfx.image.new(size, size, gfx.kColorWhite)
	local sprite = gfx.sprite.new(img)
	sprite:setImageDrawMode(gfx.kDrawModeXOR)
	sprite:moveTo(stage.kSpriteOffset, stage.kSpriteOffset)
	sprite:add()
	sprite:setZIndex(29010)
	sprite:setVisible(false)

	local cursor = {
		x = 1,
		y = 1,
		sprite = sprite
	}

	function cursor.updatePosition()
		local xpos = (cursor.x - 1) * stage.kCellSize + stage.kSpriteOffset
		local ypos = (cursor.y - 1) * stage.kCellSize + stage.kSpriteOffset
		sprite:moveTo(xpos, ypos)
	end

	levelSelect.cursor = cursor
	levelSelect.selectedIndex = 1
end

levelSelect.init()


function levelSelect.setCursorVisible(visible)
	levelSelect.cursor.sprite:setVisible(visible)
end


function levelSelect.update()
	local cursor = levelSelect.cursor
	local mx, my = 0, 0
	if playdate.buttonJustPressed(playdate.kButtonLeft)  then mx = -1 end
	if playdate.buttonJustPressed(playdate.kButtonRight) then mx = 1 end
	if playdate.buttonJustPressed(playdate.kButtonUp)    then my = -1 end
	if playdate.buttonJustPressed(playdate.kButtonDown)  then my = 1 end

	local width = stage.kWidth
	local maxStage = numCells
	if not editorEnabled then
		maxStage = math.floor(1.0 + userData.getActiveUserHighestStageCleared() / width) * width
		maxStage = clamp(maxStage, width, numCells)
	end

	-- testing a different cursor movement for menus
	if mx ~= 0 or my ~= 0 then
		local i = xy2i(cursor.x, cursor.y, width)
		local ni = i
		ni += mx
		ni += my * width
		ni = clamp(ni, 1, maxStage)
		if ni ~= i then
			local x, y = i2xy(ni, width)
			cursor.x = x
			cursor.y = y
			cursor.updatePosition()
			levelSelect.selectedIndex = ni
			sound.play("MENU_MOVE")
		else
			-- couldn't move cursor
		end
	end
end


function levelSelect.drawToImage(image, font)
	local editorEnabled = levelSelect.isEditorEnabled
	local bgColor = gfx.kColorBlack
	local fgColor = gfx.kDrawModeFillWhite
	if editorEnabled == true then
		bgColor = gfx.kColorWhite
		fgColor = gfx.kDrawModeFillBlack
	end

	image:clear(bgColor)
	gfx.lockFocus(image)

	-- get constants from stage
	local numCells = stage.kNumCells
	local width, height, size = stage.kWidth, stage.kHeight, stage.kCellSize
	local xOffset, yOffset = stage.kScreenOffset + size // 2 + 4, stage.kScreenOffset + 10
	local tileImages = stage.tileImages

	gfx.setImageDrawMode(fgColor)

	local isEmpty = levelSelect.isStageEmpty
	local maxStage = numCells
	if not editorEnabled then
		maxStage = math.floor(1.0 + userData.getActiveUserHighestStageCleared() / width) * width
		maxStage = clamp(maxStage, width, numCells)
	end

	for i = 1, numCells do
		local x, y = i2xy0(i, width)
		local xp = x * size + xOffset
		local yp = y * size + yOffset

		local text = "-"
		if i <= maxStage then
			text = string.format("%d", i)
			if editorEnabled and isEmpty(i) then
				text = "+"
			end
		end
		font:drawTextAligned(text, xp, yp, kTextAlignment.center)
	end

	gfx.unlockFocus()
end


-- Level is empty if all cells are same type
function levelSelect.isStageEmpty(stageIndex)
	if stageIndex >= 1 and stageIndex <= stage.getNumStages() then
		local stageData = stage.stageData
		local cells = stageData[stageIndex].cells
		local cellValue = cells[1]
		local cnt = stage.kNumCells

		for i = 2, cnt do
			if cells[i] ~= cellValue then
				return false
			end
		end

		return true
	end
end