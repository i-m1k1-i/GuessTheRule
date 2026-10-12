local CoinSpawnerService = require(game.ServerStorage.Modules.Services.CoinSpawnerService)

return {
	Id = "FakeCoin",
	DisplayName = "Fake Coin",
	Description = "Place a coin that triggers the Coin action but gives no coins.",
	Hint = "Place a coin that triggers the Coin action but gives no coins.",
	UnlockedByDefault = true,
	Cooldown = 15,

	Activate = function(player: Player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not rootPart or not rootPart:IsA("BasePart") then
			return false
		end

		local targetPosition = rootPart.Position + rootPart.CFrame.LookVector * 5
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {character}

		local rayResult = workspace:Raycast(targetPosition + Vector3.new(0, 10, 0), Vector3.new(0, -40, 0), raycastParams)
		if not rayResult then
			return false
		end

		return CoinSpawnerService.SpawnFakeCoin(rayResult.Position)
	end,
}