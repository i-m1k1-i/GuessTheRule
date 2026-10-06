local module = {}

local ScreenController = require(game.ReplicatedStorage.Modules.Client.UI.ScreenController)
local UIRefs = require(game.ReplicatedStorage.Modules.Client.UI.UIRefs)

local ButtonTag = "ScreenControllerButton"

function module.Init()
	setupTaggedButtons()
	setupScreens()
end

function setupScreens()
	for name, screen in UIRefs.Screens do
		if screen:HasTag("NoCloseButton") then
			continue
		end
		
		task.spawn(function()
			screen.Frame:WaitForChild("Close")
			screen.Frame.Close.Activated:Connect(function()
				ScreenController.CloseScreen(name)
			end)
		end)
	end
end

function setupTaggedButtons()
	local buttons = game.CollectionService:GetTagged(ButtonTag)
	
	for _, button in buttons do
		handleButton(button)
	end

	game.CollectionService:GetInstanceAddedSignal(ButtonTag):Connect(function(button)
		handleButton(button)
	end)
end

function handleButton(button: GuiButton)
	if not button:IsDescendantOf(game.Players.LocalPlayer) then
		return
	end
	
	local screen = button:GetAttribute("Screen")
	
	button.Activated:Connect(function()
		ScreenController.ToggleScreen(screen)
	end)
end

return module