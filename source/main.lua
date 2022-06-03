import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/crank"

-- TODO:
-- move input from player to main loop
-- move edit state from player to game
-- move jittered edges to foreground and draw each frame?
-- input to player only during game and editor states
-- title screen with jittering letter logo
-- more efficient duplication of stage data on save/load (don't create new tables)
-- game over state
-- game clear state
-- level select menu
-- user stage editing
-- stage editor menu
-- 12 stages to start with
-- think about modifications to gameplay... (5-7 modes?)
-- - default controls (go as fast as possible)
-- - randomised initial state controls
-- - dark mode (stage only visible during pulse)
-- - crank forward controls
-- - no way back (blocks previously occupied are filled)
-- polish

local gfx <const> = playdate.graphics
local snd <const> = playdate.sound

-- global constants
local STAGE_WIDTH <const> = 12
local STAGE_HEIGHT <const> = 7
local STAGE_NUM_CELLS <const> = STAGE_WIDTH * STAGE_HEIGHT
-- size/spacing of grid cells in pixels, offset of stage
local STAGE_CELLSIZE <const> = 32
local STAGE_OFFSET <const> = 4
local SPRITE_OFFSET <const> = 24

-- state
local STATE_TITLE <const> = 1
local STATE_STAGE_WAIT <const> = 2
local STATE_STAGE_PLAY <const> = 3
local STATE_STAGE_CLEAR <const> = 4
local STATE_STAGE_FAIL <const> = 5
local STATE_GAME_CLEAR <const> = 6

-- tools / sprites
local TYPE_EMPTY <const> = 0
local TYPE_SOLID <const> = 1
local TYPE_START <const> = 2
local TYPE_EXIT <const> = 3
local TYPE_DOOR <const> = 4
local TYPE_KEY <const> = 5
local TYPE_CLOCK <const> = 6

-- images
local tileTable = gfx.imagetable.new("images/tiles")
local spriteTable = gfx.imagetable.new("images/sprites")
local stageImage = gfx.image.new(400, 240, gfx.kColorBlack)

-- sounds
SFX_MOVE = snd.sampleplayer.new("sounds/move")
SFX_MOVE_FAIL = snd.sampleplayer.new("sounds/move_fail")
SFX_GET_KEY = snd.sampleplayer.new("sounds/get_key")
SFX_GET_CLOCK = snd.sampleplayer.new("sounds/get_clock")
SFX_USE_KEY = snd.sampleplayer.new("sounds/use_key")
SFX_STAGE_CLEAR = snd.sampleplayer.new("sounds/stage_clear")
SFX_TIME_TICK = snd.sampleplayer.new("sounds/time_tick")
SFX_TIME_OVER = snd.sampleplayer.new("sounds/time_over")
SFX_CONGRATULATIONS = snd.sampleplayer.new("sounds/congratulations")

-- filenames
local gameStageFileName <const> = "data/gamestages"
local userStageFileName <const> = "data/userstages"

-- all loaded stagess will be stored in this table
local stageData = {}
local currentStageId = 1

-- time
local START_TIME_MS <const> = playdate.getCurrentTimeMilliseconds() - 33
-- updated in playdate update
local LAST_TIME_MS = START_TIME_MS
local deltaTimeSeconds = 1 / playdate.display.getRefreshRate()


-- helper functions
function i2xy(i)
	i -= 1
	local x = i % STAGE_WIDTH
	local y = math.floor((i - x) / STAGE_WIDTH)
	return x + 1, y + 1
end


function i2xy0(i)
	i -= 1
	local x = i % STAGE_WIDTH
	local y = math.floor((i - x) / STAGE_WIDTH)
	return x, y
end


function xy2i(x, y)
	local i = (y - 1) * STAGE_WIDTH + x
	return i
end


function isValidIndex(x, y)
	if x < 1 or x > STAGE_WIDTH or y < 1 or y > STAGE_HEIGHT then
		return false
	end
	return true
end


function clamp(value, min, max)
	if value < min then return min end
	if max ~= nil and value > max then return max end
	return value
end



-- saving and loadings stage data
function loadStagesFromFile(filename)
	local data = playdate.datastore.read(filename)

	if data == nil then
		print(string.format("Error: Could not load '%s'", filename))
	else
		local cnt = table.getsize(data)
		print(string.format("Loaded %d stages from '%s'", cnt, filename))
		stageData = data
	end
end


function saveStagesToFile(filename)
	local cnt = table.getsize(stageData)
	print(string.format("Saving %d stages to '%s'", cnt, filename))
	playdate.datastore.write(stageData, filename)
end


-- getting and setting stage data
-- note that using stage:setData and stage:getData will
-- already deep copy the data, so no need to do so here
function getStageData(i)
	local data = stageData[i]
	if data == nil then
		print(string.format("Error: No stage data at index '%d'", i))
	end
	return data
end


function setStageData(i, data)
	stageData[i] = data
end



-------------------------------------------------------------------------------
-- JITTER ---------------------------------------------------------------------
-------------------------------------------------------------------------------
local jitter = {}
function jitter:init(numSamples)
	self.numSamples = numSamples
	self.nextSampleIdx = 1
	self.values = table.create(numSamples * 2, 0)
	for i = 1, numSamples * 2 do
		local angle = math.random() * math.pi * 2
		local x, y = math.sin(angle), math.cos(angle)
		self.values[2*i-1] = x
		self.values[2*i] = y
		-- print(string.format("%d| %.1f: (%.3f, %.3f)", i, angle * 360/(2*math.pi), x, y))
	end
end


function jitter:getAt(i)
	return self.values[2*i-1], self.values[2*i]
end


function jitter:getAtScaled(i, scale)
	return self.values[2*i-1] * scale, self.values[2*i] * scale
end


function jitter:get()
	print(self.nextSampleIdx)
	local i = self.nextSampleIdx * 2
	if self.nextSampleIdx == self.numSamples then
		self.nextSampleIdx = 1
	else
		self.nextSampleIdx += 1
	end
	return self.values[i-1], self.values[i]
end

jitter:init((STAGE_WIDTH+1) * (STAGE_HEIGHT+1))


-------------------------------------------------------------------------------
-- GAME -----------------------------------------------------------------------
-------------------------------------------------------------------------------
local game = {}
game.currentState = STATE_STAGE_PLAY
game.inProgress = true
game.startTimeMS = playdate.getCurrentTimeMilliseconds()
game.timeRemaining = 10

function game:addTime(seconds)
	self.timeRemaining += seconds
end


-------------------------------------------------------------------------------
-- STAGE ----------------------------------------------------------------------
-------------------------------------------------------------------------------
local stage = {}
stage.time = 10
stage.cells = table.create(STAGE_NUM_CELLS, 0)
stage.actors = {}


-- need to run this function on startup to initialize data
function stage:clear()
	self.time = 10
	for i = 1, STAGE_NUM_CELLS do
		self.cells[i] = 1
	end
	self:updateActors()
end


function stage:setData(data)
	if data ~= nil then
		self.time = data.time
		for i = 1, STAGE_NUM_CELLS do
			self.cells[i] = data.cells[i]
		end
		self:updateActors()
	end
end


function stage:getData()
	local data = {}
	data.time = self.time
	data.cells = table.create(STAGE_NUM_CELLS, 0)
	for i = 1, STAGE_NUM_CELLS do
		data.cells[i] = self.cells[i]
	end
	return data
end


-- unused simple version without jitter etc.
function stage:drawToImage_IMG(image)
	image:clear(gfx.kColorBlack)
	gfx.lockFocus(image)

	local cells = self.cells
	local width, height = STAGE_WIDTH, STAGE_HEIGHT
	local size, offset = STAGE_CELLSIZE, STAGE_OFFSET

	for i = 1, STAGE_NUM_CELLS do
		local y = math.floor((i-1) / STAGE_WIDTH)
		local x = i - (STAGE_WIDTH * y) - 1
		local idx = 0

		if cells[i] ~= 1 then
			-- calculate the tile index
			-- t, r, b, l order (t=1, r=2, b=4, l=8)
			local t, r, b, l = 0, 0, 0, 0
			if y == 0 or cells[i-width] == 1 then t = 1 end
			if x == width - 1 or cells[i+1] == 1 then r = 2 end
			if y == height - 1 or cells[i+width] == 1 then b = 4 end
			if x == 0 or cells[i-1] == 1 then l = 8 end
			idx = t + r + b + l
			if idx == 0 then idx = -1 end
		end
		tileTable:drawImage(idx + 1, x * size + offset, y * size + offset)
	end

	gfx.unlockFocus()
end


function stage:drawToImage(image, jitterScale)
	image:clear(gfx.kColorBlack)
	gfx.lockFocus(image)

	local cells = self.cells
	local width, height = STAGE_WIDTH, STAGE_HEIGHT
	local size, offset = STAGE_CELLSIZE, STAGE_OFFSET

	gfx.setColor(gfx.kColorWhite)
	gfx.setLineWidth(4)
	gfx.setLineCapStyle(gfx.kLineCapStyleSquare) --kLineCapStyleRound)

	for i = 1, STAGE_NUM_CELLS do
		local y = math.floor((i-1) / STAGE_WIDTH)
		local x = i - (STAGE_WIDTH * y) - 1
		local xp = x * size + offset
		local yp = y * size + offset

		-- jitter for each corner x and y
		local jitterScale = jitterScale or 0
		local tlx, tly = jitter:getAtScaled(i, jitterScale)
		local trx, try = jitter:getAtScaled(i+1, jitterScale)
		local blx, bly = jitter:getAtScaled(i+STAGE_WIDTH, jitterScale)
		local brx, bry = jitter:getAtScaled(i+STAGE_WIDTH+1, jitterScale)

		if cells[i] == 1 then
			tileTable:drawImage(1, xp, yp)
		else
			-- calculate the tile edges
			-- t, r, b, l order
			xp += 4
			yp += 4
			if y == 0 or cells[i-width] == 1 then
				-- top
				gfx.drawLine(xp+tlx, yp+tly, xp+trx + size, yp+try)
			end
			if x == width - 1 or cells[i+1] == 1 then
				-- right
				gfx.drawLine(xp+trx + size, yp+try, xp+brx + size, yp+bry + size)
			end
			if y == height - 1 or cells[i+width] == 1 then
				-- bottom
				gfx.drawLine(xp+blx, yp+bly + size, xp+brx + size, yp+bry + size)
			end
			if x == 0 or cells[i-1] == 1 then
				-- left
				gfx.drawLine(xp+tlx, yp+tly, xp+blx, yp+bly + size)
			end
		end
	end

	gfx.unlockFocus()
end


function stage:findCellOfType(typeId, start)
	start = start or 1
	if start > 0 and start <= STAGE_NUM_CELLS then
		local cells = self.cells
		for i = start, STAGE_NUM_CELLS do
			if cells[i] == typeId then
				return i
			end
		end
	end
	return 0
end


function stage:editCell(x, y, typeId)
	local i = xy2i(x, y)
	local cells = self.cells
	local prevId = cells[i]

	-- does the edit modify the stage cells?
	if typeId == TYPE_SOLID or prevId == TYPE_SOLID then
		if typeId == TYPE_SOLID then
			if prevId ~= TYPE_EMPTY then
				cells[i] = TYPE_EMPTY
			else
				cells[i] = TYPE_SOLID
			end
		else -- place item on solid cell
			cells[i] = typeId
		end

		self:drawToImage(stageImage)
		xpos = (x - 1) * STAGE_CELLSIZE
		ypos = (y - 1) * STAGE_CELLSIZE
		local size = STAGE_CELLSIZE + STAGE_OFFSET * 4
		gfx.sprite.addDirtyRect(xpos, ypos, size, size)
	else
		if typeId == prevId then
			cells[i] = TYPE_EMPTY
		else
			cells[i] = typeId
		end
	end

	self:updateActors(i, i)
end


-- populate/update actors based on cell values
function stage:updateActors(first, last)
	-- enables single cell update
	if first == nil then first = 1 end
	if last == nil then last = STAGE_NUM_CELLS end

	local cells = self.cells
	local actors = self.actors
	for i = first, last do
		local cellValue = cells[i]
		local sprite = actors[i]

		if cellValue > TYPE_SOLID and cellValue <= TYPE_CLOCK then
			if sprite ~= nil then
				sprite:setImage(spriteTable:getImage(cellValue))
				sprite:add()
			else
				local xpos, ypos = i2xy(i)
				xpos = (xpos - 1) * STAGE_CELLSIZE + SPRITE_OFFSET
				ypos = (ypos - 1) * STAGE_CELLSIZE + SPRITE_OFFSET
				sprite = gfx.sprite.new(spriteTable:getImage(cellValue))
				sprite:moveTo(xpos, ypos)
				sprite:add()
				actors[i] = sprite
			end
		elseif sprite ~= nil then
			sprite:remove()
		end
	end
end



-------------------------------------------------------------------------------
-- PLAYER ---------------------------------------------------------------------
-------------------------------------------------------------------------------
local player = {}
player.x = 1
player.y = 1
player.keys = 0
player.frame = 1
player.image1 = nil
player.image2 = nil
player.sprite = nil
player.editmodeEnabled = false
player.editmodeTypeId = TYPE_SOLID

function player:init()
	self.image1 = spriteTable:getImage(13)
	self.image2 = spriteTable:getImage(14)
	self.sprite = gfx.sprite.new(self.image1)
	self.sprite:moveTo(SPRITE_OFFSET, SPRITE_OFFSET)
	self.sprite:add()
	self.sprite:setZIndex(32000)
end


function player:moveTo(x, y)
	if isValidIndex(x, y) then
		self.x = x
		self.y = y
		local posx = (x - 1) * STAGE_CELLSIZE + SPRITE_OFFSET
		local posy = (y - 1) * STAGE_CELLSIZE + SPRITE_OFFSET
		self.sprite:moveTo(posx, posy)
	end
end

function player:update()
	-- movement
	local mx, my = 0, 0
	if playdate.buttonJustPressed(playdate.kButtonLeft)  then mx = -1 end
	if playdate.buttonJustPressed(playdate.kButtonRight) then mx = 1 end
	if playdate.buttonJustPressed(playdate.kButtonUp)    then my = -1 end
	if playdate.buttonJustPressed(playdate.kButtonDown)  then my = 1 end
	if mx ~= 0 or my ~= 0 then
		if self.editmodeEnabled then
			self:tryMoveEditMode(mx, my)
		else
			self:tryMove(mx, my)
		end
	end

	if self.editmodeEnabled then
		if playdate.buttonJustPressed(playdate.kButtonA) then
			stage:editCell(self.x, self.y, self.editmodeTypeId)
		end

		if playdate.buttonJustPressed(playdate.kButtonB) then
			saveStage(currentStageId)
		end

		local crankChange = playdate.getCrankChange()
		if crankChange ~= 0 then
			self:updateEditModeType()
		end
	end
end

function player:updateEditModeType()
	local crankPos = playdate.getCrankPosition()
	local segmentSize = 360 / TYPE_CLOCK
	local adjustedPos = (crankPos + segmentSize * 0.5) % 360
	local typeId = math.floor(adjustedPos / segmentSize) + 1
	self.editmodeTypeId = typeId
	if self.editmodeEnabled then self:updateSpriteImage() end
end

function player:updateSpriteImage()
	if self.editmodeEnabled then
		self.sprite:setImage(spriteTable:getImage(self.editmodeTypeId))
	else
		if self.keys > 0 then
			self.sprite:setImage(spriteTable:getImage(TYPE_KEY))
		else
			self.frame = math.abs(self.frame - 1)
			if self.frame == 1 then self.sprite:setImage(self.image1)
			else self.sprite:setImage(self.image2) end
		end
	end
end


function player:tryMoveEditMode(mx, my)
	if isValidIndex(self.x + mx, self.y + my) then
		self.x += mx
		self.y += my
		self.sprite:moveBy(mx * STAGE_CELLSIZE, my * STAGE_CELLSIZE)
	end
end


function player:tryMove(mx, my)
	local x, y = self.x + mx, self.y + my
	if self:tryMoveAndCollect(x, y) then
		self.x = x
		self.y = y
		self.sprite:moveBy(mx * STAGE_CELLSIZE, my * STAGE_CELLSIZE)
		self:updateSpriteImage()
	end
end

function player:tryMoveAndCollect(x, y)
	if isValidIndex(x, y) then
		local i = xy2i(x, y)
		local typeId = stage.cells[i]

		if typeId == TYPE_SOLID then
			SFX_MOVE_FAIL:play()
			return false
		elseif typeId == TYPE_DOOR then
			if self.keys > 0 then
				self.keys -= 1
				stage:editCell(x, y, TYPE_EMPTY)
				SFX_USE_KEY:play()
				return true
			else
				SFX_MOVE_FAIL:play()
				return false
			end
		elseif typeId == TYPE_KEY then
			self.keys += 1
			stage:editCell(x, y, TYPE_EMPTY)
			SFX_GET_KEY:play()
			return true
		elseif typeId == TYPE_CLOCK then
			game:addTime(2)
			stage:editCell(x, y, TYPE_EMPTY)
			SFX_GET_CLOCK:play()
			return true
		elseif typeId == TYPE_EXIT then
			game.inProgress = false
			SFX_STAGE_CLEAR:play()
			return true
		end

		-- empty or undefined
		SFX_MOVE:play()
		return true
	end
	
	SFX_MOVE_FAIL:play()
	return false
end



-------------------------------------------------------------------------------
-- MAIN -----------------------------------------------------------------------
-------------------------------------------------------------------------------
function game:update()
	local prevTime = self.timeRemaining

	if self.inProgress then
		self.timeRemaining = clamp(self.timeRemaining - deltaTimeSeconds, 0)
	end

	if prevTime > 0 and self.timeRemaining == 0 then
		SFX_TIME_OVER:play()
		self.inProgress = false
	elseif self.timeRemaining  then
		if math.floor(prevTime) > math.floor(self.timeRemaining) then
			SFX_TIME_TICK:play()
		end
		local t = self.timeRemaining % 1
		local s = self.timeRemaining - t
		local tlim = 0.5
		jitterScale = math.pow(clamp(t - tlim, 0, 1) * (1/tlim), 3) * clamp(8 - s, 1, 8)
		if t >= tlim then
			stage:drawToImage(stageImage, jitterScale)
			gfx.sprite.redrawBackground()
		end
	end

	player:update()

	-- draw all sprites and update timers
	gfx.sprite.update()
	playdate.timer.updateTimers()

	local timeString = string.format("TIME: *%.3f*", self.timeRemaining)

	-- seem to have issues if I do this before anything else...
	local px,py = player.sprite:getPosition()
	local currentDrawMode = gfx.getImageDrawMode()
	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	gfx.drawText(timeString, px+16, py-8)
	gfx.setImageDrawMode(currentDrawMode)
end


function playdate.update()
	game:update()
end


-- call with currentStageId to reload the current stage
function loadStage(stageId)
	local numStages = table.getsize(stageData)
	if stageId > 0 and stageId <= numStages then
		currentStageId = stageId
		stage:setData(getStageData(stageId))
		stage:drawToImage(stageImage)
		gfx.sprite.redrawBackground()

		local i = stage:findCellOfType(TYPE_START)
		if i > 0 then
			local x, y = i2xy(i)
			player:moveTo(x, y)
		end
	else
		print(string.format("Error: Stage with id '%d' does not exist", stageId))
	end
end


function saveStage(stageId)
	local numStages = table.getsize(stageData)
	if stageId > 0 and stageId <= numStages + 1 then	
		local data = stage:getData()
		setStageData(stageId, data)
		saveStagesToFile(gameStageFileName)
	else
		print(string.format("Error: Currently %d stages, can't save to id '%d'", stageId, numStages))
	end
end


function initGame()
	-- initialize stage data and load a stage
	loadStagesFromFile(gameStageFileName)
	stage:clear()
	player:init() -- make sure sprite initialized!
	loadStage(currentStageId)

	gfx.sprite.setBackgroundDrawingCallback(
		function(x, y, width, height)
			gfx.setClipRect(x, y, width, height)
			stageImage:draw(0, 0)
			gfx.clearClipRect()
		end
	)

	-- add menu option
	local menu = playdate.getSystemMenu()
	local editModeToggle, error = menu:addCheckmarkMenuItem("Edit Mode", false, function(value)
		player.editmodeEnabled = not player.editmodeEnabled
		player:updateEditModeType() -- make sure correct tool is set
		player:updateSpriteImage()
		if value then
			local menuitem = menu:addMenuItem("Save Stage", function()
				saveStage(currentStageId)
			end)
			local menuitem = menu:addMenuItem("Reload Stage", function()
				loadStage(currentStageId)
			end)
		end
	end)
end

initGame()