import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/crank"
import 'CoreLibs/animator'
import 'CoreLibs/easing'

-- TODO: (+ done, x cancelled)
-- move input from player to main loop
-- move edit state from player to game
-- input to player only during game and editor states

-- + title screen with jittering letter logo
-- + fade transitions between states
-- game over state
-- game clear state
-- level select menu
-- user stage editing
-- stage editor menu
-- 12 stages to start with
-- think about modifications to gameplay... (5-7 modes?)
-- - default controls
-- - crank forward controls (hold direction and use crank to move forward)
-- - dark mode (stage only visible during pulse)
-- - instant death mode (pushing into a wall or door fails you)
-- - all corners mode (touch every tile)
-- - collector (get every special item)
-- - no way back (blocks previously occupied are filled)
-- x randomised initial state controls
-- polish
-- - more efficient duplication of stage data on save/load (don't create new tables)
-- - move jittered edges to foreground and draw each frame?

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

-- logo characters (x, y positions exported from blender. each letter is 3x3)
-- offset should be 8 + multiple of 8
-- scale should be multiple of 8. 24 is good. scale y should be inverted
-- screen width: scale 24, offset per letter 80
-- drawLogo(200, 48, 72, 8, jitterScale, 4) <- this fits the logo perfectly across the top of the screen
LOGO_P = { 0, 0, 1, 0, 2, 0, 2.38, -0.0761, 2.71, -0.293, 2.92, -0.617, 3, -1, 2.92, -1.38, 2.71, -1.71, 2.38, -1.92, 2, -2, 1, -2, 1, -3, 0, -3, 0, -2, 0, -1 }
LOGO_U = { 0, -1, 0, -2, 0.0761, -2.38, 0.293, -2.71, 0.617, -2.92, 1, -3, 2, -3, 2.38, -2.92, 2.71, -2.71, 2.92, -2.38, 3, -2, 3, -1, 3, 0, 2, 0, 2, -1, 2, -2, 1, -2, 1, -1, 1, 0, 0, 0 }
LOGO_L = { 0, -1, 0, -2, 0, -3, 1, -3, 2, -3, 3, -3, 3, -2, 2, -2, 1, -2, 1, -1, 1, 0, 0, 0 }
LOGO_S = { 1, -3, 2, -3, 2.38, -2.92, 2.71, -2.71, 2.92, -2.38, 3, -2, 2.92, -1.62, 2.71, -1.29, 2.38, -1.08, 2, -1, 1, -1, 2, -1, 3, -1, 3, 0, 2, 0, 1, 0, 0.617, -0.0761, 0.293, -0.293, 0.0761, -0.617, 0, -1, 0.0761, -1.38, 0.293, -1.71, 0.617, -1.92, 1, -2, 2, -2, 1, -2, 0, -2, 0, -3 }
LOGO_E = { 0, 0, 1, 0, 2, 0, 3, 0, 3, -1, 2, -1, 1, -1, 2, -1, 2, -2, 1, -2, 2, -2, 3, -2, 3, -3, 2, -3, 1, -3, 0, -3, 0, -2, 0, -1 }

-- images
local tileTable = gfx.imagetable.new("images/tiles")
local spriteTable = gfx.imagetable.new("images/sprites")
local transition1Table = gfx.imagetable.new("images/transition1")
local stageImage = gfx.image.new(400, 240, gfx.kColorClear)
local transitionImage = gfx.image.new(400, 240)
local transitionSprite = gfx.sprite.new(transitionImage)
transitionSprite:add()
transitionSprite:setZIndex(32100)
transitionSprite:moveTo(200,120)
transitionSprite:setImageDrawMode(gfx.kDrawModeBlackTransparent)
local font = gfx.font.new("fonts/Roobert-20-Medium")
gfx.setFont(font)

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
local totalTimeSeconds = 0
local deltaTimeSeconds = 1 / playdate.display.getRefreshRate()


-- helper functions
-- https://stackoverflow.com/questions/2705793/how-to-get-number-of-entries-in-a-lua-table
-- why the actual fuck is this not built in to lua?
-- Playdate's table.getsize appears to not work for the stage data.
function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end


function i2xy(i, w)
	w = w or STAGE_WIDTH
	i -= 1
	local x = i % w
	local y = math.floor((i - x) / w)
	return x + 1, y + 1
end


function i2xy0(i, w)
	w = w or STAGE_WIDTH
	i -= 1
	local x = i % w
	local y = math.floor((i - x) / w)
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


function getNumStages()
	if stageData ~= nil then return tablelength(stageData) end
	return 0
end


-- saving and loadings stage data
function loadStagesFromFile(filename)
	local data = playdate.datastore.read(filename)

	if data == nil then
		print(string.format("Error: Could not load '%s'", filename))
	else
		local numStages = tablelength(data)
		print(string.format("Loaded %d stages from '%s'", numStages, filename))
		stageData = data
	end
end


function saveStagesToFile(filename)
	if stageData == nil then
		print("Error: No stage data to save")
	else
		local numStages = getNumStages()
		print(string.format("Saving %d stages to '%s'", numStages, filename))
		playdate.datastore.write(stageData, filename, false)
	end
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
	print("Saving stage to index ", i)
	if data ~= nil then
		stageData[i] = data
	else
		print(string.format("Error: Data cannot be set as it is nil"))
	end
end



-------------------------------------------------------------------------------
-- JITTER ---------------------------------------------------------------------
-------------------------------------------------------------------------------
local jitter = {}


-- generates random direction vector for each vertex of the grid
-- these will be used to offset or jitter the vertex positions
-- during a pulse animation every second
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


function jitter:getScaled(scale)
	local i = self.nextSampleIdx * 2
	if self.nextSampleIdx == self.numSamples then
		self.nextSampleIdx = 1
	else
		self.nextSampleIdx += 1
	end
	return self.values[i-1] * scale, self.values[i] * scale
end


function jitter:randomizeNextSampleIndex()
	self.nextSampleIdx = math.random(1, self.numSamples)
end

jitter:init((STAGE_WIDTH+1) * (STAGE_HEIGHT+1))


-- Logo drawing
function drawLineLoop(lineData, x, y, xScale, yScale, jitterScale)
	local jx, jy = jitter:getScaled(jitterScale)
	local cnt = table.getsize(lineData)
	local p1x = x + jx + lineData[1] * xScale
	local p1y = y + jy + lineData[2] * yScale
	local sx, sy = p1x, p1y
	for i=3, cnt-1, 2 do
		jx, jy = jitter:getScaled(jitterScale)
		local p2x = x + jx + lineData[i] * xScale
		local p2y = y + jy + lineData[i+1] * yScale
		gfx.drawLine(p1x, p1y, p2x, p2y)
		p1x, p1y = p2x, p2y
	end
	-- draw line back to start of loop
	gfx.drawLine(p1x, p1y, sx, sy)
end


function drawLogo(cx, cy, letterSize, letterSpacing, jitterScale, lineWidth, invertColors)
	-- jitter.nextSampleIdx = 1
	local sampleIndex = jitter.nextSampleIdx
	gfx.setLineWidth(lineWidth * 4)
	gfx.setLineCapStyle(gfx.kLineCapStyleRound)

	local letterScale = letterSize / 3
	local totalWidth = letterSize * 5 + letterSpacing * 4
	local x, y = cx - totalWidth * 0.5, cy - letterSize * 0.5
	local bgcolor, fgcolor = gfx.kColorBlack, gfx.kColorWhite
	if invertColors then bgcolor, fgcolor = gfx.kColorWhite, gfx.kColorBlack end

	gfx.setColor(bgcolor)

	for i = 1, 2 do
		drawLineLoop(LOGO_P, x, y, letterScale, -letterScale, jitterScale)
		x += letterSize + letterSpacing
		drawLineLoop(LOGO_U, x, y, letterScale, -letterScale, jitterScale)
		x += letterSize + letterSpacing
		drawLineLoop(LOGO_L, x, y, letterScale, -letterScale, jitterScale)
		x += letterSize + letterSpacing
		drawLineLoop(LOGO_S, x, y, letterScale, -letterScale, jitterScale)
		x += letterSize + letterSpacing
		drawLineLoop(LOGO_E, x, y, letterScale, -letterScale, jitterScale)

		jitter.nextSampleIdx = sampleIndex
		gfx.setColor(fgcolor)
		gfx.setLineWidth(lineWidth)
		x, y = cx - totalWidth * 0.5, cy - letterSize * 0.5
	end
end


function drawTitleScreen(image, jitterScale)
	image:clear(gfx.kColorBlack)
	gfx.lockFocus(image)

	local width, height = STAGE_WIDTH, STAGE_HEIGHT
	local size, offset = STAGE_CELLSIZE, STAGE_OFFSET

	gfx.setColor(gfx.kColorWhite)
	gfx.setLineWidth(4)
	gfx.setLineCapStyle(gfx.kLineCapStyleSquare)

	for i = 1, STAGE_NUM_CELLS do
		local x, y = i2xy0(i)
		local xp = x * size + offset
		local yp = y * size + offset
		tileTable:drawImage(1, xp, yp)
	end

	-- cx, cy, letterSize, letterSpacing, jitterScale, lineWidth
	drawLogo(200, 48, 72, 8, jitterScale, 4, false)

	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	gfx.drawTextAligned("Press Ⓐ to begin\nⒷ for options", 200, 140, kTextAlignment.center)

	gfx.unlockFocus()
end


-------------------------------------------------------------------------------
-- GAME -----------------------------------------------------------------------
-------------------------------------------------------------------------------
local game = {}
-- state machine for areas of the game
game.currentState = STATE_STAGE_PLAY
game.timeInState = 0
game.transitionDuration = 500
game.transitionEasingType = playdate.easingFunctions.inOutQuad
game.transitionNextState = -1 -- if a transition has ended and this is > 0, it will change state and start another transition
game.stateTransitionAnimator = gfx.animator.new(game.transitionDuration, 1.0, 0.0, game.transitionEasingType)
-- game state
game.inPlay = false
game.timeRemaining = 10


function game:addTime(seconds)
	self.timeRemaining += seconds
end




function game:inTransition()
	if not self.stateTransitionAnimator:ended() or self.transitionNextState > 0 then
		return true
	end

	return false
end


function game:changeState(state, skipFadeOut)
	game.transitionNextState = state

	if skipFadeOut then
		self:enterNextState()
	else
		self.stateTransitionAnimator = gfx.animator.new(self.transitionDuration, 0.0, 1.0, self.transitionEasingType)
	end
end


function game:enterNextState(skipFadeIn)
	if self.transitionNextState < STATE_TITLE then
		return
	end

	self.currentState = self.transitionNextState
	self.transitionNextState = -1
	self.timeInState = 0
	if not skipFadeIn then
		self.stateTransitionAnimator = gfx.animator.new(self.transitionDuration, 1.0, 0.0, self.transitionEasingType)
	end

	self:handleStateEntry()
end


function game:updateTransition()
	if self.transitionNextState > 0 then
		if self.stateTransitionAnimator:ended() then
			self:enterNextState()
		end
	end

	local visible = (math.floor(self.stateTransitionAnimator:currentValue() * 8) > 0)
	transitionSprite:setVisible(visible)
	if visible then
		self:drawTransition(gfx.kDrawModeBlackTransparent)
	end
end


function game:drawTransition(drawMode)
	if drawMode ~= nil then
		transitionSprite:setImageDrawMode(drawMode)
	end

	gfx.lockFocus(transitionImage)

	local t = self.stateTransitionAnimator:currentValue()
	local frameId = clamp(math.floor(t * 9), 1, 8)
	-- print(t, frameId)
	local frameImage = transition1Table:getImage(frameId)
	local tileSize = 32
	local width = math.ceil(400 / tileSize) -- fill whole screen (400x240)
	local cnt = width * math.ceil(240 / tileSize)

	for i = 1, cnt do
		local xpos, ypos = i2xy0(i, width)
		xpos = xpos * tileSize
		ypos = ypos * tileSize
		frameImage:draw(xpos, ypos)
	end

	gfx.unlockFocus()
	gfx.sprite.addDirtyRect(0, 0, 400, 240)
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


function stage:drawToImage(image, jitterScale)
	image:clear(gfx.kColorBlack)
	gfx.lockFocus(image)

	local cells = self.cells
	local width, height = STAGE_WIDTH, STAGE_HEIGHT
	local size, offset = STAGE_CELLSIZE, STAGE_OFFSET

	gfx.setColor(gfx.kColorWhite)
	gfx.setLineWidth(4)
	gfx.setLineCapStyle(gfx.kLineCapStyleSquare) --gfx.kLineCapStyleRound)

	for i = 1, STAGE_NUM_CELLS do
		local y = math.floor((i-1) / STAGE_WIDTH)
		local x = i - (STAGE_WIDTH * y) - 1
		local xp = x * size + offset
		local yp = y * size + offset

		-- jitter for each corner x and y
		if jitterScale == nil then jitterScale = 0 end
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


	-- print(string.format("%d: %d, %d (%d > %d)", i, x, y, prevId, typeId))

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
player.editModeEnabled = false
player.editModeTypeId = TYPE_SOLID

function player:init()
	self.image1 = spriteTable:getImage(13)
	self.image2 = spriteTable:getImage(14)
	self.sprite = gfx.sprite.new(self.image1)
	self.sprite:moveTo(SPRITE_OFFSET, SPRITE_OFFSET)
	self.sprite:add()
	self.sprite:setZIndex(32000)
end


function player:setVisible(isVisible)
	self.sprite:setVisible(isVisible)
end


function player:reset()
	self.sprite:setVisible(true)
	self.keys = 0
	self.frame = 1
	self.sprite:setImage(self.image1)
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
	-- movement (allows diagonals, but can't allow in game)
	local mx, my = 0, 0
	if playdate.buttonJustPressed(playdate.kButtonLeft)  then mx = -1 end
	if playdate.buttonJustPressed(playdate.kButtonRight) then mx = 1 end
	if playdate.buttonJustPressed(playdate.kButtonUp)    then my = -1 end
	if playdate.buttonJustPressed(playdate.kButtonDown)  then my = 1 end
	if not self.editModeEnabled then
		if mx ~= 0 or my ~= 0 then
			-- kind of rubbish way of disabling diagonal moves. Could check for valid direction and only move orthogonal
			if mx ~= 0 and my ~= 0 then
				my = 0
			end
			self:tryMove(mx, my)
		end
	else
		self:editModeUpdate(mx, my)
	end
end


function player:editModeUpdate(mx, my)
	if mx ~= 0 or my ~= 0 then
		self:editModeTryMove(mx, my)
	end

	if playdate.buttonJustPressed(playdate.kButtonA) then
		stage:editCell(self.x, self.y, self.editModeTypeId)
	end

	if playdate.getCrankChange() ~= 0 then
		self:editModeUpdateType()
	end
end


function player:editModeTryMove(mx, my)
	if isValidIndex(self.x + mx, self.y + my) then
		self.x += mx
		self.y += my
		self.sprite:moveBy(mx * STAGE_CELLSIZE, my * STAGE_CELLSIZE)
	end
end


function player:editModeUpdateType()
	local crankPos = playdate.getCrankPosition()
	local segmentSize = 360 / TYPE_CLOCK
	local adjustedPos = (crankPos + segmentSize * 0.5) % 360
	local typeId = math.floor(adjustedPos / segmentSize) + 1
	self.editModeTypeId = typeId
	if self.editModeEnabled then self:updateSpriteImage() end
end


function player:updateSpriteImage()
	if self.editModeEnabled then
		self.sprite:setImage(spriteTable:getImage(self.editModeTypeId))
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
			game:endStage()
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
-- GAME UPDATE FUNCTIONS ------------------------------------------------------
-------------------------------------------------------------------------------
function game:handleStateEntry()
	player:setVisible(false)

	-- handle specific state functions
	local state = self.currentState
	if state == STATE_TITLE then
		-- without this, the stage background will continue to be drawn for a short while
		drawTitleScreen(stageImage, 0)
	elseif state == STATE_STAGE_PLAY then
		player:reset()
		loadStage(currentStageId)
		self.timeRemaining = stage.time
		gfx.sprite.redrawBackground()
	end
end


function game:endStage(failed)
	if failed then
		SFX_TIME_OVER:play()
	else
		SFX_STAGE_CLEAR:play()
	end
	game.inPlay = false

	local numStages = getNumStages()
	if failed or currentStageId + 1 > numStages then
		stage:clear()
		self:changeState(STATE_TITLE)
		currentStageId = 1	
	else
		currentStageId += 1
		self:changeState(STATE_STAGE_PLAY)
	end
end


function game:update()
	self.timeInState += deltaTimeSeconds

	local state = self.currentState
	if state == STATE_TITLE then
		self:updateTitle()
	elseif state == STATE_STAGE_WAIT then
		-- play stage intro
	elseif state == STATE_STAGE_PLAY then
		if not player.editModeEnabled then
			self:updateGame()
		else
			self:updateEditMode()
		end
	elseif state == STATE_STAGE_CLEAR then
		-- play stage clear anim, advance stage
	elseif state == STATE_STAGE_FAIL then
		-- play stage fail anim
	elseif state == STATE_GAME_CLEAR then
		-- play game/course clear anim
	else
	end

	self:updateTransition()
end


function game:updateTitle()
	-- draw and update title screen
	local prevTime = totalTimeSeconds - deltaTimeSeconds
	local t = 1 - totalTimeSeconds % 1
	local tlim = 0.5
	jitterScale = math.pow(clamp(t - tlim, 0, 1) * (1/tlim), 3) * 8
	if t >= tlim then
		drawTitleScreen(stageImage, jitterScale)
		-- only redraw the whole screen after transition
		if game.timeInState > deltaTimeSeconds then
			gfx.sprite.addDirtyRect(0,0,400,100)
		else
			gfx.sprite.redrawBackground()
		end
	else
		jitter:randomizeNextSampleIndex()
	end

	-- start the game when A button pressed
	if playdate.buttonJustPressed(playdate.kButtonA) and not self:inTransition() then
		game:changeState(STATE_STAGE_PLAY)
	end
end

function game:updateGame()
	if not self:inTransition() then
		local prevTime = self.timeRemaining

		self.timeRemaining = clamp(self.timeRemaining - deltaTimeSeconds, 0)

		if prevTime > 0 and self.timeRemaining == 0 then
			game:endStage(true) -- failed: true
		elseif self.timeRemaining then
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
	end
end

function game:updateEditMode()
	player:update()
end



-------------------------------------------------------------------------------
-- MAIN -----------------------------------------------------------------------
-------------------------------------------------------------------------------
function playdate.update()
	totalTimeSeconds += deltaTimeSeconds

	game:update()

	gfx.sprite.update()
	playdate.timer.updateTimers()

	-- seem to have issues if I do this before anything else...
	-- local timeString = string.format("%.3f", game.timeRemaining)
	-- local px,py = player.sprite:getPosition()
	-- local currentDrawMode = gfx.getImageDrawMode()
	-- gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	-- gfx.drawText(timeString, px+16, py-8)
	-- gfx.setImageDrawMode(currentDrawMode)
end


-- call with currentStageId to reload the current stage
function loadStage(stageId)
	local numStages = getNumStages()
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
		-- create an empty stage in this case
		if player.editModeEnabled then
			stage:clear()
			stage:drawToImage(stageImage)
			player:moveTo(6, 3)
			gfx.sprite.redrawBackground()
		else
			print(string.format("Error: Stage with id '%d' does not exist", stageId))
		end
	end
end


function saveStage(stageId)
	local numStages = getNumStages()
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
	stage:clear() -- need to fill with some valid data
	stageImage:clear(gfx.kColorBlack)
	player:init() -- make sure sprite initialized!
	player:setVisible(false)

	game:changeState(STATE_TITLE, true)

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
		player.editModeEnabled = not player.editModeEnabled
		player:editModeUpdateType() -- make sure correct tool is set
		player:updateSpriteImage()
		if value then
			if game.currentState ~= STATE_STAGE_PLAY then
				local numStages = getNumStages()
				currentStageId = numStages + 1
				game:changeState(STATE_STAGE_PLAY)
			end

			local menuitem = menu:addMenuItem("Save Stage", function()
				saveStage(getNumStages() + 1)
			end)
			local menuitem = menu:addMenuItem("Reload Stage", function()
				loadStage(currentStageId)
			end)
		end
	end)
end

initGame()
