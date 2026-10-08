export type Reward = {
	Kind: string,
	Amount: number,
}

export type TaskDefinition = {
	Id: string,
	Description: string,
	Scope: "Global" | "Personal",
	Filters: {[string]: any}?,
	TotalNeeded: number,
	Reward: Reward,
}

local Tasks = {}

Tasks.PersonalTasksPerPlayer = 2

local GLOBAL_TASKS_BY_MAP: {TaskDefinition} = {
	Forest = {
		{
			Id = "CollectApplesForCamp",
			Description = "Take apples to the tower",
			Scope = "Global",
			Filters = {Location = "Tower", Collectible = "Apple"},
			TotalNeeded = 15,
			Reward = {Kind = "Coins", Amount = 25},
		},
		{
			Id = "RepairHut",
			Description = "Repair the hut with sticks",
			Scope = "Global",
			Filters = {Action = "RepairHut"},
			TotalNeeded = 6,
			Reward = {Kind = "Coins", Amount = 10},
		},
	}
}

local PERSONAL_TASKS_BY_MAP: {[string]: {TaskDefinition}} = {
	Forest = {
		{
			Id = "CollectApples",
			Description = "Collect apples",
			Scope = "Personal",
			Filters = {Collectible = "Apple"},
			TotalNeeded = 6,
			Reward = {Kind = "Coins", Amount = 10},
		},
		{
			Id = "CollectBlueberries",
			Description = "Collect blueberries",
			Scope = "Personal",
			Filters = {Collectible = "Blueberry"},
			TotalNeeded = 3,
			Reward = {Kind = "Coins", Amount = 10},
		},
		{
			Id = "CollectGrapes",
			Description = "Collect grapes",
			Scope = "Personal",
			Filters = {Collectible = "Grape"},
			TotalNeeded = 3,
			Reward = {Kind = "Coins", Amount = 10},
		},
		{
			Id = "LightCampfire",
			Description = "Light the campfire",
			Scope = "Personal",
			Filters = {Action = "LightCampfire"},
			TotalNeeded = 5,
			Reward = {Kind = "Coins", Amount = 10},
		}
	},
}

local function copyDefinitions(definitions: {TaskDefinition}): {TaskDefinition}
	local copiedDefinitions = {}
	for _, definition in definitions do
		table.insert(copiedDefinitions, {
			Id = definition.Id,
			Description = definition.Description,
			Scope = definition.Scope,
			Filters = definition.Filters and table.clone(definition.Filters) or nil,
			TotalNeeded = definition.TotalNeeded,
			Reward = table.clone(definition.Reward),
		})
	end
	return copiedDefinitions
end

function Tasks.GetGlobalTasks(mapName): {TaskDefinition}
	return copyDefinitions(GLOBAL_TASKS_BY_MAP[mapName])
end

function Tasks.GetPersonalTaskPool(mapName: string): {TaskDefinition}
	return copyDefinitions(PERSONAL_TASKS_BY_MAP[mapName])
end

return Tasks