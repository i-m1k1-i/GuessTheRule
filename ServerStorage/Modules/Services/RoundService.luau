local Services = game.ServerStorage.Modules.Services
local Shared = game.ReplicatedStorage.Modules.Shared
local Packages = game.ReplicatedStorage.Modules.Packages
local Network = require(Packages.Network)
local GoodSignal = require(Packages.Signals.GoodSignal)
local PlayerDataUtil = require(Packages.PlayerDataUtil)
local Notification = require(Shared.Notification)
local Config = require(Shared.Config)
local GameConfig = require(Shared.Config.Game)
local ActionsConfig = require(Shared.Config.Actions)
local TraitorService = require(Services.TraitorService)
local ActionTrackingService = require(Services.ActionTrackingService)

export type RoundState = "Lobby" | "RuleActive" | "MatchEnd"
export type MatchResult = {Player: Player, Score: number}

local RoundService = {} :: {
	Init: () -> (),
	State: RoundState,
	RuleChanged: any,
	PlayerViolated: any,
	MatchEnded: any,
	StartMatch: (self: any, players: {Player}) -> boolean,
	OnPlayerAction: (self: any, player: Player, actionName: string) -> boolean,
	HandleGuess: (self: any, player: Player, guess: {string}) -> {[string]: any},
}

RoundService.State = "Lobby"
RoundService.RuleChanged = GoodSignal.new()
RoundService.PlayerViolated = GoodSignal.new()
RoundService.MatchEnded = GoodSignal.new()

local _currentRule: {string}? = nil
local _currentRuleId = 0
local _matchTimer: thread? = nil
local _matchGeneration = 0
local _matchPlayers: {[Player]: any} = {}
local _traitor: Player? = nil
local _rulesSolvedThisMatch = 0
local _matchEndsAt: number? = nil
local _ruleLengthStage = 1

local function cancelTimer(timer: thread?): thread?
	if timer and timer ~= coroutine.running() then
		pcall(task.cancel, timer)
	end
	return nil
end

local function appendUnique(items: {string}, item: string)
	for _, existingItem in items do
		if existingItem == item then
			return
		end
	end
	table.insert(items, item)
end

local function newPlayerRoundData()
	return {
		ActionBuffer = {} :: {string},
		WarningUsed = false,
		ViolationCount = 0,
		Score = 0,
	}
end

local function getRuleLength(): number
	local minLength = math.max(1, GameConfig.Round.MinRuleLength)
	local maxLength = math.max(minLength, GameConfig.Round.MaxRuleLength or minLength)

	-- First rule of the match is randomly 1 or 2 actions; every solved rule afterwards is one action longer.
	if _ruleLengthStage <= 1 then
		return math.random(minLength, math.min(minLength + 1, maxLength))
	end

	return math.clamp(minLength + _ruleLengthStage - 1, minLength, maxLength)
end

local function generateRule(): {string}
	local availableActions = ActionsConfig.GetActionsForCurrentMap()
	local maxLength = math.max(GameConfig.Round.MinRuleLength, GameConfig.Round.MaxRuleLength)
	assert(#availableActions >= maxLength, "RoundService requires enough available actions to generate a rule")

	local pool = table.clone(availableActions)
	local ruleLength = getRuleLength()
	local rule: {string} = {}
	for _ = 1, ruleLength do
		local index = math.random(1, #pool)
		local actionId = pool[index]
		assert(actionId ~= nil)
		table.insert(rule, actionId)
	end
	return rule
end

local function resetPlayerForNewRule(playerRoundData)
	playerRoundData.ActionBuffer = {}
	playerRoundData.WarningUsed = false
	playerRoundData.ViolationCount = 0
end

local function broadcastRuleChanged()
	for player in _matchPlayers do
		Network:FireClient(player, "RuleChanged", {
			RuleId = _currentRuleId,
			Rule = player == _traitor and table.clone(_currentRule :: {string}) or nil,
			AvailableActions = ActionsConfig.GetActionsForCurrentMap(),
			SequenceLength = #(_currentRule :: {string}),
		})
	end
end

local function startNewRule(showNotification: boolean?)
	_currentRuleId += 1
	_currentRule = generateRule()

	for _, playerRoundData in _matchPlayers do
		resetPlayerForNewRule(playerRoundData)
	end

	_matchEndsAt = _matchEndsAt or (workspace:GetServerTimeNow() + GameConfig.Round.MatchDuration)
	RoundService.State = "RuleActive"
	workspace:SetAttribute("GameStage", "RuleActive")
	workspace:SetAttribute("GameStageEndsAt", _matchEndsAt)
	Network:FireAllClients("GameStageChanged", {
		Stage = "RuleActive",
		Duration = GameConfig.Round.MatchDuration,
		EndsAt = _matchEndsAt,
		RuleId = _currentRuleId,
	})
	broadcastRuleChanged()
	if showNotification ~= false then
		Notification.Info(Config.Strings.RuleChanged)
	end
	RoundService.RuleChanged:Fire(_currentRuleId)
end

function RoundService:_transitionRule(showNotification: boolean?)
	if RoundService.State ~= "RuleActive" then
		return
	end

	startNewRule(showNotification)
end

local function awardScore(player: Player, amount: number)
	local playerRoundData = _matchPlayers[player]
	if not playerRoundData then
		return
	end

	playerRoundData.Score += amount
	local dataFolder = PlayerDataUtil.GetPlayerDataFolder(player)
	if dataFolder and dataFolder.MainStats and dataFolder.MainStats.AllTimeScore then
		dataFolder.MainStats.AllTimeScore.Value += amount
	end
end

function RoundService:OnPlayerAction(player: Player, actionName: string): boolean
	if RoundService.State ~= "RuleActive" or not _currentRule or not _matchPlayers[player] then
		return false
	end
	if typeof(actionName) ~= "string" or not ActionsConfig.IsActionAvailable(actionName) then
		return false
	end
	
	local playerRoundData = _matchPlayers[player]
	table.insert(playerRoundData.ActionBuffer, actionName)
	while #playerRoundData.ActionBuffer > #_currentRule do
		table.remove(playerRoundData.ActionBuffer, 1)
	end

	Network:FireAllClients("PlayerActionObserved", {Player = player, Action = actionName})
	if #playerRoundData.ActionBuffer < #_currentRule then
		return true
	end

	for index, action in _currentRule do
		if playerRoundData.ActionBuffer[index] ~= action then
			return true
		end
	end

	self:_handleViolation(player, playerRoundData)
	return true
end

local function createGuessFeedback(guess: {string}, rule: {string}): {[string]: any}
	local exactMatches = 0
	local correctPositions = {}
	local presentActions = {}
	local missingActions = {}
	local notInRuleActions = {}
	local ruleSet = {}
	local guessedSet = {}

	for _, action in rule do
		ruleSet[action] = true
	end

	for _, action in guess do
		guessedSet[action] = true
	end

	for index, action in guess do
		if action == rule[index] then
			exactMatches += 1
			table.insert(correctPositions, index)
		end
		if ruleSet[action] then
			appendUnique(presentActions, action)
		else
			appendUnique(notInRuleActions, action)
		end
	end

	for _, action in rule do
		local foundInGuess = guessedSet[action] == true
		if not foundInGuess then
			appendUnique(missingActions, action)
		end
	end

	return {
		ExactMatches = exactMatches,
		CorrectPositions = correctPositions,
		PresentActions = presentActions,
		MissingActions = missingActions,
		NotInRuleActions = notInRuleActions,
		IsCorrect = exactMatches == #rule and #guess == #rule,
		RuleLength = #rule,
		GuessLength = #guess,
	}
end

local function normalizeGuess(guessedActions: any): {string}?
	if typeof(guessedActions) ~= "table" then
		return nil
	end

	local normalizedGuess = {}
	for _, actionName in guessedActions do
		if typeof(actionName) ~= "string" or not ActionsConfig.IsActionAvailable(actionName) then
			return nil
		end
		table.insert(normalizedGuess, actionName)
	end

	return normalizedGuess
end

function RoundService:HandleGuess(player: Player, guessedActions: {string}): {[string]: any}
	if RoundService.State ~= "RuleActive" or not _currentRule or not _matchPlayers[player] then
		return {
			Success = false,
			IsCorrect = false,
			Error = "The rule is not active.",
		}
	end

	local normalizedGuess = normalizeGuess(guessedActions)
	if not normalizedGuess then
		return {
			Success = false,
			IsCorrect = false,
			Error = "Invalid guess payload.",
		}
	end

	local feedback = createGuessFeedback(normalizedGuess, _currentRule)
	feedback.Success = true
	feedback.RuleId = _currentRuleId
	feedback.Player = player

	if feedback.IsCorrect then
		feedback.RuleSolved = true
		feedback.RuleChanged = true
		feedback.PreviousRuleId = _currentRuleId
		feedback.TotalRulesSolved = _rulesSolvedThisMatch + 1
		_rulesSolvedThisMatch += 1
		awardScore(player, GameConfig.Round.GuessReward)
		Notification.Success(`{player.DisplayName} guessed the rule!`)

		task.wait(1)

		if _rulesSolvedThisMatch >= (GameConfig.Round.RulesToGuess) then
			task.defer(function()
				if RoundService.State == "RuleActive" then
					RoundService:_endMatch("Investigators")
				end
			end)
		else
			_ruleLengthStage += 1
			startNewRule(true)
		end
		return feedback
	end

	local penalty = GameConfig.Round.GuessPenalty or 0
	if penalty > 0 then
		awardScore(player, -penalty)
	end
	feedback.RuleSolved = false
	feedback.RuleChanged = false
	feedback.PenaltyApplied = penalty
	return feedback
end

function RoundService:_handleViolation(player: Player, playerRoundData)
	playerRoundData.ActionBuffer = {}
	local penalty = 0
	local isWarning = not playerRoundData.WarningUsed

	if isWarning then
		playerRoundData.WarningUsed = true
	else
		playerRoundData.ViolationCount += 1
		local penaltyIndex = math.min(playerRoundData.ViolationCount, #GameConfig.Round.PenaltyTable)
		penalty = GameConfig.Round.PenaltyTable[penaltyIndex]
		awardScore(player, -penalty)
		if TraitorService.OnPlayerBaited(_traitor, player) then
			awardScore(_traitor :: Player, 100)
		end
	end

	local payload = {
		RuleId = _currentRuleId,
		Penalty = penalty,
		IsWarning = isWarning,
	}
	Network:FireClient(player, "RuleViolation", payload)
	Network:FireAllClients("PlayerRuleViolated", {Player = player, RuleId = _currentRuleId})
	Notification.Warning(`{player.DisplayName} violated the rule`)
	RoundService.PlayerViolated:Fire(player, isWarning)

	if not isWarning then
		local activeViolations = 0
		for _, participant in _matchPlayers do
			if participant.ViolationCount > 0 then
				activeViolations += 1
			end
		end
		if activeViolations >= (GameConfig.Round.ViolationsToForceRuleChange) then
			RoundService:_transitionRule(false)
		end
	end
end

local function getUniquePlayers(players: {Player}): {Player}
	local uniquePlayers = {}
	local seen = {}
	for _, player in players do
		if typeof(player) == "Instance" and player:IsA("Player") and player.Parent == game.Players and not seen[player] then
			seen[player] = true
			table.insert(uniquePlayers, player)
		end
	end
	return uniquePlayers
end

function RoundService:StartMatch(players: {Player}): boolean
	if RoundService.State ~= "Lobby" then
		return false
	end

	local matchPlayers = getUniquePlayers(players)
	if #matchPlayers < 1 then
		warn("RoundService:StartMatch requires at least one player")
		return false
	end

	_matchGeneration += 1
	local matchGeneration = _matchGeneration
	_matchPlayers = {}
	_rulesSolvedThisMatch = 0
	_ruleLengthStage = 1
	_matchEndsAt = workspace:GetServerTimeNow() + GameConfig.Round.MatchDuration
	for _, player in matchPlayers do
		_matchPlayers[player] = newPlayerRoundData()
	end

	_traitor = TraitorService.SelectTraitor(matchPlayers)
	if _traitor then
		Network:FireClient(_traitor, "AssignedTraitor", {})
	end

	startNewRule(false)
	_matchTimer = task.delay(GameConfig.Round.MatchDuration, function()
		if _matchGeneration == matchGeneration then
			self:_endMatch("Traitor")
		end
	end)
	return true
end

function RoundService:_endMatch(winner: string?)
	if RoundService.State == "Lobby" or RoundService.State == "MatchEnd" then
		return
	end
	_matchTimer = cancelTimer(_matchTimer)

	RoundService.State = "MatchEnd"
	local resultsEndsAt = workspace:GetServerTimeNow() + GameConfig.Round.ResultsDuration
	workspace:SetAttribute("GameStage", "Results")
	workspace:SetAttribute("GameStageEndsAt", resultsEndsAt)
	Network:FireAllClients("GameStageChanged", {
		Stage = "Results",
		Duration = GameConfig.Round.ResultsDuration,
		EndsAt = resultsEndsAt,
	})
	local results: {MatchResult} = {}
	for player, playerRoundData in _matchPlayers do
		table.insert(results, {Player = player, Score = playerRoundData.Score})
	end
	table.sort(results, function(first, second)
		return first.Score > second.Score
	end)

	Network:FireAllClients("MatchEnded", {Results = results, TraitorWas = _traitor, Winner = winner})
	RoundService.MatchEnded:Fire(results)

	_matchGeneration += 1
	_matchPlayers = {}
	_currentRule = nil
	_traitor = nil
	_rulesSolvedThisMatch = 0
	_matchEndsAt = nil
	TraitorService.Clear()

	task.wait(GameConfig.Round.ResultsDuration)
	if RoundService.State == "MatchEnd" then
		RoundService.State = "Lobby"
	end
end

function RoundService.Init()
	Network:BindFunctions({
		GuessRule = function(player: Player, guessedActions: {string})
			return RoundService:HandleGuess(player, guessedActions)
		end,
	})

	ActionTrackingService.ActionOccured:Connect(function(player: Player, actionName: string)
		RoundService:OnPlayerAction(player, actionName)
	end)

	game.Players.PlayerRemoving:Connect(function(player)
		local wasParticipant = _matchPlayers[player] ~= nil
		_matchPlayers[player] = nil
		if not wasParticipant or RoundService.State == "Lobby" or RoundService.State == "MatchEnd" then
			return
		end

		if player == _traitor then
			local remainingPlayers = {}
			for remainingPlayer in _matchPlayers do
				table.insert(remainingPlayers, remainingPlayer)
			end
			_traitor = TraitorService.SelectTraitor(remainingPlayers)
			if _traitor then
				Network:FireClient(_traitor, "AssignedTraitor", {})
				Network:FireClient(_traitor, "RuleChanged", {
					RuleId = _currentRuleId,
					Rule = table.clone(_currentRule :: {string}),
					AvailableActions = ActionsConfig.GetActionsForCurrentMap(),
				})
			end
		end

		local remainingCount = 0
		for _ in _matchPlayers do
			remainingCount += 1
		end
		if remainingCount < 2 then
			RoundService:_endMatch("Traitor")
		end
	end)
end

return RoundService