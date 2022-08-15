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


-- Used to populate the high score table
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


-- Used only for testing
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


-- Clear data, but leave a single usable user record
function userData.generateEmptyUserData()
	local userRecords = table.create(maxUserRecords)
	userRecords[1] = userData.makeUserRecord(defaultUserName)

	for i = 2, maxUserRecords do
		userRecords[i] = {}
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


-- Note: These functions will always save for the active user
function userData.trySaveRunRecord(stagesCleared, totalTime, livesUsed)
	local newPersonalBest =  userData.trySaveUserRunRecord(stagesCleared, totalTime, livesUsed)
	local newRunRank = userData.trySaveGlobalRunRecord(stagesCleared, totalTime, livesUsed)

	if newPersonalBest or newRunRank > 0 then
		userData.saveDataToFile()
	end

	-- can use these to trigger events etc.
	return newPersonalBest, newRunRank
end


-- Shouldn't use this externally without manually saving
function userData.trySaveUserRunRecord(stagesCleared, totalTime, livesUsed)
	local userRecord = userData.getActiveUser()
	local runRecord = userRecord.bestRun

	if runRecord == nil or stagesCleared > runRecord.stagesCleared or
	  (stagesCleared == runRecord.stagesCleared and totalTime < runRecord.totalTime) then
		userRecord.bestRun = userData.makeRunRecord(userRecord.name, stagesCleared, totalTime, livesUsed)
		return true
	end

	return false
end


function userData.trySaveGlobalRunRecord(stagesCleared, totalTime, livesUsed)
	if stagesCleared < 1 then return 0 end

	local name = userData.getActiveUserName()

	-- If the run cleared more stages, or got a faster time, write a new record to the table
	local rank = 0
	for i, runRecord in ipairs(userData.runRecords) do
		if stagesCleared < runRecord.stagesCleared then goto continue end
		if stagesCleared > runRecord.stagesCleared or totalTime < runRecord.totalTime then
			local record = userData.makeRunRecord(name, stagesCleared, totalTime, livesUsed)
			table.insert(userData.runRecords, i, record)
			rank = i
			break
		end
		::continue::
	end

	local numRecords = tablelength(userData.runRecords)
	if rank > 0 then
		-- new record was inserted before an existing record
		if numRecords > maxRunRecords then
			userData.runRecords[maxRunRecords + 1] = nil
		end
	elseif numRecords < maxRunRecords then
		-- no record was added, but can add new record at end of table
		local record = userData.makeRunRecord(name, stagesCleared, totalTime, livesUsed)
		userData.runRecords[numRecords + 1] = record
		rank = numRecords + 1
	end

	return rank
end


function userData.getStageTimeRecord(stageId)
	if stageId < 1 or stageId > numStages then
		return {name = "PULSE", time = nonClearTime}
	end

	return userData.stageTimeRecords[stageId]
end


function userData.setActiveUser(userId)
	local user = userData.userRecords[userId]

	if userData.activeUserId ~= userId and user ~= nil and user.name ~= nil then
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
	local user = userData.userRecords[userData.activeUserId]

	if user == nil or user.name == nil then
		return "NO USER"
	else
		return user.name
	end
end


-- Mostly useful to check a named user exists
function userData.getUserIdFromName(name)
	local userRecords = userData.userRecords

	for i, record in ipairs(userRecords) do
		if record.name == name then
			return i
		end
	end

	return 0
end


function userData.getNumUserRecords()
	local userRecords = userData.userRecords
	local count = 0
	local firstUser = 0

	for i, record in ipairs(userRecords) do
		if record.name ~= nil then
			print(record.name)
			if firstUser == 0 then firstUser = i end
			count += 1
		end
	end

	return count, firstUser
end


function userData.deleteUser(userId)
	local userRecords = userData.userRecords
	local user = userRecords[userId]

	if user ~= nil and user.name ~= nil then
		userRecords[userId] = {}

		-- Make sure there is at least one user record, and it is active
		local userCount, firstUser = userData.getNumUserRecords()
		if userCount > 0 then
			userData.activeUserId = firstUser
		else
			userData.userRecords[1] = userData.makeUserRecord(defaultUserName)
			userData.activeUserId = 1
		end

		userData.saveDataToFile()
		return true
	end

	return false
end


function userData.addOrRenameUser(userId, name)
	-- Can't add or rename if another user with the new name exists
	if userId < 1 or userId > maxUserRecords or userData.getUserIdFromName(name) > 0 then
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
		-- Cheat: Rename self to score table name, then rename back. Will inherit scores...
		-- -- Update run times
		-- local runRecords = userData.runRecords
		-- for i = 1, maxRunRecords do
		-- 	if runRecords[i].name == prevName then
		-- 		runRecords[i].name = name
		-- 	end
		-- end
		-- -- Update individual stage time records
		-- local stageTimeRecords = userData.stageTimeRecords
		-- for i = 1, numStages do
		-- 	if stageTimeRecords[i].name == prevName then
		-- 		stageTimeRecords[i].name = name
		-- 	end
		-- end
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
	userData.userRecords = userData.generateEmptyUserData()
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
