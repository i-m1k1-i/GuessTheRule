local module = {}

local player = game.Players.LocalPlayer

local DEFAULT_SPEED = 23
local SPRINT_SPEED = 55

local isSprinting = false

local function toggleSprint(actionName, inputState)
	if not player.Character or not player.Character:FindFirstChild("Humanoid") then
		return
	end
	
	if inputState ~= Enum.UserInputState.End then
		return
	end
	
	isSprinting = not isSprinting
	
	if isSprinting then
		player.Character.Humanoid.WalkSpeed = DEFAULT_SPEED
	else
		player.Character.Humanoid.WalkSpeed = SPRINT_SPEED
	end	
end

function module.Init()
	game.ContextActionService:BindAction("Sprint", toggleSprint, false, Enum.KeyCode.LeftControl)
end

return module
