local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local ServerPackages = ServerStorage.Modules.Packages
local Packages = ReplicatedStorage.Modules.Packages

local ODSWrapper = require(ServerPackages.ODSWrapper)
local GoodSignal = require(Packages.Signals.GoodSignal)

local GetUserInfosByUserIdsAsync = require(script.GetUserInfosByUserIdsAsync)

local playerNameCache = {}

local function waitUntilAllCompleted(functionList, timeout)
	if #functionList == 0 then
		return true
	end

	local mainThread = coroutine.running()
	local functionsCompleted = 0

	local isCanceled = false
	local finished = false

	local success = nil
	local message = nil

	local function canceled()
		return isCanceled
	end

	local function finish(ok, msg)
		if finished then return end
		finished = true

		success = ok
		message = msg

		if mainThread then
			task.spawn(mainThread)
		end
	end

	for _, func in functionList do
		task.defer(function()
			if finished then return end

			func(canceled)

			functionsCompleted += 1
			if functionsCompleted == #functionList and not canceled() then
				finish(true)
			end
		end)
	end

	if timeout then
		task.delay(timeout, function()
			if finished then return end
			if functionsCompleted < #functionList then
				isCanceled = true
				finish(false, `Timeout of {timeout} has been reached. {functionsCompleted}/{#functionList} functions completed`)
			end
		end)
	end

	-- Wait for finish() to resume us
	coroutine.yield()

	-- After we’re resumed, cancel any stragglers
	isCanceled = true
	mainThread = nil

	return success, message
end

local PlayerLeaderboard = {}
PlayerLeaderboard.__index = PlayerLeaderboard
PlayerLeaderboard._leaderboards = {}

function PlayerLeaderboard.new(options)
	assert(typeof(options) == "table", "Expected arg1, options, to be a table")
	assert(typeof(options.DataStoreName) == "string", "Expected options.DataStoreName to be a string")
	assert(PlayerLeaderboard._leaderboards[options.DataStoreName] == nil, `There is already a leaderboard with datastore {options.DataStoreName}`)
	assert(typeof(options.GetStatValue) == "function", "Expected options.GetStatValue to be a function")

	local self = setmetatable({}, PlayerLeaderboard)
	PlayerLeaderboard._leaderboards[options.DataStoreName] = self
	
	self.Options = options
	self.OnUpdate = GoodSignal.new()
	self.OrderedDataStore = ODSWrapper.new(options.DataStoreName)
	
	task.spawn(function()
		if not RunService:IsRunMode() and #Players:GetPlayers() == 0 then
			Players.PlayerAdded:Wait()
		end
		
		Players.PlayerAdded:Connect(function(player)
			self:_savePlayer(player)
		end)
		
		while true do
			local functionList = {}
			for _, player in Players:GetPlayers() do
				table.insert(functionList, function()
					local success, message = pcall(function()
						self:_savePlayer(player)
					end)
					
					if not success then
						warn(`Failed to save {player.Name}'s data to leaderboard: {message}`)
					end
				end)
			end
			
			waitUntilAllCompleted(functionList, 5)
			
			local success, message = pcall(function()
				self:_updateLeaderboard()
			end)
			
			if not success then
				warn(`Leaderboard failed to update: {message}`)
			end
			
			task.wait(60)
		end
	end)
	
	return self
end

function PlayerLeaderboard:_savePlayer(player)
	if player.UserId <= 0 then
		return
	end

	local statValue = self.Options.GetStatValue(player)
	
	local success, message = pcall(function()
		self.OrderedDataStore:SetAsync(player.UserId, statValue)
	end)

	if not success then
		warn(`{player.Name}'s stat failed to save to leaderboard. Data store name "{self.Options.DataStoreName}". Error message: {message}`)
	end
end

function PlayerLeaderboard:_updateLeaderboard()
	local newLeaderboardData = {}

	local pages = self.OrderedDataStore:GetSortedAsync(false, 50)
	newLeaderboardData.LastUpdated = os.time()
	newLeaderboardData.Leaderboard = {}

	local page = pages:GetCurrentPage()
	
	local userIds = {}
	
	for _, keyvalue in ipairs(page) do
		table.insert(userIds, tonumber(keyvalue.key))
	end
	
	local userInfos = GetUserInfosByUserIdsAsync(userIds)
	
	for rank, keyvalue in ipairs(page) do
		local playerName = `User {keyvalue.key}`
		local displayName = "???"
		local hasVerifiedBadge = false
		
		local userId = tonumber(keyvalue.key)
		if userInfos[userId] then
			playerName = userInfos[userId].Username
			displayName = userInfos[userId].DisplayName
			hasVerifiedBadge = userInfos[userId].HasVerifiedBadge
		end

		newLeaderboardData.Leaderboard[rank] = {
			Key = keyvalue.key,
			Value = keyvalue.value,
			PlayerName = playerName,
			DisplayName = displayName,
			HasVerifiedBadge = hasVerifiedBadge
		}
	end

	self.LeaderboardData = newLeaderboardData
	self.OnUpdate:Fire(self.LeaderboardData)
end

function PlayerLeaderboard:GetLeaderboardData()
	return self.LeaderboardData
end

return PlayerLeaderboard
