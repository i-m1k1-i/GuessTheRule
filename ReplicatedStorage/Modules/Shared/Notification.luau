local Packages = game.ReplicatedStorage.Modules.Packages
local Shared = game.ReplicatedStorage.Modules.Shared
local Network = require(Packages.Network)
local SafeIsA = require(Shared.Utility.SafeIsA)

export type NotificationProps = {
	color: Color3?,
	duration: number?,
	sound: string | Sound?,
	soundProps: {[string]: any}?,
}

type NotificationTemplate = Frame & {TextLabel: TextLabel & {UIStroke: UIStroke}, UIGradient: UIGradient}

local NotificationModule = {}

-- CONSTANTS
local DEFAULT_DURATION = 2
local FADE_IN_TIME = 0.3
local FADE_OUT_TIME = 0.5
local MAX_NOTIFICATIONS = 5

-- VARIABLES
local notifications = {}
local notificationId = 0
local notificationFrame: Frame?
local notificationTemplate: NotificationTemplate

local function areSoundPropsEqual(first: {[string]: any}?, second: {[string]: any}?): boolean
	if first == second then
		return true
	end
	if not first or not second then
		return false
	end

	for key, value in first do
		if second[key] ~= value then
			return false
		end
	end
	for key in second do
		if first[key] == nil then
			return false
		end
	end

	return true
end

local function arePropsEqual(first: NotificationProps, second: NotificationProps): boolean
	return first.color == second.color
		and first.duration == second.duration
		and first.sound == second.sound
		and areSoundPropsEqual(first.soundProps, second.soundProps)
end

local function fadeIn(notification: Frame, textLabel: TextLabel, uiStroke: UIStroke)
	game.TweenService:Create(textLabel, TweenInfo.new(FADE_IN_TIME), {
		TextTransparency = 0,
		TextStrokeTransparency = 0,
	}):Play()

	game.TweenService:Create(uiStroke, TweenInfo.new(FADE_IN_TIME), {
		Transparency = 0,
	}):Play()

	game.TweenService:Create(notification, TweenInfo.new(FADE_IN_TIME), {
		BackgroundTransparency = 0,
	}):Play()
end

local function fadeOut(record)
	if record.FadeOutTweens then
		return
	end

	local notification = record.Notification
	local token = record.Token
	local index = table.find(notifications, record)
	if index then
		table.remove(notifications, index)
	end
	local fadeOutTween = game.TweenService:Create(record.TextLabel, TweenInfo.new(FADE_OUT_TIME), {
		TextTransparency = 1,
	})
	local strokeFadeOutTween = game.TweenService:Create(record.UIStroke, TweenInfo.new(FADE_OUT_TIME), {
		Transparency = 1,
	})
	local backgroundFadeOutTween = game.TweenService:Create(notification, TweenInfo.new(FADE_OUT_TIME), {
		BackgroundTransparency = 1,
	})

	record.FadeOutTweens = {fadeOutTween, strokeFadeOutTween, backgroundFadeOutTween}
	fadeOutTween:Play()
	strokeFadeOutTween:Play()
	backgroundFadeOutTween:Play()

	task.spawn(function()
		fadeOutTween.Completed:Wait()
		if record.Token ~= token then
			return
		end

		record.FadeOutTweens = nil
		if notification.Parent then
			notification:Destroy()
		end
	end)
end

local function initializeClientGui()
	if not game["Run Service"]:IsClient() or notificationFrame then
		return
	end

	local notificationGui = script:WaitForChild("Notifications"):Clone()
	notificationGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	local frame = notificationGui:WaitForChild("Frame") :: Frame
	notificationFrame = frame
	notificationTemplate = frame:WaitForChild("Template") :: NotificationTemplate
end

function NotificationModule.Init()
	if game["Run Service"]:IsClient() then
		initializeClientGui()
		Network:BindEvents({
			Notification = function(payload: {Text: string, Props: NotificationProps})
				clientShow(payload.Text, payload.Props)
			end,
		})
	end
end

-- Show a notification
function NotificationModule.Show(text: string, props: NotificationProps?, player: Player?)
	if game["Run Service"]:IsServer() then
		serverShow(player, text, props)
	elseif game["Run Service"]:IsClient() then
		clientShow(text, props or {})
	end
end

-- Show a success notification (green)
function NotificationModule.Success(text: string, duration: number?, player: Player?)
	NotificationModule.Show(text, {color=Color3.fromRGB(100, 255, 100), duration=duration, sound="Complete"}, player)
end

-- Show an error notification (red)
function NotificationModule.Error(text: string, duration: number?, player: Player?)
	NotificationModule.Show(text, {color=Color3.fromRGB(255, 100, 100), duration=duration, sound="Error"}, player)
end

-- Show a warning notification (yellow/orange)
function NotificationModule.Warning(text: string, duration: number?, player: Player?)
	NotificationModule.Show(text, {color=Color3.fromRGB(255, 200, 100), duration=duration, sound="Warning"}, player)
end

-- Show an info notification (blue)
function NotificationModule.Info(text: string, duration: number?, player: Player?)
	NotificationModule.Show(text, {color=Color3.fromRGB(100, 200, 255), duration=duration, sound="Info"}, player)
end

function clientShow(text: string, props: NotificationProps)
	initializeClientGui()

	for _, record in notifications do
		if record.Text == text and arePropsEqual(record.Props, props) then
			record.RepeatCount += 1
			record.Token += 1
			if record.FadeOutTweens then
				for _, tween in record.FadeOutTweens do
					tween:Cancel()
				end
				record.FadeOutTweens = nil
			end
			record.TextLabel.Text = `{text} (x{record.RepeatCount})`
			playSound(record.Props.sound, record.Props.soundProps)
			local token = record.Token
			task.delay(record.Duration, function()
				if record.Token ~= token then
					return
				end
				record:Remove()
			end)
			return
		end
	end

	-- Default values
	local color = props.color or Color3.fromRGB(255, 255, 255)
	local duration = props.duration or DEFAULT_DURATION

	-- Clone the template
	local notification = notificationTemplate:Clone()
	notificationId += 1
	notification.Name = `Notification_{notificationId}`
	notification.Visible = true
	local notifTextLabel = notification:WaitForChild("Textlabel") :: TextLabel
	notifTextLabel.Text = text
	notifTextLabel.TextColor3 = color
	local uiStroke = notifTextLabel:WaitForChild("UIStroke")

	-- Start invisible for fade in
	notification.BackgroundTransparency = 1
	notifTextLabel.TextTransparency = 1
	uiStroke.Transparency = 1

	notification.Parent = notificationFrame
	local record = {
		Notification = notification,
		Text = text,
		Props = props,
		Duration = duration,
		TextLabel = notifTextLabel,
		UIStroke = uiStroke,
		RepeatCount = 1,
		Token = 0,
		FadeOutTweens = nil,
	}
	record.Remove = function()
		fadeOut(record)
	end
	table.insert(notifications, record)

	playSound(props.sound, props.soundProps)

	fadeIn(notification, notifTextLabel, uiStroke)

	-- Schedule removal
	local initialToken = record.Token
	task.delay(duration, function()
		if record.Token ~= initialToken then
			return
		end
		record.Remove()
	end)

	if #notifications > MAX_NOTIFICATIONS then
		local oldestNotification = notifications[1]
		if oldestNotification then
			oldestNotification.Remove()
		end
	end
end

function serverShow(player: Player?, text: string, props: NotificationProps?)
	local payload = {Text = text, Props = props or {}}
	if player then
		Network:FireClient(player, "Notification", payload)
	else
		Network:FireAllClients("Notification", payload)
	end
end

function playSound(sound: string?|Sound?, props)
	if not sound then
		return
	end

	local soundInstance: Sound

	if typeof(sound) == "string" then
		local soundTemplate = game.SoundService.SFX.UI:FindFirstChild(sound)
		if soundTemplate then
			soundInstance = soundTemplate:Clone()
			soundInstance.Parent = game.SoundService
		end
	elseif SafeIsA(sound, "Sound") then
		soundInstance = sound:Clone()
		soundInstance.Parent = game.SoundService
	end
	
	if soundInstance and SafeIsA(soundInstance, "Sound") then
		if props then
			for k, v in props do
				soundInstance[k] = v
			end
		end
		soundInstance:Play()
		soundInstance.Ended:Connect(function()
			soundInstance:Destroy()
		end)
	end
end

return NotificationModule