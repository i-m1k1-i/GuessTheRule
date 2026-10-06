local Client = game.ReplicatedStorage.Modules.Client
local UIRefs = require(Client.UI.UIRefs)

local LeftButtons = {}

local HudGui = UIRefs.HUD
local leftButtons = HudGui:WaitForChild("LeftButtons")

local buttonsActiveStages = {
	Guess = {"RuleActive"},
}

function LeftButtons.Init()
	workspace:GetAttributeChangedSignal("GameStage"):Connect(updateButtonsVisibilities)
	updateButtonsVisibilities()
end

function updateButtonsVisibilities()
	local stage = workspace:GetAttribute("GameStage")
	for _, button in leftButtons:GetChildren() do
		local activeStages = buttonsActiveStages[button.Name]

		if not activeStages then
			continue
		end

		if table.find(activeStages, stage) then
			button.Visible = true
		else
			button.Visible = false
		end
	end
end

return LeftButtons
