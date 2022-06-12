-- Playdate SDK
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"

-- Pulse
import "global"
import "stage"


player = {}
player.__index = player


local gfx <const> = playdate.graphics
local cellTypes <const> = stage.cellTypes

player.currentStage = nil
player.playerImages = nil
player.actorImages = nil -- used for displaying editmode tools (and player as key)

player.reachExitCallback = nil
player.getTimeCallback = nil


function player.setResources(stage, playerImageTable, actorImageTable)
	player.currentStage = stage
	player.playerImages = playerImageTable
	player.actorImages = actorImageTable
end


function player.new()
	if player.playerImages == nil then
		print("Error: Must first set image table using player.setResources")
		return nil
	end

	local sprite = gfx.sprite.new(player.playerImages:getImage(1))
	sprite:moveTo(stage.kSpriteOffset, stage.kSpriteOffset)
	sprite:add()
	sprite:setZIndex(32000)

	local a = {
		x = 1,
		y = 1,
		keys = 0,
		inputRotation = 0, -- 0-3, corresponding to 0, 90, 180, 270
		sprite = sprite,
		frame = 1,
		editModeEnabled = false,
		editModeTypeId = cellTypes.SOLID
	}

	setmetatable(a, player)
	return a
end


function player:reset()
	self.sprite:setVisible(true)
	self.keys = 0
	self.inputRotation = 0
	self.frame = 1
	self.sprite:setImage(self.playerImages:getImage(1))
end


function player:setVisible(isVisible)
	self.sprite:setVisible(isVisible)
end


function player:getRotatedInput(mx, my)
	local rx, ry = mx, my
	if self.inputRotation == 1 then -- 90
		rx = -my
		ry = mx
	elseif self.inputRotation == 2 then -- 180
		rx = -mx
		ry = -my
	elseif self.inputRotation == 3 then -- 270
		rx = my
		ry = -mx
	end

	return rx, ry
end


function player:moveTo(x, y)
	if stage.isValidIndex(x, y) then
		self.x = x
		self.y = y
		local posx = (x - 1) * stage.kCellSize + stage.kSpriteOffset
		local posy = (y - 1) * stage.kCellSize + stage.kSpriteOffset
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
	mx, my = self:getRotatedInput(mx, my)
	if not self.editModeEnabled then
		if mx ~= 0 or my ~= 0 then
			-- TODO: Make this choose whichever dir is valid
			-- kind of rubbish way of disabling diagonal moves. Could check for valid direction and choose that
			if mx ~= 0 and my ~= 0 then
				my = 0
			end
			self:tryMove(mx, my)
		end
	else
		self:editModeUpdate(mx, my)
	end
end


function player:tryMove(mx, my)
	local x, y = self.x + mx, self.y + my
	if self:tryMoveAndCollect(x, y) then
		self.x = x
		self.y = y
		self.sprite:moveBy(mx * stage.kCellSize, my * stage.kCellSize)
		self:updateSpriteImage()
	end
end


function player:tryMoveAndCollect(x, y)
	if stage.isValidIndex(x, y) then
		local i = xy2i(x, y, stage.kWidth)
		local typeId = self.currentStage.cells[i]

		if typeId == cellTypes.SOLID or typeId == cellTypes.BLOCK_CLOSED then
			-- SFX_MOVE_FAIL:play()
			return false
		elseif typeId == cellTypes.DOOR then
			if self.keys > 0 then
				self.keys -= 1
				self.currentStage:editCell(x, y, cellTypes.EMPTY)
				-- SFX_USE_KEY:play()
				return true
			else
				-- SFX_MOVE_FAIL:play()
				return false
			end
		elseif typeId == cellTypes.KEY then
			self.keys += 1
			self.currentStage:editCell(x, y, cellTypes.EMPTY)
			-- SFX_GET_KEY:play()
			return true
		elseif typeId == cellTypes.CLOCK then
			if self.getTimeCallback ~= nil then
				self.getTimeCallback(2)
			end
			self.currentStage:editCell(x, y, cellTypes.EMPTY)
			-- SFX_GET_CLOCK:play()
			return true
		elseif typeId == cellTypes.ROTATE_LEFT then
			self.inputRotation = (self.inputRotation + 3) % 4
			self.currentStage:editCell(x, y, cellTypes.EMPTY)
			-- SFX_GET_CLOCK:play()
			return true
		elseif typeId == cellTypes.ROTATE_RIGHT then
			self.inputRotation = (self.inputRotation + 1) % 4
			self.currentStage:editCell(x, y, cellTypes.EMPTY)
			-- SFX_GET_CLOCK:play()
			return true
		elseif typeId == cellTypes.SWITCH then
			-- flip state of blocks to BLOCK_OPEN and vice versa
			self.currentStage:swapCellTypes(cellTypes.BLOCK_CLOSED, cellTypes.BLOCK_OPEN)
		elseif typeId == cellTypes.EXIT then
			if self.reachExitCallback ~= nil then
				self.reachExitCallback()
			end
			return true
		end

		-- empty or undefined
		-- SFX_MOVE:play()
		return true
	end
	
	-- SFX_MOVE_FAIL:play()
	return false
end


function player:editModeUpdate(mx, my)
	if mx ~= 0 or my ~= 0 then
		self:editModeTryMove(mx, my)
	end

	if playdate.buttonJustPressed(playdate.kButtonA) then
		self.currentStage:editCell(self.x, self.y, self.editModeTypeId)
	end

	if playdate.getCrankChange() ~= 0 then
		self:editModeUpdateType()
	end
end


function player:editModeTryMove(mx, my)
	if stage.isValidIndex(self.x + mx, self.y + my) then
		self.x += mx
		self.y += my
		self.sprite:moveBy(mx * stage.kCellSize, my * stage.kCellSize)
	end
end


function player:editModeUpdateType()
	local crankPos = playdate.getCrankPosition()
	local segmentSize = 360 / cellTypes.MAX
	local adjustedPos = (crankPos + segmentSize * 0.5) % 360
	local typeId = math.floor(adjustedPos / segmentSize) + 1
	self.editModeTypeId = typeId
	if self.editModeEnabled then self:updateSpriteImage() end
end


function player:updateSpriteImage()
	if self.editModeEnabled then
		self.sprite:setImage(self.actorImages:getImage(self.editModeTypeId))
	else
		if self.keys > 0 then
			self.sprite:setImage(self.actorImages:getImage(cellTypes.KEY))
		else
			self.frame = math.abs(self.frame - 1)
			if self.frame == 1 then self.sprite:setImage(self.playerImages:getImage(1))
			else self.sprite:setImage(self.playerImages:getImage(2)) end
		end
	end
end