local TaskService = require(game.ServerStorage.Modules.Services.TaskService)
local ATS = require(game.ServerStorage.Modules.Services.ActionTrackingService)

return function(player: Player, grape: Part)
	local tool = Instance.new("Tool")
	tool.Name = "Grape"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Parent = player.Backpack
	tool:SetAttribute("Stacks", true)
	tool:SetAttribute("MapTool", true)

	grape.Name = "Handle"
	grape:RemoveTag("Proximity")
	for _, child in grape:GetChildren() do
		child:Destroy()
	end
	grape.Size = Vector3.new(0.7, 0.7, 0.7)
	grape.Anchored = false
	grape.Parent = tool

	TaskService:Track(player, {Collectible = "Grape"})
	ATS.FireAction(player, ATS.Actions.Common.Collect)
end
