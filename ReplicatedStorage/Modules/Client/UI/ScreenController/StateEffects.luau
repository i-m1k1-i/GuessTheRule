local module = {}

local UIRefs = require(game.ReplicatedStorage.Modules.Client.UI.UIRefs)

local FOV_DELTA = 10
local BLUR_SIZE_ON = 15
local BACKGROUND_TRANSPARENCY = 0.6

local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local playingTweens = setmetatable({}, {__mode='v'}) :: {[string]: Tween} 

local Settings = {
	Zoom = true,
	Blur = true,
	Background = true,
}

local defaultFOV = 0
local blur = nil

function module.Init()
	blur = Instance.new("BlurEffect", game.Lighting)
	blur.Size = 0
	module.inited = true
end

function module.Set(enabled)
	if not module.inited then
		module.Init()
	end
	
	SetZoom(enabled) 
	SetBlur(enabled)
	SetBackground(enabled)
end

function SetZoom(enabled: boolean)
	if not Settings.Zoom then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	if playingTweens.zoom then
		(playingTweens.zoom::Tween):Cancel()
		if defaultFOV then
			camera.FieldOfView = defaultFOV	
		end
	end

	local newFOV
	if enabled then
		defaultFOV = camera.FieldOfView
		newFOV = camera.FieldOfView - FOV_DELTA
	else
		newFOV = defaultFOV -- camera.FieldOfView + FOV_DELTA
	end
	
	playingTweens.zoom = game.TweenService:Create(camera, tweenInfo, {FieldOfView=newFOV})
	playingTweens.zoom:Play()
	playingTweens.zoom.Completed:Connect(function()
		playingTweens.zoom = nil
	end)
end

function SetBlur(enabled: boolean)
	if not Settings.Blur then
		return
	end
	if playingTweens.blur then
		playingTweens.blur:Cancel()
	end
	
	local size = enabled and BLUR_SIZE_ON or 0
	playingTweens.blur = game.TweenService:Create(blur, tweenInfo, {Size=size})
	playingTweens.blur:Play()
end

function SetBackground(enabled: boolean)
	if not Settings.Background then
		return
	end
	
	local background = UIRefs.Background
	
	if playingTweens.background and playingTweens.background.PlaybackState == Enum.PlaybackState.Playing then
		playingTweens.background:Cancel()
	end
	
	if enabled then
		background.Visible = true
		background.BackgroundTransparency = 1
		playingTweens.bacgkround = game.TweenService:Create(background, tweenInfo, {BackgroundTransparency=BACKGROUND_TRANSPARENCY})
		playingTweens.bacgkround:Play()
	else
		playingTweens.bacgkround = game.TweenService:Create(background, tweenInfo, {BackgroundTransparency=1})
		playingTweens.bacgkround:Play()
	end
end

return module
