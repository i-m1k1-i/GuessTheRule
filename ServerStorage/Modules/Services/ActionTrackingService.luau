local Packages = game.ReplicatedStorage.Modules.Packages
local Shared = game.ReplicatedStorage.Modules.Shared
local GoodSignal = require(Packages.Signals.GoodSignal)
local Network = require(Packages.Network)
local ActionsConfig = require(Shared.Config.Actions)

local Actions = ActionsConfig.Enum

local ActionTrackingService = {}

local _playerTrackers: {[Player]: {
    CharacterAdded: RBXScriptConnection,
	CharacterConnections: {RBXScriptConnection},
}} = {}

local actionOccured = GoodSignal.new()
ActionTrackingService.ActionOccured = actionOccured

ActionTrackingService.Actions = Actions

local function handleJump(player: Player, newState: Enum.HumanoidStateType)
	if newState ~= Enum.HumanoidStateType.Jumping then
		return
	end

	ActionTrackingService.FireAction(player, Actions.Common.Jump)
end

local function bindCharacter(player: Player, character: Instance)
	local tracker = _playerTrackers[player]
	if not tracker then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local stateConnection = humanoid.StateChanged:Connect(function(_, newState)
		handleJump(player, newState)
	end)
	table.insert(tracker.CharacterConnections, stateConnection)
end

local function trackPlayer(player: Player)
	if _playerTrackers[player] then
		return
	end

	local tracker = {
		CharacterAdded = player.CharacterAdded:Connect(function(character)
			if character then
				bindCharacter(player, character)
			end
		end),
		CharacterConnections = {},
	}

	_playerTrackers[player] = tracker

	if player.Character then
		bindCharacter(player, player.Character)
	end
end

local function untrackPlayer(player: Player)
	local tracker = _playerTrackers[player]
	if not tracker then
		return
	end

	tracker.CharacterAdded:Disconnect()
	for _, connection in tracker.CharacterConnections do
		if connection then
			connection:Disconnect()
		end
	end

	_playerTrackers[player] = nil
end

function ActionTrackingService.Init()
	for _, player in game.Players:GetPlayers() do
		trackPlayer(player)
	end

	game.Players.PlayerAdded:Connect(function(player)
		trackPlayer(player)
	end)

	game.Players.PlayerRemoving:Connect(function(player)
		untrackPlayer(player)
	end)
	
	Network:BindEvents({
		ActionOccured = function(player: Player, actionName: string)
			ActionTrackingService.FireAction(player, actionName)
		end,
	})
end

function ActionTrackingService.FireAction(player: Player, actionName: string)
	actionOccured:Fire(player, actionName)
end

return ActionTrackingService
