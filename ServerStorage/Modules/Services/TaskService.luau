local Services = game.ServerStorage.Modules.Services
local Shared = game.ReplicatedStorage.Modules.Shared
local Packages = game.ReplicatedStorage.Modules.Packages

local Network = require(Packages.Network)
local GoodSignal = require(Packages.Signals.GoodSignal)
local TasksConfig = require(Shared.Config.Tasks)
local DeepCopy = require(Shared.Utility.DeepCopy)
local Notification = require(Shared.Notification)

type TaskDefinition = TasksConfig.TaskDefinition

type ActiveTask = {
	InstanceId: string,
	Definition: TaskDefinition,
	Current: number,
	Completed: boolean,
	CompletedBy: Player?,
}

type SerializedTask = {
	InstanceId: string,
	Description: string,
	Scope: string,
	Current: number,
	TotalNeeded: number,
	Completed: boolean,
}

local TaskService = {} :: {
	Init: () -> (),
	StartRound: (self: any, players: {Player}, mapName: string) -> (),
	EndRound: (self: any) -> (),
	GetTasks: (self: any) -> {ActiveTask},
	Track: (self: any, player: Player, context: {[string]: any}?) -> boolean,
	TaskCompleted: any,
}

TaskService.TaskCompleted = GoodSignal.new()

local _roundActive = false
local _roundPlayers: {[Player]: boolean} = {}
local _globalTasks: {ActiveTask} = {}
local _personalTasks: {[Player]: {ActiveTask}} = {}

local function makeActiveTask(definition: TaskDefinition, instanceId: string): ActiveTask
	return {
		InstanceId = instanceId,
		Definition = definition,
		Current = 0,
		Completed = false,
		CompletedBy = nil,
	}
end

local function serializeTask(task: ActiveTask): SerializedTask
	return {
		InstanceId = task.InstanceId,
		Description = task.Definition.Description,
		Scope = task.Definition.Scope,
		Current = task.Current,
		TotalNeeded = task.Definition.TotalNeeded,
		Completed = task.Completed,
	}
end

local function getPlayerTaskSnapshot(player: Player): {SerializedTask}
	if not _roundActive or not _roundPlayers[player] then
		return {}
	end

	local tasks = {}
	for _, task in _globalTasks do
		table.insert(tasks, serializeTask(task))
	end

	for _, task in _personalTasks[player] or {} do
		table.insert(tasks, serializeTask(task))
	end

	return tasks
end

local function sendTasksToPlayer(player: Player)
	if player.Parent == game.Players then
		Network:FireClient(player, "TasksUpdated", {Tasks = getPlayerTaskSnapshot(player)})
	end
end

local function sendTasksToRoundPlayers()
	for player in _roundPlayers do
		sendTasksToPlayer(player)
	end
end

local function matchesTask(task: ActiveTask, context: {[string]: any}?): boolean
	if task.Completed then
		return false
	end

	for key, expectedValue in task.Definition.Filters or {} do
		if not context or context[key] ~= expectedValue then
			return false
		end
	end

	return true
end

local function progressTask(task: ActiveTask, player: Player, amount: number)
	task.Current = math.min(task.Current + amount, task.Definition.TotalNeeded)
	if task.Current < task.Definition.TotalNeeded then
		return false
	end

	task.Completed = true
	task.CompletedBy = player

	local description = task.Definition.Description
	if task.Definition.Scope == "Global" then
		Notification.Success(`{player.DisplayName} COMPLETED TASK:\n{description}`)
	else
		Notification.Success(`TASK COMPLETED:\n{description}`, nil, player)
	end

	TaskService.TaskCompleted:Fire(player, serializeTask(task), table.clone(task.Definition.Reward))
	return true
end

function TaskService:StartRound(players: {Player}, mapName: string)
	self:EndRound()
	_roundActive = true

	for _, definition in TasksConfig.GetGlobalTasks(mapName) do
		table.insert(_globalTasks, makeActiveTask(definition, `global:{definition.Id}`))
	end

	local personalTaskPool = TasksConfig.GetPersonalTaskPool(mapName)
	for _, player in players do
		if player.Parent == game.Players then
			_roundPlayers[player] = true
			_personalTasks[player] = {}
			local availablePersonalTasks = table.clone(personalTaskPool)

			for taskIndex = 1, TasksConfig.PersonalTasksPerPlayer do
				if #availablePersonalTasks == 0 then
					break
				end

				local definition = table.remove(availablePersonalTasks, math.random(1, #availablePersonalTasks))
				table.insert(_personalTasks[player], makeActiveTask(definition, `personal:{taskIndex}`))
			end
		end
	end

	sendTasksToRoundPlayers()
end

function TaskService:EndRound()
	if not _roundActive then
		return
	end

	_roundActive = false
	_globalTasks = {}
	_personalTasks = {}
	_roundPlayers = {}
end

function TaskService:Track(player: Player, context: {[string]: any}?): boolean
	if not _roundActive or not _roundPlayers[player] then
		return false
	end

	local amount = context and context.Amount or 1
	if typeof(amount) ~= "number" or amount <= 0 then
		return false
	end

	local globalChanged = false
	for _, task in _globalTasks do
		if matchesTask(task, context) then
			progressTask(task, player, amount)
			globalChanged = true
		end
	end

	local personalChanged = false
	for _, task in _personalTasks[player] or {} do
		if matchesTask(task, context) then
			progressTask(task, player, amount)
			personalChanged = true
		end
	end

	if globalChanged then
		sendTasksToRoundPlayers()
	elseif personalChanged then
		sendTasksToPlayer(player)
	end

	return globalChanged or personalChanged
end

function TaskService:GetTasks(player: Player)
	return DeepCopy(_personalTasks[player]) or {}
end

function TaskService.Init()
	Network:BindFunctions({
		GetTasks = function(player: Player)
			return {Tasks = getPlayerTaskSnapshot(player)}
		end,
	})

	game.Players.PlayerRemoving:Connect(function(player)
		_roundPlayers[player] = nil
		_personalTasks[player] = nil
	end)
end

return TaskService