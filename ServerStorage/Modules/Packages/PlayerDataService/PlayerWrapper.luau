local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage.Modules.Packages
local ServerPackages = ServerStorage.Modules.Packages

local GoodSignal = require(Packages.Signals.GoodSignal)
local Maid = require(Packages.Maid)

local function waitUntilAllCompleted(functionList, timeout)
	if #functionList == 0 then
		return true
	end

	local threads = {}
	local functionsCompleted = 0
	local mainThread = coroutine.running()
	local isCanceled = false
	local timeoutThread
	local success, message

	local function canceled()
		return isCanceled
	end

	for _, func in functionList do
		task.defer(function()
			local threadSuccess, threadMessage = pcall(func, canceled)
			if not threadSuccess then
				warn(`Thread errored: {threadMessage}`)
			end

			functionsCompleted += 1
			if functionsCompleted == #functionList and not canceled() then
				if timeoutThread then
					task.cancel(timeoutThread)
				end
				success = true
				task.spawn(mainThread)
			end
		end)
	end

	if timeout then
		timeoutThread = task.delay(timeout, function()
			if functionsCompleted < #functionList then
				success = false
				message = `Timeout of {timeout} has been reached. {functionsCompleted}/{#functionList} functions completed`
				task.spawn(mainThread)
			end
		end)
	end

	coroutine.yield()
	timeoutThread = nil

	isCanceled = true
	return success, message
end

local PlayerWrapper = {}
PlayerWrapper.__index = PlayerWrapper
PlayerWrapper._instantiated = GoodSignal.new()
PlayerWrapper._instances = {}

function PlayerWrapper.new(userId, options)
	if not options then
		options = {}
	end

	if not options.CacheDuration then
		options.CacheDuration = 600
	end

	local self = setmetatable({}, PlayerWrapper)
	self._isDestroying = false
	self._userId = userId
	self._beforeDestroyCallbacks = {}
	self.Maid = Maid.new()

	local destroyed = false
	self.Maid:GiveTask(function()
		destroyed = true
	end)

	if options.IsOffline then
		self._uniqueId = `Offline_{userId}`
		task.delay(options.CacheDuration, function()
			if destroyed then
				return
			end

			self:Destroy()
		end)
	else
		self._player = Players:GetPlayerByUserId(userId)
		if not self._player then
			error(`Player with user id {userId} is not in game`)
		end

		--self.Maid:GiveTask(self._player.Destroying:Connect(function()
		--	self:Destroy()
		--end))

		self._uniqueId = tostring(userId)
	end

	if PlayerWrapper._instances[self._uniqueId] then
		error(`Player wrapper already exists for {self._uniqueId}`)
	end

	PlayerWrapper._instances[self._uniqueId] = self
	PlayerWrapper._instantiated:Fire()

	return self
end

function PlayerWrapper.GetInstance(player)
	if not PlayerWrapper._instances[`{player.UserId}`] then
		local runningThread = coroutine.running()

		local connection = PlayerWrapper._instantiated:Connect(function()
			if PlayerWrapper._instances[`{player.UserId}`] and runningThread then
				task.spawn(runningThread)
			end
		end)
		
		local timeoutThread
		timeoutThread = task.delay(5, function()
			timeoutThread = nil
			if runningThread then
				task.spawn(runningThread)
			end
		end)

		coroutine.yield()
		runningThread = nil
		connection:Disconnect()
		if timeoutThread then
			task.cancel(timeoutThread)
		end

		if not PlayerWrapper._instances[`{player.UserId}`] then
			error(`Could not get {player.Name} ({player.UserId}) player wrapper within 5 seconds`)
		end
	end

	return PlayerWrapper._instances[`{player.UserId}`]
end

function PlayerWrapper.GetOfflineInstance(userId)
	return PlayerWrapper._instances[`Offline_{userId}`]
end

function PlayerWrapper:GetPlayer()
	return self._player
end

function PlayerWrapper:IsOffline()
	return (self._player == nil)
end

function PlayerWrapper:GetUniqueId()
	return self._uniqueId
end

function PlayerWrapper:GetUserId()
	return self._userId
end

function PlayerWrapper:BeforeDestroy(callback)
	table.insert(self._beforeDestroyCallbacks, callback)
end

function PlayerWrapper:Destroy()
	PlayerWrapper._instances[self:GetUniqueId()] = nil
	
	if self._isDestroying == true then
		local runningThread = coroutine.running()
		self.Maid:GiveTask(function()
			task.defer(runningThread)
		end)

		coroutine.yield()
		runningThread = nil
		return
	end
	
	self._isDestroying = true

	local success, message = waitUntilAllCompleted(self._beforeDestroyCallbacks, 30)
	if not success then
		error(`Failed to complete {self._userId}'s player leave callbacks: {message}`)
	end

	self.Maid:DoCleaning()
	table.clear(self)
	setmetatable(self, nil)
end

local function onPlayerAdded(player)
	local oldPlayerWrapper = PlayerWrapper._instances[`{player.UserId}`]
	if oldPlayerWrapper then
		oldPlayerWrapper:Destroy()
	end

	PlayerWrapper.new(player.UserId)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	local oldPlayerWrapper = PlayerWrapper._instances[`{player.UserId}`]
	if oldPlayerWrapper then
		oldPlayerWrapper:Destroy()
	end
end)

game:BindToClose(function()
	for _, playerWrapper in PlayerWrapper._instances do
		if playerWrapper:IsOffline() then
			playerWrapper:Destroy()
		end
	end
end)

return PlayerWrapper
