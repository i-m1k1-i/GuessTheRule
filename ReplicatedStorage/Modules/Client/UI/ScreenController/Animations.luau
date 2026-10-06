local module = {}

local DOWN_POSITION = UDim2.new(0.5, 0, 0.65, 0)
local CENTER_POSITION = UDim2.new(0.5, 0, 0.5, 0)

local OPEN_DURATION = 0.25
local CLOSE_DURATION = 0.1

-- cancel / reuse per-frame
local activeTweens: {[Frame]: Tween} = {}

local function cancelTween(frame: Frame)
	local tween = activeTweens[frame]
	if tween then
		activeTweens[frame] = nil
		tween:Cancel()
	end
end

function module.OpenFrame(frame: Frame)
	cancelTween(frame)

	frame.Position = DOWN_POSITION

	local tween = game.TweenService:Create(
		frame,
		TweenInfo.new(OPEN_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = CENTER_POSITION }
	)

	activeTweens[frame] = tween
	tween:Play()

	-- If something cancels/replaces this tween, this will still return (Cancelled/Completed).
	tween.Completed:Wait()

	-- Clear only if this tween is still the active one for the frame
	if activeTweens[frame] == tween then
		activeTweens[frame] = nil
	end
end

function module.CloseFrame(frame: Frame)
	cancelTween(frame)

	local tween = game.TweenService:Create(
		frame,
		TweenInfo.new(CLOSE_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{ Position = DOWN_POSITION }
	)

	activeTweens[frame] = tween
	tween:Play()

	tween.Completed:Wait()

	if activeTweens[frame] == tween then
		activeTweens[frame] = nil
	end
end

function module.Cancel(frame: Frame)
	cancelTween(frame)
end

return module