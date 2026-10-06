local module = {}

local touchPart = workspace.Baseplate

function module.Init()
	touchPart.Touched:Connect(function()
		
	end)
end

return module
