local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local module = {}

-- Private variables
local UI, Modules, Bindables
local Player: Player
local Drag, Drag2
local DisconnectRenderHotbar: RBXScriptConnection? = nil
local DisconnectRenderInv: RBXScriptConnection? = nil
local DragEnabled = false

local SortingLock = false
local SortQueued = false
local SlotList = {}
local backpackButton: GuiButton

local ActiveConnections = {}
local ActiveDragConnections = {}
local InventorySlotCache = {}
local StackTrackerConnections = {}

local DragLock = false

local function clearStackTrackerConnection(template: Instance)
	local connection = StackTrackerConnections[template]
	if connection then
		connection:Disconnect()
		StackTrackerConnections[template] = nil
	end
end

local function connectButton(btn: GuiButton, fn: () -> ()): RBXScriptConnection
	if btn:IsA("GuiButton") then
		return btn.Activated:Connect(fn)
	end
	return (btn :: any).MouseButton1Down:Connect(fn)
end

local function isNumericTool(tool: Tool?): boolean
	return tool ~= nil and tool:IsA("Tool") and tonumber(tool.Name) ~= nil
end

-- Main setup method
function module:Setup(ui, modules, bindables)
	self.UI = ui
	self.enabled = true

	UI = ui
	Modules = modules
	Bindables = bindables

	Player = game.Players.LocalPlayer
	local playerUI = Player:WaitForChild("PlayerGui")
	backpackButton = script.Parent.Parent.Parent.Refs.BackpackButton.Value

	-- Initialize drag functionality
	Drag = Modules.Helpers.Draggables.new(UI.DragObject)
	Drag2 = Modules.Helpers.Draggables.new(UI.DragObject2)

	-- Setup bindables
	Bindables.FindSlotInPages.OnInvoke = function(obj)
		if not obj or typeof(obj) ~= "Instance" then
			return nil
		end

		local key = nil
		if obj:IsA("Tool") then
			key = getItemKey(obj)
		else
			if typeof((obj :: any).Value) == "Instance" and (obj :: any).Value:IsA("Tool") then
				key = getItemKey((obj :: any).Value)
			end
		end

		if type(key) ~= "string" or key == "" then
			return nil
		end

		for i = 1, self:GetValidPage(true) do
			local page = UI.Inventory["Page." .. i]
			local slot = page:FindFirstChild(key)
			if slot then
				return slot
			end
			local found = page:FindFirstChild(key, true)
			if found and found:IsA("Frame") then
				return found
			end
		end
		return nil
	end


	Bindables.SendToInventory.Event:Connect(function(...)
		self:SendToInventory(...)
	end)

	Bindables.RefreshSlots.Event:Connect(function(slotObjects)
		self:RefreshSlots(slotObjects)
	end)

	Modules.Helpers.Settings.Interface.CurrentSlot:GetPropertyChangedSignal("Value"):Connect(function()
		self:OnSlotChange()
	end)

	-- Setup UI components
	self:SetupInventoryHotkey()
	self:SetupMobileInventory()
	self:SetupPageNavigation()
	self:SetupDeleteFunctionality()
	self:SetupGamepadControls()

	UI.Parent = playerUI
end

function module:SetEnabled(enabled)
	if self.UI then
		self.UI.Enabled = enabled
	end
	self.enabled = enabled
end

-- Animation methods
function module:AnimateBounce(template)
	template.Main.Size = UDim2.new(0.7, 0, 0.7, 0)
	template.Visible = true
	TweenService:Create(
		template.Main,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0),
		{Size = UDim2.new(0.9, 0, 0.9, 0)}
	):Play()
end

function module:Unselect(slot)
	TweenService:Create(
		slot.Main,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0),
		{Position = UDim2.new(0.5, 0, 0.5, 0)}
	):Play()

	local existingGradient = slot.Main:FindFirstChildWhichIsA("UIGradient") 
	if existingGradient and existingGradient.Name ~= "d" then
		existingGradient:Destroy()
		script.Unselected:Clone().Parent = slot.Main
	end

	TweenService:Create(
		slot.Main.UIStroke,
		TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0),
		{Transparency = 1}
	):Play()
end

-- Page management methods
function module:GetSlotsInPage(frame)
	local slotsThisPage = 0
	for _, child in pairs(frame:GetChildren()) do 
		if child:IsA("Frame") then
			slotsThisPage = slotsThisPage + 1
		end    
	end
	return slotsThisPage
end

function getItemKey(tool: Tool): string
	local itemId = tool:GetAttribute("ItemId")
	if type(itemId) == "string" and itemId ~= "" then
		return itemId
	end
	return tool.Name
end

local function isStackableTool(tool: Tool): boolean
	local itemId = tool:GetAttribute("ItemId")
	if itemId == "Hammer" then return false end
	if isNumericTool(tool) then return false end
	if tool:GetAttribute("CantDelete") then return false end

	local stacksAttr = tool:GetAttribute("Stacks")
	return stacksAttr == true
end



function module:GetValidPage(returnTotalOnly)
	local pageList = {}
	local totalPages = 0

	for _, child in pairs(UI.Inventory:GetChildren()) do 
		if child:IsA("Frame") and string.match(child.Name, "Page") then
			if (self:GetSlotsInPage(child) + 1) <= Modules.Helpers.Settings.Interface.SlotsPerPage then
				table.insert(pageList, {child, tonumber(string.split(child.Name, ".")[2])})
			end
			totalPages = totalPages + 1
		end
	end

	if returnTotalOnly then
		return totalPages
	end

	table.sort(pageList, function(a, b)
		return a[2] < b[2]
	end)

	return pageList, totalPages
end

function module:GetCurrentPage()
	return tonumber(string.split(Modules.Helpers.Settings.Interface.CurrentPage, ".")[2])
end

function module:OpenPage(frame)
	Modules.Helpers.Settings.Interface.CurrentPage = frame.Name

	for _, child in pairs(UI.Inventory:GetChildren()) do 
		if child:IsA("Frame") and child ~= frame and child.Name ~= "Bottom" and child.Name ~= "Delete" then
			child.Visible = false
		end
	end

	UI.Inventory.Bottom.TextLabel.Text = "Page " .. self:GetCurrentPage()
	frame.Visible = true
end

function module:UpdateNavigationBottom()
	local function setButtonState(button, locked)
		button.Main.Icon.ImageTransparency = locked and 0.5 or 0.75
	end

	local currentPage = self:GetCurrentPage()
	local totalPages = self:GetValidPage(true)

	setButtonState(UI.Inventory.Bottom.Previous, currentPage == 1)

	if currentPage == totalPages then
		if self:GetSlotsInPage(UI.Inventory["Page." .. currentPage]) > 0 then
			setButtonState(UI.Inventory.Bottom.Next, false)
			return
		end
		setButtonState(UI.Inventory.Bottom.Next, true)
	else
		setButtonState(UI.Inventory.Bottom.Next, false)
	end
end

function module:IsWithin(gui1, gui2)
	local gui1_topLeft = gui1.AbsolutePosition
	local gui1_bottomRight = gui1_topLeft + gui1.AbsoluteSize
	local gui2_topLeft = gui2.AbsolutePosition
	local gui2_bottomRight = gui2_topLeft + gui2.AbsoluteSize

	return ((gui1_topLeft.x < gui2_bottomRight.x and gui1_bottomRight.x > gui2_topLeft.x) and 
		(gui1_topLeft.y < gui2_bottomRight.y and gui1_bottomRight.y > gui2_topLeft.y))
end

function module:ManuallyCreatePage(totalPages, autoOpen)
	local newPage = script["PageTemplate"]:Clone()
	newPage.Name = "Page." .. tostring(totalPages + 1)
	newPage.Parent = UI.Inventory

	if autoOpen or Modules.Helpers.Settings.Interface.CurrentPage == newPage.Name then
		self:OpenPage(newPage)
	end

	self:UpdateNavigationBottom()
	return newPage
end

-- Slot visibility methods
function module:ShowSlot(slot, tween, hideNumber, bounce)
	local time = tween and 0.2 or 0

	if bounce then
		time = 0
		slot.Main.Size = UDim2.new(0.6, 0, 0.6, 0)
	end

	local tweenInfo = TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0)

	slot.Main.SlotNumber.Visible = hideNumber ~= true
	TweenService:Create(slot.Main, tweenInfo, {BackgroundTransparency = 0.3}):Play()
	TweenService:Create(slot.Main.Icon, tweenInfo, {ImageTransparency = 0}):Play()
	TweenService:Create(slot.Main.Stacks, tweenInfo, {TextTransparency = 0}):Play()
	TweenService:Create(slot.Main:FindFirstChild("Name"), tweenInfo, {TextTransparency = 0}):Play()

	if bounce then
		TweenService:Create(
			slot.Main,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0),
			{Size = UDim2.new(0.9, 0, 0.9, 0)}
		):Play()
	end    
end

function module:HideSlot(slot, tween)
	local time = tween and 0.2 or 0
	local tweenInfo = TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0)

	slot.Main.SlotNumber.Visible = false
	TweenService:Create(slot.Main, tweenInfo, {BackgroundTransparency = 1}):Play()
	TweenService:Create(slot.Main.Icon, tweenInfo, {ImageTransparency = 1}):Play()
	TweenService:Create(slot.Main.Stacks, tweenInfo, {TextTransparency = 1}):Play()
	TweenService:Create(slot.Main:FindFirstChild("Name"), tweenInfo, {TextTransparency = 1}):Play()
end

-- Inventory management methods
function module:SendToInventory(slotNumber, singleClick, unreferencedEntry, entryTool, isDraggedItem)
	if not unreferencedEntry and Modules.Helpers.Settings.AssignedSlots[slotNumber].Value == nil then
		return
	end

	local toolObject = entryTool or Modules.Helpers.Settings.AssignedSlots[slotNumber].Value

	local itemKey = getItemKey(toolObject)

	local isStackable = false
	if not unreferencedEntry then
		isStackable = isStackableTool(Modules.Helpers.Settings.AssignedSlots[slotNumber].Value)
		if singleClick and not isStackable then
			return
		end
	end

	local emptyPage = nil

	if not unreferencedEntry then
		if (self:GetSlotsInPage(UI.Inventory[Modules.Helpers.Settings.Interface.CurrentPage]) + 1) > Modules.Helpers.Settings.Interface.SlotsPerPage then
			return
		end
	else
		local validPages, totalPages = self:GetValidPage()
		if validPages[1] and validPages[1][1]:IsA("Frame") then
			emptyPage = validPages[1][1]
		else
			emptyPage = self:ManuallyCreatePage(totalPages)
		end
	end

	local invSlot, backendSlot = self:FindOrCreateInventorySlot(toolObject, slotNumber, emptyPage, isDraggedItem)

	if not invSlot then
		return
	end

	self:HandleStacking(invSlot, toolObject, slotNumber, singleClick, isDraggedItem)
	self:UpdateSlotSelection(toolObject, slotNumber)
	self:PlaySoundEffect(singleClick, isDraggedItem)
	self:UpdateNavigationBottom()

	-- delete slot from hotbar
	if not unreferencedEntry then
		if isStackable and singleClick and Modules.Helpers.Settings.StackList[itemKey] then
			if Modules.Helpers.Settings.StackList[itemKey].Value <= 0 then
				Modules.Helpers.Settings.AssignedSlots[slotNumber].Value = nil
			end
		else
			Modules.Helpers.Settings.AssignedSlots[slotNumber].Value = nil
		end
	end
end

function module:FindOrCreateInventorySlot(toolObject, slotNumber, emptyPage, isDraggedItem)
	local backendSlot = self:FindBackendSlot(toolObject)

	local key = getItemKey(toolObject)
	if Modules.Helpers.Settings.Interface.ItemStacks and isStackableTool(toolObject) then
		if backendSlot then
			return backendSlot, backendSlot
		end
	end


	local validPage = emptyPage or (isDraggedItem and UI.Inventory[Modules.Helpers.Settings.Interface.CurrentPage] or self:GetValidPage()[1][1])
	local invSlot = self:CreateInventorySlot(toolObject, slotNumber, validPage, emptyPage)

	if not invSlot then
		return nil
	end

	if backendSlot then
		invSlot.LayoutOrder = backendSlot.LayoutOrder
	end

	invSlot.Name = getItemKey(toolObject)
	invSlot:SetAttribute("ItemKey", invSlot.Name)
	self:SetupInventorySlotEvents(invSlot, toolObject)

	return invSlot, backendSlot
end

function module:FindBackendSlot(toolObject)
	local key = getItemKey(toolObject)
	for i = 1, self:GetValidPage(true) do
		local page = UI.Inventory["Page." .. i]
		local slot = page:FindFirstChild(key)
		if slot then
			return slot
		end
	end
	return nil
end


function module:CreateInventorySlot(toolObject, slotNumber, validPage, emptyPage)
	local invSlot

	if emptyPage then
		invSlot = script["Template"]:Clone()
		invSlot.Main.Icon.Image = toolObject.TextureId

		if not toolObject.TextureId or toolObject.TextureId == "" then
			self:SetItemName(invSlot, toolObject.Name)
		end
	else
		invSlot = UI.Frame[slotNumber]:Clone()
	end
	invSlot.Main.SlotNumber.Visible = false

	invSlot:SetAttribute("Layout", -(self:GetSlotsInPage(validPage) + 1))
	self:HideSlot(invSlot)
	self:ShowSlot(invSlot, true, true, true)

	if not toolObject or toolObject.Parent == nil then
		invSlot:Destroy()
		return nil
	end

	invSlot.Parent = validPage
	return invSlot
end

function module:SetItemName(slot, itemName)
	if itemName:find("%(") then
		local baseName, parenthetical = string.match(itemName, "^(.-)%s?(%(.*%))$")
		if baseName and parenthetical then
			slot.Main:FindFirstChild("Name").Text = baseName .. "\n" .. parenthetical
		else
			slot.Main:FindFirstChild("Name").Text = itemName
		end
	else
		slot.Main:FindFirstChild("Name").Text = itemName
	end
end

function module:HandleStacking(invSlot, toolObject, slotNumber, singleClick, isDraggedItem)
	if not Modules.Helpers.Settings.Interface.ItemStacks then
		return
	end

	if not isStackableTool(toolObject) then
		return
	end

	local key = getItemKey(toolObject)
	local tracker = Modules.Helpers.Settings.StackList[key]
	if not tracker then
		return
	end

	local stackCount = Instance.new("IntValue")
	stackCount.Name = "Stacks"

	if singleClick and tracker.Value > 1 then
		tracker.Value -= 1
		stackCount.Value = 1
		self:AnimateBounce(UI.Frame[slotNumber])
	else
		stackCount.Value = tracker.Value
		tracker.Value = 0
		tracker:Destroy()
		Modules.Helpers.Settings.StackList[key] = nil
	end

	stackCount.Parent = invSlot
	self:SetupStackDisplay(invSlot, stackCount)
end



function module:SetupStackDisplay(invSlot, stackCount)
	local function updateStackCount()
		if stackCount.Value <= 1 then
			if invSlot.Parent then
				invSlot.Main.Stacks.Text = ""
			end
			return
		end
		invSlot.Main.Stacks.Text = "x" .. stackCount.Value
	end

	invSlot.Main.Stacks.Visible = true
	updateStackCount()
	stackCount:GetPropertyChangedSignal("Value"):Connect(updateStackCount)
end

function module:UpdateSlotSelection(toolObject, slotNumber)
	if Modules.Helpers.Settings.Interface.CurrentSlot.Value == tostring(slotNumber) then
		if Player.Character and Player.Character:FindFirstChild("Humanoid") then
			Player.Character.Humanoid:UnequipTools()
		end
		Modules.Helpers.Settings.Interface.CurrentSlot.Value = ""
		self:Unselect(UI.Frame[slotNumber])
	end
end

function module:PlaySoundEffect(singleClick, isDraggedItem)
	if singleClick or isDraggedItem then
		script["Swish"]:Play()
	else
		script["Backpack"]:Play()
	end
end

-- Slot management methods
function module:OnSlotChange()
	if not tonumber(Modules.Helpers.Settings.Interface.CurrentSlot.Value) then
		for _, slot in pairs(SlotList) do 
			self:Unselect(slot)
		end
		if Player.Character and Player.Character:FindFirstChild("Humanoid") then
			Player.Character.Humanoid:UnequipTools()
		end
		return
	end

	local currentSlotIndex = tonumber(Modules.Helpers.Settings.Interface.CurrentSlot.Value)
	local currentTemplate = SlotList[currentSlotIndex]

	for i, slot in pairs(SlotList) do 
		if slot ~= currentTemplate then
			self:Unselect(slot)
		else
			self:SelectSlot(slot)
			if Modules.Helpers.Settings.AssignedSlots[i].Value ~= nil then
				Player.Character.Humanoid:EquipTool(Modules.Helpers.Settings.AssignedSlots[i].Value)
			else 
				Player.Character.Humanoid:UnequipTools()
			end 
		end
	end
end

function module:SelectSlot(slot)
	TweenService:Create(
		slot.Main,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0),
		{Position = UDim2.new(0.5, 0, 0.45, 0)}
	):Play()

	if Modules.Helpers.Settings.Interface.UnderlineOnSelection then
		slot.Main:FindFirstChildWhichIsA("UIGradient"):Destroy()
		script.Selected:Clone().Parent = slot.Main
	end

	if Modules.Helpers.Settings.Interface.OutlineOnSelection then
		slot.Main.UIStroke.Transparency = 1
		TweenService:Create(
			slot.Main.UIStroke,
			TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0),
			{Transparency = 0}
		):Play()
	end
end

function module:RefreshSlots(slotObjects)
	self:ClearSlots()
	self:CreateSlots()
	self:SetupSlotReferences(slotObjects)
	self:SetupSlotEvents()
	self:OnSlotChange()

	-- Сортируем слоты по Priority после обновления
	self:SortSlotsByPriority()
end

function module:ClearSlots()
	for i, slot in pairs(SlotList) do 
		clearStackTrackerConnection(slot)
		slot:Destroy()
		slot = nil
	end
	table.clear(SlotList)

	if Modules.Helpers.Settings.Interface.AppearanceOnFill then
		script.Template.Visible = false
	end
end

function module:CreateSlots()
	for i = 1, Modules.Helpers.Settings.Interface.MaxSlots do 
		local newSlot = script["Template"]:Clone()
		newSlot.Name = tostring(i)
		newSlot.LayoutOrder = i
		newSlot.Main.SlotNumber.Text = tostring(i)

		self:SetupSlotInteraction(newSlot, i)
		newSlot.Parent = UI.Frame
		SlotList[i] = newSlot
	end
end

function module:SetupSlotInteraction(slot, slotIndex)
	slot.Main.MouseButton1Down:Connect(function()
		if DragEnabled then 
			return 
		end

		if Modules.Helpers.Settings.Deleting then
			self:HandleSlotDeletion(slot, slotIndex)
			-- Сортируем после удаления
			self:SortSlotsByPriority()
			return
		end

		if UI.Inventory.Visible then
			self:HandleInventoryDrag(slot, slotIndex)
		else
			self:HandleSlotSelection(slotIndex)
		end
	end)
end

function module:HandleSlotSelection(slotIndex)
	if not game.Players.LocalPlayer.Character then 
		return 
	end
	if not game.Players.LocalPlayer.Character:FindFirstChild("Humanoid") then 
		return 
	end

	if Modules.Helpers.Settings.Interface.Debounce.Status then
		return
	end

	Modules.Helpers.Settings.Interface.Debounce.Status = true

	if tonumber(Modules.Helpers.Settings.Interface.CurrentSlot.Value) == slotIndex then
		Modules.Helpers.Settings.Interface.CurrentSlot.Value = ""
	else 
		Modules.Helpers.Settings.Interface.CurrentSlot.Value = tostring(slotIndex)
	end

	task.wait(Modules.Helpers.Settings.Interface.Debounce.Duration)
	Modules.Helpers.Settings.Interface.Debounce.Status = false
end

function module:HandleSlotDeletion(slot, slotIndex)
	script["Click"]:Play()

	local toolObject = Modules.Helpers.Settings.AssignedSlots[slotIndex].Value
	if not toolObject then
		return
	end

	if toolObject:GetAttribute("CantDelete") then
		script["MenuError"]:Play()
		return
	end

	local key = getItemKey(toolObject)

	if Modules.Helpers.Settings.Interface.ItemStacks and typeof(toolObject:GetAttribute("Stacks")) ~= "nil" then
		local tracker = getStackTracker(toolObject)
		if tracker and tracker.Value > 1 then
			tracker.Value -= 1
			script["Delete"]:Play()
		else
			toolObject:Destroy()
			Modules.Helpers.Settings.AssignedSlots[slotIndex].Value = nil
			if tracker then
				tracker:Destroy()
				Modules.Helpers.Settings.StackList[key] = nil
			end
			script["Delete"]:Play()
		end
	else
		toolObject:Destroy()
		Modules.Helpers.Settings.AssignedSlots[slotIndex].Value = nil
		script["Delete"]:Play()
	end

	if Modules.Helpers.Settings.Interface.CurrentSlot.Value == tostring(slotIndex) then
		local char = Player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:UnequipTools()
		end
		Modules.Helpers.Settings.Interface.CurrentSlot.Value = ""
	end
end


function module:SetupSlotReferences(slotObjects)
	local function clearTemplate(template)
		clearStackTrackerConnection(template)
		template.Main.Icon.Image = ""
		template.Main.Stacks.Text = ""
		template.Main.Stacks.Visible = false
		local nameObj = template.Main:FindFirstChild("Name")
		if nameObj then
			(nameObj :: TextLabel).Text = ""
		end
		local infoObj = template.Main:FindFirstChild("ItemInfo")
		if infoObj then
			(infoObj :: TextLabel).Text = ""
		end
		--if Modules.Helpers.Settings.Interface.AppearanceOnFill then
		--	template.Visible = false
		--end
	end

	local function applyTool(template, tool: Tool)
		clearStackTrackerConnection(template)
		template.Main.Icon.Image = tool.TextureId or ""

		if not tool.TextureId or tool.TextureId == "" then
			self:SetItemName(template, tool.Name)
		else
			self:SetItemName(template, "")
		end

		if isNumericTool(tool) then
			template.Main.Stacks.Text = ""
			template.Main.Stacks.Visible = false
			return
		end

		if Modules.Helpers.Settings.Interface.ItemStacks and typeof(tool:GetAttribute("Stacks")) ~= "nil" then
			self:SetupStackTracker(template, tool)
		else
			template.Main.Stacks.Text = ""
			template.Main.Stacks.Visible = false
		end
	end

	local function updateVisualOnTool(obj)
		script["Backpack"]:Play()

		local idx = tonumber(obj.Name)
		if not idx then
			return
		end

		local template = SlotList[idx]
		if not template then
			return
		end

		local tool = obj.Value
		if tool == nil then
			clearTemplate(template)
			if Modules.Helpers.Settings.Interface.AppearanceOnFill then
				template.Visible = false
			end
		else
			if Modules.Helpers.Settings.Interface.AppearanceOnFill then
				template.Visible = true
			end
			applyTool(template, tool)
			if Modules.Helpers.Settings.Interface.AppearanceOnFill then
				self:AnimateBounce(template)
			end
		end

		if Modules.Helpers.Settings.Interface.CurrentSlot.Value == obj.Name then
			if obj.Value ~= nil then
				local char = Player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum then
					hum:EquipTool(obj.Value)
				end
			else
				self:Unselect(template)
				Modules.Helpers.Settings.Interface.CurrentSlot.Value = ""
			end
		end

		if Modules.Helpers.Settings.Interface.AppearanceOnFill then
			self:ShiftHotbarSlots()
		end
	end

	for _, slotObj in pairs(slotObjects) do
		slotObj:GetPropertyChangedSignal("Value"):Connect(function()
			updateVisualOnTool(slotObj)
			self:QueueSort()
		end)

		updateVisualOnTool(slotObj)
	end

	self:QueueSort()
end

function getStackTracker(tool: Tool): IntValue?
	local key = getItemKey(tool)

	local stackList = Modules and Modules.Helpers and Modules.Helpers.Settings and Modules.Helpers.Settings.StackList
	if type(stackList) ~= "table" then
		return nil
	end

	local tracker = stackList[key]
	if tracker and tracker:IsA("IntValue") then
		return tracker
	end

	tracker = stackList[tool.Name]
	if tracker and tracker:IsA("IntValue") then
		return tracker
	end

	return nil
end

function module:SetupStackTracker(template, tool: Tool)
	clearStackTrackerConnection(template)

	if isNumericTool(tool) then
		template.Main.Stacks.Text = ""
		template.Main.Stacks.Visible = false
		return
	end

	local tracker = getStackTracker(tool)
	if not tracker then
		template.Main.Stacks.Text = ""
		template.Main.Stacks.Visible = false
		return
	end

	local function updateTracker()
		if not template.Parent then
			return
		end
		
		template.Main.Stacks.Text = "x" .. tracker.Value
		template.Main.Stacks.Visible = tracker.Value > 1
	end

	updateTracker()
	StackTrackerConnections[template] = tracker:GetPropertyChangedSignal("Value"):Connect(function()
		updateTracker()
		if tracker.Value > 0 and template.Parent then
			self:AnimateBounce(template)
		end
	end)
end

local QueuedSortThread = nil

function module:QueueSort()
	if SortQueued then return end
	SortQueued = true

	if QueuedSortThread then
		task.cancel(QueuedSortThread)
	end

	QueuedSortThread = task.defer(function()
		if not Player.Parent then 
			SortQueued = false
			return 
		end

		SortQueued = false
		if SortingLock then return end
		self:SortSlotsByPriority()
		QueuedSortThread = nil
	end)
end

function module:Cleanup()
	if QueuedSortThread then
		task.cancel(QueuedSortThread)
		QueuedSortThread = nil
	end
end



local ShiftingHotbar = false

function module:ShiftHotbarSlots()
	if ShiftingHotbar then
		return
	end
	ShiftingHotbar = true

	local assigned = Modules.Helpers.Settings.AssignedSlots
	local max = Modules.Helpers.Settings.Interface.MaxSlots

	-- Remember which tool is equipped so its slot number can follow it after compacting
	local currentSlotNo = tonumber(Modules.Helpers.Settings.Interface.CurrentSlot.Value)
	local currentTool = currentSlotNo and assigned[currentSlotNo] and assigned[currentSlotNo].Value or nil

	local newList = {}
	for i = 1, max do
		if assigned[i].Value ~= nil then
			table.insert(newList, assigned[i].Value)
		end
	end
	for i = 1, max do
		assigned[i].Value = newList[i]
	end
	-- Visuals will update automatically via Value changed signals

	if currentTool then
		local newIndex = table.find(newList, currentTool)
		if newIndex and newIndex ~= currentSlotNo then
			Modules.Helpers.Settings.Interface.CurrentSlot.Value = tostring(newIndex)
		end
	end

	ShiftingHotbar = false
end

function module:SetupSlotEvents()
	for _, slot in pairs(SlotList) do 
		slot.Main.MouseEnter:Connect(function()
			TweenService:Create(
				slot.Main,
				TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0),
				{BackgroundColor3 = Color3.fromRGB(159, 159, 159)}
			):Play()
		end)

		slot.Main.MouseLeave:Connect(function()
			TweenService:Create(
				slot.Main,
				TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0),
				{BackgroundColor3 = Color3.fromRGB(255, 255, 255)}
			):Play()
		end)
	end
end

local function getTouchPosition()
	return game.UserInputService:GetMouseLocation()
end

-- В начале модуля добавьте:
local ActiveDragConnections = {}
local DragLock = false

function module:SetupInventorySlotEvents(invSlot: Frame, toolObject: Tool)
	local main = invSlot:FindFirstChild("Main")
	if not main or not main:IsA("GuiButton") then
		return
	end

	local slotKey = HttpService:GenerateGUID(false)
	invSlot:SetAttribute("SlotKey", slotKey)

	-- Helper functions
	local function itemKeyFromTool(t: Tool): string
		local itemId = t:GetAttribute("ItemId")
		if type(itemId) == "string" and itemId ~= "" then
			return itemId
		end
		return t.Name
	end

	local function hasStacks(slotFrame: Instance): boolean
		local stacks = slotFrame:FindFirstChild("Stacks")
		return stacks ~= nil and stacks:IsA("IntValue") and stacks.Value > 0
	end

	local function getStacksValue(slotFrame: Instance): number
		local stacks = slotFrame:FindFirstChild("Stacks")
		if stacks and stacks:IsA("IntValue") then
			return stacks.Value
		end
		return 1
	end

	local function decStacksOrDestroy(slotFrame: Frame, amount: number): boolean
		local stacks = slotFrame:FindFirstChild("Stacks")
		if stacks and stacks:IsA("IntValue") then
			stacks.Value = math.max(0, stacks.Value - amount)
			if stacks.Value <= 0 then
				slotFrame:Destroy()
				return true
			end
			return false
		else
			slotFrame:Destroy()
			return true
		end
	end

	local function findToolInBackpackByKey(key: string): Tool?
		local bp = Player:FindFirstChildOfClass("Backpack")
		if not bp then return nil end

		for _, inst in bp:GetChildren() do
			if inst:IsA("Tool") and itemKeyFromTool(inst) == key then
				return inst
			end
		end
		return nil
	end

	local function findHotbarSlotForItem(key: string, requireStackableMerge: boolean): number?
		for i = 1, Modules.Helpers.Settings.Interface.MaxSlots do
			local v = Modules.Helpers.Settings.AssignedSlots[i].Value
			if v == nil then
				return i
			end
			if requireStackableMerge and v:IsA("Tool") and itemKeyFromTool(v) == key then
				return i
			end
		end
		return nil
	end

	local function cleanupSlotConnections()
		if ActiveDragConnections[slotKey] then
			for _, conn in ipairs(ActiveDragConnections[slotKey]) do
				if typeof(conn) == "RBXScriptConnection" then
					conn:Disconnect()
				end
			end
			ActiveDragConnections[slotKey] = nil
		end
	end

	ActiveDragConnections[slotKey] = {}

	local enterConn = main.MouseEnter:Connect(function()
		if not main.Parent then return end
		TweenService:Create(
			main,
			TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0),
			{ BackgroundColor3 = Color3.fromRGB(159, 159, 159) }
		):Play()
	end)

	local leaveConn = main.MouseLeave:Connect(function()
		if not main.Parent then return end
		TweenService:Create(
			main,
			TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0),
			{ BackgroundColor3 = Color3.fromRGB(255, 255, 255) }
		):Play()
	end)

	table.insert(ActiveDragConnections[slotKey], enterConn)
	table.insert(ActiveDragConnections[slotKey], leaveConn)

	local clickConn = main.MouseButton1Down:Connect(function()
		if DragEnabled or DragLock then
			return
		end

		if not invSlot.Parent or not toolObject.Parent then
			return
		end

		local key = itemKeyFromTool(toolObject)
		local stackable = hasStacks(invSlot)

		if Modules.Helpers.Settings.Deleting then
			pcall(function() script.Click:Play() end)

			local backpackTool = findToolInBackpackByKey(key)
			if backpackTool and backpackTool:GetAttribute("CantDelete") == true then
				pcall(function() script.MenuError:Play() end)
				return
			end

			if stackable then
				local destroyed = decStacksOrDestroy(invSlot, 1)
				if destroyed then
					cleanupSlotConnections()
				end
				pcall(function() script.Delete:Play() end)
				return
			end

			if backpackTool then
				backpackTool:Destroy()
			end
			invSlot:Destroy()
			cleanupSlotConnections()
			pcall(function() script.Delete:Play() end)
			return
		end

		if not UI.Inventory.Visible then
			return
		end

		DragLock = true
		task.defer(function()
			if DragEnabled then
				DragLock = false
				return
			end

			DragEnabled = true
			DragLock = false

			pcall(function() script.Click:Play() end)

			local dragFrame = UI.DragObject2

			for _, x in dragFrame.Page:GetChildren() do
				if x:IsA("Frame") then
					x:Destroy()
				end
			end

			local mainClone: Frame? = nil
			local mainReference: Frame? = nil
			local connectionKey = invSlot:GetAttribute("Layout")

			for _, x in UI.Inventory[Modules.Helpers.Settings.Interface.CurrentPage]:GetChildren() do
				if x:IsA("Frame") and x:GetAttribute("Layout") == connectionKey then
					local clone = x:Clone()
					clone.Parent = dragFrame.Page
					clone.Active = false
					clone.Interactable = false

					local cloneMain = clone:FindFirstChild("Main")
					if cloneMain then
						cloneMain.Active = false
						cloneMain.Interactable = false
					end

					mainClone = clone
					mainReference = x

					task.delay(0.15, function()
						if not DragEnabled or not clone.Parent then return end

						local cm = clone:FindFirstChild("Main")
						if not cm or not cm:IsA("GuiObject") then return end

						local select = clone:FindFirstChild("Select")
						if select then
							local stroke = cm:FindFirstChildWhichIsA("UIStroke")
							if stroke then stroke:Destroy() end
							select.Parent = cm
							if select:IsA("GuiObject") then
								select.Visible = true
							end
						end

						TweenService:Create(
							cm,
							TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0),
							{ Rotation = 7 }
						):Play()
					end)

					break
				end
			end

			if DisconnectRenderInv then
				DisconnectRenderInv:Disconnect()
				DisconnectRenderInv = nil
			end

			local startTime = tick()
			local dragCompleted = false

			local function cleanupDrag()
				if dragCompleted then return end
				dragCompleted = true

				for _, x in dragFrame.Page:GetChildren() do
					if x:IsA("Frame") then
						x:Destroy()
					end
				end

				dragFrame.Visible = false
				Drag2:Disable()
				dragFrame.Position = UI.Inventory.Position

				if DisconnectRenderInv then
					DisconnectRenderInv:Disconnect()
					DisconnectRenderInv = nil
				end
			end

			local function tryMoveToHotbar(moveOne: boolean)
				if not invSlot.Parent then
					return
				end

				local allowMerge = stackable
				local emptySlotNo = findHotbarSlotForItem(key, allowMerge)
				if not emptySlotNo then
					return
				end

				if moveOne then
					if stackable then
						local destroyed = decStacksOrDestroy(invSlot, 1)
						if destroyed then
							cleanupSlotConnections()
						end
					else
						invSlot:Destroy()
						cleanupSlotConnections()
					end
					self:AnimateBounce(UI.Frame[emptySlotNo])
					Bindables.SendToHotbar:Fire(toolObject, 1)
					return
				end

				local countToSend = stackable and getStacksValue(invSlot) or 1
				invSlot:Destroy()
				cleanupSlotConnections()
				self:AnimateBounce(UI.Frame[emptySlotNo])
				Bindables.SendToHotbar:Fire(toolObject, countToSend)
			end

			DisconnectRenderInv = UserInputService.InputEnded:Connect(function(input, _gameProcessed)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1
					and input.UserInputType ~= Enum.UserInputType.MouseButton2
					and input.UserInputType ~= Enum.UserInputType.Touch
				then
					return
				end

				if not DragEnabled or dragCompleted then
					return
				end

				DragEnabled = false

				local fastClick = (tick() - startTime) <= 0.1

				if fastClick then
					tryMoveToHotbar(true)
				elseif mainClone and not self:IsWithin(mainClone, UI.Inventory) then
					tryMoveToHotbar(false)
				else
					if invSlot.Parent then
						self:ShowSlot(invSlot, false, true)
					end
				end

				cleanupDrag()
			end)

			Drag2:Enable(true)

			task.delay(0.1, function()
				if not DragEnabled or dragCompleted then
					return
				end

				dragFrame.Visible = true
				Drag2:Disable(UI.DragObject2)

				local touchPos = getTouchPosition()
				dragFrame.Position = UDim2.fromOffset(touchPos.X, touchPos.Y)

				if mainReference and mainReference.Parent then
					self:HideSlot(mainReference, false)
				end

				Drag2:Enable(false)
			end)
		end)
	end)

	table.insert(ActiveDragConnections[slotKey], clickConn)

	invSlot.Destroying:Once(function()
		cleanupSlotConnections()
	end)

	local playerRemoving
	playerRemoving = game.Players.PlayerRemoving:Connect(function(plr)
		if plr == Player then
			cleanupSlotConnections()
			if playerRemoving then
				playerRemoving:Disconnect()
			end
		end
	end)

	table.insert(ActiveDragConnections[slotKey], playerRemoving)
end


function module:CleanupAllDragConnections()
	for slotKey, connections in pairs(ActiveDragConnections) do
		for _, conn in ipairs(connections) do
			if typeof(conn) == "RBXScriptConnection" then
				conn:Disconnect()
			end
		end
	end
	table.clear(ActiveDragConnections)

	if DisconnectRenderInv then
		DisconnectRenderInv:Disconnect()
		DisconnectRenderInv = nil
	end

	if DisconnectRenderHotbar then
		DisconnectRenderHotbar:Disconnect()
		DisconnectRenderHotbar = nil
	end
end



function module:HandleInventoryDrag(slot, slotIndex)
	DragEnabled = true
	script["Click"]:Play()

	local dragFrame = UI.DragObject
	self:SetupDragFrame(dragFrame, slot)

	local startTime = tick()
	self:SetupDragEndHandler(slot, dragFrame, slotIndex, startTime)

	Drag:Enable(true)

	task.delay(0.1, function()
		if not DragEnabled then
			return
		end

		self:HideSlot(slot, false)
		dragFrame.Visible = true
		Drag:Disable(UI.DragObject)
		Drag:Enable()
		local touchPos = getTouchPosition()
		dragFrame.Position = UDim2.fromOffset(touchPos.X, touchPos.Y)
	end)
end

function module:SetupDragFrame(dragFrame, slot)
	for _, child in pairs(dragFrame:GetChildren()) do 
		if child:IsA("Frame") then 
			child:Destroy() 
		end
	end

	local clone = slot:Clone()
	clone.Parent = dragFrame
	clone.Active = false
	clone.Main.Active = false
	clone.Interactable = false
	clone.Main.Interactable = false
	self:SetupDraggedSlot(clone)
end

function module:SetupDraggedSlot(slot)
	slot.Main.UIStroke:Destroy()
	local select = slot.Select
	select.Parent = slot.Main
	select.Enabled = true

	task.delay(0.15, function()
		if not DragEnabled then 
			return 
		end
		TweenService:Create(
			slot.Main,
			TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0),
			{Rotation = 7}
		):Play()
	end)
end

function module:SetupDragEndHandler(slot, dragFrame, slotIndex, startTime)
	if DisconnectRenderHotbar then
		DisconnectRenderHotbar:Disconnect()
		DisconnectRenderHotbar = nil
	end

	DisconnectRenderHotbar = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
			input.UserInputType == Enum.UserInputType.Touch or 
			input.UserInputType == Enum.UserInputType.MouseButton2 then

			if not DragEnabled then 
				return 
			end

			DragEnabled = false

			if self:IsWithin(dragFrame, UI.Inventory) then
				self:SendToInventory(slotIndex, nil, nil, nil, true)
			end

			self:CleanupDrag(slot, dragFrame, startTime, slotIndex)
		end
	end)
end

function module:CleanupDrag(slot, dragFrame, startTime, slotIndex)
	for _, child in pairs(dragFrame:GetChildren()) do 
		if child:IsA("Frame") then 
			child:Destroy() 
		end
	end

	dragFrame.Visible = false
	if DisconnectRenderHotbar then
		DisconnectRenderHotbar:Disconnect()
		DisconnectRenderHotbar = nil
	end
	Drag:Disable()

	self:ShowSlot(slot, true)

	dragFrame.Position = UI.Frame.Position

	if (tick() - startTime) <= 0.1 then
		self:SendToInventory(slotIndex, true, nil, nil, true)
	end
end

-- Inventory UI methods
function module:OpenInventory()
	UI.Inventory.Position = UDim2.new(0.5, 0, 0.6, 0)
	TweenService:Create(
		UI.Inventory,
		TweenInfo.new(0.23, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0),
		{Position = UDim2.new(0.5, 0, 0.5, 0)}
	):Play()

	TweenService:Create(
		backpackButton.UIStroke,
		TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0),
		{Transparency = 0}
	):Play()

	UI.Inventory.Visible = true
end

function module:CloseInventory()
	UI.Inventory.Visible = false

	TweenService:Create(
		backpackButton.UIStroke,
		TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0),
		{Transparency = 1}
	):Play()
end

function module:SetupInventoryHotkey()
	if typeof(Modules.Helpers.Settings.Interface.InventoryHotkey) == "nil" then
		return
	end

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then 
			return 
		end

		if input.KeyCode == Modules.Helpers.Settings.Interface.InventoryHotkey then
			if Modules.Helpers.Settings.Interface.Debounce.Status then
				return
			end

			Modules.Helpers.Settings.Interface.Debounce.Status = true

			if not UI.Inventory.Visible then
				self:OpenInventory()
			else
				self:CloseInventory()
			end

			task.wait(Modules.Helpers.Settings.Interface.Debounce.Duration)
			Modules.Helpers.Settings.Interface.Debounce.Status = false
		end
	end)
end

function module:SetupMobileInventory()
	if not backpackButton then
		return
	end

	backpackButton.Activated:Connect(function()
		if Modules.Helpers.Settings.Interface.Debounce.Status then
			return
		end

		Modules.Helpers.Settings.Interface.Debounce.Status = true
		script["Click"]:Play()

		local mobileRoot = UI:FindFirstChild("Mobileinventory") or UI:FindFirstChild("MobileInventory")
		if mobileRoot and mobileRoot:IsA("GuiObject") then
			local main = mobileRoot:FindFirstChild("Main")
			if main and main:IsA("GuiObject") then
				TweenService:Create(
					main,
					TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0),
					{ Size = UDim2.new(0.9, 0, 0.9, 0) }
				):Play()
			end
		end

		if not UI.Inventory.Visible then
			self:OpenInventory()
		else
			self:CloseInventory()
		end

		task.wait(Modules.Helpers.Settings.Interface.Debounce.Duration)
		Modules.Helpers.Settings.Interface.Debounce.Status = false
	end)

	-- if mobile device then hide the hint text label
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then  
		backpackButton.KeyCodeLabel.Visible = false
	end
	
	backpackButton.Visible = true
end

function module:SetupPageNavigation()
	local bottom = UI.Inventory:FindFirstChild("Bottom")
	if not bottom then return end
	local nextObj = bottom:FindFirstChild("Next")
	local prevObj = bottom:FindFirstChild("Previous")
	if not nextObj or not prevObj then return end
	local nextMain = nextObj:FindFirstChild("Main")
	local prevMain = prevObj:FindFirstChild("Main")
	if not nextMain or not prevMain then return end
	if not nextMain:IsA("GuiButton") and not nextMain:FindFirstChildWhichIsA("GuiButton") then return end
end


function module:SetupDeleteFunctionality()
	local deleteFrame = UI.Inventory:FindFirstChild("Delete")
	if not deleteFrame then
		return
	end

	local btn = deleteFrame:FindFirstChild("TextButton")
	if not btn or not btn:IsA("GuiButton") then
		return
	end

	connectButton(btn, function()
		if Modules.Helpers.Settings.Interface.Debounce.Status then
			return
		end

		Modules.Helpers.Settings.Deleting = not Modules.Helpers.Settings.Deleting

		if Modules.Helpers.Settings.Deleting then
			(btn :: TextButton).Text = "Deleting"
			(btn :: TextButton).TextColor3 = Color3.new(1, 0.25, 0.25)
		else
			(btn :: TextButton).Text = "Delete"
			(btn :: TextButton).TextColor3 = Color3.new(1, 1, 1)
		end

		script["Click"]:Play()
	end)

	UI.Inventory:GetPropertyChangedSignal("Visible"):Connect(function()
		if not UI.Inventory.Visible then
			Modules.Helpers.Settings.Deleting = false
			(btn :: TextButton).Text = "Delete"
			(btn :: TextButton).TextColor3 = Color3.new(1, 1, 1)
		end
	end)
end


-- Gamepad controls
function module:SetupGamepadControls()
	if not UserInputService.GamepadEnabled then 
		return
	end

	local currentSlotIndex = tonumber(Modules.Helpers.Settings.Interface.CurrentSlot.Value) or 1
	local maxSlots = Modules.Helpers.Settings.Interface.MaxSlots

	local function selectSlot(index)
		if index < 1 then 
			index = maxSlots 
		end
		if index > maxSlots then 
			index = 1 
		end
		Modules.Helpers.Settings.Interface.CurrentSlot.Value = tostring(index)
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not self.enabled then 
			return 
		end

		-- LB → предыдущий слот
		if input.KeyCode == Enum.KeyCode.ButtonL1 then
			currentSlotIndex = currentSlotIndex - 1
			if currentSlotIndex <= 0 then
				currentSlotIndex = maxSlots
			end
			selectSlot(currentSlotIndex)
		end

		-- RB → следующий слот
		if input.KeyCode == Enum.KeyCode.ButtonR1 then
			currentSlotIndex = currentSlotIndex + 1
			if currentSlotIndex > maxSlots then
				currentSlotIndex = 1
			end
			selectSlot(currentSlotIndex)
		end

		-- RT/X → использовать инструмент
		if input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonX then
			local char = Player.Character
			if char and char:FindFirstChild("Humanoid") then
				local tool = char:FindFirstChildOfClass("Tool")
				if tool and tool:FindFirstChild("Activate") then
					tool:Activate()
				end
			end
		end
	end)
end

function module:SortSlotsByPriority()
	if SortingLock then return end
	SortingLock = true

	local assigned = Modules.Helpers.Settings.AssignedSlots
	local maxSlots = Modules.Helpers.Settings.Interface.MaxSlots
	local slotsData = {}

	for i = 1, maxSlots do
		local toolObject = assigned[i].Value
		if toolObject then
			local priority = toolObject:GetAttribute("Priority")
			if type(priority) ~= "number" then priority = 999 end
			table.insert(slotsData, { toolObject = toolObject, priority = priority, oldIndex = i })
		end
	end

	table.sort(slotsData, function(a, b)
		if a.priority == b.priority then
			return a.oldIndex < b.oldIndex
		end
		return a.priority < b.priority
	end)

	for i = 1, maxSlots do
		local item = slotsData[i]
		assigned[i].Value = item and item.toolObject or nil
	end

	SortingLock = false
end


return module