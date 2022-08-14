-- Playdate SDK
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/crank"
import "CoreLibs/animator"
import "CoreLibs/easing"
import "CoreLibs/keyboard"

-- Pulse
import "global"
import "jitterTable"
import "stage"
import "player"
import "sound"
import "titleScreen"
import "levelSelect"
import "menu"
import "intermission"
import "userData"
import "hiscore"
import "settings"

local gfx <const> = playdate.graphics
local keyboard <const> = playdate.keyboard

-- user data
userData.loadDataFromFile()

-- state
local STATE_TITLE <const> = 1
local STATE_STAGE_PLAY <const> = 2
local STATE_STAGE_INTERMISSION <const> = 3
local STATE_LEVEL_SELECT <const> = 4
local STATE_HISCORE <const> = 5
local STATE_SETTINGS <const> = 6

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

local jitter = jitterTable.new((stage.kWidth + 1) * (stage.kHeight + 1))

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
	GET_ALL_GEMS = "sounds/get_all_gems",
	TIME_TICK = "sounds/time_tick",
	TIME_OVER = "sounds/time_over",
	MINE_EXPLODE = "sounds/mine_explode",
	STAGE_CLEAR = "sounds/stage_clear",
	-- STAGE_NEW_RECORD = "sounds/stage_new_record", -- TODO: Make sound
	CONGRATULATIONS = "sounds/congratulations",
	MENU_MOVE = "sounds/menu_move_2",
	MENU_BACK = "sounds/menu_back",
	MENU_SELECT = "sounds/menu_select",
	EDIT_MOVE = "sounds/edit_move",
	EDIT_TILE = "sounds/edit_tile"
})

-- TEST
local channel = sound.getChannel("PULSE")
local effect = playdate.sound.overdrive.new()
effect:setMix(0)
effect:setGain(5)
channel:addEffect(effect)
sound.addSampleToChannel("TIME_TICK", "PULSE")

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
-- playdate.display.setRefreshRate(30)
local totalTimeSeconds = 0
local deltaTimeSeconds = 1 / playdate.display.getRefreshRate()

-- menu test
-- font, 260, 32, 12, 32000) -- 6 rows max
-- fontSmall, 260, 22, 8, 32000) -- 10 rows max
menu.new("TITLE_MENU", {
	"Start Game",
	"Level Select",
	"High Scores",
	"User Settings"
}, font, 280, 32, 12, 32000)

menu.new("LEVELS_MENU", {
	"Play Level",
	"Edit Level",
	"Back to Title"
}, font, 280, 32, 12, 32000)

menu.new("PAUSE_MENU", {
	"Resume",
	"Quit to Title"
}, font, 280, 32, 12, 32000)

menu.new("PAUSE_MENU_EDIT", {
	"Resume",
	"Back to Level Edit"
}, font, 280, 32, 12, 32000)

menu.new("EDIT_MENU", {
	"Play Level",
	"Save Level",
	"Revert Level",
	"Clear (Filled)",
	"Clear (Empty)",
	"Back to Level Select"
}, font, 280, 32, 12, 32000)

menu.new("SETTINGS_MENU", {
	"Rename User",
	"Delete User",
	"Back to Title",
	"---",
	"Delete ALL Data"

}, font, 280, 32, 12, 32000)


-- Helper function for input check
function anyButtonJustPressed()
	if playdate.buttonJustPressed(playdate.kButtonA) or
	  playdate.buttonJustPressed(playdate.kButtonB) or
	  playdate.buttonJustPressed(playdate.kButtonLeft) or
	  playdate.buttonJustPressed(playdate.kButtonRight) or
	  playdate.buttonJustPressed(playdate.kButtonUp) or
	  playdate.buttonJustPressed(playdate.kButtonDown) then
	  	return true
	end
	return false
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
game.timeRemaining = 10.0
game.timeElapsed = 0.0
game.totalTimeElapsed = 0.0
game.startStageId = 1
game.livesUsed = 0
game.prevRecord = 20.0 -- used to store the best time of the previous stage
game.inPlay = false


function game:getPlayData()
	local playData = {
		totalTime = self.totalTimeElapsed,
		stageTime = self.timeElapsed,
		startStage = self.startStageId,
		currentStage = currentStageIndex,
		livesRemaining = player1.lives,
		livesUsed = self.livesUsed,
		prevRecord = self.prevRecord
	}
	return playData
end


function game:resetPlayData()
	-- player1.reset()
	player1.lives = 0
	self.timeElapsed = 0.0
	self.timeRemaining = 10.0
	self.totalTimeElapsed = 0.0
	self.startStageId = 1
	self.livesUsed = 0
	self.prevRecord = 20.0
end


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
	currentStage:clear()
	player1:setVisible(false)
	levelSelect.setCursorVisible(false)
	settings.setCursorVisible(false)

	-- handle specific state functions
	local state = self.currentState
	if state == STATE_TITLE then
		-- without this, the stage background will continue to be drawn for a short while
		titleScreen.drawToImage(bgImage, jitter, 0)
		player1.editModeEnabled = false
		currentStageIndex = 1
		self:resetPlayData() -- make sure previous session data is cleared
	elseif state == STATE_STAGE_PLAY then
		player1:reset()
		loadStage(currentStageIndex)
		self.timeRemaining = currentStage.time
		self.timeElapsed = 0.0
		self.inPlay = true
		gfx.sprite.redrawBackground()
	elseif state == STATE_LEVEL_SELECT then
		levelSelect.drawToImage(bgImage, fontSmall)
		levelSelect.setCursorVisible(true)
	elseif state == STATE_STAGE_INTERMISSION then
		local playData = self:getPlayData()
		intermission.drawToImage(bgImage, font, fontSmall, playData)
	elseif state == STATE_HISCORE then
		hiscore.drawToImage(bgImage, font, fontSmall)
	elseif state == STATE_SETTINGS then
		settings.drawToImage(bgImage, font, fontSmall)
		settings.setCursorVisible(true)
	end
end


function game:endStage(failed)
	if self.editModeTestingStage then
		return self:endStageEditModeTesting(failed)
	end

	-- prevent this from being triggered twice
	if not self.inPlay then return end
	self.inPlay = false

	local userName = userData.getActiveUserName()

	if failed then
		if self.timeRemaining > 0 then
			-- player died
		else
			sound.play("TIME_OVER")
		end

		if player1.lives > 0 then
			-- reload the level
			player1.lives = 0
			self.livesUsed += 1
			self:changeState(STATE_STAGE_PLAY)
		else
			-- TODO: STATE_GAME_OVER

			local newRecord = false

			-- Try to save run record
			if self.startStageId == 1 then
				newRecord = userData.trySaveRunRecord(userName, currentStageIndex - 1, self.totalTimeElapsed, self.livesUsed)
			end

			currentStageIndex = 1
			if newRecord then
				self:changeState(STATE_HISCORE)
			else
				self:changeState(STATE_TITLE)
			end
		end
	else
		sound.play("STAGE_CLEAR")
		local numStages = stage.getNumStages()

		-- Try to save stage record
		local record = userData.getStageTimeRecord(currentStageIndex)
		self.prevRecord = record.time -- need to store this for intermission screen!
		userData.trySaveStageTime(currentStageIndex, userName, self.timeElapsed)

		if currentStageIndex + 1 > numStages then
			-- TODO: STATE_GAME_CLEAR (only if run started from stage 1)
			self:changeState(STATE_TITLE)
			currentStageIndex = 1
		else
			currentStageIndex += 1
			self:changeState(STATE_STAGE_INTERMISSION)
		end
	end
end


function game:endStageEditModeTesting(failed)
	player1.editModeEnabled = true
	self:changeState(STATE_STAGE_PLAY)

	if not failed then
		sound.play("STAGE_CLEAR")
	elseif self.timeRemaining <= 0 then
		sound.play("TIME_OVER")
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
	elseif state == STATE_STAGE_INTERMISSION then
		self:updateIntermission()
	elseif state == STATE_LEVEL_SELECT then
		self:updateLevelSelect()
	elseif state == STATE_HISCORE then
		self:updateHiscore()
	elseif state == STATE_SETTINGS then
		self:updateSettings()
	end

	self:updateTransition()
end


-- NAME EDITING STUFF 
-- TODO: Move elsewhere
local textEntry = {}

function textEntry.init()
	textEntry.image = gfx.image.new(250, 240, gfx.kColorBlack)
	textEntry.sprite = gfx.sprite.new(textEntry.image)
	textEntry.sprite:setCenter(0, 0)
	textEntry.sprite:moveTo(0, 0)
	textEntry.sprite:setVisible(false)
	textEntry.sprite:add()
end

textEntry.init()


function textEntry.refreshSpriteImage(font)
	textEntry.image:clear(gfx.kColorBlack)
	gfx.lockFocus(textEntry.image)

	local x, y = 20, 50

	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	font:drawText("Enter a name:\n", x, y)

	y += 32
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(x, y, 180, 40)

	if keyboard.text ~= "" then
		gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
		font:drawText(keyboard.text, x + 10, y + 10)
	end


	gfx.unlockFocus()

	-- Force sprite to refresh
	textEntry.sprite:markDirty()
end


function textEntry.setVisible(visible)
	textEntry.sprite:setVisible(visible)

	if visible then
		textEntry.refreshSpriteImage(fontSmall)
	end
end


function textEntry.getValidatedText(text, maxWidth, font)
	-- Allow all alphanumeric chars, space and _
	text = string.gsub(text, "[^%w _]+", "")

	-- Set a maximum display width
	if font ~= nil then
		while font:getTextWidth(text) > maxWidth do
			text = string.sub(text, 1, string.len(text) - 1)
		end
	end

	return text
end


function textEntry.textChanged()
	textEntry.sprite:setVisible(true)
	keyboard.text = textEntry.getValidatedText(keyboard.text, 100, fontSmall)
	textEntry.refreshSpriteImage(fontSmall)

	print(string.format("Text: %s", keyboard.text))
end


function textEntry.textEntryFinished(ok)
	if ok then 
		print(string.format("Text entered: %s", keyboard.text))
	else
		print("Text entry cancelled")
	end

	textEntry.setVisible(false)
	gfx.sprite.redrawBackground()
end


function game:updateSettings()
	if keyboard.isVisible() then
		settings.setCursorVisible(false)
		return
	else
		settings.setCursorVisible(true)
	end

	-- menu update
	if menu.isMenuActive("SETTINGS_MENU") then
		local m = menu.activeMenu
		local si = m:updateAndGetAnySelection()
		if si == 1 then
			keyboard.textChangedCallback = textEntry.textChanged
			keyboard.keyboardWillHideCallback = textEntry.textEntryFinished
			keyboard.show("")
			textEntry.setVisible(true)
		elseif si == 2 then
		elseif si == 3 then
			game:changeState(STATE_TITLE)
		-- si 4 is a divider
		elseif si == 5 then -- DELETE ALL DATA
		end
	elseif not self:inTransition() then
		settings.update()

		if playdate.buttonJustPressed(playdate.kButtonB) then
			menu.setActiveMenu("SETTINGS_MENU")
		elseif playdate.buttonJustPressed(playdate.kButtonA) then
			local userId = settings.selectedIndex
			if userData.setActiveUser(userId) then
				settings.drawToImage(bgImage, font, fontSmall)
				gfx.sprite.redrawBackground()
				sound.play("MENU_SELECT")
			end
		end
	end
end


function game:updateHiscore()
	if not self:inTransition() then
		if anyButtonJustPressed() or self.timeInState > 15.0 then
			game:changeState(STATE_TITLE)
		end		
	end
end


function game:updateIntermission()
	-- STATE_STAGE_INTERMISSION - Between stages
	-- retry - Lost life. Retry stage
	-- clear - Finish game
	-- game_over - All lives gone

	-- elapsed time (total, last stage)
	-- current stage (show current group and highlight current stage)
	--   should show start stage of playthrough? e.g. [01] --- [34]
	-- lives (filled vs empty heart?)

	-- need to query game state here
	if not self:inTransition() then
		if anyButtonJustPressed() or self.timeInState > 5.0 then
			game:changeState(STATE_STAGE_PLAY)
		end
	end
end


function game:updateLevelSelect()
	-- menu update
	if menu.isMenuActive("LEVELS_MENU") then
		local m = menu.activeMenu
		local si = m:updateAndGetAnySelection()
		if si == 1 or si == 2 then -- PLAY / EDIT
			local isEdit = (si == 2)
			self:levelSelectPlayOrEdit(isEdit)
		elseif si == 3 then
			game:changeState(STATE_TITLE)
		end
	elseif not self:inTransition() then
		-- levelSelect.setCursorVisible(true)
		levelSelect.update()

		if playdate.buttonJustPressed(playdate.kButtonB) then
			menu.setActiveMenu("LEVELS_MENU")
			-- levelSelect.setCursorVisible(false)
		elseif playdate.buttonJustPressed(playdate.kButtonA) then
			self:levelSelectPlayOrEdit()
			sound.play("MENU_SELECT")
		end
	end
end


function game:levelSelectPlayOrEdit(isEdit)
	levelSelect.setCursorVisible(false)
	currentStageIndex = levelSelect.selectedIndex
	self.startStageId = currentStageIndex
	if isEdit or currentStageIndex > stage.getNumStages() then
		player1.editModeEnabled = true
		player1:editModeUpdateType()
	end
	game:changeState(STATE_STAGE_PLAY)
end


function game:updateTitle()
	-- draw and update title screen
	if self.timeInState <= deltaTimeSeconds or menu.activeMenu == nil then
		local t = 1 - totalTimeSeconds % 1
		local tlim = 0.5
		jitterScale = math.pow(clamp(t - tlim, 0, 1) * (1/tlim), 3) * 8
		if t >= tlim then
			titleScreen.drawToImage(bgImage, jitter, jitterScale)
			-- only redraw the whole screen after transition
			if self.timeInState > deltaTimeSeconds then
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
			self:changeState(STATE_STAGE_INTERMISSION)
		elseif si == 2 then
			self:changeState(STATE_LEVEL_SELECT)
		elseif si == 3 then
			self:changeState(STATE_HISCORE)
		elseif si == 4 then
			self:changeState(STATE_SETTINGS)
		end
	elseif not self:inTransition() then
		if playdate.buttonJustPressed(playdate.kButtonA) then
			self:changeState(STATE_STAGE_INTERMISSION)
		elseif playdate.buttonJustPressed(playdate.kButtonB) then
			menu.setActiveMenu("TITLE_MENU")
		end
		-- Show best runs screen after a delay?
		if self.timeInState > 30.0 then
			self:changeState(STATE_HISCORE)
		end
	end
end


function game:updateGame()
	if self:inTransition() then return end

	local activeMenu = menu.getActiveMenu()
	if self.inPlay and activeMenu == nil then
		local prevTime = self.timeRemaining

		self.timeElapsed += deltaTimeSeconds -- time only for this stage. Keeps ticking up and ignores timer items etc.
		self.totalTimeElapsed += deltaTimeSeconds -- always counts up while in play
		self.timeRemaining = clamp(self.timeRemaining - deltaTimeSeconds, 0)

		if prevTime > 0 and self.timeRemaining == 0 then
			self:endStage(true) -- failed: true
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
			-- These two menus have the same options, but slightly different text
			if self.editModeTestingStage then
				menu.setActiveMenu("PAUSE_MENU_EDIT")
			else
				menu.setActiveMenu("PAUSE_MENU")
			end
		end
	elseif activeMenu ~= nil then
		local si = activeMenu:updateAndGetAnySelection()
		-- si == 1 resumes
		if si == 2 then
			currentStage:clear()
			if self.editModeTestingStage then
				player1.editModeEnabled = true
				game:changeState(STATE_STAGE_PLAY)
			else
				game:changeState(STATE_TITLE)
			end
		end
	end
end


function game:updateEditMode()
	if self:inTransition() then return end

	self.editModeTestingStage = false
	local editMenu = menu.getMenu("EDIT_MENU")
	if not editMenu:isActive() then
		player1:update()

		if playdate.buttonJustPressed(playdate.kButtonB) then
			menu.setActiveMenu("EDIT_MENU")
		end
	else
		local si = editMenu:updateAndGetAnySelection()
		if si == 1 then -- Play Level
			currentStage:saveToTemp()
			self.editModeTestingStage = true
			player1.editModeEnabled = false
			game:changeState(STATE_STAGE_PLAY)
		elseif si == 2 then -- Save Stage
			currentStage:saveToStageData(currentStageIndex)
		elseif si == 3 then -- Revert Stage
			currentStage:loadFromStageData(currentStageIndex)
			currentStage:drawToImage()
			gfx.sprite.redrawBackground()
		elseif si == 4 then -- Clear to Filled
			currentStage:clear()
			currentStage:drawToImage()
			gfx.sprite.redrawBackground()
		elseif si == 5 then -- Clear to Empty
			currentStage:clear(stage.cellTypes.EMPTY)
			currentStage:drawToImage()
			gfx.sprite.redrawBackground()
		elseif si == 6 then -- Back to Level Select
			player1.editModeEnabled = false
			currentStage:clear() -- TODO: This should be in state change already?
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
end


-- call with currentStageIndex to reload the current stage
function loadStage(stageId)
	local numStages = stage.getNumStages()

	if game.editModeTestingStage then
		currentStage:loadFromTemp()
	elseif stageId >= 1 and stageId <= numStages then
		currentStageIndex = stageId
		currentStage:loadFromStageData(stageId)
	elseif player1.editModeEnabled then
		currentStage:clear()
	else
		print(string.format("Error: Stage with id '%d' does not exist", stageId))
		return
	end

	currentStage:drawToImage()
	gfx.sprite.redrawBackground()

	local i = currentStage:findCellOfType(stage.cellTypes.START)
	if i then
		local x, y = i2xy(i, stage.kWidth)
		player1:moveTo(x, y)
	else
		player1:moveTo(3, 3)
	end
end


function initGame()
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
