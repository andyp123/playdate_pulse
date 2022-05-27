-- comment

import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/crank"

local gfx <const> = playdate.graphics
local snd <const> = playdate.sound

-- SPECS:
-- screen is 400x240
-- tiles are 40x40, but overlap when drawn to make them 32x32
-- sprites are 32x32, but a little smaller to fit in the tiles
-- the board/grid size is 12x7 (84 tiles)
-- 384x224

-- NOTES:
-- arrays in LUA are 1 indexed...
-- init variables with local. Without local the variable will be added to global scope
-- use . to call a function, but : to call a function on an object

-- playdate.graphics.drawRect(x, y, w, h)
-- playdate.graphics.fillRect(x, y, w, h)
-- playdate.graphics.setLineWidth(width)
-- playdate.graphics.setStrokeLocation(location)
-- playdate.graphics.kStrokeCentered, kStrokeOutside, kStrokeInside

-- Can draw offscreen (i.e. for the stage)
-- playdate.graphics.lockFocus(image)
-- playdate.graphics.unlockFocus()
-- lockFocus will route all graphics drawing to the image until unlockFocus is called

-- math library is lua
-- math.random() -> 0.0->1.0
-- math.random(6) -> int from 1-6

-- SPRITE FRAMES
-- 1 - add (editor)
-- 2 - subtract (editor)
-- 3 - entrance
-- 4 - exit
-- 5 - locked door
-- 6 - key
-- 7 - clock
-- 13 - player frame 1
-- 14 - player frame 2

-- PLAYER SPRITES
-- EDITOR SPRITES
-- TILES
-- OVERLAYS
-- MENUS + ICONS
-- FONTS

local stageFileName <const> = "stages"

local EMPTY <const> = 0
local SOLID <const> = 1

local EDIT_ADD <const> = 1
local EDIT_SUB <const> = 2
local ENTRANCE <const> = 3
local EXIT <const> = 4
local LOCK <const> = 5
local KEY <const> = 6
local CLOCK <const> = 7

local EDIT_MAX <const> = CLOCK

local spriteOffsetX <const> = 24
local spriteOffsetY <const> = 24
local cellSize <const> = 32


local startTime = 0


local sfx = {}
sfx.init = function()
	sfx.MOVE = snd.sampleplayer.new("sounds/move")
	sfx.MOVE_FAIL = snd.sampleplayer.new("sounds/move_fail")
	sfx.GET_KEY = snd.sampleplayer.new("sounds/get_key")
	sfx.GET_CLOCK = snd.sampleplayer.new("sounds/get_clock")
	sfx.USE_KEY = snd.sampleplayer.new("sounds/use_key")
	sfx.STAGE_CLEAR = snd.sampleplayer.new("sounds/stage_clear")
end


-- current (loaded) stage
-- - only current stage contains actors table
-- stages
-- stage groups
-- user stages

local player = {}

-- STAGE ----------------------------------------------------------------------
local stage = {}
stage.width = 12
stage.height = 7
stage.cells = nil
stage.time = 10 -- time in seconds

stage.actors = nil -- array of actors (items, start pos, exit etc.)


stage.init = function()
	stage.loadData()
end


stage.loadData = function()
	stage.cells = nil
	stage.cells = playdate.datastore.read(stageFileName)

	if stage.cells == nil then
		print("Could not load file", stageFileName)
		stage.generateGrid()
	else
		print("Loaded data from file", stageFileName)
	end

	stage.actors = {}
	stage.populate()
end


stage.saveData = function()
	print("Attempting to save grid to", stageFileName)
	playdate.datastore.write(stage.cells, stageFileName)
end


stage.reload = function()
	print("Reloading stage")
	stage.loadData()
end


-- populate actors based on cell values
stage.populate = function()
	local cells = stage.cells
	local actors = stage.actors
	local cnt = stage.width * stage.height
	for i=1, cnt, 1 do
		local cellValue = cells[i]
		local sprite = actors[i]

		if cellValue > EDIT_SUB and cellValue <= EDIT_MAX then
			if sprite ~= nil then
				sprite:setImage(spriteTable:getImage(cellValue))
				sprite:add()
			else
				local x = i % stage.width - 1
				local y = (i - x - 1) / stage.width
				sprite = gfx.sprite.new(spriteTable:getImage(cellValue))
				sprite:moveTo(x * cellSize + spriteOffsetX, y * cellSize + spriteOffsetY)
				sprite:add()
				actors[i] = sprite
			end
		elseif sprite ~= nil then
			sprite:remove()
		end
	end
end


stage.refreshCell = function(i)
	local cellValue = stage.cells[i]
	local sprite = stage.actors[i]

	if cellValue > EDIT_SUB and cellValue <= EDIT_MAX then
		if sprite ~= nil then
			sprite:setImage(spriteTable:getImage(cellValue))
			sprite:add()
		else
			local x = i % stage.width - 1
			local y = math.floor((i - x - 1) / stage.width)
			sprite = gfx.sprite.new(spriteTable:getImage(cellValue))
			sprite:moveTo(x * cellSize + spriteOffsetX, y * cellSize + spriteOffsetY)
			sprite:add()
			stage.actors[i] = sprite
		end
	elseif sprite ~= nil then
		sprite:remove()
	end
end


stage.isEmptyCell = function(x, y)
	if x < 1 or x > stage.width or y < 1 or y > stage.height then
		return false
	end

	local i = (y - 1) * stage.width + x
	return stage.cells[i] ~= 1
end


stage.isValidCell = function(x, y)
	if x < 1 or x > stage.width or y < 1 or y > stage.height then
		return false
	end
	return true
end


stage.editCell = function(x, y, toolId)
	if stage.isValidCell(x, y) then
		local i = (y-1) * stage.width + x

		local cells = stage.cells
		local cellValue = cells[i]

		if toolId == EDIT_ADD or toolId == EDIT_SUB then
			if cellValue == 0 then cells[i] = 1 else cells[i] = 0 end
		else
			cells[i] = 0
			if cellValue ~= toolId then
				cells[i] = toolId
			end
		end
		-- refresh the cell actor/sprite
		stage.refreshCell(i)
	else
		-- shouldn't happen, but just in case
		print("ERROR: Invalid cell %d, %d", x, y)
	end
end


stage.generateGrid = function()
	if stage.cells == nil then
		stage.cells = {}
	end
	local cells = stage.cells
	local cnt = stage.width * stage.height
	for i=1, cnt, 1 do
		cells[i] = math.random(2)-1
	end
end


stage.findCellOfType = function(typeId)
	local cells = stage.cells
	local cnt = stage.width * stage.height
	for i=1, cnt, 1 do
		if cells[i] == typeId then
			return i
		end
	end

	return -1
end


-- calculation requires 0 to n-1 indexing
-- return value is 1 to n
stage.indexToXY = function(i)
	local x = i % stage.width
	local y = math.floor((i - x) / stage.width) + 1
	return x, y
end


-- PLAYER ---------------------------------------------------------------------
local player = {}
player.sprite = nil
player.image1 = nil
player.image2 = nil
player.frame = 1 -- 1 or 2
player.x = 1
player.y = 1
player.editMode = false
player.editModeTool = EDIT_ADD
player.keyItems = 0


player.init = function()
	player.image1 = spriteTable:getImage(13)
	player.image2 = spriteTable:getImage(14)
	player.sprite = gfx.sprite.new(player.image1)
	player.sprite:moveTo(spriteOffsetX, spriteOffsetY)
	player.sprite:add()
	player.updateEditModeTool()
end


player.update = function()
	-- movement
	local mx, my = 0, 0
	if playdate.buttonJustPressed(playdate.kButtonLeft) then
		mx = -1
	elseif playdate.buttonJustPressed(playdate.kButtonRight) then
		mx = 1
	end
	if playdate.buttonJustPressed(playdate.kButtonUp) then
		my = -1
	elseif playdate.buttonJustPressed(playdate.kButtonDown) then
		my = 1
	end
	if mx ~= 0 or my ~= 0 then
		player.tryMove(mx, my)
	end

	-- crank
	local crankChange = playdate.getCrankChange()
	if crankChange ~= 0 then
		player.updateEditModeTool()
	end

	if playdate.buttonJustPressed(playdate.kButtonA) then
		if player.editMode then
			stage.editCell(player.x, player.y, player.editModeTool)
			generateGridImage(screenImage)
			gfx.sprite.redrawBackground()
			stage.saveData()
		end
	end
end


player.updateEditModeTool = function()
	local crankPos = playdate.getCrankPosition()
	local segmentSize = 360 / EDIT_MAX
	local adjustedPos = (crankPos + segmentSize * 0.5) % 360
	local toolId = math.floor(adjustedPos / segmentSize) + 1
	player.editModeTool = toolId

	if player.editMode then
		player.sprite:setImage(spriteTable:getImage(toolId))
	end
end


-- more of a teleport than for moving by one square
-- useful for postioning the player when the game starts
player.moveTo = function(x, y)
	player.x = x
	player.y = y
	player.sprite:moveTo((x-1) * cellSize + spriteOffsetX, (y-1) * cellSize + spriteOffsetY)
	player.sprite:setImage(player.image1)
end


player.tryMove = function(tx, ty)
	-- return on trying to move to an invalid (edge) cell
	if stage.isValidCell(player.x + tx, player.y + ty) == false then
		if player.editMode == false then
			sfx.MOVE_FAIL:play()
		end
		return
	end

	-- edit mode movement
	if player.editMode then
		player.x += tx
		player.y += ty
		player.sprite:moveBy(tx * cellSize, ty * cellSize)
		return
	end

	-- regular movement
	local i = (player.y + ty - 1) * stage.width + player.x + tx
	if player.tryMoveAndCollect(i) then
		player.x += tx
		player.y += ty
		player.sprite:moveBy(tx * cellSize, ty * cellSize)

		if player.keyItems > 0 then
			player.sprite:setImage(spriteTable:getImage(KEY))
		else
			if player.frame == 1 then
				player.frame = 2
				player.sprite:setImage(player.image2)
			else
				player.frame = 1
				player.sprite:setImage(player.image1)
			end
		end
	end
end


player.moveToStart = function()
	local cellIndex = stage.findCellOfType(ENTRANCE)
	if cellIndex > 0 then
		local x, y = stage.indexToXY(cellIndex)
		player.moveTo(x, y)
	end
end


player.tryMoveAndCollect = function(i)
	local typeId = stage.cells[i]

	if typeId == SOLID then
		sfx.MOVE_FAIL:play()
		return false
	elseif typeId == CLOCK then
		stage.cells[i] = 0
		stage.refreshCell(i)
		sfx.GET_CLOCK:play()
		return true
	elseif typeId == KEY then
		player.keyItems += 1
		stage.cells[i] = 0
		stage.refreshCell(i)
		sfx.GET_KEY:play()
		return true
	elseif typeId == LOCK then
		if player.keyItems > 0 then
			player.keyItems -= 1
			stage.cells[i] = 0
			stage.refreshCell(i)
			sfx.USE_KEY:play()
			return true
		end
		sfx.MOVE_FAIL:play()		
		return false
	elseif typeId == EXIT then
		sfx.STAGE_CLEAR:play()
		return true
	end

	-- can move to any other cell type
	sfx.MOVE:play()
	return true
end

player.toggleEditMode = function()
	player.editMode = not player.editMode
	player.setEditMode(player.editMode)
end

player.setEditMode = function(value)
	if player.editMode == value then
		return
	end

	player.editMode = value
	if player.editMode then
		player.sprite:setImage(spriteTable:getImage(player.editModeTool))
	else
		player.frame = 1
		player.sprite:setImage(player.image1)
	end

	stage.reload()
end


-- GAME -----------------------------------------------------------------------
function initGame()
	-- clear screen to black and set sprite alpha to clear
	gfx.clear(gfx.kColorBlack)
	gfx.setBackgroundColor(gfx.kColorClear)

	-- global image tables
	spriteTable = gfx.imagetable.new("images/sprites")
	tileTable = gfx.imagetable.new("images/tiles")
	assert(spriteTable)
	assert(tileTable)

	-- initialize main objects
	sfx.init()
	player.init()
	stage.init()

	player.moveToStart()

	-- add menu option
	local menu = playdate.getSystemMenu()
	local editModeToggle, error = menu:addCheckmarkMenuItem("Edit Mode", false, function(value)
		player.setEditMode(value)
		if not value then
			player.moveToStart()
		end
	end)

	-- set up background
	screenImage = gfx.image.new(400, 240, gfx.kColorBlack)
	generateGridImage(screenImage)

	-- this callback only redraws parts of the screen it needs to,
	-- such as when a sprite moves in front of the bg. Must manually
	-- redraw the background if updating image
	-- gfx.sprite.redrawBackground()
	gfx.sprite.setBackgroundDrawingCallback(
		function(x, y, width, height)
			gfx.setClipRect(x, y, width, height)
			screenImage:draw(0, 0)
			gfx.clearClipRect()
		end
	)

end



function generateGridImage(image)
	local filledTile = tileTable:getImage(1)
	image:clear(gfx.kColorBlack)

	gfx.lockFocus(image)

	local cells = stage.cells
	local width = stage.width
	local height = stage.height
	local cnt = width * height

	for i=1, cnt do
		local y = math.floor((i-1) / width)
		local x = i - (width * y) - 1

		local idx = 0

		if cells[i] ~= 1 then
			-- calculate the frame index
			-- t,r,b,l order (t=1, r=2, b=4, l=8)
			local t,r,b,l = 0,0,0,0
			if y == 0 or cells[i-width] == 1 then t = 1 end
			if x == width-1 or cells[i+1] == 1 then r = 2 end
			if y == height-1 or cells[i+width] == 1 then b = 4 end
			if x == 0 or cells[i-1] == 1 then l = 8 end
			idx = t + r + b + l
			if idx == 0 then idx = -1 end
		end

		tileTable:drawImage(idx + 1, x * cellSize + 4, y * cellSize + 4)
	end

	gfx.unlockFocus()
end



-- main update loop
function playdate.update()
	local elapsedTime = playdate.getCurrentTimeMilliseconds() - startTime

	player.update()

	-- draw all sprites and update timers
	gfx.sprite.update()
	playdate.timer.updateTimers()

	if player.editMode == false then
		-- print time
		local timeLeft = 0
		local stageTime = stage.time * 1000
		if elapsedTime < stageTime then
			timeLeft = stageTime - elapsedTime
		end

		local timeString = string.format("TIME: *%.3f*", timeLeft/1000)

		-- seem to have issues if I do this before anything else...
		local px,py = player.sprite:getPosition()
		local currentDrawMode = gfx.getImageDrawMode()
		gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
		gfx.drawText(timeString, px+16, py-8)
		gfx.setImageDrawMode(currentDrawMode)
	end
end




initGame()