-- Playdate SDK
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/keyboard"

-- Pulse
import "global"
import "stage" -- need constants from here
import "userData"

local gfx <const> = playdate.graphics
local keyboard <const> = playdate.keyboard

textEntry = {}
textEntry.__index = textEntry

function textEntry.init(font)
	textEntry.image = gfx.image.new(250, 240, gfx.kColorBlack)
	textEntry.sprite = gfx.sprite.new(textEntry.image)
	textEntry.sprite:setCenter(0, 0)
	textEntry.sprite:moveTo(0, 0)
	textEntry.sprite:setVisible(false)
	textEntry.sprite:add()
	textEntry.maxTextWidth = 100

	textEntry.textEntryFinishedCallback = nil
	textEntry.textEntryCanceledCallback = nil
	textEntry.font = font
end


function textEntry.refreshSpriteImage()
	textEntry.image:clear(gfx.kColorBlack)
	gfx.lockFocus(textEntry.image)

	local x, y = 20, 50
	local font = textEntry.font

	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	font:drawText("Enter a name:\n", x, y)

	y += 32
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(x, y, textEntry.maxTextWidth + 20, 40)

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
		keyboard.show("")
		textEntry.refreshSpriteImage()
	else
		keyboard.hide()
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
	local font = textEntry.font
	textEntry.sprite:setVisible(true)
	keyboard.text = textEntry.getValidatedText(keyboard.text, textEntry.maxTextWidth, font)
	textEntry.refreshSpriteImage()
end


function textEntry.textEntryFinished(ok)
	textEntry.setVisible(false)

	if ok then
		if textEntry.textEntryFinishedCallback ~= nil then
			local text = keyboard.text
			if text == "" then text = "Player" end
			textEntry.textEntryFinishedCallback(text)
		end
	else
		if textEntry.textEntryCanceledCallback ~= nil then
			textEntry.textEntryCanceledCallback()
		end
	end

	gfx.sprite.redrawBackground()
end