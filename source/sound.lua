-- Playdate SDK
import "CoreLibs/object"

sound = {}
sound.__index = sound

sound.samples = {}

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
		print(string.format("Error: Sound with id '%s' does not exist", sampleId))
	end
end