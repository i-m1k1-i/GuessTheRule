local module = {}

local touchPart = workspace.Baseplate

function module.Init()
	touchPart.Touched:Connect(function()
		-- TODO : Handle map dropout: return to the active map or lobby
	end)
end

return module
