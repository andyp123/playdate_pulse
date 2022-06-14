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
import "titleScreen"

local gfx <const> = playdate.graphics

-- constants from stage
local STAGE_WIDTH <const> = stage.kWidth
local STAGE_HEIGHT <const> = stage.kHeight
-- local STAGE_NUM_CELLS <const> = stage.kNumCells
-- local STAGE_CELLSIZE <const> = stage.kCellSize
-- local SCREEN_OFFSET <const> = stage.kScreenOffset
-- local SPRITE_OFFSET <const> = stage.kSpriteOffset

local cellTypes <const> = stage.cellTypes

-- state
local STATE_TITLE <const> = 1
local STATE_STAGE_WAIT <const> = 2
local STATE_STAGE_PLAY <const> = 3
local STATE_STAGE_CLEAR <const> = 4
local STATE_STAGE_FAIL <const> = 5
local STATE_GAME_CLEAR <const> = 6

-- Images
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


local jitter = jitterTable.new((STAGE_WIDTH + 1) * (STAGE_HEIGHT + 1))

-- Fonts
local font = gfx.font.new("fonts/Roobert-20-Medium")
gfx.setFont(font)

-- Sounds
sound.loadSamples({
	MOVE = "sounds/move",
	MOVE_FAIL = "sounds/move_fail",
	GET_KEY = "sounds/get_key",
	GET_CLOCK = "sounds/get_clock",
	USE_KEY = "sounds/use_key",
	GET_ROTATE_L = "",
	GET_ROTATE_R = "",
	GET_DIAMOND = "",
	GET_HEART = "",
	PRESS_SWITCH = "",
	FLIP_BLOCK = "",
	TIME_TICK = "sounds/time_tick",
	TIME_OVER = "sounds/time_over",
	STAGE_CLEAR = "sounds/stage_clear",
	CONGRATULATIONS = "sounds/congratulations"
})

-- Stage
local gameStageFileName <const> = "data/gamestages"
local userStageFileName <const> = "data/userstages"

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
		titleScreen.drawToImage(bgImage, jitter, 0)
	elseif state == STATE_STAGE_PLAY then
		player1:reset()
		loadStage(currentStageIndex)
		self.timeRemaining = currentStage.time
		gfx.sprite.redrawBackground()
	end
end


function game:endStage(failed)
	if failed then
		sound.play("TIME_OVER")
	else
		sound.play("STAGE_CLEAR")
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
		titleScreen.drawToImage(bgImage, jitter, jitterScale)
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
				sound.play("TIME_TICK")
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
