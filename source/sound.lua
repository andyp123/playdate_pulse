-- Playdate SDK
import "CoreLibs/object"

sound = {}
sound.__index = sound

sound.samples = {}
sound.channels = {} -- channels for adding effects to sounds


function sound.loadSamples(samplePaths)
	if samplePaths == nil then return end

	local snd = playdate.sound
	local samples = sound.samples
	for k, v in pairs(samplePaths) do
		local sample, err = snd.sampleplayer.new(v)
		if sample ~= nil then
			samples[k] = sample
			-- print(string.format("Loaded '%s' as [%s]", v, k))
		else
			print(string.format("Error: Could not load sample (%s)", err))
		end	
	end
end


function sound.play(sampleId)
	local sample = sound.samples[sampleId]
	if sample ~= nil then
		sample:play()
	else
		print(string.format("Error: Sample with id '%s' does not exist", sampleId))
	end
end


-- create channel if it doesn't exist and return
function sound.getChannel(channelId)
	channel = sound.channels[channelId]
	if channel == nil then
		channel = playdate.sound.channel.new()
		sound.channels[channelId] = channel
	end
	return channel
end


function sound.addSampleToChannel(sampleId, channelId)
	local channel = sound.channels[channelId]
	local sample = sound.samples[sampleId]
	if sample ~= nil and channel ~= nil then
		channel:addSource(sample)
	elseif sample == nil then
		print(string.format("Error: Sample with id '%s' does not exist", sampleId))
	else
		print(string.format("Error: Channel with id '%s' does not exist", channelId))
	end
end


function sound.removeChannel(channelId)
	local channel = sound.channels[channelId]
	if channel ~= nil then
		channel:remove()
		sound.channels[channelId] = nil
	end
end
