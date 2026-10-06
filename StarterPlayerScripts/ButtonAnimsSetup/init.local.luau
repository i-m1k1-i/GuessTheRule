local ButtonAnimation = require(script.ButtonAnimation)
local PlayerGui = game.Players.LocalPlayer.PlayerGui


local function isSystemGui(button: GuiButton)
	if game.UserInputService.TouchEnabled then
		local TouchGui = PlayerGui:WaitForChild("TouchGui")
		local ContextActionGui = PlayerGui:FindFirstChild("ContextActionGui")

		return button:IsDescendantOf(TouchGui)
			or (ContextActionGui and button:IsDescendantOf(ContextActionGui))
	end
	
	return false
end

local function handle(button: GuiButton)
	if button:IsA("GuiButton")
		and not button:HasTag("Ignore") 
		and not isSystemGui(button)
	then
		local sizeFactor: number = button:GetAttribute("SizeFactor") or 1.15 
		local sizeable: boolean = button:GetAttribute("Sizeable") or true
		local buttonAnimation = ButtonAnimation.new(button, sizeFactor, sizeable)
		
		button.MouseEnter:Connect(function()
			buttonAnimation:OnMouseEnter()
		end)

		button.MouseLeave:Connect(function()
			buttonAnimation:OnMouseLeave()
		end)

		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				buttonAnimation:OnMouseClick()
			end
		end)

		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				buttonAnimation:OnMouseLeave()
			end
		end)
	end
end

for _, button in ipairs(PlayerGui:GetDescendants()) do
	handle(button)
end

PlayerGui.DescendantAdded:Connect(function(button)
	handle(button)
end)
