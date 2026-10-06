local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Packages = ReplicatedStorage.Modules.Packages
local ServerPackages = ServerStorage.Modules.Packages

local Network = require(Packages.Network)
local PlayerDataUtil = require(Packages.PlayerDataUtil)
local PlayerDataService = require(ServerPackages.PlayerDataService)

local PlayerDataServer = PlayerDataService.PlayerDataServer
local MiddlewareTable = PlayerDataService.MiddlewareTable

local middlewareTable = MiddlewareTable.new()
middlewareTable:AddMiddlewareFolder(script.Middleware)

local playerDataServer = PlayerDataServer.new({
	Mock = false,
	SaveInStudio = true,
	DataStoreName = "PlayerDataStore",
	Schema = require(script.Schema),
	Middleware = middlewareTable,
})

playerDataServer:Initialize()

local function onPlayerAdded(player : Player)
	local playerDataManager = playerDataServer:GetPlayerDataManager(player)

	playerDataManager.OnSaveAttempt:Connect(function(success, message)
		if success then
			return
		end

		Network:FireClient(player, "Notify", {
			Text = "Failed to save your data, trying again in 60 seconds",
			Style = "Danger"
		})
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

local PlayerDataController = {}

function PlayerDataController.GetObjectSchemaByName(name : string)
	return require(script.ObjectSchemas[name])
end

return PlayerDataController