export type ButtonMethods = {
	OnMouseLeave: (self: ButtonAnimation) -> (),
	OnMouseClick: (self: ButtonAnimation) -> (),
	OnMouseEnter: (self: ButtonAnimation) -> (),
}

export type ButtonAnimation = {
	Button: GuiButton,
	OriginalSize: UDim2,
	SizeFactor: number,
	Sizeable: boolean,
} & ButtonMethods

type ButtonAnimationClass = {
	__index: ButtonAnimationClass,
	new: (button: GuiButton, sizeFactor: number, sizeable: boolean) -> ButtonAnimation,
} & ButtonMethods

local module: ButtonAnimationClass = {} :: any
module.__index = module

local Sounds = require(script.Parent.Sounds)

local Mouse_Enter_Size = 1.1
local MOUSE_ENTER_DURATION = 0.2
local MOUSE_CLICK_DURATION = 0.2

function module.new(button: GuiButton, sizeFactor: number, sizeable: boolean)
	local self: ButtonAnimation = setmetatable({
		Button = button,
		OriginalSize = button.Size,
		SizeFactor = sizeFactor,
		Sizeable = sizeable,
	}, module) :: any

	return self
end

function module:OnMouseEnter()
	task.spawn(Sounds.ButtonHover, nil)
	
	if self.Sizeable == true then
		local HoverSize = UDim2.new(
			self.OriginalSize.X.Scale * self.SizeFactor, 0,
			self.OriginalSize.Y.Scale * self.SizeFactor, 0
		)
		local tween = game.TweenService:Create(self.Button, 
			TweenInfo.new(MOUSE_ENTER_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{Size=HoverSize}
		)
		tween:Play()
		
		if self.Button:FindFirstChild("Icon") then
			local icon = self.Button:FindFirstChild("Icon") :: ImageLabel
			local tween = game.TweenService:Create(icon, TweenInfo.new(0.1), {Rotation = 25})
			tween:Play()
		end
	end
end

function module:OnMouseClick()
	task.spawn(Sounds.ButtonClick, nil)

	if self.Sizeable == true then
		local ClickSize = UDim2.new(
			self.OriginalSize.X.Scale / self.SizeFactor,
			0,
			self.OriginalSize.Y.Scale / self.SizeFactor,
			0
		)
		local tween = game.TweenService:Create(self.Button, 
			TweenInfo.new(MOUSE_CLICK_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{Size=ClickSize}
		)
		tween:Play()
	end
end

function module:OnMouseLeave()
	task.spawn(Sounds.ButtonLeave, nil)

	if self.Sizeable == true then
		local tween = game.TweenService:Create(self.Button, 
			TweenInfo.new(MOUSE_ENTER_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{Size=self.OriginalSize}
		)
		tween:Play()
		if self.Button:FindFirstChild("Icon") then
			local icon = self.Button:FindFirstChild("Icon") :: ImageLabel
			game.TweenService:Create(icon, TweenInfo.new(0.1), {Rotation = 0})
				:Play()
		end
	end
end

return module
