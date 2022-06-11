import "CoreLibs/graphics"
import "CoreLibs/sprites"

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
	MAX = 11
}

-- Image tables for drawing the stage and actors in it
local tileImages = nil
local actorImages = nil

function stage.setImageTables(tileImageTable, spriteImageTable)
	tileImages = tileImageTable
	actorImages = spriteImageTable
end


function stage.new()
	local cells = table.create(stage.kNumCells)
	for i = 1, stage.kNumCells do
		cells[i] = 1
	end

	local a = {
		cells = cells,
		actors = {},
		time = 10
	}

	setmetatable(a, stage)
	return a
end


-- need to run this function on startup to initialize data
function stage:clear(cellValue)
	cellValue = cellValue or 1

	self.time = 10
	for i = 1, self.kNumCells do
		self.cells[i] = cellValue
	end
	self:updateActors()
end


function stage:setData(data)
	if data ~= nil then
		self.time = data.time
		for i = 1, self.kNumCells do
			self.cells[i] = data.cells[i]
		end
		self:updateActors()
	end
end


function stage:getData()
	local data = {}
	data.time = self.time
	data.cells = table.create(self.kNumCells, 0)
	for i = 1, self.kNumCells do
		data.cells[i] = self.cells[i]
	end
	return data
end


function stage:drawToImage(image, jitterTable, jitterScale)
	image:clear(gfx.kColorBlack)
	gfx.lockFocus(image)

	local cells = self.cells
	local width, height = self.kWidth, self.kHeight
	local size, offset = self.kCellSize, self.kScreenOffset

	gfx.setColor(gfx.kColorWhite)
	gfx.setLineWidth(4)
	gfx.setLineCapStyle(gfx.kLineCapStyleSquare)

	for i = 1, self.kNumCells do
		local y = math.floor((i - 1) / width)
		local x = i - (width * y) - 1
		local xp = x * size + offset
		local yp = y * size + offset

		-- jitter for each corner x and y
		if jitterScale == nil then jitterScale = 0 end
		local tlx, tly = jitterTable:getAt(i, jitterScale)
		local trx, try = jitterTable:getAt(i + 1, jitterScale)
		local blx, bly = jitterTable:getAt(i + width, jitterScale)
		local brx, bry = jitterTable:getAt(i + width + 1, jitterScale)

		if cells[i] == 1 then
			tileImages:drawImage(1, xp, yp)
		else
			-- calculate the tile edges
			-- t, r, b, l order
			xp += 4
			yp += 4
			if y == 0 or cells[i - width] == 1 then
				-- top
				gfx.drawLine(xp + tlx, yp + tly, xp + trx + size, yp + try)
			end
			if x == width - 1 or cells[i + 1] == 1 then
				-- right
				gfx.drawLine(xp + trx + size, yp + try, xp + brx + size, yp + bry + size)
			end
			if y == height - 1 or cells[i + width] == 1 then
				-- bottom
				gfx.drawLine(xp + blx, yp + bly + size, xp + brx + size, yp + bry + size)
			end
			if x == 0 or cells[i - 1] == 1 then
				-- left
				gfx.drawLine(xp + tlx, yp + tly, xp + blx, yp + bly + size)
			end
		end
	end

	gfx.unlockFocus()
end


function stage:findCellOfType(typeId, start)
	start = start or 1
	local cells = self.cells
	for i = start, self.kNumCells do
		if cells[i] == typeId then
			return i
		end
	end
end


function stage:editCell(x, y, typeId)
	local i = xy2i(x, y)
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

		self:drawToImage(stageImage)
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
	for i = first, last do
		local cellValue = cells[i]
		local sprite = actors[i]

		if cellValue > SOLID and cellValue <= MAX then
			if sprite ~= nil then
				sprite:setImage(actorImages:getImage(cellValue))
				sprite:add()
			else
				local xpos, ypos = i2xy(i)
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