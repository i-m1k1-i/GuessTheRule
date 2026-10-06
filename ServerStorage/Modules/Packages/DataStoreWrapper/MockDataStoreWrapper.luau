local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Modules.Packages

local Promise = require(Packages.Promise)
local GoodSignal = require(Packages.Signals.GoodSignal)
local MiddlewareData = require(script.Parent.MiddlewareData)

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

local dataStores = {}

local MockDataStoreWrapper = {}
MockDataStoreWrapper.__index = MockDataStoreWrapper

MockDataStoreWrapper.OnDataStoreCreated = GoodSignal.new()

function MockDataStoreWrapper.new(dataStoreName, middleware)
	if not middleware then
		middleware = {}
	end
	assert(dataStores[dataStoreName] == nil, `DataStore {dataStoreName} has already been created, use GetInstance instead.`)

	local self = setmetatable({}, MockDataStoreWrapper)
	self.DataStoreName = dataStoreName
	self.GlobalDataStore = {}
	self.Middleware = middleware
	
	MockDataStoreWrapper.OnDataStoreCreated:Fire(self)
	
	dataStores[dataStoreName] = self
	return self
end

function MockDataStoreWrapper.GetInstance(dataStoreName)
	if dataStores[dataStoreName] then
		return dataStores[dataStoreName]
	end
	
	local runningThread = coroutine.running()
	
	local thread = task.delay(5, task.spawn, runningThread)
	
	local connection
	connection = MockDataStoreWrapper.OnDataStoreCreated:Connect(function(dataStore)
		if dataStore.DataStoreName == dataStoreName then
			task.cancel(thread)
			task.spawn(runningThread)
		end
	end)
		
	local dataStore = coroutine.yield()
	connection:Disconnect()
	assert(dataStore, "Could not get data store object")
	
	return dataStore
end

function MockDataStoreWrapper:GetAsync(key)
	local data
	local success, message = try(function()
		data = self.GlobalDataStore[key]
	end)
	assert(success, message)

	local success, message = pcall(function()
		for _, middlewareFunction in self.Middleware do
			if typeof(middlewareFunction) ~= "table" then
				error(`Expected middleware function object to be a table, got {typeof(middlewareFunction)}`)
			end

			local middlewareData = MiddlewareData.new(data, key)
			middlewareFunction:Call(middlewareData)
			data = middlewareData:GetData()
		end
	end)

	assert(success, message)

	return data
end

function MockDataStoreWrapper:SetAsync(key, data)
	--error(`Mock data store cannot save data. Key: {key}`)
	warn(`Mock data store cannot save data. Did not do anything. Key: {key}`)
end

function MockDataStoreWrapper:UpdateAsync(key, callback)
	--error(`Mock data store cannot save data. Key: {key}`)
	warn(`Mock data store cannot save data. Did not do anything. Key: {key}`)
end

function MockDataStoreWrapper:RemoveAsync(key)
	local success, message = try(function()
		self.GlobalDataStore[key] = nil
	end)

	assert(success, message)
end

return MockDataStoreWrapper
