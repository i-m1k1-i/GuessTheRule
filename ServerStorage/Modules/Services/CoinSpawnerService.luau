local Services = game.ServerStorage.Modules.Services
local Packages = game.ReplicatedStorage.Modules.Packages
local Shared = game.ReplicatedStorage.Modules.Shared
local PlayerDataUtil = require(Packages.PlayerDataUtil)
local ActionTrackingService = require(Services.ActionTrackingService)
local ActionsConfig = require(Shared.Config.Actions)

local Actions = ActionsConfig.Enum

local CoinSpawner = {}

local coinTemplate = game.ReplicatedStorage.Assets.Models.Coin
local collectSound = game.SoundService.SFX.Game.CoinCollect

local SPAWNER_TAG = "CoinSpawner"
local COIN_TAG = "CollectableCoin"

local default = {
	MaxCoins = 10,
	HeightOffset = 2.5,
}

local function getDecals(coin: BasePart): {Decal}
	local decals = {}
	for _, descendant in coin:GetDescendants() do
		if descendant:IsA("Decal") then
			table.insert(decals, descendant)
		end
	end
	return decals
end

local function playCoinCollectSound(coin: BasePart)
	local sound = collectSound:Clone()
	sound.Parent = coin
	sound.Volume = collectSound.Volume
	sound.PlaybackSpeed = collectSound.PlaybackSpeed
	sound.Looped = false
	sound:Play()

	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function animateCollectedCoin(coin: BasePart)
	local startPosition = coin.Position
	local decals = getDecals(coin)
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

			coin.Position = startPosition + Vector3.new(0, rise, 0)
			coin.Transparency = transparency

			for _, decal in decals do
				decal.Transparency = transparency
			end
		end

		coin:Destroy()
	end)
end

local function collectCoin(player: Player, coin: BasePart)
	local playerData = PlayerDataUtil.GetPlayerDataFolder(player)
	if playerData then
		playerData.MainStats.Coins.Value += 1
	end

	ActionTrackingService.FireAction(player, Actions.Common.Coin)
	animateCollectedCoin(coin)
end

local function collectFakeCoin(player: Player, coin: BasePart)
	ActionTrackingService.FireAction(player, Actions.Common.Coin)
	animateCollectedCoin(coin)
end

local function spawnCoin(position: Vector3, isFake: boolean, onCollected: (Player, BasePart) -> ())
	local coin = coinTemplate:Clone()
	coin.Name = "CollectableCoin"
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanTouch = true
	coin.Transparency = 0
	coin.Position = position
	coin:SetAttribute("IsFakeCoin", isFake)
	coin.Parent = workspace

	game.CollectionService:AddTag(coin, COIN_TAG)
	coin.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then
			return
		end

		local player = game.Players:GetPlayerFromCharacter(character)
		if not player or coin:GetAttribute("IsCollecting") then
			return
		end

		coin:SetAttribute("IsCollecting", true)
		coin.CanTouch = false
		onCollected(player, coin)
	end)

	return coin
end

function CoinSpawner.SpawnFakeCoin(position: Vector3): boolean
	local coinHeight = coinTemplate.Size.Y / 2
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
