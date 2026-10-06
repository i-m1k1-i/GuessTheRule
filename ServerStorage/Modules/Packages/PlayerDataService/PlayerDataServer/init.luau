--[[
PlayerDataServer

If you're using this module, make sure to follow do the following practice:
Whenever you release an update that modifies the player data schema, make sure to shutdown all servers
to avoid a specfic situiation from happening, where a player joins a new server, modifies data, then leaves
and joins an old server and that data is lost because the old server doesn't have the new schema.

Fixing this problem is difficult and may reduce the cleaniness of this module, however,
if this practice is too hard to follow, then i might try to solve it
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage.Modules.Packages
local ServerPackages = ServerStorage.Modules.Packages

local Promise = require(Packages.Promise)
local DataStoreWrapper = require(ServerPackages.DataStoreWrapper)
local PlayerDataUtil = require(Packages.PlayerDataUtil)
local GoodSignal = require(Packages.Signals.GoodSignal)

local PlayerWrapper = require(script.Parent.PlayerWrapper)
local DataTypes = require(script.Parent.DataTypes)
local Schemas = require(script.Parent.Schemas)
local MiddlewareTable = require(script.Parent.MiddlewareTable)

local PlayerDataServer = {}
PlayerDataServer.__index = PlayerDataServer
PlayerDataServer._instantiated = GoodSignal.new()

local PlayerDataManager = {}
PlayerDataManager.__index = PlayerDataManager
PlayerDataManager._initialized = GoodSignal.new()
PlayerDataManager.InstanceDestroyed = GoodSignal.new()
PlayerDataManager._instances = {}

function PlayerDataManager.new(playerWrapper)
	local playerDataServer = PlayerDataServer._instance

	local self = setmetatable({}, PlayerDataManager)
	self._playerWrapper = playerWrapper
	self._player = playerWrapper:GetPlayer()
	self._userId = playerWrapper:GetUserId()
	self._uniqueId = playerWrapper:GetUniqueId()
	self._key = `/{self._userId}`
	self._isSaving = false
	self._active = true
	self._isLoaded = false
	self._isLeaving = false
	self._lastSaveTime = DateTime.now().UnixTimestampMillis
	self._serverOnlyValues = {}
	self._playerDataFolder = nil :: Folder?
	self.OnSaveAttempt = GoodSignal.new()
	self.Destroyed = GoodSignal.new()

	self:_loadData()

	PlayerDataManager._instances[playerWrapper:GetUniqueId()] = self

	if playerWrapper:IsOffline() then
		self._playerWrapper:BeforeDestroy(function()
			self:_onLeaving()
		end)
	else
		task.spawn(function()
			while self._active do
				self:Save()
				task.wait(60)
			end
		end)

		task.spawn(function()
			if playerDataServer._isMockDataStore or playerDataServer._saveInStudio == false then
				return
			end

			while self._active do
				if DateTime.now().UnixTimestampMillis - self._lastSaveTime >= 600000 then
					self._player:Kick(`Your data has not been saving for the last 10 minutes, please rejoin.`)
				end
				task.wait(1)
			end
		end)
	end

	PlayerDataManager._initialized:Fire()
	return self
end

function PlayerDataManager.GetInstance(player : Player) : typeof(PlayerDataManager.new())
	if typeof(player) ~= "Instance" then
		error(`Expected Player to be an Instance, got {typeof(player)}`)
	end
	local playerWrapper = PlayerWrapper.GetInstance(player)
	local uniqueId = playerWrapper:GetUniqueId()

	local playerDataManager = PlayerDataManager._instances[uniqueId]
	if playerDataManager then
		-- If old one still exists then wait for it to destroy 
		if playerDataManager:IsLeaving() then
			playerDataManager.Destroyed:Wait()
		else
			return playerDataManager
		end
	end

	if not PlayerDataManager._instances[uniqueId] then
		local errorMessage
		local mainThread = coroutine.running()
		local connections = {}

		local thread = task.delay(5, function()
			if not PlayerDataManager._instances[uniqueId] then
				warn(`Could not get {player.Name}'s player data manager in 5 seconds, could yield indefinitely`)
			end
		end)

		local function goBackToMainThread()
			for _, connection in connections do
				connection:Disconnect()
			end

			task.cancel(thread)
			task.spawn(mainThread)
		end

		table.insert(connections, PlayerDataManager._initialized:Connect(function()
			if PlayerDataManager._instances[uniqueId] then
				goBackToMainThread()
			end
		end))

		table.insert(connections, player.AncestryChanged:Connect(function()
			if player.Parent == nil then
				errorMessage = `Player {player.Name} left the game before player data manager initialized`
				goBackToMainThread()
			end
		end))

		coroutine.yield()
		if not PlayerDataManager._instances[uniqueId] then
			error(errorMessage)
		end
	end

	return PlayerDataManager._instances[uniqueId]
end

function PlayerDataManager.GetOfflineInstance(offlinePlayer)
	return PlayerDataManager._instances[offlinePlayer:GetUniqueId()]
end

function PlayerDataManager:GetPlayerDataFolder()
	if self._isLeaving then
		error("Could not get player data folder as the player is leaving.")
	end

	return self._playerDataFolder
end

function PlayerDataManager:_loadData()
	local playerDataServer = PlayerDataServer.GetInstance()
	local uniqueId = self._uniqueId

	local success, message = Promise.new(function(resolve, reject)
		local data = playerDataServer:GetAsync(self._key) or {}
		if not self._active then
			error(`{uniqueId}'s player data manager got destroyed while loading data`)
		end

		self:_reconcileData(data, playerDataServer._schema)

		self._playerDataFolder = Instance.new("Folder")
		self._playerDataFolder.Name = self._playerWrapper:GetUniqueId()

		self:_createDataInstances(playerDataServer._schema, data, self._playerDataFolder)
		self._playerDataFolder:SetAttribute("DescendantsCount", #self._playerDataFolder:GetDescendants())

		if self._player then
			local metadataFolder = self._playerDataFolder._metadata
			metadataFolder.PlayerName.Value = self._player.Name
		end

		self._isLoaded = true
		self._playerDataFolder.Parent = playerDataServer._playersDataFolder
		resolve()
	end):await()

	if not success then
		if self._player then
			self._player:Kick(`Failed to load data: {message}`)
		end
		error(`Failed to load {if self._player then self._player else self._userId}'s data: {message}`)
	end

	self._syncedDataTable = self:GetDataTable(true)
	if RunService:IsStudio() then
		--print(`{if self._player then self._player else self._userId}'s data on load: `, self:GetDataTable())
	end
end

function PlayerDataManager:IsLeaving()
	return self._isLeaving
end

function PlayerDataManager:GetServerOnlyValue(path)
	return self._serverOnlyValues[path]
end

function PlayerDataManager:_reconcileData(dataTable, schemaTable, onlySavables)
	local function reconcile(dataTable, dataName, schemaDataInfo)
		local dataTypeInfo = DataTypes[schemaDataInfo.DataType]

		if onlySavables == true and schemaDataInfo.Save == false then
			dataTable[dataName] = nil
			return
		end

		if schemaDataInfo.DataType == "Table" then
			if typeof(dataTable[dataName]) ~= "table" then
				dataTable[dataName] = {}
			end
			self:_reconcileData(dataTable[dataName], schemaDataInfo.Schema, onlySavables)
			return
		end

		local success, message = dataTypeInfo.Validate(dataTable[dataName])
		if not success or schemaDataInfo.Save == false then
			if typeof(schemaDataInfo.DefaultValue) == "function" then
				dataTable[dataName] = schemaDataInfo.DefaultValue()
			elseif schemaDataInfo.DefaultValue ~= nil then
				dataTable[dataName] = schemaDataInfo.DefaultValue
			elseif typeof(dataTypeInfo.DefaultValue) == "function" then
				dataTable[dataName] = dataTypeInfo.DefaultValue()
			else
				dataTable[dataName] = dataTypeInfo.DefaultValue
			end
		end
	end


	local schemaType = schemaTable:GetType()
	if schemaType == "DataSchema" then
		for dataName, schemaDataInfo in schemaTable:GetSchema() do
			reconcile(dataTable, dataName, schemaDataInfo)
		end
	elseif schemaType == "ObjectSchema" then
		for dataName in dataTable do
			--self:_reconcileData(dataTable[dataName], )
			for childDataName, schemaDataInfo in schemaTable:GetSchema() do
				reconcile(dataTable[dataName], childDataName, schemaTable:GetSchema()[childDataName])
			end
		end
	end
end

function PlayerDataManager:_createDataInstances(schemaTable, dataTable, dataFolder)
	local function createDataInstance(dataTable, dataFolder, dataName, schemaDataInfo)
		local dataTypeInfo = DataTypes[schemaDataInfo.DataType]

		local childDataInstance = Instance.new(dataTypeInfo.ClassName)
		childDataInstance.Name = dataName
		if dataTypeInfo.Type == "table" then
			self:_createDataInstances(schemaDataInfo.Schema, dataTable[dataName], childDataInstance)
		else
			childDataInstance.Value = dataTable[dataName]
		end

		if schemaDataInfo.ServerOnly == true then
			self._serverOnlyValues[schemaDataInfo.Path] = childDataInstance
		else
			childDataInstance.Parent = dataFolder
		end
	end

	local schemaType = schemaTable:GetType()
	if schemaType == "DataSchema" then
		for dataName, schemaDataInfo in schemaTable:GetSchema() do
			createDataInstance(dataTable, dataFolder, dataName, schemaDataInfo)
		end
	elseif schemaType == "ObjectSchema" then
		for dataName in dataTable do
			local folder = Instance.new("Folder")
			folder.Name = dataName

			for childDataName, schemaDataInfo in schemaTable:GetSchema() do
				createDataInstance(dataTable[dataName], folder, childDataName, schemaTable:GetSchema()[childDataName])
			end

			folder.Parent = dataFolder
		end
	end
end

function PlayerDataManager:_getDataTable(schemaTable, dataFolder)
	local dataTable = {}

	local function getDataTable(dataFolder, dataName, schemaDataInfo)
		local dataTypeInfo = DataTypes[schemaDataInfo.DataType]

		if schemaDataInfo.ServerOnly == true then
			return self._serverOnlyValues[schemaDataInfo.Path].Value
		end

		local childDataInstance = dataFolder:FindFirstChild(dataName)
		if not childDataInstance then
			return nil
		end

		if schemaDataInfo.DataType == "Table" then
			return self:_getDataTable(schemaDataInfo.Schema, childDataInstance)
		else
			return childDataInstance.Value
		end
	end

	local schemaType = schemaTable:GetType()
	if schemaType == "DataSchema" then
		for dataName, schemaDataInfo in schemaTable:GetSchema() do
			dataTable[dataName] = getDataTable(dataFolder, dataName, schemaDataInfo)
		end
	elseif schemaType == "ObjectSchema" then
		for _, childDataFolder in dataFolder:GetChildren() do
			dataTable[childDataFolder.Name] = {}
			for dataName, schemaDataInfo in schemaTable:GetSchema() do
				dataTable[childDataFolder.Name][dataName] = getDataTable(childDataFolder, dataName, schemaDataInfo)
			end
		end
	end

	return dataTable
end

function PlayerDataManager:GetDataTable(onlySaveables)
	local playerDataServer = PlayerDataServer.GetInstance()

	local dataTable = self:_getDataTable(playerDataServer._schema, self._playerDataFolder)
	self:_reconcileData(dataTable, playerDataServer._schema, onlySaveables)

	return dataTable
end

function PlayerDataManager:GetSyncedDataTable() : {}
	return self._syncedDataTable
end

function PlayerDataManager:Save()
	if self._isSaving then
		return self.OnSaveAttempt:Wait()
	end

	if not self._player then
		error(`PlayerDataService cannot currently save offline player data`)
	end

	if self._player.UserId < 0 then
		return false, "Cannot save data as player is not real: user id is less than or equal to 0"
	end

	local playerDataServer = PlayerDataServer.GetInstance()

	if playerDataServer._saveInStudio == false and RunService:IsStudio() then
		return false, "Player data saving in studio is disabled"
	end

	self._isSaving = true

	local player = self._player

	local playerDataFolder = self._playerDataFolder
	local metadataFolder = playerDataFolder._metadata

	local _old
	local _current

	local saved = false
	local savedDataTable
	local success, message = pcall(function()
		playerDataServer:UpdateAsync(self._key, function(oldDataTable)
			local oldDataId
			if typeof(oldDataTable) == "table" and oldDataTable._metadata and oldDataTable._metadata.DataId then
				oldDataId = oldDataTable._metadata.DataId
			end

			_old = oldDataId
			_current = metadataFolder.DataId.Value

			if not oldDataId or metadataFolder.DataId.Value >= oldDataId then
				local now = DateTime.now().UnixTimestampMillis

				metadataFolder.DataId.Value += 1
				metadataFolder.LastUpdatedAt.Value = now
				if self._isLeaving then
					metadataFolder.LeftAt.Value = now
				end

				savedDataTable = self:GetDataTable(true)
				saved = true
				return savedDataTable
			else
				return nil
			end
		end)
	end)

	if success then
		if saved then
			self._lastSaveTime = metadataFolder.LastUpdatedAt.Value
			self._syncedDataTable = savedDataTable
			if RunService:IsStudio() then
				--print(`Successfully saved {player.Name}'s data:`, savedDataTable)
			end
		else
			message = `{player.Name}'s data is not update to date.`
			player:Kick(`Your data is not up to date. Please rejoin. Old: {_old} Current: {_current}`)
		end
	end

	self._isSaving = false
	self.OnSaveAttempt:Fire((success and saved), message)
	return (success and saved), message
end

function PlayerDataManager.Exists(player : Player)
	if PlayerDataManager._instances[`{player.UserId}`] then
		return true
	end

	return false
end

function PlayerDataManager:_onLeaving()
	self._isLeaving = true

	if self._playerDataFolder then
		self._playerDataFolder.Parent = nil
	end

	if self._isLoaded then
		local success, message = self:Save()
		if not success then
			warn(`Could not save {self._player.Name}'s data on leave: {message}`)
		end
	end
	
	self:_destroy()
end

function PlayerDataManager:_destroy()
	for _, serverOnlyValue in self._serverOnlyValues do
		serverOnlyValue:Destroy()
	end

	-- Only destroy player data folder after the player has left the game
	if self._player.Parent then
		-- this happens if :Save() doesn't yield (like an precondition has errored)
		task.wait()
		self._playerDataFolder:Destroy()
	else
		self._playerDataFolder:Destroy()
	end
	
	PlayerDataManager._instances[self._uniqueId] = nil

	self.Destroyed:Fire()
	PlayerDataManager.InstanceDestroyed:Fire()
	setmetatable(self, nil)
	table.clear(self)
end

function PlayerDataServer.new(options)
	if PlayerDataServer._instance then
		error("There is already a PlayerDataServer; use .GetInstance instead")
	end
	if typeof(options) ~= "table" then
		error(`Expected options to be a table, got {typeof(options)}`)
	end
	if typeof(options.Schema) ~= "table" then
		error(`Expected options.Schema to be a table, got {typeof(options.Schema)}`)
	end
	if typeof(options.DataStoreName) ~= "string" then
		error(`Expected options.DataStoreName to be a table, got {typeof(options.DataStoreName)}`)
	end

	if not options.Middleware then
		options.Middleware = MiddlewareTable.new()
	end

	local self = setmetatable({}, PlayerDataServer)
	self._initialized = false
	self._isUsingOneOffMiddleware = options.Middleware:IsUsingOneOffMiddleware()
	self._playersDataFolder = PlayerDataUtil.GetPlayersDataFolder()
	self.PlayerDataManagerDestroyed = PlayerDataManager.InstanceDestroyed

	if typeof(options.SaveInStudio) == "boolean" then
		self._saveInStudio = options.SaveInStudio
	else
		self._saveInStudio = false
	end

	if options.Mock == true and RunService:IsStudio() then
		self._isMockDataStore = true
		self._dataStore = DataStoreWrapper.Mock.new(options.DataStoreName, options.Middleware:ToTable())
	else
		self._isMockDataStore = false
		self._dataStore = DataStoreWrapper.new(options.DataStoreName, options.Middleware:ToTable())
	end

	local metadataSchema = require(script.MetadataSchema)
	for key, value in options.MetadataSchema or {} do
		metadataSchema[key] = value
	end

	if self._isUsingOneOffMiddleware then
		metadataSchema.OneOffMiddlewareIndex = {
			DataType = "Integer",
			DefaultValue = 0,
		}
	end

	self._schema = Schemas.DataSchema.Combine(
		options.Schema,
		Schemas.DataSchema.new({
			_metadata = {
				DataType = "Table",
				Schema = Schemas.DataSchema.new(metadataSchema)
			}
		})
	)

	self._schema:Process()

	PlayerDataServer._instance = self
	PlayerDataServer._instantiated:Fire()
	return self
end

function PlayerDataServer:Initialize()
	if self._initialized then
		error(`PlayerDataServer is already initialized`)
	end

	local function onPlayerAdded(player : Player)
		local playerWrapper = PlayerWrapper.GetInstance(player)

		-- Wait for old player data manager to get deleted if they rejoined the server quickly
		local oldPlayerDataManager = PlayerDataManager._instances[playerWrapper:GetUniqueId()]
		if oldPlayerDataManager then
			local runningThread = coroutine.running()
			local connections = {}

			table.insert(connections, oldPlayerDataManager.Destroyed:Connect(function()
				if runningThread then
					task.spawn(runningThread)
					runningThread = nil
				end
			end))

			table.insert(connections, player.Destroying:Connect(function()
				if runningThread then
					task.spawn(runningThread)
					runningThread = nil
				end
			end))

			coroutine.yield()
			for _, connection in connections do
				connection:Disconnect()
			end

			if not player.Parent then
				return
			end
		end

		PlayerDataManager.new(playerWrapper)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local playerWrapper = PlayerWrapper.GetInstance(player)
		local playerDataManager = PlayerDataManager._instances[playerWrapper:GetUniqueId()]
		if playerDataManager then
			playerDataManager:_onLeaving()
		end
	end)

	self._initialized = true
end

function PlayerDataServer.GetInstance() : typeof(setmetatable({}, PlayerDataServer))
	if not PlayerDataServer._instance then
		task.delay(5, function()
			if not PlayerDataServer._instance then
				warn("Could not get PlayerDataServer in 5 seconds, could yield indefinitely")
			end
		end)

		PlayerDataServer._instantiated:Wait()
	end

	return PlayerDataServer._instance
end

function PlayerDataServer:GetSchema() : Schemas.Schema
	return self._schema:GetSchema()
end

function PlayerDataServer:GetPlayerDataManager(player) : typeof(PlayerDataManager.new())
	return PlayerDataManager.GetInstance(player)
end

function PlayerDataServer:GetOfflinePlayerDataManager(userId, cacheDuration) : typeof(PlayerDataManager.new())
	local offlinePlayer = PlayerWrapper.GetOfflineInstance(userId)
	if not offlinePlayer then
		offlinePlayer = PlayerWrapper.new(userId, {
			IsOffline = true,
			CacheDuration = cacheDuration,
		})
	end

	return PlayerDataManager.new(offlinePlayer)
end

function PlayerDataServer:PlayerDataManagerExists(player : Player) : boolean
	return PlayerDataManager.Exists(player)
end

function PlayerDataServer:GetPlayerDataFolder(player)
	return Promise.new(function(resolve, reject)
		local playerDataManager
		local success, message = pcall(function()
			playerDataManager = PlayerDataManager.GetInstance(player)
		end)

		if playerDataManager then
			resolve(playerDataManager:GetPlayerDataFolder())
		else
			reject(message)
		end
	end)
end

function PlayerDataServer:GetAsync(key)
	return self._dataStore:GetAsync(key)
end

function PlayerDataServer:UpdateAsync(key, callback)
	return self._dataStore:UpdateAsync(key, callback)
end

function PlayerDataServer:RemoveAsync(key)
	return self._dataStore:RemoveAsync(key)
end

local playersRateLimit = {}
local MAX_REQUESTS_PER_MINUTE = 9

PlayerDataUtil.LoadOfflinePlayerDataRemote.OnServerInvoke = function(player, userId)
	local offlinePlayerDataFolder = PlayerDataUtil.GetOffinePlayerDataFolder(userId)
	if offlinePlayerDataFolder then
		return true, offlinePlayerDataFolder
	end

	if not playersRateLimit[player.UserId] then
		playersRateLimit[player.UserId] = 0
	end

	if playersRateLimit[player.UserId] >= MAX_REQUESTS_PER_MINUTE then
		return false
	end

	playersRateLimit[player.UserId] += 1
	task.delay(60/MAX_REQUESTS_PER_MINUTE, function()
		playersRateLimit[player.UserId] -= 1
	end)

	return true, PlayerDataServer.GetInstance():GetOfflinePlayerDataManager(userId):GetPlayerDataFolder()
end

game:BindToClose(function(closeReason)
	local playerDataServer = PlayerDataServer._instance
	if not playerDataServer then
		return
	end

	-- wait for all player data manager instances to be destroyed
	-- which indicates an attempt has been made to save the data

	if next(PlayerDataManager._instances) then
		local runningThread = coroutine.running()

		local connection = PlayerDataManager.InstanceDestroyed:Connect(function()
			if next(PlayerDataManager._instances) then
				return
			end

			task.spawn(runningThread)
		end)

		if RunService:IsStudio() then
			task.delay(3, function()
				if runningThread then
					warn("Studio shutdown before all data saved")
					task.spawn(runningThread)
				end
			end)
		end

		coroutine.yield()
		connection:Disconnect()
		runningThread = nil
	end

end)

return PlayerDataServer