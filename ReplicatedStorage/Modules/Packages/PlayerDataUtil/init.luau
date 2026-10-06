local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Modules.Packages

local Maid = require(Packages.Maid)
local GoodSignal = require(Packages.Signals.GoodSignal)
local ModuleLoader = require(Packages.ModuleLoader)
local Types = require(ReplicatedStorage.Modules.Shared.Config.Types)

local PlayerDataUtil = {}
PlayerDataUtil.LoadOfflinePlayerDataRemote = script:WaitForChild("LoadOfflinePlayerData")
PlayerDataUtil._playersDataFolder = script:WaitForChild("PlayersData")
PlayerDataUtil._foldersLoaded = {}
PlayerDataUtil._onFolderLoaded = GoodSignal.new()

function PlayerDataUtil._waitForPlayerDataFolderLoaded(playerDataFolder : Folder)
	if not PlayerDataUtil._foldersLoaded[playerDataFolder] then
		local runningThread = coroutine.running()
		local waitMaid = Maid.new()
		
		waitMaid:GiveTask(PlayerDataUtil._onFolderLoaded:Connect(function()
			if PlayerDataUtil._foldersLoaded[playerDataFolder] and runningThread then
				task.spawn(runningThread)
			end
		end))
		
		waitMaid:GiveTask(playerDataFolder.AncestryChanged:Connect(function()
			if playerDataFolder.Parent == nil and runningThread then
				task.spawn(runningThread)
			end
		end))

		coroutine.yield()
		runningThread = nil
		waitMaid:DoCleaning()
		
		if not playerDataFolder.Parent then
			error(`Player data folder got destroyed before loaded`)
		end
	end
end

function PlayerDataUtil.GetPlayersDataFolder() : Folder
	return PlayerDataUtil._playersDataFolder
end

function PlayerDataUtil.GetPlayerDataFolder(player: Player?) : Types.DataFolder
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		error("Expected argument 1 to be a Player")
	end
	
	if RunService:IsServer() then
		local ServerPackages = ServerStorage.Modules.Packages
		local playerDataServer = require(ServerPackages.PlayerDataService).PlayerDataServer.GetInstance() :: any
		
		local success, result = playerDataServer:GetPlayerDataFolder(player):await()
		
		if not success then
			error(result)
		end
		
		return result
	end
	
	local playerDataFolder = PlayerDataUtil._playersDataFolder:WaitForChild(player.UserId, 10)
	if not playerDataFolder then
		error(`Could not get player data folder within 10 seconds`)
	end
	
	if RunService:IsClient() then
		PlayerDataUtil._waitForPlayerDataFolderLoaded(playerDataFolder)
	end

	return playerDataFolder
end

function PlayerDataUtil.GetPlayerDataFolderNoYield(player)
	if not PlayerDataUtil._playersDataFolder[player.UserId] or not PlayerDataUtil._foldersLoaded[PlayerDataUtil._playersDataFolder[player.UserId]] then
		return
	end

	return PlayerDataUtil._playersDataFolder[player.UserId]
end

function PlayerDataUtil.GetOffinePlayerDataFolder(userId) : Folder
	local offlinePlayerDataFolder = PlayerDataUtil._playersDataFolder:FindFirstChild(`Offline_{userId}`)
	if RunService:IsClient() and not offlinePlayerDataFolder then
		local success, result = PlayerDataUtil.LoadOfflinePlayerDataRemote:InvokeServer(userId)
		if not success then
			error(result)
		end
		
		PlayerDataUtil._waitForPlayerDataFolderLoaded(result)
		return result
	end

	return offlinePlayerDataFolder
end

local function onChildAdded(playerDataFolder : Folder)
	local totalDescendantsCount = playerDataFolder:GetAttribute("DescendantsCount")
	local currentDescendantsCount = #playerDataFolder:GetDescendants()
	
	if currentDescendantsCount < totalDescendantsCount then
		local isLocalPlayer = playerDataFolder.Name == tostring(Players.LocalPlayer.UserId)
		local function setLoadingState(...)
			if isLocalPlayer then
				ModuleLoader.SetLoadingState(...)
			end
		end
		
		setLoadingState(
			"PlayerDataReplication",
			`Loading Player Data ({currentDescendantsCount}/{totalDescendantsCount})`,
			10
		)

		local mainThread = coroutine.running()
		local replicateMaid = Maid.new()

		replicateMaid:GiveTask(playerDataFolder.DescendantAdded:Connect(function()
			currentDescendantsCount += 1
			setLoadingState(
				"PlayerDataReplication",
				`Loading Player Data ({currentDescendantsCount}/{totalDescendantsCount})`,
				10
			)

			if currentDescendantsCount >= totalDescendantsCount then
				task.spawn(mainThread)
			end
		end))

		replicateMaid:GiveTask(playerDataFolder.AncestryChanged:Connect(function()
			if playerDataFolder.Parent ~= nil then
				return
			end

			task.spawn(mainThread)
		end))

		local warnThread = task.delay(10, function()
			warn(`Player data folder descendants failed to replicate within 10 seconds, could yield indefinitely.`)
		end)

		coroutine.yield()
		if isLocalPlayer then
			ModuleLoader.RemoveLoadingState("PlayerDataReplication")
		end
		replicateMaid:DoCleaning()
		task.cancel(warnThread)
	end

	PlayerDataUtil._foldersLoaded[playerDataFolder] = true
	PlayerDataUtil._onFolderLoaded:Fire()
end

if RunService:IsClient() then
	PlayerDataUtil._playersDataFolder.ChildRemoved:Connect(function(child)
		PlayerDataUtil._foldersLoaded[child] = nil
	end)
	
	PlayerDataUtil._playersDataFolder.ChildAdded:Connect(onChildAdded)
	for _, child in PlayerDataUtil._playersDataFolder:GetChildren() do
		task.spawn(onChildAdded, child)
	end
end

return PlayerDataUtil
