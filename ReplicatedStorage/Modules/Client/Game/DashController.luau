local player = game.Players.LocalPlayer
local DASH_SPEED = 60
local DASH_DURATION = 0.18
local DASH_COOLDOWN = 2

local Network = require(game.ReplicatedStorage.Modules.Packages.Network)
local Actions = require(game.ReplicatedStorage.Modules.Shared.Config.Actions)

local DashController = {}
local lastDashTime = -math.huge

function DashController.GetCooldownRemaining()
	return math.max(0, DASH_COOLDOWN - (os.clock() - lastDashTime))
end

function DashController.TryDash()
	if DashController.GetCooldownRemaining() > 0 then
		return false
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or humanoid.SeatPart or not rootPart or not rootPart:IsA("BasePart") then
		return false
	end

	local direction = humanoid.MoveDirection
	if direction.Magnitude == 0 then
		direction = rootPart.CFrame.LookVector
	end
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude == 0 then
		return false
	end
	direction = direction.Unit

	local attachment = Instance.new("Attachment")
	attachment.Name = "DashAttachment"
	attachment.Parent = rootPart

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "DashVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.PlaneVelocity = Vector2.new(direction.X, direction.Z) * DASH_SPEED
	velocity.ForceLimitsEnabled = true
	velocity.MaxForce = rootPart.AssemblyMass * 10000
	velocity.Parent = rootPart

	game.Debris:AddItem(velocity, DASH_DURATION)
	game.Debris:AddItem(attachment, DASH_DURATION)

	lastDashTime = os.clock()
	Network:FireServer("ActionOccured", Actions.Enum.Common.Dash)
	return true
end

local function handleDashKey(_actionName, inputState)
	if inputState == Enum.UserInputState.Begin then
		DashController.TryDash()
		return Enum.ContextActionResult.Sink
	end

	return Enum.ContextActionResult.Pass
end

function DashController.Init()
	game.ContextActionService:BindAction("Dash", handleDashKey, false, Enum.KeyCode.Q)
end

return DashController
