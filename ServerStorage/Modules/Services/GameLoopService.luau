local Packages = game.ReplicatedStorage.Modules.Packages
local Shared = game.ReplicatedStorage.Modules.Shared
local Services = game.ServerStorage.Modules.Services
local Config = require(game.ReplicatedStorage.Modules.Shared.Config.Game)
local Network = require(Packages.Network)
local MapsConfig = require(Shared.Config.Maps)
local RoundService = require(Services.RoundService)
local TaskService = require(Services.TaskService)

local GameLoopService = {}
local _activeMap: Instance? = nil

local function announceStage(stage: string, duration: number?, mapName: string?)
	local endsAt = duration and workspace:GetServerTimeNow() + duration or nil
	workspace:SetAttribute("GameStage", stage)
	workspace:SetAttribute("GameStageEndsAt", endsAt)
	Network:FireAllClients("GameStageChanged", {
		Stage = stage,
		Duration = duration,
		EndsAt = endsAt,
		MapName = mapName,
	})
end

local function getMapTemplate(mapName: string): Instance
	local mapsFolder = game.ReplicatedStorage.Assets.Maps
	local mapTemplate = mapsFolder:FindFirstChild(mapName)
	assert(mapTemplate, `Configured map "{mapName}" was not found in ReplicatedStorage.Assets.Maps`)
	return mapTemplate
end

local function spawnMap(mapName: string): Instance
	local map = getMapTemplate(mapName):Clone()
	map:SetAttribute("MapName", map.Name)
	map.Name = Config.GameLoop.ActiveMapName
	map.Parent = workspace
	if not map:IsA("Folder") then
		map:Destroy()
		error(`Configured map "{mapName}" must be a Folder`)
	end

	game["Run Service"].Heartbeat:Wait()
	_activeMap = map
	return map
end

local function getSpawnPart(map: Instance): BasePart
	local spawnPart = map:FindFirstChild("Spawn", true)
	assert(spawnPart and spawnPart:IsA("BasePart"), `Map "{map.Name}" must contain a BasePart named Spawn`)
	return spawnPart
end

local function isPositionAvailable(position: Vector3, occupiedPositions: {Vector3}): boolean
	for _, occupiedPosition in occupiedPositions do
		if (position - occupiedPosition).Magnitude < Config.GameLoop.MinimumSpawnDistance then
			return false
		end
	end
	return true
end

local function getRandomSpawnPosition(spawnPart: BasePart, occupiedPositions: {Vector3}, characterHeight: number): Vector3
	local size = spawnPart.Size
	local lastPosition = spawnPart.Position + Vector3.new(0, size.Y / 2 + characterHeight, 0)

	for _ = 1, Config.GameLoop.SpawnAttempts do
		local localPosition = Vector3.new(
			(math.random() - 0.5) * size.X,
			size.Y / 2 + characterHeight,
			(math.random() - 0.5) * size.Z
		)
		local candidate = spawnPart.CFrame:PointToWorldSpace(localPosition)
		lastPosition = candidate
		if isPositionAvailable(candidate, occupiedPositions) then
			return candidate
		end
	end

	return lastPosition
end

local function teleportPlayers(players: {Player}, map: Instance)
	local spawnPart = getSpawnPart(map)
	local occupiedPositions = {}

	for _, player in players do
		if player.Parent == game.Players then
			local character = player.Character or player.CharacterAdded:Wait()
			if character.Parent then
				local characterHeight = character:GetExtentsSize().Y / 2 + 1
				local position = getRandomSpawnPosition(spawnPart, occupiedPositions, characterHeight)
				table.insert(occupiedPositions, position)
				character:PivotTo(CFrame.new(position))
			end
		end
	end
end

local function destroyActiveMap()
	if _activeMap then
		_activeMap:Destroy()
		_activeMap = nil
	end
end

local function returnPlayersToLobby(players: {Player})
	local spawnLocation = workspace.Lobby:FindFirstChild("SpawnLocation")
	if not spawnLocation or not spawnLocation:IsA("BasePart") then
		warn("GameLoopService requires workspace.SpawnLocation to return players after a match")
		return
	end

	for _, player in players do
		if player.Parent == game.Players then
			local character = player.Character
			local backpack = player.Backpack
			
			if character and character.Parent then
				local characterHeight = character:GetExtentsSize().Y / 2
				local spawnPosition = spawnLocation.Position + Vector3.new(0, spawnLocation.Size.Y / 2 + characterHeight + 1, 0)
				character:PivotTo(CFrame.new(spawnPosition))
				
				for _, tool in character:GetChildren() do
					if tool:GetAttribute("MapTool") then
						tool:Destroy()
					end
				end
			end
			
			if backpack then
				for _, tool in backpack:GetChildren() do
					if tool:GetAttribute("MapTool") then
						tool:Destroy()
					end
				end
			end
		end
	end
end

local function getCurrentPlayers(): {Player}
	local currentPlayers = {}
	for _, player in game.Players:GetPlayers() do
		table.insert(currentPlayers, player)
	end
	return currentPlayers
end

local function waitForMatchToEnd()
	local matchEnded = false
	local connection = RoundService.MatchEnded:Connect(function()
		matchEnded = true
	end)
	while not matchEnded do
		task.wait(1)
	end
	connection:Disconnect()
end

function GameLoopService.Init()
	task.spawn(function()
		while true do
			announceStage("Lobby", Config.GameLoop.LobbyDuration)
			task.wait(Config.GameLoop.LobbyDuration)

			local players = getCurrentPlayers()
			if #players < Config.GameLoop.MinimumPlayers then
				continue
			end

			local mapDefinition = MapsConfig.GetRandomMap()
			announceStage("MapLoading", nil, mapDefinition.Name)
			local success, mapOrError = pcall(spawnMap, mapDefinition.Name)
			if not success then
				warn(mapOrError)
				announceStage("Lobby", Config.GameLoop.LobbyDuration)
				continue
			end
			
			task.wait(Config.GameLoop.MapLoadingDuration)

			local map = mapOrError :: Instance
			local teleportSuccess, teleportError = pcall(teleportPlayers, players, map)
			if not teleportSuccess then
				warn(teleportError)
				destroyActiveMap()
				continue
			end

			if not RoundService:StartMatch(players) then
				destroyActiveMap()
				continue
			end

			TaskService:StartRound(players, mapDefinition.Name)

			waitForMatchToEnd()
			TaskService:EndRound()
			destroyActiveMap()
			returnPlayersToLobby(players)
			task.wait(Config.Round.ResultsDuration)
		end
	end)
end

return GameLoopService
