local Signal = require(game.ReplicatedStorage.Modules.Packages.Signals.GoodSignal)

local COMPUTER_TYPES = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
	[Enum.UserInputType.MouseButton3] = true,
	[Enum.UserInputType.MouseWheel] = true,
	[Enum.UserInputType.MouseMovement] = true,
	[Enum.UserInputType.Keyboard] = true
}

local GAMEPAD_TYPES = {
	[Enum.UserInputType.Gamepad1] = true,
	[Enum.UserInputType.Gamepad2] = true,
	[Enum.UserInputType.Gamepad3] = true,
	[Enum.UserInputType.Gamepad4] = true,
	[Enum.UserInputType.Gamepad5] = true,
	[Enum.UserInputType.Gamepad6] = true,
	[Enum.UserInputType.Gamepad7] = true,
	[Enum.UserInputType.Gamepad8] = true
}

local PLAYSTATION_STRINGS = {
	ButtonCross = true, ButtonCircle = true, ButtonSquare = true, ButtonTriangle = true,
	ButtonL1 = true, ButtonL2 = true, ButtonL3 = true,
	ButtonR1 = true, ButtonR2 = true, ButtonR3 = true,
	ButtonOptions = true, ButtonTouchpad = true, ButtonShare = true
}

local changedSignal = Signal.new()
local mouseSuppressUntil = 0
local lastInputClock = os.clock()

local currentDevice
if game.UserInputService.GamepadEnabled then
	currentDevice = "Xbox"
elseif game.UserInputService.TouchEnabled then
	currentDevice = "Mobile"
else
	currentDevice = "Computer"
end

-- FUNCTIONS --

local function setDevice(device)
	if device == currentDevice then return end
	currentDevice = device
	changedSignal:Fire(device)
end

local function classifyGamepad(keyCode)
	local str = game.UserInputService:GetStringForKeyCode(keyCode)
	if PLAYSTATION_STRINGS[str] then
		return "Playstation"
	end
	return "Xbox"
end

local function handleInput(input, gameProcessed)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then
		lastInputClock = os.clock()
	end
	if gameProcessed then return end
	local inputType = input.UserInputType
	if inputType == Enum.UserInputType.MouseMovement
		and (game.UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter or os.clock() < mouseSuppressUntil) then
		return
	end
	if COMPUTER_TYPES[inputType] then
		setDevice("Computer")
	elseif inputType == Enum.UserInputType.Touch then
		setDevice("Mobile")
	elseif GAMEPAD_TYPES[inputType] then
		setDevice(classifyGamepad(input.KeyCode))
	end
end

local DeviceController = {}

DeviceController.Changed = changedSignal

function DeviceController.SuppressMouseMovement(duration)
	mouseSuppressUntil = os.clock() + duration
end

function DeviceController.Get()
	return currentDevice
end

function DeviceController.IsMobile()
	return currentDevice == "Mobile"
end

function DeviceController.GetIdleSeconds()
	return os.clock() - lastInputClock
end

function DeviceController.Init()
	game.UserInputService.InputBegan:Connect(handleInput)
	game.UserInputService.InputChanged:Connect(handleInput)
end

return DeviceController
