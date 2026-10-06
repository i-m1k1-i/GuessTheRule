local Packages = game.ReplicatedStorage.Modules.Packages
local Client = game.ReplicatedStorage.Modules.Client
local Network = require(Packages.Network)
local UIRefs = require(Client.UI.UIRefs)
local StateEffects = require(script.StateEffects)
local Animations = require(script.Animations)

local ScreenController = {} :: {
	Init: () -> (),
	CurrentScreen: UIRefs.ScreensList?,
	OpenScreen: (screenId: UIRefs.ScreensList, remainHUD: boolean?) -> (),
	CloseScreen: (screenId: UIRefs.ScreensList, switching: boolean?) -> (),
	ToggleScreen: (screenId: UIRefs.ScreensList) -> (),
}

ScreenController.CurrentScreen = nil
local Controllers = {}

function ScreenController.Init()
	for _, controller in script.Parent.ScreenControllers:GetChildren() do
		Controllers[controller.Name] = require(controller)
	end
	
	Network:BindEvents({
		OpenScreen = function(params: {screenid: UIRefs.ScreensList, remainHUD: boolean})
			ScreenController.OpenScreen(params.screenid, params.remainHUD)
		end,

		CloseScreen = function(params: {screenId: UIRefs.ScreensList, switching: boolean?})
			ScreenController.CloseScreen(params.screenId, params.switching)
		end,
	})
end

function ScreenController.ToggleScreen(screenId: UIRefs.ScreensList)
	if ScreenController.CurrentScreen == screenId then
		ScreenController.CloseScreen(screenId)
	else
		ScreenController.OpenScreen(screenId, true)
	end
end

function ScreenController.OpenScreen(screenId: UIRefs.ScreensList, remainHUD: boolean?)
	if ScreenController.CurrentScreen then
		ScreenController.CloseScreen(ScreenController.CurrentScreen, true)
	else -- set effects only if there is no screen opened, otherwise zoom is already set
		StateEffects.Set(true)
	end
	
	ScreenController.CurrentScreen = screenId
	
	local screen = UIRefs.Screens[screenId]
	screen.Enabled = true
	Animations.OpenFrame(screen.Frame)
	
	UIRefs.HUD.Enabled = remainHUD == true
end

function ScreenController.CloseScreen(screenId: UIRefs.ScreensList, switching: boolean?)
	if ScreenController.CurrentScreen ~= screenId then
		return
	end
	
	local screen = UIRefs.Screens[screenId]
	Animations.CloseFrame(screen.Frame)
	screen.Enabled = false
	
	if not switching then -- if not switching to another screen then show HUD
		ScreenController.CurrentScreen = nil
		UIRefs.HUD.Enabled = true
		StateEffects.Set(false)
	end
end

return ScreenController