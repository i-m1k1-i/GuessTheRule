local module = {}

local touchPart = workspace.Baseplate
local RoundService = require(game.ServerStorage.Modules.Services.RoundService)
local teleportingPlayers: {[Player]: boolean} = {}

local function getDestination(): BasePart?
	if RoundService.State == "RuleActive" then
		local activeMap = workspace:FindFirstChild("ActiveMap")
		local spawnPart = activeMap and activeMap:FindFirstChild("Spawn", true)
		if spawnPart and spawnPart:IsA("BasePart") then
			return spawnPart
		end
		return nil
	end

	local lobby = workspace:FindFirstChild("Lobby")
	local spawnPart = lobby and lobby:FindFirstChild("SpawnLocation")
	if spawnPart and spawnPart:IsA("BasePart") then
		return spawnPart
	end
	return nil
end

function module.Init()
	touchPart.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and game.Players:GetPlayerFromCharacter(character)
		if not player or teleportingPlayers[player] then
			return
		end

		local destination = getDestination()
		if not destination then
			return
		end

		teleportingPlayers[player] = true
		local characterHeight = character:GetExtentsSize().Y / 2
		local position = destination.Position + Vector3.new(0, destination.Size.Y / 2 + characterHeight + 1, 0)
		character:PivotTo(CFrame.new(position))
		task.delay(1, function()
			teleportingPlayers[player] = nil
		end)
	end)

	game.Players.PlayerRemoving:Connect(function(player)
		teleportingPlayers[player] = nil
	end)
end

return module
