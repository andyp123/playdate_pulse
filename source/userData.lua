-- Playdate SDK
import "CoreLibs/object"

userData = {}
userData.__index = userData

local userDataFilename <const> = "data/userdata"

local maxUserRecords <const> = 10
local maxRunRecords <const> = 10

-- Stage width * height (12 * 7) to make level select grid, so 84 stages
local numStages <const> = 84

-- Used to fill time for stages that haven't been cleared
-- The time limit is 10 seconds, but items can increase this a little
local nonClearTime <const> = 20.0
local defaultUserName <const> = "Player" -- can we get a name from the playdate?


-- Init data with empty
function userData.init()
	userData.userRecords = {}
	userData.runRecords = {}
	userData.stageTimeRecords = table.create(numStages)
	for i = 1, numStages do
		userData.stageTimeRecords[i] = {
			name = "PULSE",
			time = nonClearTime,
		}
	end
end

userData.init()


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


function userData.trySaveRunRecord(name, stagesCleared, totalTime, livesUsed)
	if stagesCleared < 1 then return end

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
		userData.saveDataToFile()
	elseif numRecords < maxRunRecords then
		-- no record was added, but can add new record at end of table
		local record = userData.makeRunRecord(name, stagesCleared, totalTime, livesUsed)
		userData.runRecords[numRecords + 1] = record
		userData.saveDataToFile()
	end

	return newRecord
end


function userData.getStageTimeRecord(stageId)
	if stageId < 1 or stageId > numStages then
		return {name = "PULSE", time = nonClearTime}
	end

	return userData.stageTimeRecords[stageId]
end


function userData.tryAddUser(name)
	if userData.userRecords[name] == nil and tablelength(userData.userRecords) < maxUserRecords then
		local record = userData.makeUserRecord(name)
		userData.userRecords[name] = record
		return record
	end

	print(string.format("Error: Could not add user with name '%s'", name))
	return nil
end


function userData.tryRemoveUser(name)
	if userData.userRecords[name] ~= nil then
		table.remove(userData.userRecords, name)
	end
end


function userData.getUserRecord(name)
	if userData.userRecords[name] ~= nil then
		return userData.userRecords[name]
	end

	print(string.format("Error: Could not find user with name '%s'", name))
	return nil
end


function userData.renameUser(name, newName)
	local userRecords = userData.userRecords
	if userRecords[name] ~= nill and userRecords[newName] == nil then
		local record = userRecords[name]
		record.name = newName
		userRecords[newName] = record
		userRecords[name] = nil

		-- Update run times
		local runRecords = userData.runRecords
		for i = 1, maxRunRecords do
			if runRecords[i].name == name then
				runRecords[i].name = newName
			end
		end
		-- Update individual stage time records
		local stageTimeRecords = userData.stageTimeRecords
		for i = 1, numStages do
			if stageTimeRecords[i].name == name then
				stageTimeRecords[i].name = newName
			end
		end
	end
end


function userData.loadDataFromFile()
	local data = playdate.datastore.read(userDataFilename)

	if data == nil then
		print(string.format("Error: Could not load user data from '%s'", userDataFilename))

		-- TODO: Remove this and save only when a user is added?
		userData.saveDataToFile()
	else
		-- Copy any user and run records from the loaded data
		-- Note that I'm doing no real validation of the data here...
		if data.userRecords ~= nil then
			local userRecords = {}
			local i = 0
			for name, record in ipairs(data.userRecords) do
				if i > maxUserRecords then break end
				userRecords[name] = record
				i += 1
			end
			userData.userRecords = userRecords
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
		userRecords = userData.userRecords,
		runRecords = userData.runRecords,
		stageTimeRecords = userData.stageTimeRecords
	}

	print(string.format("Saving user data to '%s'", userDataFilename))
	playdate.datastore.write(data, userDataFilename, false)
end