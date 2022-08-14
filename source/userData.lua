-- Playdate SDK
import "CoreLibs/object"

userData = {}
userData.__index = userData

local userDataFilename <const> = "data/userdata"

local numStages <const> = 84 -- Stage width * height (12 * 7) to make level select grid, so 84 stages
local maxUserRecords <const> = 5 -- number of records that can be shown on the user settings screen
local maxRunRecords <const> = 6 -- number of records that can be displayed on the best runs screen

-- Used to fill time for stages that haven't been cleared
-- The time limit is 10 seconds, but items can increase this a little
local nonClearTime <const> = 20.0
local defaultUserName <const> = "Player"

-- For testing, generating dummy highscores etc.
local dummyUserNames = {
	"Falcon",
	"Pigeon",
	"Cheetah",
	"Tortoise",
	"Sloth",
	"Slow Loris",
}

-- Main data
userData.stageTimeRecords = {}
userData.userRecords = {}
userData.runRecords = {}
userData.activeUserId = 1 -- There must be at least one user record


function userData.makeUserRecord(name)
	local stageTimes = table.create(numStages)
	for i = 1, numStages do
		stageTimes[i] = -1.0
	end

	local record = {
		name = name,
		bestRun = nil,
		stageTimes = stageTimes
	}

	return record
end


function userData.makeRunRecord(name, stagesCleared, totalTime, livesUsed)
	local record = {
		name = name,
		stagesCleared = stagesCleared,
		totalTime = totalTime,
		livesUsed = livesUsed
	}

	return record
end


function userData.generateDummyRunData()
	local runRecords = {}
	local names = dummyUserNames

	for i = 1, maxRunRecords do
		local name = names[i % #names + 1]
		local stagesCleared = clamp((maxRunRecords - i + 1) * 4, 1, 42)
		local totalTime = 10.0 * stagesCleared
		local livesUsed = math.random(0, maxRunRecords - i)
		runRecords[i] = userData.makeRunRecord(name, stagesCleared, totalTime, livesUsed)
	end

	return runRecords
end


function userData.generateDummyUserData()
	local userRecords = {}
	local names = dummyUserNames

	for i = 1, maxUserRecords do
		local name = names[i % #names + 1]
		local record = userData.makeUserRecord(name)
		record.bestRun = userData.makeRunRecord(name, 84, 314.159, 7)
		userRecords[i] = record
	end

	return userRecords
end



-- For user records only, since sum of random user best times doesn't make sense
function userData.getSumOfStageTimes(times)
	local totalTime = 0.0

	for _, time in ipairs(times) do
		if time <= 0.0 then
			totalTime += nonClearTime
		else
			totalTime += time
		end
	end

	return totalTime
end


function userData.trySaveStageTime(stageId, name, clearTime)
	if stageId < 1 or stageId > numStages then return end
	
	local stageRecord = userData.stageTimeRecords[stageId]
	if clearTime < stageRecord.time then
		stageRecord.name = name
		stageRecord.time = clearTime
		userData.saveDataToFile()
		return true
	end

	return false
end


function userData.trySaveRunRecord(name, stagesCleared, totalTime, livesUsed, saveFile)
	if stagesCleared < 1 then return end
	if saveFile == nil then saveFile = true end

	-- If the run cleared more stages, or got a faster time, write a new record to the table
	local newRecord = false
	for i, runRecord in ipairs(userData.runRecords) do
		if stagesCleared < runRecord.stagesCleared then goto continue end
		if stagesCleared > runRecord.stagesCleared or totalTime < runRecord.totalTime then
			local record = userData.makeRunRecord(name, stagesCleared, totalTime, livesUsed)
			table.insert(userData.runRecords, i, record)
			newRecord = true
			break
		end
		::continue::
	end

	local numRecords = tablelength(userData.runRecords)
	if newRecord then
		-- new record was inserted before an existing record
		if numRecords > maxRunRecords then
			userData.runRecords[maxRunRecords + 1] = nil
		end
		if saveFile then userData.saveDataToFile() end
	elseif numRecords < maxRunRecords then
		-- no record was added, but can add new record at end of table
		local record = userData.makeRunRecord(name, stagesCleared, totalTime, livesUsed)
		userData.runRecords[numRecords + 1] = record
		if saveFile then userData.saveDataToFile() end
	end

	return newRecord
end


function userData.getStageTimeRecord(stageId)
	if stageId < 1 or stageId > numStages then
		return {name = "PULSE", time = nonClearTime}
	end

	return userData.stageTimeRecords[stageId]
end


function userData.setActiveUser(userId)
	if userData.activeUserId ~= userId and userData.userRecords[userId] ~= nil then
		userData.activeUserId = userId
		userData.saveDataToFile()
		return true
	end

	return false
end


function userData.getActiveUser()
	return userData.userRecords[userData.activeUserId]
end


function userData.getActiveUserName()
	local user =  userData.userRecords[userData.activeUserId]
	if user ~= nil then
		return user.name
	else
		return "NO USER"
	end
end


function userData.doesUserNameExist(name)
	local userRecords = userData.userRecords

	for i, record in ipairs(userRecords) do
		if record.name == name then
			return true
		end
	end

	return false
end


function userData.deleteUser(userId)
	local userRecords = userData.userRecords

	if userRecords[userId] ~= nil then
		table.remove(userRecords, userId)
		userData.saveDataToFile()
		return true
	end

	return false
end


function userData.addOrRenameUser(userId, name)
	-- Can't add or rename if another user with the new name exists
	if userId < 1 or userId > maxUserRecords or userData.doesUserNameExist(name) then
		return false
	end

	local record = userData.userRecords[userId]
	if record == nil then -- Add new user
		record = userData.makeUserRecord(name)
		userData.userRecords[userId] = record
	else -- Rename existing user
		local prevName = record.name
		record.name = name

		if record.bestRun ~= nil then
			record.bestRun.name = name
		end

		-- Rename user in high score tables etc? Could potentially cheat this way?
		-- Update run times
		local runRecords = userData.runRecords
		for i = 1, maxRunRecords do
			if runRecords[i].name == prevName then
				runRecords[i].name = name
			end
		end
		-- Update individual stage time records
		local stageTimeRecords = userData.stageTimeRecords
		for i = 1, numStages do
			if stageTimeRecords[i].name == prevName then
				stageTimeRecords[i].name = name
			end
		end
	end

	userData.saveDataToFile()
	return true
end


function userData.loadDataFromFile()
	local data = playdate.datastore.read(userDataFilename)

	if data == nil then
		print(string.format("Error: Could not load user data from '%s'", userDataFilename))

		userData.saveDataToFile()
	else
		-- Copy any user and run records from the loaded data
		-- Note that I'm doing no real validation of the data here...
		if data.userRecords ~= nil then
			local userRecords = {}
			for i, record in ipairs(data.userRecords) do
				if i > maxUserRecords then break end
				userRecords[i] = record
			end
			userData.userRecords = userRecords
		end

		local userId = data.activeUserId
		if userId ~= nil and userId <= #userData.userRecords then
			userData.activeUserId = userId
		else
			userData.activeUserId = 1
		end

		if data.runRecords ~= nil then
			local runRecords = {}
			for i, record in ipairs(data.runRecords) do
				if i > maxRunRecords then break end
				runRecords[i] = record
			end
			userData.runRecords = runRecords
		end

		-- Modify directly as time records are initialized with default records
		if data.stageTimeRecords ~= nil then
			local records = data.stageTimeRecords
			for i = 1, numStages do
				if records[i] ~= nil then
					userData.stageTimeRecords[i] = records[i]
				end
			end
		end

		print(string.format("Loaded user data from '%s'", userDataFilename))
	end
end


function userData.saveDataToFile()
	local data = {
		activeUserId = userData.activeUserId,
		userRecords = userData.userRecords,
		runRecords = userData.runRecords,
		stageTimeRecords = userData.stageTimeRecords
	}

	print(string.format("Saving user data to '%s'", userDataFilename))
	playdate.datastore.write(data, userDataFilename, false)
end


-- Init data with empty
function userData.init()
	userData.userRecords = userData.generateDummyUserData()
	userData.runRecords = userData.generateDummyRunData()
	userData.stageTimeRecords = table.create(numStages)
	for i = 1, numStages do
		userData.stageTimeRecords[i] = {
			name = "PULSE",
			time = nonClearTime,
		}
	end

	userData.activeUserId = 1
end

userData.init()
