-- Playdate SDK
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"

-- Pulse
import "global"
import "userData"

local gfx <const> = playdate.graphics

settings = {}
settings.__index = settings


local cursorWidth <const> = 380
local cursorHeight <const> = 32
local entrySpacing <const> = 38
local maxEntries <const> = 5 -- todo: sync with userData?
local iconTable = gfx.imagetable.new("images/menu_icons")

local entryStartHeight = 56

function settings.init()
	local img = gfx.image.new(cursorWidth, cursorHeight, gfx.kColorWhite)
	local sprite = gfx.sprite.new(img)
	sprite:setImageDrawMode(gfx.kDrawModeXOR)
	sprite:setCenter(0, 0)
	sprite:moveTo(10, entryStartHeight - 5)
	sprite:add()
	sprite:setVisible(false)
	sprite:setZIndex(29000)

	settings.cursorSprite = sprite
	settings.selectedIndex = 1
end

settings.init()


function settings.setCursorVisible(visible)
	settings.cursorSprite:setVisible(visible)
end


function settings.update()
	local cursorSprite = settings.cursorSprite
	local my = 0
	if playdate.buttonJustPressed(playdate.kButtonUp)    then my = -1 end
	if playdate.buttonJustPressed(playdate.kButtonDown)  then my = 1 end

	if my ~= 0 then
		local pi = settings.selectedIndex
		local ni = clamp(pi + my, 1, 5)
		if ni ~= pi then
			cursorSprite:moveBy(0, entrySpacing * my)
			settings.selectedIndex = ni
			sound.play("MENU_MOVE")
		end
	end
end


function settings.drawToImage(image, font, fontSmall)
	image:clear(gfx.kColorBlack)
	gfx.lockFocus(image)

	-- Header
	gfx.setColor(gfx.kColorWhite)
	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	font:drawTextAligned("USER SETTINGS", 200, 10, kTextAlignment.center)

	local y = entryStartHeight
	local userRecords = userData.userRecords
	local activeUserId = userData.activeUserId

	gfx.setLineWidth(3)
	gfx.setStrokeLocation(gfx.kStrokeInside)

	for i = 1, maxEntries do
		gfx.setImageDrawMode(gfx.kDrawModeFillWhite)

		local record = userRecords[i]
		if record == nil or record.name == nil then
			fontSmall:drawTextAligned("[  NO DATA  ]", 200, y, kTextAlignment.center)
		else

			-- Draw around active user only
			if i == activeUserId then
				gfx.drawRect(10, y - 5, cursorWidth, cursorHeight)
				iconTable:drawImage(4, 40 - 22, y + 2)
			end

			-- Name
			fontSmall:drawTextAligned(record.name, 40, y, kTextAlignment.left)

			local bestRun = record.bestRun

			if bestRun ~= nil then
				-- Stage cleared
				local x_stage = 180
				fontSmall:drawText(string.format("%d", bestRun.stagesCleared), x_stage, y)

				-- Time
				local x_time = 240
				local tu = getTimeUnits(bestRun.totalTime)
				local text = string.format("%.2d:%.2d.%.3d", tu.minutes, tu.seconds, tu.milliseconds)
				fontSmall:drawText(text, x_time, y)

				-- Retries
				x_retries = 365
				fontSmall:drawText(bestRun.livesUsed, x_retries, y)

				-- Icons
				gfx.setImageDrawMode(gfx.kDrawModeCopy)
				if bestRun.stagesCleared == 84 then
					iconTable:drawImage(1, x_stage - 22, y + 1)
				end
				iconTable:drawImage(2, x_time - 22, y + 1)
				iconTable:drawImage(3, x_retries - 22, y + 1)
			end
		end

		y += entrySpacing
	end

	gfx.unlockFocus()
end