-- The function used for deep copying a table
local function deepCopy(original)
	-- Define the new table for the copy
	local copy = {}

	-- Loop through the original table to clone
	for key, value in original do
		-- If the type of the value is a table, deep copy it to the key (index)
		-- Else (or) the type isn't a table, assign the default value to the index instead
		copy[key] = if type(value) == "table" then deepCopy(value) else value
	end

	-- Return the finalized copy of the deep cloned table
	return copy
end

local MiddlewareData = {}
MiddlewareData.__index = MiddlewareData

function MiddlewareData.new(data, key)
	local self = setmetatable({}, MiddlewareData)
	self._data = if typeof(data) == "table" then deepCopy(data) else data
	self._key = key

	return self
end

function MiddlewareData:GetData()
	return if typeof(self._data) == "table" then deepCopy(self._data) else self._data
end

function MiddlewareData:GetKey()
	return self._key
end

function MiddlewareData:SetData(newData)
	self._data = if typeof(newData) == "table" then deepCopy(newData) else newData
end

return MiddlewareData
