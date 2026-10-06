local TaskService = require(game.ServerStorage.Modules.Services.TaskService)
local ATS = require(game.ServerStorage.Modules.Services.ActionTrackingService)

return function(player: Player, blueberry: Part)
	TaskService:Track(player, {Collectible = "Blueberry"})
	ATS.FireAction(player, ATS.Actions.Common.Collect)
	blueberry:Destroy()
end
