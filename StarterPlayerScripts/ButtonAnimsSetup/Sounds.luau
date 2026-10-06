local module = {}

local sounds = {
	Click = "rbxassetid://8354589135",
	Hover = "rbxassetid://10066942189",
	openUI = "rbxassetid://95038599585391",
	--closeUI = "rbxassetid://121253508969064",
	
	--openStore = "rbxassetid://6926253319",
	--purchasePrompted = "rbxassetid://8382337318"
}

local function playSound(soundId: string, properties: Sound?)
	properties = properties or {}
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Parent = game.SoundService

	for property, value in properties do
		sound[property] = value
	end

	sound.PlayOnRemove = true
	sound:Destroy()
end

function module.ButtonClick(properties: Sound?)
	playSound(sounds.Click, properties)
end

function module.ButtonHover(properties: Sound?)
	playSound(sounds.Hover, properties)
end

function module.ButtonLeave(properties: Sound?)
	playSound("", properties)
end

return module
