local Packages = game.ReplicatedStorage.Modules.Packages
local Client = game.ReplicatedStorage.Modules.Client
local Shared = game.ReplicatedStorage.Modules.Shared

local Network = require(Packages.Network)
local UIRefs = require(Client.UI.UIRefs)
local ActionsConfig = require(Shared.Config.Actions)
local GameConfig = require(Shared.Config.Game)

local ActionsBufferView = {}

local DISPLAY_DURATION = GameConfig.Round.ActionViewDuration
local FADE_DURATION = 1
local MAX_ACTIONS = 3

local player = game.Players.LocalPlayer
local entries = {}
local nextLayoutOrder = 0

local bufferFrame: Frame
local actionTemplate: Frame

local function removeEntry(entry)
	local index = table.find(entries, entry)
	if index then
		table.remove(entries, index)
	end

	entry.Frame:Destroy()
end

local function fadeEntry(entry)
	if not table.find(entries, entry) or not entry.Frame.Parent then
		return
	end

	local tweenInfo = TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local objects = {entry.Frame}
	for _, descendant in entry.Frame:GetDescendants() do
		table.insert(objects, descendant)
	end

	for _, object in objects do
		local properties = {}
		if object:IsA("GuiObject") then
			properties.BackgroundTransparency = 1
		end
		if object:IsA("TextLabel") or object:IsA("TextButton") then
			properties.TextTransparency = 1
			properties.TextStrokeTransparency = 1
		elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
			properties.ImageTransparency = 1
		elseif object:IsA("UIStroke") then
			properties.Transparency = 1
		end

		if next(properties) then
			game.TweenService:Create(object, tweenInfo, properties):Play()
		end
	end

	task.delay(FADE_DURATION, function()
		removeEntry(entry)
	end)
end

local function addAction(actionName: string)
	local actionDefinition = ActionsConfig.GetAction(actionName)
	local actionFrame = actionTemplate:Clone()
	local iconLabel = actionFrame:WaitForChild("ImageLabel") :: ImageLabel
	local nameLabel = actionFrame:WaitForChild("TextLabel") :: TextLabel
	local icon = actionDefinition and actionDefinition.Icon or ""

	nameLabel.Text = actionDefinition and actionDefinition.DisplayName or actionName
	iconLabel.Image = icon
	iconLabel.Visible = icon ~= ""

	nextLayoutOrder += 1
	actionFrame.LayoutOrder = nextLayoutOrder
	actionFrame.Visible = true
	actionFrame.Parent = bufferFrame

	local entry = {Frame = actionFrame}
	table.insert(entries, entry)

	while #entries > MAX_ACTIONS do
		removeEntry(entries[1])
	end

	task.delay(DISPLAY_DURATION - FADE_DURATION, function()
		fadeEntry(entry)
	end)
end

function ActionsBufferView.Init()
	local bufferScreen = UIRefs.HUD:WaitForChild("ActionsBuffer")
	bufferFrame = bufferScreen:WaitForChild("ActionsBuffer") :: Frame
	actionTemplate = bufferFrame:WaitForChild("Action") :: Frame
	actionTemplate.Visible = false

	Network:BindEvents({
		PlayerActionObserved = function(params: {Player: Player, Action: string})
			if params.Player ~= player or typeof(params.Action) ~= "string" then
				return
			end

			addAction(params.Action)
		end,

		GameStageChanged = function(params: {Stage: string})
			if params.Stage == "RuleActive" then
				return
			end

			table.clear(entries)
			for _, child in bufferFrame:GetChildren() do
				if child ~= actionTemplate and child:IsA("Frame") then
					child:Destroy()
				end
			end
		end,
	})
end

return ActionsBufferView