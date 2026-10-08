local Services = game.ServerStorage.Modules.Services
local Packages = game.ReplicatedStorage.Modules.Packages
local Shared = game.ReplicatedStorage.Modules.Shared
local PlayerDataUtil = require(Packages.PlayerDataUtil)
local ActionTrackingService = require(Services.ActionTrackingService)
local ActionsConfig = require(Shared.Config.Actions)

local Actions = ActionsConfig.Enum

local CoinSpawner = {}

local coinTemplate = game.ReplicatedStorage.Assets.Models.Coin :: Model
local coinPrimaryPart = coinTemplate.PrimaryPart
assert(coinPrimaryPart, "Coin model must have a PrimaryPart")
local collectSound = game.SoundService.SFX.Game.CoinCollect

local SPAWNER_TAG = "CoinSpawner"
local COIN_TAG = "CollectableCoin"

local default = {
	MaxCoins = 10,
	HeightOffset = 2.5,
}

local MAX_GROUND_LIFT = 5
local GROUND_CLEARANCE = 0.05
local templatePivot = coinTemplate:GetPivot()
local templateBounds, templateBoundsSize = coinTemplate:GetBoundingBox()
local coinBottomOffset = templateBounds.Position.Y - templatePivot.Position.Y - templateBoundsSize.Y / 2

local function getGroundAdjustedPosition(position: Vector3): Vector3
	local excludedCharacters = {}
	for _, player in game.Players:GetPlayers() do
		if player.Character then
			table.insert(excludedCharacters, player.Character)
		end
	end
	for _, coin in game.CollectionService:GetTagged(COIN_TAG) do
		table.insert(excludedCharacters, coin)
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = excludedCharacters

	local halfHeight = templateBoundsSize.Y / 2
	local rayOrigin = position + Vector3.new(0, MAX_GROUND_LIFT + halfHeight, 0)
	local rayDirection = Vector3.new(0, -(MAX_GROUND_LIFT + 2 * halfHeight + GROUND_CLEARANCE), 0)
	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	if not result then
		return position
	end

	local requiredY = result.Position.Y - coinBottomOffset + GROUND_CLEARANCE
	if requiredY <= position.Y or requiredY > position.Y + MAX_GROUND_LIFT then
		return position
	end

	return Vector3.new(position.X, requiredY, position.Z)
end

local function getCoinVisuals(coin: Model)
	local visuals = {}
	for _, descendant in coin:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			table.insert(visuals, {
				Instance = descendant,
				Transparency = descendant.Transparency,
			})
		end
	end
	return visuals
end

local function playCoinCollectSound(coin: Model)
	local sound = collectSound:Clone()
	sound.Parent = coin.PrimaryPart
	sound.Volume = collectSound.Volume
	sound.PlaybackSpeed = collectSound.PlaybackSpeed
	sound.Looped = false
	sound:Play()

	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function animateCollectedCoin(coin: Model)
	local startPivot = coin:GetPivot()
	local visuals = getCoinVisuals(coin)
	local duration = 0.45
	local startTime = os.clock()

	playCoinCollectSound(coin)

	task.spawn(function()
		while task.wait(0.03) do
			local elapsed = os.clock() - startTime
			if elapsed >= duration then
				break
			end

			local progress = elapsed / duration
			local rise = math.sin(progress * math.pi) * 2
			local transparency = math.clamp(progress, 0, 1)

			coin:PivotTo(startPivot + Vector3.new(0, rise, 0))

			for _, visual in visuals do
				visual.Instance.Transparency = visual.Transparency + (1 - visual.Transparency) * transparency
			end
		end

		coin:Destroy()
	end)
end

local function collectCoin(player: Player, coin: Model)
	local playerData = PlayerDataUtil.GetPlayerDataFolder(player)
	if playerData then
		playerData.MainStats.Coins.Value += 1
	end

	ActionTrackingService.FireAction(player, Actions.Common.Coin)
	animateCollectedCoin(coin)
end

local function collectFakeCoin(player: Player, coin: Model)
	ActionTrackingService.FireAction(player, Actions.Common.Coin)
	animateCollectedCoin(coin)
end

local function spawnCoin(position: Vector3, isFake: boolean, onCollected: (Player, Model) -> ())
	position = getGroundAdjustedPosition(position)

	local coin = coinTemplate:Clone()
	coin.Name = "CollectableCoin"
	local primaryPart = coin.PrimaryPart
	assert(primaryPart, "Cloned coin model must have a PrimaryPart")
	for _, descendant in coin:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end
	primaryPart.CanTouch = true
	local pivot = coin:GetPivot()
	coin:PivotTo(CFrame.new(position) * pivot.Rotation)
	coin:SetAttribute("IsFakeCoin", isFake)
	coin.Parent = workspace

	game.CollectionService:AddTag(coin, COIN_TAG)
	primaryPart.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then
			return
		end

		local player = game.Players:GetPlayerFromCharacter(character)
		if not player or coin:GetAttribute("IsCollecting") then
			return
		end

		coin:SetAttribute("IsCollecting", true)
		primaryPart.CanTouch = false
		onCollected(player, coin)
	end)

	return coin
end

function CoinSpawner.SpawnFakeCoin(position: Vector3): boolean
	local coinHeight = -coinBottomOffset + GROUND_CLEARANCE
	local coin = spawnCoin(position + Vector3.new(0, coinHeight, 0), true, collectFakeCoin)
	game.Debris:AddItem(coin, 45)
	return true
end

function CoinSpawner.HandleSpawner(part: BasePart, maxCoins: number)
	if part:GetAttribute("CoinSpawnerInitialized") then
		return
	end

	part:SetAttribute("CoinSpawnerInitialized", true)

	local coinCount = math.max(0, tonumber(maxCoins) or default.MaxCoins)

	for _ = 1, coinCount do
		local halfSize = part.Size / 2
		local randomPosition = Vector3.new(
			math.random(-halfSize.X, halfSize.X),
			default.HeightOffset,
			math.random(-halfSize.Z, halfSize.Z)
		)
		spawnCoin(part.Position + randomPosition, false, collectCoin)
	end
end

function CoinSpawner.Init()
	local function handleSpawner(instance)
		if instance:IsA("BasePart") and instance:IsDescendantOf(workspace) then
			local maxCoins = instance:GetAttribute("MaxCoins") or default.MaxCoins
			CoinSpawner.HandleSpawner(instance, maxCoins)
		end
	end

	for _, instance in game.CollectionService:GetTagged(SPAWNER_TAG) do
		handleSpawner(instance)
	end

	game.CollectionService:GetInstanceAddedSignal(SPAWNER_TAG):Connect(handleSpawner)
end

return CoinSpawner
