local GamepassHandlers = {}

local passesData = require(script.Parent.Parent.Values.MonetizationIDsTable.Value).Gamepasses

GamepassHandlers[passesData["VIP"]] = function(player: Player, onLoad: boolean)
	print("Vip bought")
end


return GamepassHandlers
