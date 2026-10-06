local DeviceController = require(script.Parent.DeviceController)
local localPlayer = game.Players.LocalPlayer
local UserInputService = game.UserInputService
local RunService = game.RunService

local changedSignal = require(game.ReplicatedStorage.Modules.Packages.Signals.GoodSignal).new()
local CameraConfig = require(game.ReplicatedStorage.Modules.Shared.Config.Camera)

local CAMERA_OFFSET = CameraConfig.CameraLockOffset
local TRANSITION_SPEED = CameraConfig.CameraLockTransitionSpeed
local MOUSE_ICON = CameraConfig.CameraLockMouseIcon
local DEVICE_SUPPRESS = CameraConfig.CameraLockDeviceSuppressSeconds
local FIRST_PERSON_DISTANCE = CameraConfig.CameraFirstPersonDistance
local MIN_LOOK = 0.01

local locked = false
local alpha = 0

-- FUNCTIONS --

local function setLocked(value)
	if locked == value then return end
	locked = value

	if locked then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIcon = MOUSE_ICON
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIcon = ""
	end

	DeviceController.SuppressMouseMovement(DEVICE_SUPPRESS)
	changedSignal:Fire(locked)
end

local function onRenderStep(dt)
	local camera = workspace.CurrentCamera
	if not camera then return end

	local character = localPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	if locked and (camera.CFrame.Position - camera.Focus.Position).Magnitude < FIRST_PERSON_DISTANCE then
		setLocked(false)
	end

	local busy = humanoid.Sit
	humanoid.AutoRotate = not locked and not busy

	if locked then
		if not busy then
			local look = camera.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > MIN_LOOK then
				flat = flat.Unit
				rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + flat)
			end
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end

	local targetAlpha = if locked then 1 else 0
	alpha += (targetAlpha - alpha) * math.min(1, dt * TRANSITION_SPEED)

	if alpha > 0.001 then
		camera.CFrame = camera.CFrame + camera.CFrame:VectorToWorldSpace(CAMERA_OFFSET * alpha * character:GetScale())
	end
end

local function onInputBegan(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.ButtonL1
		or input.KeyCode == Enum.KeyCode.LeftShift
		or input.KeyCode == Enum.KeyCode.RightShift then
		setLocked(not locked)
	end
end

-- MODULE --

local CameraLockController = {}

CameraLockController.LockChanged = changedSignal

function CameraLockController.IsLocked()
	return locked
end

function CameraLockController.Toggle()
	setLocked(not locked)
end

function CameraLockController.SetLocked(value)
	setLocked(value and true or false)
end

function CameraLockController.Init()
	UserInputService.InputBegan:Connect(onInputBegan)
	RunService:BindToRenderStep("CameraLockController", Enum.RenderPriority.Camera.Value + 1, onRenderStep)
end

return CameraLockController
