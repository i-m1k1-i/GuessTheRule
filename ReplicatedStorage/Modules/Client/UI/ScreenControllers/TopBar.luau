local Packages = game.ReplicatedStorage.Modules.Packages
local Client = game.ReplicatedStorage.Modules.Client
local UIRefs = require(Client.UI.UIRefs)
local Network = require(Packages.Network)
local ActionsConfig = require(game.ReplicatedStorage.Modules.Shared.Config.Actions)

local TopBar = {}

local topBarFrame = UIRefs.TopBar
local timerLabel = topBarFrame:WaitForChild("TimerLabel") :: TextLabel
local stateLabel = topBarFrame:WaitForChild("StateLabel") :: TextLabel
local ruleView = topBarFrame:WaitForChild("RuleView") :: TextLabel
local timerConnection: RBXScriptConnection?
local currentStage = "Lobby"
local stageEndsAt: number? = nil
local currentRuleText: string? = nil

local STAGE_LABELS = {
	Lobby = "Intermission",
	MapLoading = "Loading map",
	RuleActive = "In game",
	Results = "Results",
}

local function formatTime(seconds: number): string
	local totalSeconds = math.max(0, math.ceil(seconds))
	local minutes = math.floor(totalSeconds / 60)
	local remainingSeconds = totalSeconds % 60
	return string.format("%02d:%02d", minutes, remainingSeconds)
end

local function updateTimer()
	local stageLabel = STAGE_LABELS[currentStage] or currentStage
	stateLabel.Text = stageLabel
	stateLabel.Visible = currentStage ~= "RuleActive"

	local showTimer = currentStage == "Lobby" or currentStage == "RuleActive"
	if not showTimer or not stageEndsAt then
		timerLabel.Text = ""
		return
	end

	local remaining = stageEndsAt - workspace:GetServerTimeNow()
	timerLabel.Text = `{formatTime(remaining)}`
end

local function updateRuleView()
	ruleView.Visible = currentStage == "RuleActive" and currentRuleText ~= nil
	ruleView.Text = ruleView.Visible and currentRuleText or ""
end

function TopBar.Init()
	ruleView.Visible = false
	ruleView.Text = ""

	local savedStage = workspace:GetAttribute("GameStage")
	local savedEndsAt = workspace:GetAttribute("GameStageEndsAt")
	if typeof(savedStage) == "string" then
		currentStage = savedStage
	end
	if typeof(savedEndsAt) == "number" then
		stageEndsAt = savedEndsAt
	end

	Network:BindEvents({
		GameStageChanged = function(params: {Stage: string, EndsAt: number?, MapName: string?})
			currentStage = params.Stage
			stageEndsAt = params.EndsAt
			if currentStage ~= "RuleActive" then
				currentRuleText = nil
			end
			updateRuleView()
			updateTimer()
		end,
		RuleChanged = function(params: {Rule: {string}?})
			currentRuleText = nil
			if typeof(params.Rule) == "table" and #params.Rule > 0 then
				local displayNames = {}
				for _, actionId in params.Rule do
					local actionDefinition = ActionsConfig.GetAction(actionId)
					table.insert(displayNames, actionDefinition and actionDefinition.DisplayName or actionId)
				end
				currentRuleText = table.concat(displayNames, " > ")
			end
			updateRuleView()
		end,
	})

	if timerConnection then
		timerConnection:Disconnect()
	end
	timerConnection = game["Run Service"].RenderStepped:Connect(updateTimer)
	updateRuleView()
	updateTimer()
end

return TopBar
