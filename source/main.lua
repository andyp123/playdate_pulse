-- comment

import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
-- import "CoreLibs/save"

local gfx <const> = playdate.graphics

-- SPECS:
-- screen is 400x240
-- tiles are 40x40, but overlap when drawn to make them 32x32
-- sprites are 32x32, but a little smaller to fit in the tiles
-- the board/grid size is 12x7 (84 tiles)
-- 384x224

-- TODO:
-- load tiles
-- load sprites
-- draw a grid using the tiles
-- make the cursor use the + and - sprites for now
-- pressing A will toggle the tile between 0 and 1 (for now)

-- add save/load stage to menu
-- allow placing player start and items

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

-- GRID CELL TYPES
-- 0 : empty space
-- 1 : solid wall
-- 2 : start point
-- 3 : exit
-- 4 : locked door
-- 5 : key (opens locked door)
-- 6 : clock (adds 1 second extra time)

-- SPRITE FRAMES
-- 1 - player frame 1
-- 2 - player frame 2
-- 3 - exit door
-- 4 - locked door
-- 5 - add (editor)
-- 6 - subtract (editor)
-- 7 - clock
-- 8 - key

-- PLAYER SPRITES
-- EDITOR SPRITES
-- TILES
-- OVERLAYS
-- MENUS + ICONS
-- FONTS

local grid = nil
local stageFileName <const> = "stages"


-- STAGE ----------------------------------------------------------------------
local stage = {}
stage.width = 12
stage.height = 7
stage.cells = nil
stage.cellSize = 32 -- size in pixels
stage.time = 10 -- time in seconds

stage.actors = nil -- array of actors (items, start pos, exit etc.)


stage.init = function()
	stage.cells = playdate.datastore.read(stageFileName)
	if stage.cells == nil then
		print("Could not load file", stageFileName)
		stage.generateGrid()
	else
		print("Loaded data from file", stageFileName)
	end
end

-- populate actors based on cell values
-- 0: empty
-- 1: solid
-- start, exit, locked door, key, clock
stage.populate = function()

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

stage.saveData = function()
	print("Attempting to save grid to", stageFileName)
	playdate.datastore.write(stage.cells, stageFileName)
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

player.init = function()
	player.image1 = spriteTable:getImage(1)
	player.image2 = spriteTable:getImage(2)
	player.sprite = gfx.sprite.new(player.image1)
	player.sprite:moveTo(24, 24)
	player.sprite:add()
end

player.update = function()
	if playdate.buttonJustPressed(playdate.kButtonLeft) then
		player.tryMove("left")
	end
	if playdate.buttonJustPressed(playdate.kButtonRight) then
		player.tryMove("right")
	end
	if playdate.buttonJustPressed(playdate.kButtonUp) then
		player.tryMove("up")
	end
	if playdate.buttonJustPressed(playdate.kButtonDown) then
		player.tryMove("down")
	end
end

player.tryMove = function(direction)
	local tx = 0
	local ty = 0
	if direction == "left" then
		tx = -1
	elseif direction == "right" then
		tx = 1
	elseif direction == "up" then
		ty = -1
	else
		ty = 1
	end

	-- print(direction, tx, ty)

	-- edit mode movement
	if player.editMode then
		if stage.isValidCell(player.x + tx, player.y + ty) then
			player.x += tx
			player.y += ty
			player.sprite:moveBy(tx * stage.cellSize, ty * stage.cellSize)
		end

		return
	end

	-- regular movement
	if stage.isEmptyCell(player.x + tx, player.y + ty) then
		player.x += tx
		player.y += ty
		player.sprite:moveBy(tx * stage.cellSize, ty * stage.cellSize)
		if player.frame == 1 then
			player.frame = 2
			player.sprite:setImage(player.image2)
		else
			player.frame = 1
			player.sprite:setImage(player.image1)
		end
	end
end

player.toggleEditMode = function()
	player.editMode = not player.editMode
	if player.editMode then
		player.sprite:setImage(spriteTable:getImage(5))
	else
		player.frame = 1
		player.sprite:setImage(player.image1)
	end
end


local startTime = 0


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
	stage.init()
	player.init()

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

		tileTable:drawImage(idx+1, x*32+4, y*32+4)
	end

	gfx.unlockFocus()

end



-- main update loop
function playdate.update()
	local elapsedTime = playdate.getCurrentTimeMilliseconds() - startTime

	player.update()

	local px,py = player.sprite:getPosition()

	if playdate.buttonJustPressed(playdate.kButtonA) then
		if player.editMode then
			local x = player.x
			local y = player.y
			local i = (y-1) * stage.width + x
			-- print(x, y, " : ", i)
			stage.cells[i] = math.abs(stage.cells[i] - 1)
			generateGridImage(screenImage)
			gfx.sprite.redrawBackground()
			stage.saveData()

			-- test
			startTime = playdate.getCurrentTimeMilliseconds()
			print("time since last tile change:", elapsedTime/1000)
		end
	end

	if playdate.buttonJustPressed(playdate.kButtonB) then
		player.toggleEditMode()
		-- stage.generateGrid()
		-- generateGridImage(screenImage)
		-- gfx.sprite.redrawBackground()
	end

	-- draw all sprites and update timers
	gfx.sprite.update()
	playdate.timer.updateTimers()

	-- print time
	local timeLeft = 0
	local stageTime = stage.time * 1000
	if elapsedTime < stageTime then timeLeft = stageTime - elapsedTime end
	local timeString = string.format("TIME: *%.3f*", timeLeft/1000)

	-- seem to have issues if I do this before anything else...
	local currentDrawMode = gfx.getImageDrawMode()
	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	gfx.drawText(timeString, px+16, py-8)
	gfx.setImageDrawMode(currentDrawMode)
end




initGame()