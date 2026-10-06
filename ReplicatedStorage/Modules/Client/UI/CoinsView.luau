local Packages = game.ReplicatedStorage.Modules.Packages
local PlayerDataUtil = require(Packages.PlayerDataUtil)

local player = game.Players.LocalPlayer

local CoinsView = {}

local coinLables: {TextLabel} = {}
local TAG = "CoinsView"

function CoinsView.Init()
	local playerDataFolder = PlayerDataUtil.GetPlayerDataFolder(player)
	local coinsValue = playerDataFolder.MainStats.Coins
	
	for _, label: TextLabel in game.CollectionService:GetTagged(TAG) do
		handleLabel(label)
	end
	
	game.CollectionService:GetInstanceAddedSignal(TAG):Connect(function(label)
		handleLabel(label)
	end)

	refreshCoins(coinsValue.Value)
	coinsValue.Changed:Connect(refreshCoins)
end

function handleLabel(label: TextLabel)
	table.insert(coinLables, label)
end

function refreshCoins(coins: number)
	for _, label in coinLables do
		label.Text = tostring(coins)
	end
end

return CoinsView
