local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local player = game.Players.LocalPlayer

ProximityPromptService.PromptShown:Connect(function(proximityPrompt)
	local success, error = pcall(function()
		local highlightAdornee = proximityPrompt:FindFirstAncestorWhichIsA("PVInstance")

		local newHighlight = Instance.new("Highlight")
		newHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
		newHighlight.FillColor = Color3.fromRGB(230, 230, 230)
		newHighlight.FillTransparency = 0.75
		newHighlight.Adornee = highlightAdornee
		newHighlight.Parent = player:WaitForChild("PlayerGui")

		proximityPrompt.PromptHidden:Once(function()
			newHighlight:Destroy()
		end)
	end)
	
	if error then
		print(error)
	end
end)