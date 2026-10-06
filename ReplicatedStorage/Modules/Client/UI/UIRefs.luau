export type Screen = ScreenGui & {Frame: Frame&{Close: GuiButton?}}
export type ScreensList = "Guess" | "Settings"
export type ScreensModule = {
	HUD: ScreenGui,
	MobileHUD: ScreenGui,
	Screens: {[ScreensList]: Screen},
	Background: Frame,
	TopBar: Frame,
}

local module = {} :: ScreensModule

local playerGui: PlayerGui = game.Players.LocalPlayer.PlayerGui
local Screens: ScreenGui = playerGui:WaitForChild("Screens")

module.HUD = playerGui:WaitForChild("HUD")
module.MobileHUD = playerGui:WaitForChild("MobileHUD")
module.TopBar = module.HUD:WaitForChild("TopBar")
module.Screens = {
	Shop = Screens:WaitForChild("Shop"),
	Guess = Screens:WaitForChild("Guess"),
}
module.Background = Screens:WaitForChild("Background")

-- Setup screens
for _, screen in module.Screens do
	screen.Enabled = false
	screen:WaitForChild("Frame").Visible = true
end

return module
