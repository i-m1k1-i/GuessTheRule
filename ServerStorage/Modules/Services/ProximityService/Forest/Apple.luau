local TaskService = require(game.ServerStorage.Modules.Services.TaskService)
local ATS = require(game.ServerStorage.Modules.Services.ActionTrackingService)

return function(player: Player, apple: Part)
	local appleTool = Instance.new("Tool")
	appleTool.Name = "Apple"
	appleTool.RequiresHandle = true
	appleTool.CanBeDropped = false
	appleTool.Parent = player.Backpack
	appleTool:SetAttribute("Stacks", true)
	appleTool:SetAttribute("MapTool", true)

	apple.Name = "Handle"
	apple:RemoveTag("Proximity")
	for _, child in apple:GetChildren() do
		child:Destroy()
	end
	apple.Size = Vector3.new(1.5, 1.5, 1.5)
	apple.Anchored = false
	apple.Parent = appleTool

	TaskService:Track(player, {Collectible = "Apple"})
	ATS.FireAction(player, ATS.Actions.Common.Collect)
end
