jitterTable = {}
jitterTable.__index = jitterTable

-- A table that stores a series of random direction vectors
-- that can be used to jitter vertices of polygons, lines etc.
-- Because the data is static, it can be used for animated
-- data as long as the sample index is consistent between
-- frames, or for a more random effect, different samples can
-- be used to simulate noise etc.

-- TODO: Should this just be a single instance instead of having a new function?


-- Make a new jitterTable
function jitterTable.new(numSamples)
	local samples = table.create(numSamples * 2, 0)
	for i = 1, numSamples * 2 do
		local angle = math.random() * math.pi * 2
		local x, y = math.sin(angle), math.cos(angle)
		samples[2*i-1] = x
		samples[2*i] = y
	end

	local a = {
		numSamples = numSamples,
		nextSampleIdx = 1,
		samples = samples
	}
	setmetatable(a, jitterTable)

	return a
end


function jitterTable:getAt(i, scale)
	scale = scale or 1.0

	return self.samples[2*i-1] * scale, self.samples[2*i] * scale
end


function jitterTable:get(scale)
	scale = scale or 1.0

	local i = self.nextSampleIdx * 2
	if self.nextSampleIdx == self.numSamples then
		self.nextSampleIdx = 1
	else
		self.nextSampleIdx += 1
	end
	return self.samples[i-1] * scale, self.samples[i] * scale
end


function jitterTable:randomizeNextSampleIndex()
	self.nextSampleIdx = math.random(1, self.numSamples)
end