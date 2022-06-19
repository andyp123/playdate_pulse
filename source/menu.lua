-- Playdate SDK
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"

menu = {}
menu.__index = menu


local gfx <const> = playdate.graphics


menu.menus = {}
menu.activeMenu = nil

-- make a vertical menu
-- items is a table of strings
function menu.new(menuId, items, font, width, rowHeight, padding, zIndex, bgColor)
	bgColor = bgColor or gfx.kColorWhite
	local fgColor = gfx.kColorWhite
	if bgColor == gfx.kColorWhite then fgColor = gfx.kColorBlack end
	local height = rowHeight * #items
	local px, py = 200, 120

	-- menu itself
	local img = gfx.image.new(width + padding * 2, height + padding * 2, bgColor)
	local sprite = gfx.sprite.new(img)
	sprite:setZIndex(zIndex)
	sprite:moveTo(px, py)
	sprite:setVisible(false)
	sprite:add()

	-- selection highlight
	img = gfx.image.new(width, rowHeight, gfx.kColorWhite)
	local selectionSprite = gfx.sprite.new(img)
	selectionSprite:setImageDrawMode(gfx.kDrawModeXOR)
	selectionSprite:setZIndex(zIndex + 1)
	selectionSprite:moveTo(px, py - height // 2 + rowHeight // 2)
	selectionSprite:setVisible(false)
	selectionSprite:add()

	local a = {
		selectedIndex = 1,
		items = items,
		width = width,
		rowHeight = rowHeight,
		padding = padding,
		fgColor = fgColor,
		bgColor = bgColor,
		font = font,
		menuSprite = sprite,
		selectionSprite = selectionSprite
	}
	setmetatable(a, menu)
	a:updateImage()

	menu.menus[menuId] = a
	return a
end


function menu.setActiveMenu(menuId)
	if menu.activeMenu ~= nil then
		menu.activeMenu:setVisible(false)
		menu.activeMenu = nil
	end

	if menuId ~= nil then
		local m = menu.menus[menuId]
		if m ~= nil then
			m:setVisible(true)
			menu.activeMenu = m
			return m
		else
			print(string.format("Error: Menu with id '%s' is not registered", menuId))
		end
	end
end


function menu.getMenu(menuId)
	local m = menu.menus[menuId]
	if m ~= nil then
		return m
	else
		print(string.format("Error: Menu with id '%s' is not registered", menuId))
	end
end


function menu.isMenuActive(menuId)
	local m = menu.menus[menuId]
	if m ~= nil then
		return menu.activeMenu == m
	else
		print(string.format("Error: Menu with id '%s' is not registered", menuId))
	end
end


function menu:isActive()
	return self == menu.activeMenu
end


function menu:setVisible(visible)
	local zIndex = 32000
	if not visible then zIndex = -32000 end
	self.menuSprite:setZIndex(zIndex)
	self.selectionSprite:setZIndex(zIndex + 1)
	self.menuSprite:setVisible(visible)
	self.selectionSprite:setVisible(visible)
end


function menu:moveSelection(offset)
	self:setSelection(self.selectedIndex + offset)
end


function menu:setSelection(newIndex)
	local numItems = #self.items
	self.selectedIndex = clamp(newIndex, 1, numItems)

	local px, py = self.menuSprite:getPosition()
	local height = self.rowHeight * numItems
	local yOffset = math.floor((self.selectedIndex - 0.5) * self.rowHeight)

	self.selectionSprite:moveTo(px, py - height // 2 + yOffset)
end


-- keepActive will force the menu to stay active when a selection is made
function menu:updateAndGetAnySelection(keepActive)
	if not self:isActive() then return nil end

	if playdate.buttonJustPressed(playdate.kButtonB) then
		menu.setActiveMenu(nil)
		return nil
	end

	if playdate.buttonJustPressed(playdate.kButtonUp) then self:moveSelection(-1) end
	if playdate.buttonJustPressed(playdate.kButtonDown) then self:moveSelection(1) end
	if playdate.buttonJustPressed(playdate.kButtonA) then
		if not keepActive then menu.setActiveMenu(nil) end
		return self.selectedIndex
	end

	return nil
end


function menu:updateImage()
	local image = self.menuSprite:getImage()
	image:clear(self.bgColor)
	gfx.lockFocus(image)
	gfx.setImageDrawMode(gfx.kDrawModeFillBlack)

	-- draw each piece of text
	local items = self.items
	local cnt = #items
	for i = 1, cnt do
		local x, y = self.padding + self.width // 2, (i-1) * self.rowHeight + self.padding
		local text = items[i]
		self.font:drawTextAligned(text, x, y, kTextAlignment.center)
	end

	gfx.unlockFocus()
end