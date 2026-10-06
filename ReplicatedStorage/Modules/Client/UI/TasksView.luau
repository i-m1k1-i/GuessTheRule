local Packages = game.ReplicatedStorage.Modules.Packages
local Client = game.ReplicatedStorage.Modules.Client

local Network = require(Packages.Network)
local UIRefs = require(Client.UI.UIRefs)

local TasksView = {}

local ANIMATION_DURATION = 0.5

local tasksFrame: Frame
local scrollingFrame: ScrollingFrame
local taskTemplate: Frame
local toggleButton: ImageButton

local stateConfig = {
	Default = {
		framePosition = nil ,
		buttonRotation = nil,
	},
	Hidden = {
		framePosition = nil ,
		buttonRotation = nil,
	}
}

local isShown = true
local isAnimating = false

local function clearGeneratedTasks()
	for _, child in scrollingFrame:GetChildren() do
		if child:GetAttribute("GeneratedTask") then
			child:Destroy()
		end
	end
end

local function renderTasks(tasks: {any})
	clearGeneratedTasks()

	for _, task in tasks do
		local taskCard = taskTemplate:Clone()
		local descriptionLabel = taskCard:FindFirstChild(" Description") or taskCard:FindFirstChild("Description")
		local progressLabel = taskCard:FindFirstChild("Progress")
		local checkmarkLabel = taskCard:FindFirstChild("Checkmark")

		if not descriptionLabel or not descriptionLabel:IsA("TextLabel") then
			warn("TasksView requires TaskTemplate to contain a Description TextLabel")
			taskCard:Destroy()
			continue
		end
		if not progressLabel or not progressLabel:IsA("TextLabel") then
			warn("TasksView requires TaskTemplate to contain a Progress TextLabel")
			taskCard:Destroy()
			continue
		end
		if not checkmarkLabel or not checkmarkLabel:IsA("TextLabel") then
			warn("TasksView requires TaskTemplate to contain a Checkmark TextLabel")
			taskCard:Destroy()
			continue
		end

		descriptionLabel.Text = task.Description
		progressLabel.Text = `{task.Current}/{task.TotalNeeded}`
		progressLabel.Visible = not task.Completed
		checkmarkLabel.Visible = task.Completed
		taskCard.Name = task.InstanceId
		taskCard.LayoutOrder = task.Scope == "Global" and 0 or 3
		taskCard:SetAttribute("GeneratedTask", true)
		taskCard.Visible = true
		taskCard.Parent = scrollingFrame
	end
end

local function toggle(on: boolean)
	if isAnimating then
		return
	end
	
	if on ~= nil then
		isShown = on
	else
		isShown = not isShown
	end
	isAnimating = true
	
	local tweenInfo = TweenInfo.new(ANIMATION_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	
	local frameTween: Tween
	local buttonTween: Tween
	
	if isShown then
		local defaultState = stateConfig.Default
		
		frameTween = game.TweenService:Create(tasksFrame, tweenInfo, {
			Position = defaultState.framePosition,
			AnchorPoint = Vector2.new(1, 0)
		})
		buttonTween = game.TweenService:Create(toggleButton, tweenInfo, {
			Rotation = defaultState.buttonRotation
		})
	else
		local hiddenState = stateConfig.Hidden
		
		frameTween = game.TweenService:Create(tasksFrame, tweenInfo, {
			Position = hiddenState.framePosition,
			AnchorPoint = Vector2.new(0, 0)
		})
		buttonTween = game.TweenService:Create(toggleButton, tweenInfo, {
			Rotation = hiddenState.buttonRotation
		})
	end

	frameTween:Play()
	buttonTween:Play()
	
	frameTween.Completed:Wait()
	
	isAnimating = false
end

function TasksView.Init()
	tasksFrame = UIRefs.HUD:WaitForChild("Tasks") :: Frame
	scrollingFrame = tasksFrame:WaitForChild("ScrollingFrame") :: ScrollingFrame
	taskTemplate = scrollingFrame:WaitForChild("TaskTemplate") :: Frame
	toggleButton = tasksFrame:WaitForChild("ToggleButton") :: ImageButton
	
	stateConfig.Default.buttonRotation = toggleButton.Rotation
	stateConfig.Default.framePosition = tasksFrame.Position
	stateConfig.Hidden.buttonRotation = toggleButton.Rotation + 180
	stateConfig.Hidden.framePosition = UDim2.fromScale(1.005, tasksFrame.Position.Y.Scale)
	
	tasksFrame.Visible = false
	taskTemplate.Visible = false

	toggleButton.Activated:Connect(function()
		toggle()
	end)

	Network:BindEvents({
		TasksUpdated = function(params: {Tasks: {any}})
			renderTasks(params.Tasks or {})
		end,

		GameStageChanged = function(params: {Stage: string})
			if params.Stage ~= "RuleActive" then
				renderTasks({})
				tasksFrame.Visible = false
			else
				tasksFrame.Visible = true
				toggle(true)
			end
		end,
	})

	task.defer(function()
		local success, result = pcall(function()
			return Network:InvokeServer("GetTasks")
		end)
		if success and typeof(result) == "table" then
			renderTasks(result.Tasks or {})
		end
	end)
end

return TasksView