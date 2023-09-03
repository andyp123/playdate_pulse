-- Pulse, Copyright 2022 Andrew Palmer

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
import "textEntry"

local gfx <const> = playdate.graphics
local keyboard <const> = playdate.keyboard

-- Stage Data
local gameStageFileName = "stages/gamestages"
if playdate.isSimulator then
	gameStageFileName = "data/gamestages"
end
local isEditorEnabled <const> = false and playdate.isSimulator == 1
levelSelect.isEditorEnabled = isEditorEnabled

-- User Data
userData.loadDataFromFile()

-- Images
local tileImageTable = gfx.imagetable.new("images/tiles")
local spriteImageTable = gfx.imagetable.new("images/sprites")
local playerImageTable = gfx.imagetable.new("images/player")
local bgImage = gfx.image.new(400, 240, gfx.kColorClear)

local transitionImageTable = gfx.imagetable.new("images/transition1")
local transitionImage = gfx.image.new(400, 240)
local transitionSprite = gfx.sprite.new(transitionImage)
transitionSprite:add()
transitionSprite:setZIndex(32700)
transitionSprite:moveTo(200,120)
transitionSprite:setImageDrawMode(gfx.kDrawModeBlackTransparent)

local jitter = jitterTable.new((stage.kWidth + 1) * (stage.kHeight + 1))

-- Fonts
local font = gfx.font.new("fonts/Roobert-20-Medium")
local fontSmall = gfx.font.new("fonts/Roobert-11-Medium")
gfx.setFont(font)

-- Text entry and keyboard
textEntry.init(fontSmall)
keyboard.textChangedCallback = textEntry.textChanged
keyboard.keyboardWillHideCallback = textEntry.textEntryFinished

-- Sounds
sound.loadSamples({
	MOVE = "sounds/move",
	MOVE_FAIL = "sounds/move_fail",
	GET_KEY = "sounds/get_key",
	GET_CLOCK = "sounds/get_clock",
	USE_KEY = "sounds/use_key",
	GET_ROTATE = "sounds/get_rotate",
	PRESS_SWITCH = "sounds/block_move",
	GET_HEART = "sounds/get_heart",
	GET_GEM = "sounds/get_gem",
	GET_ALL_GEMS = "sounds/get_all_gems",
	TIME_TICK = "sounds/time_tick",
	TIME_TICK_2 = "sounds/time_tick_2",
	TIME_TICK_3 = "sounds/time_tick_3",
	TIME_OVER = "sounds/time_over",
	MINE_EXPLODE = "sounds/mine_explode",
	STAGE_CLEAR = "sounds/stage_clear",
	HISCORE_ENTRY = "sounds/hiscore",
	CONGRATULATIONS = "sounds/congratulations",
	MENU_MOVE = "sounds/menu_move_2",
	MENU_BACK = "sounds/menu_back",
	MENU_SELECT = "sounds/menu_select",
	EDIT_MOVE = "sounds/edit_move",
	EDIT_TILE = "sounds/edit_tile"
})

-- Stage
local currentStage = stage.new()
local currentStageIndex = 1
stage.setResources(tileImageTable, spriteImageTable, jitter)
stage.drawTarget = bgImage

-- Player
player.setResources(currentStage, playerImageTable, spriteImageTable)
local player1 = player.new()

-- Time
-- playdate.display.setRefreshRate(30)
local totalTimeSeconds = 0
local deltaTimeSeconds = 1 / playdate.display.getRefreshRate()

-- Menus
-- menuId, items, font, width, rowHeight, padding, ?bgColor
-- font, 260, 32, 12) -- 6 rows max
-- fontSmall, 260, 22, 8) -- 10 rows max
menu.new("TITLE_MENU", {
	"Start Run",
	"Practice Mode",
	"High Scores",
	"User Settings",
}, font, 280, 32, 12)

menu.new("PAUSE_MENU", {
	"Resume",
	"Quit to Title"
}, font, 280, 32, 12)

menu.new("PAUSE_MENU_PRACTICE", {
	"Resume",
	"Restart",
	"Back to Stage Select"
}, font, 280, 32, 12)

menu.new("SETTINGS_MENU", {
	"Rename User",
	"Delete User",
	"Back to Title",
	"---",
	"Delete ALL Data"
}, font, 280, 32, 12)

menu.new("HISCORE_MENU", {
	"Toggle Local/Online",
	"Toggle Time/Score",
	"Back to Title"
}, font, 280, 32, 12)

if not isEditorEnabled then
	menu.new("LEVELS_MENU", {
		"Play Stage",
		"Play From Here",
		"Back to Title"
	}, font, 280, 32, 12)

else
	menu.new("LEVELS_MENU", {
		"Play Stage",
		"Edit Stage",
		"Back to Title"
	}, font, 280, 32, 12)

	menu.new("PAUSE_MENU_EDIT", {
		"Resume",
		"Back to Stage Edit"
	}, font, 280, 32, 12)

	menu.new("EDIT_MENU", {
		"Play Stage",
		"Save Stage",
		"Revert Stage",
		"Clear (Filled)",
		"Clear (Empty)",
		"Back to Stage Select"
	}, font, 340, 32, 12)
end

-- Should appear above transition sprite
menu.makeRankCard("RANK_CARD", font, 280, 32, 12)

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
-- SCOREBOARD CALLBACKS -------------------------------------------------------
-------------------------------------------------------------------------------

-- See userData.lua for main functions

function generateOnlineRankMessage(rank, prevRank)
	local message = ""
	if rank > 50 then
		message = string.format("%d is far from the top.\nI hope you get there one day!", rank)
	elseif rank > 6 and rank < prevRank then
		message = "An improvement over your\nprevious rank. Well done!"
	elseif rank > 6 then
		message = "You need a rank of 6 or better\nto appear on the leaderboard."
	elseif rank > 1 and prevRank > 6 then
		message = "Congratulations!\nYou made the leaderboard!"
	elseif rank > prevRank then
		message = "You made the leaderboard,\nbut your old rank was better!"
	elseif rank > 1 and rank == prevRank then
		message = "Equal to your previous rank.\nCan you beat it?"
	elseif rank == 1 then
		message = "You're number 1!\nSo why try harder?"
	else
		message = "Sneaking up the leaderboard!\nCan you reach the top?"
	end

	return message
end


function onlineScoresUpdated()
	-- Refresh scoreboard if it is currently being viewed
	if state == STATE_HISCORE and hiscore.showOnlineRanking == true then
		hiscore.drawToImage(bgImage, font, fontSmall)
	end
end


function onlineRankReceived(result)
	local rank = result.rank
	local player = result.player
	local score = result.value

	local prevRank = userData.onlineRank.rank
	if prevRank == nil then
		prevRank = 9999
	end
	local rankCardMenu = menu.setActiveMenu("RANK_CARD")
	local message = generateOnlineRankMessage(rank, prevRank)
	rankCardMenu:updateRankCardImage(rank, player, score, message, fontSmall)
end


userData.onOnlineScoresUpdated = onlineScoresUpdated
userData.onOnlineRankReceived = onlineRankReceived

-- refresh scores and get current rank on boot
userData.refreshOnlineScores()



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
game.gameMode = MODE_STANDARD
game.gameClear = false


function game:getPlayData()
	local playData = {
		totalTime = self.totalTimeElapsed,
		stageTime = self.timeElapsed,
		startStage = self.startStageId,
		currentStage = currentStageIndex,
		livesRemaining = player1.lives,
		livesUsed = self.livesUsed,
		prevRecord = self.prevRecord,
		gameMode = self.gameMode,
		gameClear = self.gameClear,
	}
	return playData
end


function game:resetPlayData(keepStageIndex)
	player1.lives = 0
	self.timeElapsed = 0.0
	self.timeRemaining = 10.0
	self.totalTimeElapsed = 0.0
	self.startStageId = 1
	self.livesUsed = 0
	self.prevRecord = 20.0
	self.gameMode = MODE_STANDARD
	self.gameClear = false

	if keepStageIndex ~= true then
		currentStageIndex = 1
	end
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
		self:drawTransition()
	end
end


function game:drawTransition()
	gfx.lockFocus(transitionImage)
	local floor = math.floor

	transitionSprite:setImageDrawMode(gfx.kDrawModeWhiteTransparent)
	local t = 1.0 - self.stateTransitionAnimator:currentValue()
	local frameId = clamp(floor(t * 9), 1, 8)
	local frameImage = transitionImageTable:getImage(frameId)
	local tileSize = 32
	local width = math.ceil(400 / tileSize) -- fill whole screen (400x240)
	local cnt = width * math.ceil(240 / tileSize) - 1

	for i = 0, cnt do
		local x = i % width
		local y = floor((i - x) / width)
		frameImage:draw(x * tileSize, y * tileSize)
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
		player1.editModeEnabled = false
		self:resetPlayData()
		-- without this, the stage background will continue to be drawn for a short while
		titleScreen.drawToImage(bgImage, jitter, 0, font, fontSmall)
	elseif state == STATE_STAGE_PLAY then
		player1:reset() -- No full reset in case we are changing stages
		loadStage(currentStageIndex)
		self.timeRemaining = 10.0
		self.timeElapsed = 0.0
		self.inPlay = true
		gfx.sprite.redrawBackground()
	elseif state == STATE_LEVEL_SELECT then
		self:resetPlayData()
		levelSelect.drawToImage(bgImage, fontSmall, isEditorEnabled)
		levelSelect.setCursorVisible(true)
	elseif state == STATE_STAGE_INTERMISSION then
		local playData = self:getPlayData()
		intermission.drawToImage(bgImage, font, fontSmall, playData)
	elseif state == STATE_HISCORE then
		userData.refreshOnlineScores()
		hiscore.drawToImage(bgImage, font, fontSmall)
	elseif state == STATE_SETTINGS then
		textEntry.textEntryFinishedCallback = addOrRenameUser
		settings.drawToImage(bgImage, font, fontSmall)
		settings.setCursorVisible(true)
	elseif state == STATE_GAME_CLEAR then
		local playData = self:getPlayData()
		intermission.drawGameClear(bgImage, font, fontSmall, playData)
		sound.play("CONGRATULATIONS")
	else
		print(string.format("Error: Unknown game state '%d'", state))
	end
end


function game:endStage(failed)
	-- Shouldn't happen, but prevent this from being triggered twice
	if not self.inPlay then return end
	self.inPlay = false

	-- Play sounds
	if not failed then
		sound.play("STAGE_CLEAR")
	elseif self.timeRemaining <= 0 then
		sound.play("TIME_OVER")
	end

	-- Retry the stage if the player has more lives remaining
	if failed and player1.lives > 0 then
		player1.lives = 0
		self.livesUsed += 1
		self:changeState(STATE_STAGE_PLAY)
		return
	end

	-- If we are just testing the stage, go back into edit mode
	if self.editModeTestingStage then
		player1.editModeEnabled = true
		self:resetPlayData(true)
		self:changeState(STATE_STAGE_PLAY)
		return
	end

	local userName = userData.getActiveUserName()
	local numStages = stage.getNumStages()
	local lastStageCleared = currentStageIndex

	-- Try to save stage record (even in practice mode)
	if not failed then
		local record = userData.getStageTimeRecord(currentStageIndex)
		self.prevRecord = record.time -- need to store this for intermission screen!
		userData.trySaveStageTime(currentStageIndex, userName, self.timeElapsed)

		-- currentStageIndex = clamp(currentStageIndex + 1, 1, numStages)
		currentStageIndex += 1
	else
		lastStageCleared -= 1
	end

	-- Try to save run record (standard mode only)
	local isRun = self.gameMode == MODE_STANDARD and self.startStageId == 1 and lastStageCleared > 0
	local saveRun = isRun and (failed or lastStageCleared == numStages)
	self.gameClear = isRun and lastStageCleared == numStages
	
	if saveRun then
		userData.trySaveRunRecord(lastStageCleared, self.totalTimeElapsed, self.livesUsed)
	end

	-- Change state
	if not failed then
		self:changeState(STATE_STAGE_INTERMISSION)
		return
	end

	if self.gameMode == MODE_STANDARD then
		-- Always show local runs after game ends
		hiscore.showOnlineRanking = false
		self:changeState(STATE_HISCORE)
	else
		self:changeState(STATE_LEVEL_SELECT)
	end
end


function game:update()
	-- Rank card hack
	if menu.isMenuActive("RANK_CARD") then
		if anyButtonJustPressed() then
			sound.play("MENU_SELECT")
			menu.setActiveMenu(nil)
		end

		-- need to return so we don't get input passed to title screen etc.
		return
	end

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
	elseif state == STATE_GAME_CLEAR then
		self:updateGameClear()
	else
		print(string.format("Error: Unknown game state '%d'", state))
	end

	self:updateTransition()
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
		if si == 1 then -- add/rename
			-- keyboard.show("")
			textEntry.setVisible(true)
		elseif si == 2 then -- delete
			if userData.deleteUser(settings.selectedIndex) then
				settings.drawToImage(bgImage, font, fontSmall)
				gfx.sprite.redrawBackground()
			end
		elseif si == 3 then -- back to title
			self:changeState(STATE_TITLE)
		-- si 4 is a divider
		elseif si == 5 then -- DELETE ALL DATA
			userData.init()
			userData.saveDataToFile()
			settings.drawToImage(bgImage, font, fontSmall)
			gfx.sprite.redrawBackground()
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
			elseif not userData.isValidUserId(userId) then
				-- add/rename when hitting A on empty slot
				-- keyboard.show("")
				textEntry.setVisible(true)
				sound.play("MENU_SELECT")
			end
		end
	end
end


function game:updateGameClear()
	if not self:inTransition() then
		if anyButtonJustPressed() or self.timeInState > 15.0 then
			self:changeState(STATE_HISCORE)
		end		
	end
end


function game:updateHiscore()
	-- menu update
	if menu.isMenuActive("HISCORE_MENU") then
		local m = menu.activeMenu
		local si = m:updateAndGetAnySelection()
		if si == 1 then -- Toggle local/online
			hiscore.showOnlineRanking = not hiscore.showOnlineRanking
			self:changeState(STATE_HISCORE)
		elseif si == 2 then -- Toggle times
			hiscore.showTimes = not hiscore.showTimes
			hiscore.drawToImage(bgImage, font, fontSmall)
			gfx.sprite.redrawBackground()
			self.timeInState = 0.0 -- Hacky way to reset state time
		elseif si == 3 then
			self:changeState(STATE_TITLE)			
		end
	elseif not self:inTransition() then

		if playdate.buttonJustPressed(playdate.kButtonB) then
			menu.setActiveMenu("HISCORE_MENU")
		elseif playdate.buttonJustPressed(playdate.kButtonA) or self.timeInState > 15.0 then
			self:changeState(STATE_TITLE)
		end	
	end
end


function game:updateIntermission()
	-- STATE_STAGE_INTERMISSION - Between stages
	-- retry - Lost life. No intermission, just replay
	-- clear - Finish game. Game over screen
	-- game_over - All lives gone. Hiscore screen

	-- need to query game state here
	if not self:inTransition() then
		if anyButtonJustPressed() or self.timeInState > 5.0 then
			if self.gameClear then
				self:changeState(STATE_GAME_CLEAR)
				return
			end

			local numStages = stage.getNumStages()
			if self.gameMode == MODE_PRACTICE or currentStageIndex > numStages then
				self:changeState(STATE_LEVEL_SELECT)
			else
				self:changeState(STATE_STAGE_PLAY)
			end
		end
	end
end


function game:updateLevelSelect()
	-- menu update
	if menu.isMenuActive("LEVELS_MENU") then
		local m = menu.activeMenu
		local si = m:updateAndGetAnySelection()
		if si == 1 then -- PLAY (SINGLE)
			self.gameMode = MODE_PRACTICE
			self:levelSelectPlayOrEdit(false)
		elseif si == 2 then -- PLAY FROM HERE / EDIT STAGE
			if isEditorEnabled then
				self.gameMode = MODE_PRACTICE
				self:levelSelectPlayOrEdit(true)
			else
				self.gameMode = MODE_PRACTICE_MULTI
				self:levelSelectPlayOrEdit(false)
			end
		elseif si == 3 then
			self:changeState(STATE_TITLE)
		end
	elseif not self:inTransition() then
		levelSelect.update()

		if playdate.buttonJustPressed(playdate.kButtonB) then
			menu.setActiveMenu("LEVELS_MENU")
		elseif playdate.buttonJustPressed(playdate.kButtonA) then
			self.gameMode = MODE_PRACTICE
			self:levelSelectPlayOrEdit(false)
			sound.play("MENU_SELECT")
		end
	end
end


function game:levelSelectPlayOrEdit(isEdit)
	levelSelect.setCursorVisible(false)
	currentStageIndex = levelSelect.selectedIndex
	self.startStageId = currentStageIndex
	if isEdit == true then
		player1.editModeEnabled = true
		player1:editModeUpdateType()
	end
	self:changeState(STATE_STAGE_PLAY)
end


function game:updateTitle()
	-- draw and update title screen
	if self.timeInState <= deltaTimeSeconds or menu.activeMenu == nil then
		local t = 1 - totalTimeSeconds % 1
		local tlim = 0.5
		jitterScale = math.pow(clamp(t - tlim, 0, 1) * (1/tlim), 3) * 8
		if t >= tlim then
			titleScreen.drawToImage(bgImage, jitter, jitterScale, font, fontSmall)
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
			-- Level Select unlock cheat
			local crankPos = playdate.getCrankPosition()
			if crankPos > 260 and crankPos < 280
			  and playdate.buttonIsPressed(playdate.kButtonUp)
			  and not levelSelect.isPlayAllCheatEnabled then
			  	sound.play("GET_ALL_GEMS")
			  	levelSelect.isPlayAllCheatEnabled = true
			end

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
		-- Show best runs screen after a delay
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
			local t = self.timeRemaining % 1
			local s = self.timeRemaining - t
			local tlim = 0.5 -- used so we don't redraw the screen every frame
			jitterScale = math.pow(clamp(t - tlim, 0, 1) * (1/tlim), 3) * clamp(8 - s, 1, 8)

			-- if we just ticked into a new second
			if math.floor(prevTime) > math.floor(self.timeRemaining) then
				local tr = self.timeRemaining
				if tr < 1 then -- 0-1
					sound.play("TIME_TICK_3")
					jitterScale += 8
				elseif tr < 2 then
					sound.play("TIME_TICK_2")
					jitterScale += 4
				else
					sound.play("TIME_TICK")
				end
			end

			if t >= tlim then
				currentStage:drawToImage(jitterScale)
				gfx.sprite.redrawBackground()
			end

			player1:update()
		end

		if playdate.buttonJustPressed(playdate.kButtonB) then
			-- Pause menu has some variations depending on mode etc.
			if self.editModeTestingStage then
				menu.setActiveMenu("PAUSE_MENU_EDIT")
			elseif self.gameMode == MODE_STANDARD then
				menu.setActiveMenu("PAUSE_MENU")
			else
				menu.setActiveMenu("PAUSE_MENU_PRACTICE")
			end
		end

	elseif activeMenu ~= nil then
		local si = activeMenu:updateAndGetAnySelection()
		-- si == 1 resumes
		if si == 2 then
			if self.editModeTestingStage then
				player1.editModeEnabled = true
				self:changeState(STATE_STAGE_PLAY)
			elseif self.gameMode == MODE_STANDARD then
				self:changeState(STATE_TITLE)
			else -- restart stage
				player1.lives = 0
				self:changeState(STATE_STAGE_PLAY)
			end
		elseif si == 3 then -- practice mode
			self:changeState(STATE_LEVEL_SELECT)
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
			self:changeState(STATE_STAGE_PLAY)
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
			-- currentStage:clear() -- TODO: This should be in state change already?
			self:changeState(STATE_LEVEL_SELECT)
		end
	end
end


-- Keyboard callback (user settings screen)
function addOrRenameUser(name)
	if userData.addOrRenameUser(settings.selectedIndex, name) then
		local userId = settings.selectedIndex
		userData.setActiveUser(userId)
		settings.drawToImage(bgImage, font, fontSmall)
		gfx.sprite.redrawBackground()
		sound.play("MENU_SELECT")
	end
end


function renameDefaultUser(name)
	if name ~= nil then
		if userData.addOrRenameUser(userData.activeUserId, name) then
			gfx.sprite.redrawBackground()
			sound.play("MENU_SELECT")
		end
	end

	textEntry.textEntryFinishedCallback = nil
	textEntry.textEntryCanceledCallback = nil
	game:changeState(STATE_TITLE)
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

	if userData.onlyDefaultUserExists() then
		textEntry.textEntryFinishedCallback = renameDefaultUser
		textEntry.textEntryCanceledCallback = renameDefaultUser
		textEntry.setVisible(true)
	else
		game:changeState(STATE_TITLE, true)
	end

	-- RANK CARD TEST
	-- local rank = 1
	-- local oldRank = 6
	-- local rankCardMenu = menu.setActiveMenu("RANK_CARD")
	-- local message = generateOnlineRankMessage(rank, oldRank)
	-- rankCardMenu:updateRankCardImage(rank, "BillyBob", 47560001, message, fontSmall)

	gfx.sprite.setBackgroundDrawingCallback(
		function(x, y, width, height)
			gfx.setClipRect(x, y, width, height)
			bgImage:draw(0, 0)
			gfx.clearClipRect()
		end
	)
end

initGame()
