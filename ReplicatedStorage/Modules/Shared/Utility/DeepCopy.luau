local function deepCopy(original)
	if type(original) ~= "table" then
		return original
	end

	local copy = {}

	for key, value in original do
		copy[deepCopy(key)] = deepCopy(value)
	end

	return copy
end

return deepCopy