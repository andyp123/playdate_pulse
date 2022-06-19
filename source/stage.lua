-- Playdate SDK
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"

-- Pulse
import "global"
import "jitterTable"

local gfx <const> = playdate.graphics


stage = {}
stage.__index = stage

-- Basic stage constants
stage.kWidth = 12
stage.kHeight = 7
stage.kNumCells = stage.kWidth * stage.kHeight

-- Size/spacing of grid cells in pixels, offset of stage
stage.kCellSize = 32
stage.kScreenOffset = 4
stage.kSpriteOffset = 24

-- Default settings
stage.kDefaultTime = 10

stage.modes = {
	STANDARD = 0,
	GEM_COLLECTOR = 1,
	SPACE_FILLER = 2
}

-- Cell types correspond to sprite indices
-- A table of values seems easier to work with than individual constants
stage.cellTypes = {
	EMPTY = 0,
	SOLID = 1,
	START = 2,
	EXIT = 3,
	DOOR = 4,
	KEY = 5,
	CLOCK = 6,
	ROTATE_LEFT = 7,
	ROTATE_RIGHT = 8,
	BLOCK_CLOSED = 9,
	BLOCK_OPEN = 10,
	SWITCH = 11,
	SWITCH_ONCE = 12,
	GEM = 13,
	GEM_DOOR = 14,
	MINE = 15,
	HEART = 16,
	PASSBLOCK_UP = 17,
	PASSBLOCK_RIGHT = 18,
	PASSBLOCK_DOWN = 19,
	PASSBLOCK_LEFT = 20,
	MAX = 20
}

-- Stage data file names
local gameStageFilename <const> = "data/gamestages"
local userStageFilename <const> = "data/userstages"

-- Table for stage data loaded from a file
-- Data always copied to and from stage objects to avoid accidental modification
stage.stageData = {}
-- stage.stageDataCurrentIndex = 1


-- Image tables for drawing the stage and actors in it
stage.tileImages = nil
stage.actorImages = nil

stage.jitter = nil -- jitter table for drawing
stage.drawTarget = nil -- 400x240 screen image


function stage.setResources(tileImageTable, spriteImageTable, jitterTable)
	stage.tileImages = tileImageTable
	stage.actorImages = spriteImageTable
	stage.jitter = jitterTable
end


function stage.isValidIndex(x, y)
	if x < 1 or x > stage.kWidth or y < 1 or y > stage.kHeight then
		return false
	end
	return true
end


function stage.new()
	local cells = table.create(stage.kNumCells)
	for i = 1, stage.kNumCells do
		cells[i] = 1
	end

	local a = {
		cells = cells,
		actors = {},
		time = stage.kDefaultTime
	}

	setmetatable(a, stage)
	return a
end


function stage:clear(cellValue)
	cellValue = cellValue or 1

	self.time = self.kDefaultTime
	for i = 1, self.kNumCells do
		self.cells[i] = cellValue
	end
	self:updateActors()
end


function stage:drawToImage(jitterScale)
	self.drawTarget:clear(gfx.kColorBlack)
	gfx.lockFocus(self.drawTarget)

	local cells = self.cells
	local width, height = self.kWidth, self.kHeight
	local size, offset = self.kCellSize, self.kScreenOffset

	gfx.setColor(gfx.kColorWhite)
	gfx.setLineWidth(4)
	gfx.setLineCapStyle(gfx.kLineCapStyleSquare)

	local tileImages = self.tileImages
	local jitter = self.jitter
	if jitterScale == nil then jitterScale = 0 end

	for i = 1, self.kNumCells do
		local y = math.floor((i - 1) / width)
		local x = i - (width * y) - 1
		local xp = x * size + offset
		local yp = y * size + offset

		-- jitter for each corner x and y
		local tlx, tly = jitter:getAt(i, jitterScale)
		local trx, try = jitter:getAt(i + 1, jitterScale)
		local blx, bly = jitter:getAt(i + width, jitterScale)
		local brx, bry = jitter:getAt(i + width + 1, jitterScale)

		if cells[i] == 1 then
			tileImages:drawImage(1, xp, yp)
		else
			-- calculate the tile edges
			-- t, r, b, l order
			xp += 4
			yp += 4
			if y == 0 or cells[i - width] == 1 then -- Top
				gfx.drawLine(xp + tlx, yp + tly, xp + trx + size, yp + try)
			end
			if x == width - 1 or cells[i + 1] == 1 then -- Right
				gfx.drawLine(xp + trx + size, yp + try, xp + brx + size, yp + bry + size)
			end
			if y == height - 1 or cells[i + width] == 1 then -- Bottom
				gfx.drawLine(xp + blx, yp + bly + size, xp + brx + size, yp + bry + size)
			end
			if x == 0 or cells[i - 1] == 1 then -- Left
				gfx.drawLine(xp + tlx, yp + tly, xp + blx, yp + bly + size)
			end
		end
	end

	gfx.unlockFocus()
end


-- Returns the first instance of a cell of typeId
function stage:findCellOfType(typeId, start)
	start = start or 1
	local cells = self.cells
	for i = start, self.kNumCells do
		if cells[i] == typeId then
			return i
		end
	end
end


function stage:countCellOfType(typeId)
	local cells = self.cells
	local count = 0
	for i = 0, self.kNumCells do
		if cells[i] == typeId then count += 1 end
	end
	return count
end


function stage:editCell(x, y, typeId)
	local i = xy2i(x, y, self.kWidth)
	local cells = self.cells
	local prevId = cells[i]
	local EMPTY, SOLID = self.cellTypes.EMPTY, self.cellTypes.SOLID

	-- print(string.format("%d: %d, %d (%d > %d)", i, x, y, prevId, typeId))

	-- does the edit modify the stage cells?
	if typeId == SOLID or prevId == SOLID then
		if typeId == SOLID then
			if prevId ~= EMPTY then
				cells[i] = EMPTY
			else
				cells[i] = SOLID
			end
		else -- place item on solid cell
			cells[i] = typeId
		end

		self:drawToImage()
		xpos = (x - 1) * self.kCellSize
		ypos = (y - 1) * self.kCellSize
		local size = self.kCellSize + self.kScreenOffset * 4
		gfx.sprite.addDirtyRect(xpos, ypos, size, size)
	else
		if typeId == prevId then
			cells[i] = EMPTY
		else
			cells[i] = typeId
		end
	end

	self:updateActors(i, i)
end


-- populate/update actors based on cell values
function stage:updateActors(first, last)
	-- enables single cell update
	first = first or 1
	last = last or self.kNumCells
	local SOLID, MAX = self.cellTypes.SOLID, self.cellTypes.MAX

	local cells = self.cells
	local actors = self.actors
	local actorImages = self.actorImages
	for i = first, last do
		local cellValue = cells[i]
		local sprite = actors[i]

		if cellValue > SOLID and cellValue <= MAX then
			if sprite ~= nil then
				sprite:setImage(actorImages:getImage(cellValue))
				sprite:add()
			else
				local xpos, ypos = i2xy(i, self.kWidth)
				xpos = (xpos - 1) * self.kCellSize + self.kSpriteOffset
				ypos = (ypos - 1) * self.kCellSize + self.kSpriteOffset
				sprite = gfx.sprite.new(actorImages:getImage(cellValue))
				sprite:moveTo(xpos, ypos)
				sprite:add()
				actors[i] = sprite
			end
		elseif sprite ~= nil then
			sprite:remove()
		end
	end
end


-- Useful function for things like toggling blocks when a switch is activated
-- swapCellTypes(stage.cellTypes.BLOCK_OPEN, stage.cellTypes.BLOCK_CLOSED)
function stage:swapCellTypes(typeA, typeB)
	local cells = self.cells
	for i = 1, self.kNumCells do
		local cellValue = cells[i]
		if cellValue == typeA then
			cells[i] = typeB
			self:updateActors(i, i)
		elseif cellValue == typeB then
			cells[i] = typeA
			self:updateActors(i, i)
		end
	end
end


-- Loading and saving stage data
function stage.getNumStages()
	return tablelength(stage.stageData)
end


function stage.loadStagesFromFile(filename)
	local data = playdate.datastore.read(filename)

	if data == nil then
		print(string.format("Error: Could not load '%s'", filename))
	else
		local numStages = tablelength(data)
		print(string.format("Loaded %d stages from '%s'", numStages, filename))
		stage.stageData = data
	end
end


function stage.saveStagesToFile(filename)
	if stage.stageData == nil then
		print("Error: No stage data to save")
	else
		local numStages = stage.getNumStages()
		print(string.format("Saving %d stages to '%s'", numStages, filename))
		playdate.datastore.write(stage.stageData, filename, false)
	end
end


function stage.delete(stageIndex)
	if stage.stageData ~= nil and stageIndex >= 1 and stageIndex <= stage.getNumStages() then
		print(string.format("Deleting stage '%d'", stageIndex))
		table.remove(stage.stageData, stageIndex)
		stage.saveStagesToFile(gameStageFilename)
	end
end


-- Get and set functions do not link tables from stageData to avoid accidental modification
function stage:setData(fromData)
	if fromData and fromData.cells then
		self.time = fromData.time or self.kDefaultTime
		for i = 1, self.kNumCells do
			self.cells[i] = fromData.cells[i]
		end
		self:updateActors()
	end
end


-- when adding new stages
function stage:getDataCopy()
	local cells = table.create(stage.kNumCells)
	for i = 1, self.kNumCells do
		cells[i] = self.cells[i]
	end

	return {
		time = self.time,
		cells = cells
	}
end


function stage:loadFromStageData(stageIndex)
	local numStages = stage.getNumStages()
	if stageIndex >= 1 and stageIndex <= numStages then
		self:setData(stage.stageData[stageIndex])
	else
		print("Error: No stage data at index '%d'")
	end
end


function stage:saveToStageData(stageIndex)
	local numStages = stage.getNumStages()
	stageIndex = stageIndex or numStages + 1
	stageIndex = math.floor(stageIndex)

	if stageIndex >= 1 and stageIndex <= numStages + 1 then
		stage.stageData[stageIndex] = self:getDataCopy(stageIndex)
		print(string.format("Writing to stageData at index '%d'", stageIndex))
		stage.saveStagesToFile(gameStageFilename)
	else
		print(string.format("Error: Currently %d stages, can't save to id '%d'", stageIndex, numStages))
	end
end

