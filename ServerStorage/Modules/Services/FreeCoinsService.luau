local module = {}

local PlayerDataUtil = require(game.ReplicatedStorage.Modules.Packages.PlayerDataUtil)

local ENABLED = false

function module.Init()
	if not ENABLED then
		return
	end
	
	game.Players.PlayerAdded:Connect(function(player)
		local playerDataFolder = PlayerDataUtil.GetPlayerDataFolder(player)
		local coinsValue = playerDataFolder.MainStats.Coins
		
		task.spawn(function()
			while task.wait(1) do
				coinsValue.Value += 1
			end
		end)
	end)	
end

return module
