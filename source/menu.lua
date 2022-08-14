-- Playdate SDK
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"

-- Pulse
import "sound"

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


function menu.getActiveMenu()
	return menu.activeMenu
end


function menu.setActiveMenu(menuId)
	if menu.activeMenu ~= nil then
		menu.activeMenu:setVisible(false)
		menu.activeMenu = nil
	end

	if menuId ~= nil then
		local m = menu.menus[menuId]
		if m ~= nil then
			m:setSelection(1)
			m:setVisible(true)
			menu.activeMenu = m
			sound.play("MENU_MOVE")
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
	local item = self.items[self.selectedIndex + offset]
	if item ~= nil then
		-- Skip dividers (won't skip multiple, but why would you have multiple?)
		if item == "---" then offset *= 2 end
		-- Set and do final validation of selection
		self:setSelection(self.selectedIndex + offset, true)
	end
end


function menu:setSelection(newIndex, playSound)
	local originalIndex = self.selectedIndex
	local numItems = #self.items
	self.selectedIndex = clamp(newIndex, 1, numItems)

	local px, py = self.menuSprite:getPosition()
	local height = self.rowHeight * numItems
	local yOffset = math.floor((self.selectedIndex - 0.5) * self.rowHeight)

	self.selectionSprite:moveTo(px, py - height // 2 + yOffset)

	if playSound and originalIndex ~= self.selectedIndex then
		sound.play("MENU_MOVE")
	end
end


-- keepActive will force the menu to stay active when a selection is made
function menu:updateAndGetAnySelection(keepActive)
	if not self:isActive() then return nil end

	if playdate.buttonJustPressed(playdate.kButtonB) then
		menu.setActiveMenu(nil)
		sound.play("MENU_BACK")
		return nil
	end

	if playdate.buttonJustPressed(playdate.kButtonUp) then self:moveSelection(-1) end
	if playdate.buttonJustPressed(playdate.kButtonDown) then self:moveSelection(1) end
	if playdate.buttonJustPressed(playdate.kButtonA) then
		if not keepActive then menu.setActiveMenu(nil) end
		sound.play("MENU_SELECT")
		return self.selectedIndex
	end

	return nil
end


function menu:updateImage()
	local image = self.menuSprite:getImage()
	image:clear(self.bgColor)
	gfx.lockFocus(image)
	gfx.setImageDrawMode(gfx.kDrawModeFillBlack)

	-- in case there are dividers
	local halfWidth = self.width * 0.5 - self.padding
	local halfHeight = self.rowHeight * 0.5
	gfx.setLineWidth(3)

	-- draw each piece of text
	local items = self.items
	local cnt = #items
	for i = 1, cnt do
		local x, y = self.padding + self.width // 2, (i-1) * self.rowHeight + self.padding
		local text = items[i]
		if text == "---" then
			gfx.drawLine(x - halfWidth, y + halfHeight, x + halfWidth, y + halfHeight)
		else
			self.font:drawTextAligned(text, x, y, kTextAlignment.center)
		end
	end

	gfx.unlockFocus()
end