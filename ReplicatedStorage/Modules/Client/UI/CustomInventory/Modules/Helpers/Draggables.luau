local UserInputService = game:GetService("UserInputService")

local DraggableObject 		= {}
DraggableObject.__index 	= DraggableObject

-- Check if either mouse movement or touch input
function MouseOrTouchMovement(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

-- Sets up a new draggable object
function DraggableObject.new(Object)
	local self = {}
	self.Object	= Object
	self.DragStarted = nil
	self.DragEnded = nil
	self.Dragged = nil
	self.Dragging = false

	setmetatable(self, DraggableObject)

	return self
end

-- Enables dragging
local newPosition=nil
function DraggableObject:Enable(IgnoreVisualUpdate)
	local object = self.Object
	local preparingToDrag = false
	local offset = game.GuiService:GetGuiInset()
	
	local function update(input)
		local inputPosition = Vector2.new(input.Position.X, input.Position.Y) + offset
		local pos = inputPosition

		newPosition = UDim2.fromOffset(pos.X, pos.Y)

		if IgnoreVisualUpdate ~= true then
			object.Position = newPosition
		end

		return newPosition
	end
	preparingToDrag = true
	self.InputChanged2 = UserInputService.InputChanged:Connect(function(input)
		if object.Parent == nil then
			self:Disable()
			return
		end
		if MouseOrTouchMovement(input) and preparingToDrag then
			preparingToDrag = false
			if self.DragStarted then
				self.DragStarted()
			end

			self.Dragging = true
		end
		if self.Dragging then
			local newPosition = update(input)

			if self.Dragged then
				self.Dragged(newPosition)
			end
		end
	end)
end

-- Disables dragging
function DraggableObject:Disable(object)
	if typeof(self.InputChanged2)~='nil' then
		self.InputChanged2:Disconnect()
	end
	if self.Dragging then
		self.Dragging = false

		if self.DragEnded then
			self.DragEnded()
		end
	end
	if object and typeof(newPosition)~='nil' then
		object.Position = newPosition
	end
end

return DraggableObject