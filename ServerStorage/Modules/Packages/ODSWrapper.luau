local DataStoreService = game:GetService("DataStoreService")

local function try(func)
	local success, message
	for i = 1, 3 do
		success, message = pcall(func)
		if success then
			return true, nil
		end
	end

	return success, message
end

local ODSWrapper = {}
ODSWrapper.__index = ODSWrapper

function ODSWrapper.new(dataStoreName)
	local orderedDataStore : OrderedDataStore = DataStoreService:GetOrderedDataStore(dataStoreName)
	
	local self = setmetatable({}, ODSWrapper)
	self.OrderedDataStore = orderedDataStore
	return self
end

function ODSWrapper:SetAsync(key, value)
	local success, message = try(function()
		self.OrderedDataStore:SetAsync(key, value)
	end)
	
	assert(success, message)
end

function ODSWrapper:GetSortedAsync(ascending, pageSize) : DataStorePages
	local pages
	local success, message = try(function()
		pages = self.OrderedDataStore:GetSortedAsync(ascending, pageSize)
	end)
	assert(success, message)
	
	return pages
end

return ODSWrapper
