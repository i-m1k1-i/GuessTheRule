local player = game.Players.LocalPlayer
local UserInputService = game.UserInputService

local UIRefs = require(script.Parent.UIRefs)
local DashController = require(game.ReplicatedStorage.Modules.Client.Game.DashController)
local CameraLockController = require(game.ReplicatedStorage.Modules.Client.Other.CameraLockController)

local MobileControlsController = {}

local LOCK_COLOR_ENABLED = Color3.fromRGB(255, 255, 255)
local LOCK_COLOR_DISABLED = Color3.fromRGB(50, 50, 50)

local dashButtons = {}
local cameraLockButtons = {}

local function updateDashCooldown()
	local remaining = DashController.GetCooldownRemaining()
	for _, buttons in dashButtons do
		buttons.Cooldown.Visible = remaining > 0
		if remaining > 0 then
			buttons.Timer.Text = tostring(math.ceil(remaining))
		end
	end
	return remaining
end

local function startDashCooldownDisplay()
	task.spawn(function()
		while updateDashCooldown() > 0 do
			task.wait(0.1)
		end
	end)
end

local function refreshLockColor()
	local color = if CameraLockController.IsLocked() then LOCK_COLOR_ENABLED else LOCK_COLOR_DISABLED
	for _, button in cameraLockButtons do
		button.ImageColor3 = color
	end
end

local function applyHudSize(smallFrame, largeFrame, smallDash, largeDash, jumpButton)
	local jumpButtonSize = jumpButton.AbsoluteSize.X
	if jumpButtonSize <= 0 then
		return
	end

	local smallSize = smallDash.AbsoluteSize.X
	local largeSize = largeDash.AbsoluteSize.X
	local useLarge = math.abs(jumpButtonSize - largeSize) <= math.abs(jumpButtonSize - smallSize)
	largeFrame.Visible = useLarge
	smallFrame.Visible = not useLarge
end

function MobileControlsController.Init()
	local mobileHud = UIRefs.MobileHUD
	local smallFrame = mobileHud:WaitForChild("Small")
	local largeFrame = mobileHud:WaitForChild("Large")
	local smallDash = smallFrame:WaitForChild("Dash")
	local largeDash = largeFrame:WaitForChild("Dash")

	for _, frame in {smallFrame, largeFrame} do
		local dashButton = frame:WaitForChild("Dash")
		local cooldown = dashButton:WaitForChild("Cooldown")
		table.insert(dashButtons, {
			Cooldown = cooldown,
			Timer = cooldown:WaitForChild("Timer"),
		})
		dashButton.Activated:Connect(function()
			if DashController.TryDash() then
				startDashCooldownDisplay()
			end
		end)

		local cameraLockButton = frame:WaitForChild("CameraLock")
		table.insert(cameraLockButtons, cameraLockButton)
		cameraLockButton.Activated:Connect(CameraLockController.Toggle)
	end

	CameraLockController.LockChanged:Connect(refreshLockColor)
	refreshLockColor()
	updateDashCooldown()

	mobileHud.Enabled = UserInputService.TouchEnabled
	if not UserInputService.TouchEnabled then
		return
	end

	local playerGui = player:WaitForChild("PlayerGui")
	local touchGui = playerGui:WaitForChild("TouchGui")
	local touchControlFrame = touchGui:WaitForChild("TouchControlFrame")
	local jumpButton = touchControlFrame:WaitForChild("JumpButton")

	while jumpButton.AbsoluteSize.X <= 0 do
		jumpButton:GetPropertyChangedSignal("AbsoluteSize"):Wait()
	end

	applyHudSize(smallFrame, largeFrame, smallDash, largeDash, jumpButton)
	jumpButton:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		applyHudSize(smallFrame, largeFrame, smallDash, largeDash, jumpButton)
	end)
end

return MobileControlsController
