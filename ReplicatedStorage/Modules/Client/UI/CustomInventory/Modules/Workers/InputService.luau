local module={}
module.enabled = true

function module:Setup(Modules)
	local UserInputService=game:GetService("UserInputService")
	UserInputService.InputBegan:Connect(function(Input,Processed)
		if not self.enabled then
			return
		end
		if Processed then 
			return
		end
		
		if Input.KeyCode.Value>=49 and Input.KeyCode.Value<=(48+Modules.Helpers.Settings.Interface.MaxSlots) then
			if not game.Players.LocalPlayer.Character then 
				return 
			end
			if not game.Players.LocalPlayer.Character:FindFirstChild("Humanoid") then
				return
			end
			
			if Modules.Helpers.Settings.Interface.Debounce.Status==false then
				Modules.Helpers.Settings.Interface.Debounce.Status=true
				local SlotNumber=(Input.KeyCode.Value-48)
				if tonumber(Modules.Helpers.Settings.Interface.CurrentSlot.Value)==SlotNumber then
					Modules.Helpers.Settings.Interface.CurrentSlot.Value=""
				else 
					Modules.Helpers.Settings.Interface.CurrentSlot.Value=tostring(SlotNumber)
				end
				task.wait(Modules.Helpers.Settings.Interface.Debounce.Duration)
				Modules.Helpers.Settings.Interface.Debounce.Status=false
			end
		end
	end)
end

function module:SetEnabled(enabled)
	if enabled then
		self.enabled = true
	else
		self.enabled = false
	end
end

return module