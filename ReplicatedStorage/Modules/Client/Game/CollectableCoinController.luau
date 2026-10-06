local CollectableCoin = {}

local TAG = "CollectableCoin"
local SPIN_SPEED = 180

local coins = {}

local function handleCoin(coin: BasePart)
	if not coin or not coin:IsA("BasePart") then
		return
	end

	table.insert(coins, coin)
end

function CollectableCoin.Init()
	for _, coin in game.CollectionService:GetTagged(TAG) do
		handleCoin(coin)
	end

	game.CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance)
		handleCoin(instance)
	end)
	
	game["Run Service"].RenderStepped:Connect(function(deltaTime)
		for i, coin in coins do
			if not coin.Parent then
				table.remove(coins, i)
				return
			end

			coin.Rotation += Vector3.new(0, 0, SPIN_SPEED*deltaTime)
		end
	end)
end

return CollectableCoin
