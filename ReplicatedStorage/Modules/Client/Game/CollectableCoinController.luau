local CollectableCoin = {}

local TAG = "CollectableCoin"
local SPIN_SPEED = 180

local coins: {Model} = {}

local function handleCoin(coin: Instance)
	if not coin:IsA("Model") then
		return
	end
	
	local startTime = os.clock()
	repeat
		task.wait()
	until coin.PrimaryPart or (os.clock() - startTime) >= 5
	
	if not coin.PrimaryPart then
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
		for i = #coins, 1, -1 do
			local coin = coins[i]
			if not coin.Parent or not coin.PrimaryPart then
				table.remove(coins, i)
			else
				local rotation = CFrame.Angles(0, math.rad(SPIN_SPEED * deltaTime), 0)
				coin:PivotTo(coin:GetPivot() * rotation)
			end
		end
	end)
end

return CollectableCoin
