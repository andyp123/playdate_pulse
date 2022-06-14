-- Playdate SDK
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/crank"
import "CoreLibs/animator"
import "CoreLibs/easing"

-- Pulse
import "global"
import "jitterTable"
import "stage"
import "player"
import "sound"

-- TODO: (+ done, x cancelled)
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
-- move input from player to main loop
-- move edit state from player to game
-- input to player only during game and editor states


local gfx <const> = playdate.graphics
local snd <const> = playdate.sound

-- constants from stage
local STAGE_WIDTH <const> = stage.kWidth
local STAGE_HEIGHT <const> = stage.kHeight
local STAGE_NUM_CELLS <const> = stage.kNumCells
local STAGE_CELLSIZE <const> = stage.kCellSize
local SCREEN_OFFSET <const> = stage.kScreenOffset
local SPRITE_OFFSET <const> = stage.kSpriteOffset

local cellTypes <const> = stage.cellTypes

-- state
local STATE_TITLE <const> = 1
local STATE_STAGE_WAIT <const> = 2
local STATE_STAGE_PLAY <const> = 3
local STATE_STAGE_CLEAR <const> = 4
local STATE_STAGE_FAIL <const> = 5
local STATE_GAME_CLEAR <const> = 6


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
local tileImageTable = gfx.imagetable.new("images/tiles")
local spriteImageTable = gfx.imagetable.new("images/sprites")
local playerImageTable = gfx.imagetable.new("images/player")
local bgImage = gfx.image.new(400, 240, gfx.kColorClear)

local transitionImageTable = gfx.imagetable.new("images/transition1")
local transitionImage = gfx.image.new(400, 240)
local transitionSprite = gfx.sprite.new(transitionImage)
transitionSprite:add()
transitionSprite:setZIndex(32100)
transitionSprite:moveTo(200,120)
transitionSprite:setImageDrawMode(gfx.kDrawModeBlackTransparent)

local font = gfx.font.new("fonts/Roobert-20-Medium")
gfx.setFont(font)

-- Sounds
sound.loadSamples({
	SFX_MOVE = "sounds/move",
	SFX_MOVE_FAIL = "sounds/move_fail",
	SFX_GET_KEY = "sounds/get_key",
	SFX_GET_CLOCK = "sounds/get_clock",
	SFX_USE_KEY = "sounds/use_key",
	SFX_STAGE_CLEAR = "sounds/stage_clear",
	SFX_TIME_TICK = "sounds/time_tick",
	SFX_TIME_OVER = "sounds/time_over",
	SFX_CONGRATULATIONS = "sounds/congratulations"
})

-- filenames
local gameStageFileName <const> = "data/gamestages"
local userStageFileName <const> = "data/userstages"

local jitter = jitterTable.new((STAGE_WIDTH + 1) * (STAGE_HEIGHT + 1))

-- stage
local currentStage = stage.new()
local currentStageIndex = 1
stage.setResources(tileImageTable, spriteImageTable, jitter)
stage.drawTarget = bgImage

-- player
player.setResources(currentStage, playerImageTable, spriteImageTable)
local player1 = player.new()


-- time
local totalTimeSeconds = 0
local deltaTimeSeconds = 1 / playdate.display.getRefreshRate()


-- Logo drawing
function drawLineLoop(lineData, x, y, xScale, yScale, jitterScale)
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


function drawLogo(cx, cy, letterSize, letterSpacing, jitterScale, lineWidth, invertColors)
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
	local size, offset = STAGE_CELLSIZE, SCREEN_OFFSET

	gfx.setColor(gfx.kColorWhite)
	gfx.setLineWidth(4)
	gfx.setLineCapStyle(gfx.kLineCapStyleSquare)

	for i = 1, STAGE_NUM_CELLS do
		local x, y = i2xy0(i, STAGE_WIDTH)
		local xp = x * size + offset
		local yp = y * size + offset
		tileImageTable:drawImage(1, xp, yp)
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
	local frameImage = transitionImageTable:getImage(frameId)
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
-- GAME UPDATE FUNCTIONS ------------------------------------------------------
-------------------------------------------------------------------------------
function game:handleStateEntry()
	player1:setVisible(false)

	-- handle specific state functions
	local state = self.currentState
	if state == STATE_TITLE then
		-- without this, the stage background will continue to be drawn for a short while
		drawTitleScreen(bgImage, 0)
	elseif state == STATE_STAGE_PLAY then
		player1:reset()
		loadStage(currentStageIndex)
		self.timeRemaining = currentStage.time
		gfx.sprite.redrawBackground()
	end
end


function game:endStage(failed)
	if failed then
		sound.play("SFX_TIME_OVER")
	else
		sound.play("SFX_STAGE_CLEAR")
	end
	game.inPlay = false

	local numStages = stage.getNumStages()
	if failed or currentStageIndex + 1 > numStages then
		currentStage:clear()
		self:changeState(STATE_TITLE)
		currentStageIndex = 1	
	else
		currentStageIndex += 1
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
		if not player1.editModeEnabled then
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
		drawTitleScreen(bgImage, jitterScale)
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
				sound.play("SFX_TIME_TICK")
			end
			local t = self.timeRemaining % 1
			local s = self.timeRemaining - t
			local tlim = 0.5
			jitterScale = math.pow(clamp(t - tlim, 0, 1) * (1/tlim), 3) * clamp(8 - s, 1, 8)
			if t >= tlim then
				currentStage:drawToImage(jitterScale)
				gfx.sprite.redrawBackground()
			end
		end

		player1:update()
	end
end

function game:updateEditMode()
	player1:update()
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
	-- local px,py = player1.sprite:getPosition()
	-- local currentDrawMode = gfx.getImageDrawMode()
	-- gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	-- gfx.drawText(timeString, px+16, py-8)
	-- gfx.setImageDrawMode(currentDrawMode)
end


-- call with currentStageIndex to reload the current stage
function loadStage(stageId)
	local numStages = stage.getNumStages()
	if stageId >= 1 and stageId <= numStages then
		currentStageIndex = stageId
		currentStage:loadFromStageData(stageId)
		currentStage:drawToImage()
		gfx.sprite.redrawBackground()

		local i = currentStage:findCellOfType(cellTypes.START)
		if i > 0 then
			local x, y = i2xy(i, STAGE_WIDTH)
			player1:moveTo(x, y)
		end
	elseif player1.editModeEnabled then
		currentStage:clear()
		currentStage:drawToImage()
		player1:moveTo(3, 3)
		gfx.sprite.redrawBackground()
	else
		print(string.format("Error: Stage with id '%d' does not exist", stageId))
	end
end


function initGame()
	-- initialize stage data and load a stage
	stage.loadStagesFromFile(gameStageFileName)
	bgImage:clear(gfx.kColorBlack)

	player1:setVisible(false)
	player.getTimeCallback = function(t) game:addTime(t) end
	player.reachExitCallback = function() game:endStage() end

	game:changeState(STATE_TITLE, true)

	gfx.sprite.setBackgroundDrawingCallback(
		function(x, y, width, height)
			gfx.setClipRect(x, y, width, height)
			bgImage:draw(0, 0)
			gfx.clearClipRect()
		end
	)

	-- add menu option
	local menu = playdate.getSystemMenu()
	local editModeToggle, error = menu:addCheckmarkMenuItem("Edit Mode", false, function(value)
		player1.editModeEnabled = not player1.editModeEnabled
		player1:editModeUpdateType() -- make sure correct tool is set
		player1:updateSpriteImage()
		if value then
			if game.currentState ~= STATE_STAGE_PLAY then
				currentStageIndex = stage.getNumStages() + 1
				game:changeState(STATE_STAGE_PLAY)
			end

			local menuitem = menu:addMenuItem("Save Stage", function()
				currentStage:saveToStageData(currentStageIndex)
			end)
			local menuitem = menu:addMenuItem("Reload Stage", function()
				currentStage:loadFromStageData(currentStageIndex)
			end)
		end
	end)
end

initGame()
