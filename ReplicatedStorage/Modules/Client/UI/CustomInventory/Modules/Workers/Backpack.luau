local module = {}

function module:Setup(Modules, Bindables)
	local Player = game.Players.LocalPlayer
	local LoadedTools = {}
	local backpackConn: RBXScriptConnection? = nil
	local backpackChildConn: RBXScriptConnection? = nil

	local function ClearAssignedSlots()
		for _, obj in pairs(Modules.Helpers.Settings.AssignedSlots) do
			if obj then
				obj:Destroy()
			end
		end
		table.clear(Modules.Helpers.Settings.AssignedSlots)
	end

	local function ClearStackedList()
		for _, obj in pairs(Modules.Helpers.Settings.StackList) do
			if obj then
				obj:Destroy()
			end
		end
		table.clear(Modules.Helpers.Settings.StackList)
	end

	local function AddToInventory(tool: Tool)
		Bindables.SendToInventory:Fire(nil, false, true, tool)
	end

	-- Finds another live copy of the same tool, ignoring the one currently being destroyed
	-- (Destroying fires before the tool is actually removed, so it can still show up in searches)
	local function FindReplacementTool(name: string, exclude: Tool): Tool?
		local backpack = Player:FindFirstChild("Backpack")
		if backpack then
			for _, inst in ipairs(backpack:GetChildren()) do
				if inst ~= exclude and inst:IsA("Tool") and inst.Name == name then
					return inst
				end
			end
		end

		local char = Player.Character
		if char then
			for _, inst in ipairs(char:GetChildren()) do
				if inst ~= exclude and inst:IsA("Tool") and inst.Name == name then
					return inst
				end
			end
		end

		return nil
	end

	local function SetDestroyingConnection(tool: Tool)
		tool.Destroying:Connect(function()
			if Modules.Helpers.Settings.Interface.ItemStacks and typeof(Modules.Helpers.Settings.StackList[tool.Name]) ~= "nil" then
				local Tracker = Modules.Helpers.Settings.StackList[tool.Name]
				if Tracker.Value > 1 then
					Tracker.Value -= 1

					local AssignedSlot = nil
					for _, v in pairs(Modules.Helpers.Settings.AssignedSlots) do
						if v.Value == tool then
							AssignedSlot = v
							break
						end
					end

					if AssignedSlot then
						local NewTool = FindReplacementTool(tool.Name, tool)
						if NewTool then
							AssignedSlot.Value = NewTool
							if Modules.Helpers.Settings.Interface.CurrentSlot.Value == AssignedSlot.Name then
								local char = Player.Character
								local hum = char and char:FindFirstChildOfClass("Humanoid")
								if hum then
									hum:EquipTool(NewTool)
								end
							end
						else
							-- No live replacement left (e.g. all copies destroyed at once); clear the slot instead of leaving a stale reference
							Tracker.Value = 0
							AssignedSlot.Value = nil
							if Modules.Helpers.Settings.Interface.CurrentSlot.Value == AssignedSlot.Name then
								local char = Player.Character
								local hum = char and char:FindFirstChildOfClass("Humanoid")
								if hum then
									hum:UnequipTools()
								end
								Modules.Helpers.Settings.Interface.CurrentSlot.Value = ""
							end
						end
					end

					return
				end
			end

			local PresentInHotbar = false

			for _, v in pairs(Modules.Helpers.Settings.AssignedSlots) do
				if v.Value == tool then
					PresentInHotbar = true
					local Tracker = Modules.Helpers.Settings.StackList[tool.Name]
					if Tracker then
						Tracker.Value = 0
					end
					v.Value = nil
					if Modules.Helpers.Settings.Interface.CurrentSlot.Value == v.Name then
						local char = Player.Character
						local hum = char and char:FindFirstChildOfClass("Humanoid")
						if hum then
							hum:UnequipTools()
						end
					end
					break
				end
			end

			if not PresentInHotbar then
				local InvTemplate = Bindables.FindSlotInPages:Invoke(tool)
				if typeof(InvTemplate) ~= "nil" then
					if Modules.Helpers.Settings.Interface.ItemStacks and InvTemplate:FindFirstChild("Stacks") then
						local stacks = InvTemplate.Stacks
						if stacks.Value > 1 then
							stacks.Value -= 1
						else
							InvTemplate:Destroy()
						end
					else
						InvTemplate:Destroy()
					end
				end
			end
		end)
	end

	local function AssignSlot(tool: Tool, FromInventory: boolean?, StackCount: number?)
		if not tool or tool.Parent == nil then
			return
		end

		if FromInventory ~= true then
			if table.find(LoadedTools, tool) then
				return
			end
			table.insert(LoadedTools, tool)
		end

		if Modules.Helpers.Settings.Interface.ItemStacks == true and typeof(tool:GetAttribute("Stacks")) ~= "nil" then
			if typeof(Modules.Helpers.Settings.StackList[tool.Name]) == "nil" then
				Modules.Helpers.Settings.StackList[tool.Name] = Instance.new("IntValue")
				if FromInventory == true then
					Modules.Helpers.Settings.StackList[tool.Name].Value += (StackCount or 1)
				else
					Modules.Helpers.Settings.StackList[tool.Name].Value = 1
				end
			else
				if FromInventory == true then
					Modules.Helpers.Settings.StackList[tool.Name].Value += (StackCount or 1)
				else
					Modules.Helpers.Settings.StackList[tool.Name].Value += 1
				end
			end

			if Modules.Helpers.Settings.StackList[tool.Name].Value > 1 and FromInventory ~= true then
				SetDestroyingConnection(tool)
				return
			end
		end

		local function SetItemSlot()
			local isHammer = tonumber(tool.Name) ~= nil

			if isHammer then
				local slot1 = Modules.Helpers.Settings.AssignedSlots[1]
				if slot1 then
					if slot1.Value == nil then
						slot1.Value = tool
						return
					end

					if slot1.Value ~= tool then
						local existing = slot1.Value
						slot1.Value = tool

						local moved = false
						for i = 2, Modules.Helpers.Settings.Interface.MaxSlots do
							local s = Modules.Helpers.Settings.AssignedSlots[i]
							if s and s.Value == nil then
								s.Value = existing
								moved = true
								break
							end
						end

						if not moved then
							AddToInventory(existing)
						end
						return
					end

					return
				end
			end

			local ItemNo: number? = nil
			for i = 1, Modules.Helpers.Settings.Interface.MaxSlots do
				local slotObj = Modules.Helpers.Settings.AssignedSlots[i]
				if slotObj and slotObj.Value == nil then
					slotObj.Value = tool
					ItemNo = i
					break
				end
			end

			if ItemNo == nil then
				AddToInventory(tool)
			end
		end

		if not FromInventory or (Modules.Helpers.Settings.Interface.ItemStacks == false or typeof(tool:GetAttribute("Stacks")) == "nil") then
			SetItemSlot()
		else
			local Exists = false
			for i = 1, Modules.Helpers.Settings.Interface.MaxSlots do
				local v = Modules.Helpers.Settings.AssignedSlots[i]
				if v and v.Value ~= nil and v.Value.Name == tool.Name then
					Exists = true
					break
				end
			end
			if not Exists then
				SetItemSlot()
			end
		end

		SetDestroyingConnection(tool)
	end

	local function SetupSlots()
		ClearAssignedSlots()
		ClearStackedList()

		for i = 1, Modules.Helpers.Settings.Interface.MaxSlots do
			local NewObject = Instance.new("ObjectValue")
			NewObject.Name = tostring(i)
			Modules.Helpers.Settings.AssignedSlots[i] = NewObject
		end

		Modules.Helpers.Settings.Interface.CurrentSlot.Value = ""
		Bindables.RefreshSlots:Fire(Modules.Helpers.Settings.AssignedSlots)

		for _, v in pairs(LoadedTools) do
			if v and v.Parent == nil then
				v:Destroy()
			end
		end
		table.clear(LoadedTools)
	end

	local function OnBackpack(backpack: Backpack)
		if backpackChildConn then
			backpackChildConn:Disconnect()
			backpackChildConn = nil
		end

		SetupSlots()

		backpackChildConn = backpack.ChildAdded:Connect(function(inst)
			if inst:IsA("Tool") then
				AssignSlot(inst)
			end
		end)

		for _, inst in ipairs(backpack:GetChildren()) do
			if inst:IsA("Tool") then
				AssignSlot(inst)
			end
		end
	end

	Bindables.SendToHotbar.Event:Connect(function(tool: Tool?, stacks: number?)
		if tool == nil or tool.Parent == nil then
			return
		end
		AssignSlot(tool, true, stacks or 1)
	end)

	if Player:FindFirstChild("Backpack") then
		OnBackpack(Player.Backpack)
	end

	if backpackConn then
		backpackConn:Disconnect()
		backpackConn = nil
	end

	backpackConn = Player.ChildAdded:Connect(function(inst)
		if inst.Name == "Backpack" and inst:IsA("Backpack") then
			OnBackpack(inst)
		end
	end)
end

return module
