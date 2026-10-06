local TaskService = require(game.ServerStorage.Modules.Services.TaskService)
local ATS = require(game.ServerStorage.Modules.Services.ActionTrackingService)

return function(player: Player, stick: Part)
	local stickTool = Instance.new("Tool")
	stickTool.Name = "Stick"
	stickTool.RequiresHandle = true
	stickTool.CanBeDropped = false
	stickTool.Parent = player.Backpack
	stickTool:SetAttribute("Stacks", true)
	stickTool:SetAttribute("MapTool", true)
	
	stick.Name = "Handle"
	stick:RemoveTag("Proximity")
	for _, child in stick:GetChildren() do
		child:Destroy()
	end
	stick.Anchored = false
	stick.Parent = stickTool
	
	ATS.FireAction(player, ATS.Actions.Common.Collect)
end
