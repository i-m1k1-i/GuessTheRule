local Packages = game.ReplicatedStorage.Modules.Packages
local Client = game.ReplicatedStorage.Modules.Client
local Shared = game.ReplicatedStorage.Modules.Shared
local UIRefs = require(Client.UI.UIRefs)
local Network = require(Packages.Network)
local GameConfig = require(Shared.Config.Game)
local Notification = require(Shared.Notification)

local Guess = {}

local guessGui = UIRefs.Screens.Guess

local currentActionNumber = 1
local currentState = {
	RuleId = 0,
	SequenceLength = 0,
	AvailableActions = {},
	SelectedActions = {},
	IsRuleActive = false,
}

local guessCooldownEndsAt = 0
local guessCooldownDuration = GameConfig.Round.BaseGuessWait

local choicesFrame: Frame
local actionNumberLabel: TextLabel
local sequenceLengthLabel: TextLabel
local choicedActionLabel: TextLabel
local timerFrame: Frame
local timerLabel: TextLabel
local resultFrame: Frame
local resultLabel: TextLabel
local checkButton: ImageButton
local actionButton: ImageButton
local leftButton: ImageButton
local rightButton: ImageButton

local RESULT_COLORS = {
	CorrectPosition = "#4ADE80",
	PresentElsewhere = "#FACC15",
	NotInRule = "#F87171",
}

local function escapeRichText(text: string): string
	return text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

local function resetResult()
	resultFrame.Visible = false
	resultLabel.Text = ""
end

local function showGuessResult(guessedActions: {string}, result: {[string]: any})
	local correctPositions = {}
	for _, position in result.CorrectPositions or {} do
		correctPositions[position] = true
	end

	local presentActions = {}
	for _, actionName in result.PresentActions or {} do
		presentActions[actionName] = true
	end

	local formattedActions = {}
	for position, actionName in guessedActions do
		local color = RESULT_COLORS.NotInRule
		if correctPositions[position] then
			color = RESULT_COLORS.CorrectPosition
		elseif presentActions[actionName] then
			color = RESULT_COLORS.PresentElsewhere
		end

		table.insert(formattedActions, `<font color="{color}">{escapeRichText(actionName)}</font>`)
	end

	resultLabel.RichText = true
	resultLabel.Text = table.concat(formattedActions, " &gt; ")
	resultFrame.Visible = true
end

local function clampCurrentActionNumber()
	if currentState.SequenceLength <= 0 then
		currentActionNumber = 1
		return
	end

	currentActionNumber = math.clamp(currentActionNumber, 1, currentState.SequenceLength)
end

local function updateActionNavigationButtons()
	if currentState.SequenceLength <= 1 then
		leftButton.Visible = false
		rightButton.Visible = false
		return
	end

	clampCurrentActionNumber()
	leftButton.Visible = currentActionNumber > 1
	rightButton.Visible = currentActionNumber < currentState.SequenceLength
end

local function updateActionLabels()
	if currentState.SequenceLength <= 0 then
		actionNumberLabel.Text = "Action 0"
		choicedActionLabel.Text = "-"
		leftButton.Visible = false
		rightButton.Visible = false
		return
	end

	clampCurrentActionNumber()
	actionNumberLabel.Text = `Action {currentActionNumber}`
	local currentChoice = currentState.SelectedActions[currentActionNumber]
	choicedActionLabel.Text = currentChoice ~= nil and currentChoice or "-"
	sequenceLengthLabel.Text = `Length: {currentState.SequenceLength}`
	updateActionNavigationButtons()
end

local function getSelectedActions()
	local selectedActions = {}

	for index = 1, currentState.SequenceLength do
		local selectedAction = currentState.SelectedActions[index]
		if selectedAction == nil then
			return nil
		end

		table.insert(selectedActions, selectedAction)
	end

	return selectedActions
end

local function updateCheckButtonState()
	local now = workspace:GetServerTimeNow()
	local remainingCooldown = math.max(0, math.ceil(guessCooldownEndsAt - now))

	if remainingCooldown > 0 then
		timerFrame.Visible = true
		timerLabel.Text = tostring(remainingCooldown)
		checkButton.Active = false
		return
	end

	timerFrame.Visible = false
	timerLabel.Text = ""
	checkButton.Active = currentState.IsRuleActive
end

local function toggleChoices()
	choicesFrame.Visible = not choicesFrame.Visible
end

local function refreshChoicesFrame()
	local scrollingFrame = choicesFrame:WaitForChild("ScrollingFrame") :: ScrollingFrame
	local template = scrollingFrame:FindFirstChild("Template") :: TextButton?
	if not template then
		return
	end

	template.Visible = false

	for _, child in scrollingFrame:GetChildren() do
		if child:IsA("ImageButton") and child ~= template and child.Name ~= "Filler" then
			child:Destroy()
		end
	end

	for _, actionName in ipairs(currentState.AvailableActions) do
		local actionButtonClone = template:Clone()
		actionButtonClone.Name = actionName
		actionButtonClone.TextLabel.Text = actionName
		actionButtonClone.Visible = true
		actionButtonClone.Parent = scrollingFrame

		actionButtonClone.Activated:Connect(function()
			if not currentState.IsRuleActive or currentState.SequenceLength <= 0 then
				return
			end

			currentState.SelectedActions[currentActionNumber] = actionName
			choicesFrame.Visible = false
			updateActionLabels()
			updateCheckButtonState()
		end)
	end
end

local function resetLocalState()
	currentState.RuleId = 0
	currentState.SequenceLength = 0
	currentState.AvailableActions = {}
	currentState.SelectedActions = {}
	currentState.IsRuleActive = false
	currentActionNumber = 1
	guessCooldownEndsAt = 0
	guessCooldownDuration = GameConfig.Round.BaseGuessWait
	choicesFrame.Visible = false
	resetResult()
	updateActionLabels()
	updateCheckButtonState()
	refreshChoicesFrame()
end

function Guess.Init()
	local mainFrame = guessGui:WaitForChild("Frame") :: Frame
	local choiceFrame = mainFrame:WaitForChild("Choice") :: Frame
	local actionFrame = choiceFrame:WaitForChild("Action") :: Frame
	choicesFrame = mainFrame:WaitForChild("Choices") :: Frame
	actionNumberLabel = choiceFrame:WaitForChild("ActionNumber") :: TextLabel
	sequenceLengthLabel = choiceFrame:WaitForChild("SequenceLength") :: TextLabel
	actionButton = actionFrame:WaitForChild("Button") :: ImageButton
	choicedActionLabel = actionFrame:WaitForChild("ChoicedAction") :: TextLabel
	checkButton = mainFrame:WaitForChild("Check") :: ImageButton
	timerFrame = checkButton:WaitForChild("TimerFrame") :: Frame
	timerLabel = timerFrame:WaitForChild("Timer") :: TextLabel
	resultFrame = mainFrame:WaitForChild("Result") :: Frame
	resultLabel = resultFrame:WaitForChild("TextLabel") :: TextLabel
	leftButton = choiceFrame:WaitForChild("Left") :: ImageButton
	rightButton = choiceFrame:WaitForChild("Right") :: ImageButton

	local function moveAction(delta: number)
		if currentState.SequenceLength <= 0 then
			return
		end

		local nextActionNumber = currentActionNumber + delta
		if nextActionNumber < 1 or nextActionNumber > currentState.SequenceLength then
			return
		end

		currentActionNumber = nextActionNumber
		updateActionLabels()
	end

	leftButton.Activated:Connect(function()
		moveAction(-1)
	end)

	rightButton.Activated:Connect(function()
		moveAction(1)
	end)

	actionButton.Activated:Connect(function()
		toggleChoices()
	end)

	checkButton.Activated:Connect(function()
		if not currentState.IsRuleActive or currentState.SequenceLength <= 0 then
			return
		end

		local now = workspace:GetServerTimeNow()
		if now < guessCooldownEndsAt then
			return
		end

		local selectedActions = getSelectedActions()
		if not selectedActions then
			Notification.Error("Select an action for every position", 2)
			return
		end

		guessCooldownEndsAt = now + guessCooldownDuration
		updateCheckButtonState()

		local success, result = pcall(function()
			return Network:InvokeServer("GuessRule", selectedActions)
		end)

		if not success or typeof(result) ~= "table" then
			return
		end

		if result.Success == false then
			return
		end

		showGuessResult(selectedActions, result)

		if result.IsCorrect == true then
			guessCooldownEndsAt = 0
			guessCooldownDuration = GameConfig.Round.BaseGuessWait
			currentState.SelectedActions = {}
			currentActionNumber = 1
			updateActionLabels()
		else
			guessCooldownEndsAt = workspace:GetServerTimeNow() + guessCooldownDuration
			guessCooldownDuration += 5
			Notification.Error("You guessed wrong", 2)
		end

		updateCheckButtonState()
	end)

	Network:BindEvents({
		RuleChanged = function(params: {RuleId: number, SequenceLength: number?, AvailableActions: {string}?})
			currentState.RuleId = params.RuleId or currentState.RuleId
			currentState.SequenceLength = params.SequenceLength
			currentState.AvailableActions = params.AvailableActions or {}
			currentState.SelectedActions = {}
			currentState.IsRuleActive = true
			currentActionNumber = 1
			guessCooldownEndsAt = 0
			guessCooldownDuration = GameConfig.Round.BaseGuessWait
			resetResult()
			refreshChoicesFrame()
			updateActionLabels()
			updateCheckButtonState()
		end,

		GameStageChanged = function(params: {Stage: string})
			if params.Stage ~= "RuleActive" then
				resetLocalState()
			end
		end,
	})

	game["Run Service"].RenderStepped:Connect(function()
		updateCheckButtonState()
	end)

	resetLocalState()
end

return Guess
