local Attempts,MaxAttempts=0,5
local Success,Fail
local StarterGui = game:GetService("StarterGui")
for i=1, MaxAttempts do 
	Success,Fail=pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	if Success or Attempts>=MaxAttempts then
		break
	end
	Attempts=Attempts+1
	task.wait(1)
end
if Success and not Fail then
	return true
end
return {}