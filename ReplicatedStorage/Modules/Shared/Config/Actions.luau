export type ActionDefinition = {
	Id: string,
	DisplayName: string,
	Icon: string?,
	Tracking: "Server" | "ClientValidated",
}

local COMMON_ACTIONS: {[string]: ActionDefinition} = {
	Jump = {Id = "Jump", DisplayName = "Jump", Tracking = "Server"},
	Dash = {Id = "Dash", DisplayName = "Dash", Tracking = "Server"},
	Interact = {Id = "Interact", DisplayName = "Interact", Tracking = "Server"},
	Collect = {Id = "Collect", DisplayName = "Collect", Tracking = "Server"},
	Coin = {Id = "Coin", DisplayName = "Coin", Tracking = "Server"},
}

local MAPS: {[string]: {UniqueActions: {[string]: ActionDefinition}}} = {
	Default = {UniqueActions={}},
	Forest = {
		UniqueActions = {
			--Apple = {Id = "Apple", DisplayName = "Apple", Tracking = "Server"},
		}
	},
}

local Actions = {}

Actions.Enum = {
	Common = {
		Jump = "Jump",
		Dash = "Dash",
		Coin = "Coin",
		Interact = "Interact",
		Collect = "Collect",
	},
	Forest = {
		--Apple = "Apple"
	}
}

local function getCurrentMapName(): string
	local activeMap = workspace:FindFirstChild("ActiveMap")
	if activeMap then
		return activeMap:GetAttribute("MapName")
	end

	return "Default"
end

function Actions.GetCurrentMapName(): string
	return getCurrentMapName()
end

function Actions.GetActionsForMap(mapName: string): {string}
	local mapConfig = MAPS[mapName] or MAPS.Default
	local actionIds = {}
	local seen = {}

	for actionId in COMMON_ACTIONS do
		table.insert(actionIds, actionId)
		seen[actionId] = true
	end
	for actionId in mapConfig.UniqueActions do
		if not seen[actionId] then
			table.insert(actionIds, actionId)
		end
	end

	table.sort(actionIds)
	return actionIds
end

function Actions.GetActionsForCurrentMap(): {string}
	return Actions.GetActionsForMap(getCurrentMapName())
end

function Actions.GetAction(actionId: string, mapName: string?): ActionDefinition?
	local commonAction = COMMON_ACTIONS[actionId]
	if commonAction then
		return commonAction
	end

	local mapConfig = MAPS[mapName or getCurrentMapName()] or MAPS.Default
	return mapConfig.UniqueActions[actionId]
end

function Actions.IsActionAvailable(actionId: string, mapName: string?): boolean
	return Actions.GetAction(actionId, mapName) ~= nil
end

function Actions.GetActionDefinitionsForCurrentMap(): {ActionDefinition}
	local definitions = {}
	for _, actionId in Actions.GetActionsForCurrentMap() do
		table.insert(definitions, Actions.GetAction(actionId) :: ActionDefinition)
	end
	return definitions
end

return Actions
