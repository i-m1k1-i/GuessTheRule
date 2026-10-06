local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Modules.Packages

local Promise = require(Packages.Promise)
local GoodSignal = require(Packages.Signals.GoodSignal)

local MiddlewareData = require(script.MiddlewareData)

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

local DataStoreWrapper = {}
DataStoreWrapper.MiddlewareFunction = require(script.MiddlewareFunction)
DataStoreWrapper.Mock = require(script.MockDataStoreWrapper)
DataStoreWrapper.__index = DataStoreWrapper

DataStoreWrapper.OnDataStoreCreated = GoodSignal.new()

function DataStoreWrapper.new(dataStoreName, middleware)
	if not middleware then
		middleware = {}
	end
	assert(dataStores[dataStoreName] == nil, `DataStore {dataStoreName} has already been created, use GetInstance instead.`)

	local self = setmetatable({}, DataStoreWrapper)
	self.DataStoreName = dataStoreName
	self.GlobalDataStore = DataStoreService:GetDataStore(dataStoreName)
	self.Middleware = middleware
	
	DataStoreWrapper.OnDataStoreCreated:Fire(self)
	
	dataStores[dataStoreName] = self
	return self
end

function DataStoreWrapper.GetInstance(dataStoreName)
	if dataStores[dataStoreName] then
		return dataStores[dataStoreName]
	end
	
	local runningThread = coroutine.running()
	
	local thread = task.delay(5, task.spawn, runningThread)
	
	local connection
	connection = DataStoreWrapper.OnDataStoreCreated:Connect(function(dataStore)
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

function DataStoreWrapper:GetAsync(key)
	local data
	local success, message = try(function()
		data = self.GlobalDataStore:GetAsync(key)
	end)
	assert(success, message)

	local success, message = Promise.new(function(resolve)
		for _, middlewareFunction in self.Middleware do
			if typeof(middlewareFunction) ~= "table" then
				error(`Expected middleware function object to be a table, got {typeof(middlewareFunction)}`)
			end
			
			local middlewareData = MiddlewareData.new(data, key)
			middlewareFunction:Call(middlewareData)
			data = middlewareData:GetData()
		end
		
		resolve()
	end):await()
	
	assert(success, tostring(message))
	
	return data
end

function DataStoreWrapper:SetAsync(key, data)
	local success, message = try(function()
		self.GlobalDataStore:SetAsync(key, data)
	end)
	
	assert(success, message)
end

function DataStoreWrapper:UpdateAsync(key, callback)
	local success, message = try(function()
		self.GlobalDataStore:UpdateAsync(key, callback)
	end)

	assert(success, message)
end

function DataStoreWrapper:RemoveAsync(key)
	local success, message = try(function()
		self.GlobalDataStore:RemoveAsync(key)
	end)

	assert(success, message)
end

return DataStoreWrapper
