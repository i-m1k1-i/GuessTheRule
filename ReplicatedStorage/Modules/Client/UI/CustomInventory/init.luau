local module = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local UI = script:WaitForChild("UI")

-- Setting Up Modules
local Modules={}
local Bindables={}

local function OnModule(v: ModuleScript,Reference)
	if v:IsA('Folder') then
		Modules[v.Name]={}
		local function OnChild(x)
			OnModule(x,Modules[v.Name])
		end
		for a, b in pairs(v:GetChildren()) do 
			OnChild(b)
		end
		v.ChildAdded:Connect(OnChild)
	else
		Reference[v.Name]=require(v)
	end
end

local function OnBindable(v,Reference)
	if v:IsA('Folder') then
		Bindables[v.Name]={}
		local function OnChild(x)
			OnBindable(x,Bindables[v.Name])
		end
		for a, b in pairs(v:GetChildren()) do 
			OnChild(b)
		end
		v.ChildAdded:Connect(OnChild)
	else
		Reference[v.Name]=v
	end
end

local function CreateWait(Reference, Name)
	repeat task.wait() until typeof(Reference[Name])~='nil'
end

function module.Init()
	for i, v in pairs(script:WaitForChild("Modules"):GetChildren()) do 
		OnModule(v,Modules)
	end

	script.Modules.ChildAdded:Connect(function(v)
		OnModule(v,Modules)
	end)

	for i, v in pairs(script:WaitForChild("Bindables"):GetChildren()) do 
		OnBindable(v,Bindables)
	end

	script.Bindables.ChildAdded:Connect(function(v,Modules)
		OnBindable(v,Bindables)
	end)
	
	if Modules.Workers.Disabler then
		if not Modules.Helpers.Settings then
			CreateWait(Modules.Workers,"Interface")
		end
		if not Modules.Workers.Interface then
			CreateWait(Modules.Workers,"Interface")
		end
		Modules.Workers.Interface:Setup(UI,Modules,Bindables)
		Modules.Workers.Backpack:Setup(Modules,Bindables)
		Modules.Workers.InputService:Setup(Modules)
	else
		warn("Custom Inventory: Unable to disable default inventory.")
	end
end

-- Public functions 
function module.SetEnabled(enabled)
	Modules.Workers.InputService:SetEnabled(enabled)
	Modules.Workers.Interface:SetEnabled(enabled)

	if not enabled then
		local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:UnequipTools()
		end
	end
end

return module