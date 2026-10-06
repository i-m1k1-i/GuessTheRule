local TaskService = require(game.ServerStorage.Modules.Services.TaskService)
local ATS = require(game.ServerStorage.Modules.Services.ActionTrackingService)

local ProximityService = {}

local PROXIMITY_TAG = "Proximity"

local ObjectHandlers = {
	Grape = false,
}

function ProximityService.Init()
	for _, folder in script:GetChildren() do
		for _, module in folder:GetChildren() do
			ObjectHandlers[module.Name] = require(module)
		end
	end
	
	for _, object in game.CollectionService:GetTagged(PROXIMITY_TAG) do
		handleProximityTag(object)
	end
	
	game.CollectionService:GetInstanceAddedSignal(PROXIMITY_TAG):Connect(handleProximityTag)
	
	game.ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		local object = prompt.Parent
		if not object then
			return
		end
		
		if not object:IsDescendantOf(workspace) then
			return
		end

		local objectName = object:GetAttribute("Object")
		if not objectName then
			return
		end

		local handler = ObjectHandlers[objectName]
		
		if handler then
			handler(player, object)
		end
	end)
end

function handleProximityTag(object: Instance)
	if not object:IsDescendantOf(workspace) then
		return
	end
	
	local objectName = object:GetAttribute("Object")
	if not objectName then
		warn(`No object name for {object}`)
		return
	end
	
	local handler = ObjectHandlers[objectName]
	
	if typeof(handler) ~= "function" then
		if handler == nil then
			warn(`No handler for {objectName}`)
		end
		return
	end
	
	local actionText = object:GetAttribute("Action")
	
	local proximity = Instance.new("ProximityPrompt")
	proximity.ActionText = actionText
	proximity.ObjectText = objectName
	proximity.RequiresLineOfSight = false
	proximity.Parent = object
	proximity.Style = Enum.ProximityPromptStyle.Custom
end

return ProximityService
