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
import "levelSelect"
import "menu"

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
local STATE_LEVEL_SELECT <const> = 7

-- Images
local tileImageTable = gfx.imagetable.new("images/tiles")
local spriteImageTable = gfx.imagetable.new("images/sprites")
local playerImageTable = gfx.imagetable.new("images/player")
local bgImage = gfx.image.new(400, 240, gfx.kColorClear)

local transitionImageTable = gfx.imagetable.new("images/transition1")
local transitionImage = gfx.image.new(400, 240)
local transitionSprite = gfx.sprite.new(transitionImage)
transitionSprite:add()
transitionSprite:setZIndex(32767)
transitionSprite:moveTo(200,120)
transitionSprite:setImageDrawMode(gfx.kDrawModeBlackTransparent)


local jitter = jitterTable.new((STAGE_WIDTH + 1) * (STAGE_HEIGHT + 1))

-- Fonts
local font = gfx.font.new("fonts/Roobert-20-Medium")
local fontSmall = gfx.font.new("fonts/Roobert-11-Medium")
gfx.setFont(font)

-- Sounds
sound.loadSamples({
	MOVE = "sounds/move",
	MOVE_FAIL = "sounds/move_fail",
	GET_KEY = "sounds/get_key",
	GET_CLOCK = "sounds/get_clock",
	USE_KEY = "sounds/use_key",
	GET_ROTATE_L = "sounds/get_rotate",
	GET_ROTATE_R = "sounds/get_rotate", -- TODO: Make sound
	GET_ROTATE_180 = "sounds/get_rotate", -- TODO: Make sound
	PRESS_SWITCH = "sounds/block_move",
	GET_HEART = "sounds/get_heart",
	GET_GEM = "sounds/get_gem",
	GET_ALL_GEMS = "sounds/get_all_gems", -- TODO: Make sound
	TIME_TICK = "sounds/time_tick",
	TIME_OVER = "sounds/time_over",
	MINE_EXPLODE = "sounds/mine_explode",
	STAGE_CLEAR = "sounds/stage_clear",
	CONGRATULATIONS = "sounds/congratulations",
	MENU_MOVE = "sounds/menu_move_2",
	MENU_BACK = "sounds/menu_back",
	MENU_SELECT = "sounds/menu_select",
	EDIT_MOVE = "sounds/edit_move",
	EDIT_TILE = "sounds/edit_tile"
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

-- menu test
-- font, 260, 32, 12, 32000) -- 6 rows max
-- fontSmall, 260, 22, 8, 32000) -- 10 rows max
menu.new("TITLE_MENU", {
	"Start Game",
	"Level Select",
	"High Scores",
	"Settings"
}, font, 260, 32, 12, 32000)

menu.new("LEVELS_MENU", {
	"Play Level",
	"Edit Level",
	"Delete Level",
	"Back to Title"
}, font, 260, 32, 12, 32000)

menu.new("PAUSE_MENU", {
	"Restart Zone",
	"Quit to Title"
}, font, 260, 32, 12, 32000)

menu.new("EDIT_MENU", {
	"Play Level",
	"Save Level",
	"Revert Level",
	"Clear (Filled)",
	"Clear (Empty)",
	"Back to Level Select"
}, font, 260, 32, 12, 32000)


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

	-- hack for player lives (make sure to reset to 1 unless continuing a game)
	if state == STATE_STAGE_PLAY and game.currentState ~= STATE_STAGE_PLAY then
		player1.lives = 1
	end

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
	levelSelect.setCursorVisible(false)


	-- handle specific state functions
	local state = self.currentState
	if state == STATE_TITLE then
		-- without this, the stage background will continue to be drawn for a short while
		titleScreen.drawToImage(bgImage, jitter, 0)
		player1.editModeEnabled = false
		currentStageIndex = 1
	elseif state == STATE_STAGE_PLAY then
		player1:reset()
		loadStage(currentStageIndex)
		self.timeRemaining = currentStage.time
		gfx.sprite.redrawBackground()
	elseif state == STATE_LEVEL_SELECT then
		levelSelect.setCursorVisible(true)
	end
end


function game:endStage(failed)
	if failed then
		if self.timeRemaining > 0 then
			-- player died
		else
			sound.play("TIME_OVER")
		end
		player1.lives -= 1
	else
		sound.play("STAGE_CLEAR")
	end
	-- game.inPlay = false

	local numStages = stage.getNumStages()
	if failed and player1.lives > 0 then
		-- reload the level
		self:changeState(STATE_STAGE_PLAY)
	elseif (failed and player1.lives <= 0) or currentStageIndex + 1 > numStages then
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
	elseif state == STATE_LEVEL_SELECT then
		self:updateLevelSelect()
	else
	end

	self:updateTransition()
end


function game:updateLevelSelect()
	if game.timeInState <= deltaTimeSeconds then
		levelSelect.drawToImage(bgImage, fontSmall)
	end

	-- menu update
	if menu.isMenuActive("LEVELS_MENU") then
		local m = menu.activeMenu
		local si = m:updateAndGetAnySelection()
		if si == 1 or si == 2 then -- PLAY / EDIT
			local isEdit = (si == 2)
			self:levelSelectPlayOrEdit(isEdit)
		elseif si == 3 then -- DELETE
			stage.delete(levelSelect.selectedIndex)
			levelSelect.drawToImage(bgImage, fontSmall)
			gfx.sprite.redrawBackground()
		elseif si == 4 then
			game:changeState(STATE_TITLE)
		end
	elseif not self:inTransition() then
		levelSelect.setCursorVisible(true)
		levelSelect.update()

		if playdate.buttonJustPressed(playdate.kButtonB) then
			menu.setActiveMenu("LEVELS_MENU")
			levelSelect.setCursorVisible(false)
		elseif playdate.buttonJustPressed(playdate.kButtonA) then
			self:levelSelectPlayOrEdit()
			sound.play("MENU_SELECT")
		end
	end
end


function game:levelSelectPlayOrEdit(isEdit)
	levelSelect.setCursorVisible(false)
	currentStageIndex = levelSelect.selectedIndex
	if isEdit or currentStageIndex > stage.getNumStages() then
		player1.editModeEnabled = true
		player1:editModeUpdateType()
	end
	game:changeState(STATE_STAGE_PLAY)
end


function game:updateTitle()
	-- draw and update title screen
	if game.timeInState <= deltaTimeSeconds or menu.activeMenu == nil then
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
	end

	-- menu update
	if menu.isMenuActive("TITLE_MENU") then
		local m = menu.activeMenu
		local si = m:updateAndGetAnySelection()
		if si == 1 then
			game:changeState(STATE_STAGE_PLAY)
		elseif si == 2 then
			game:changeState(STATE_LEVEL_SELECT)
		end
	elseif not self:inTransition() then
		if playdate.buttonJustPressed(playdate.kButtonA) then
			game:changeState(STATE_STAGE_PLAY)
		elseif playdate.buttonJustPressed(playdate.kButtonB) then
			menu.setActiveMenu("TITLE_MENU")
		end
	end
end


function game:updateGame()
	if self:inTransition() then return end

	local pauseMenu = menu.getMenu("PAUSE_MENU")
	if not pauseMenu:isActive() then
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

		if playdate.buttonJustPressed(playdate.kButtonB) then
			menu.setActiveMenu("PAUSE_MENU")
		end
	else
		local si = pauseMenu:updateAndGetAnySelection()
		if si == 2 then
			currentStage:clear()
			game:changeState(STATE_TITLE)
		elseif si == 1 then
			-- restart zone
		end
	end
end


function game:updateEditMode()
	if self:inTransition() then return end

	local editMenu = menu.getMenu("EDIT_MENU")
	if not editMenu:isActive() then
		player1:update()

		if playdate.buttonJustPressed(playdate.kButtonB) then
			menu.setActiveMenu("EDIT_MENU")
		end
	else
		local si = editMenu:updateAndGetAnySelection()
		if si == 1 then
			-- "Play Level",
		elseif si == 2 then
			currentStage:saveToStageData(currentStageIndex)
		elseif si == 3 then
			currentStage:loadFromStageData(currentStageIndex)
			currentStage:drawToImage()
			gfx.sprite.redrawBackground()
		elseif si == 4 then
			currentStage:clear()
			currentStage:drawToImage()
			gfx.sprite.redrawBackground()
		elseif si == 5 then
			currentStage:clear(cellTypes.EMPTY)
			currentStage:drawToImage()
			gfx.sprite.redrawBackground()
		elseif si == 6 then
			player1.editModeEnabled = false
			currentStage:clear()
			game:changeState(STATE_LEVEL_SELECT)
		end
	end
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
		if i then
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
	player.deathCallback = function() game:endStage(true) end

	game:changeState(STATE_TITLE, true)

	gfx.sprite.setBackgroundDrawingCallback(
		function(x, y, width, height)
			gfx.setClipRect(x, y, width, height)
			bgImage:draw(0, 0)
			gfx.clearClipRect()
		end
	)
end

initGame()
