local module = {}

local hintLabel: TextLabel? = nil
local trackedCharacter: Model? = nil
local activeTool: Tool? = nil
local characterConnections: {RBXScriptConnection} = {}
local playerConnections: {RBXScriptConnection} = {}
local toolHintConnection: RBXScriptConnection? = nil

local function clearHint()
	if hintLabel then
		hintLabel.Text = ""
		hintLabel.Visible = false
	end
end

local function showToolHint(tool: Tool?)
	if toolHintConnection then
		toolHintConnection:Disconnect()
		toolHintConnection = nil
	end

	activeTool = tool
	if not tool or not hintLabel then
		clearHint()
		return
	end

	local function updateHint()
		local hint = tool:GetAttribute("Hint")
		if typeof(hint) == "string" and hint ~= "" then
			hintLabel.Text = hint
			hintLabel.Visible = true
		else
			clearHint()
		end
	end

	updateHint()
	toolHintConnection = tool:GetAttributeChangedSignal("Hint"):Connect(function()
		if activeTool == tool and trackedCharacter == tool.Parent then
			updateHint()
		end
	end)
end

local function stopTrackingCharacter()
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	table.clear(characterConnections)
	if toolHintConnection then
		toolHintConnection:Disconnect()
		toolHintConnection = nil
	end
	trackedCharacter = nil
	activeTool = nil
	clearHint()
end

local function trackCharacter(character: Model)
	stopTrackingCharacter()
	trackedCharacter = character

	local function onChildAdded(child: Instance)
		if child:IsA("Tool") then
			showToolHint(child)
		end
	end

	local function onChildRemoved(child: Instance)
		if child == activeTool then
			local replacementTool = nil
			for _, characterChild in character:GetChildren() do
				if characterChild:IsA("Tool") then
					replacementTool = characterChild
					break
				end
			end
			showToolHint(replacementTool)
		end
	end

	table.insert(characterConnections, character.ChildAdded:Connect(onChildAdded))
	table.insert(characterConnections, character.ChildRemoved:Connect(onChildRemoved))
	for _, child in character:GetChildren() do
		onChildAdded(child)
	end
end

function module:Setup(ui: Instance, player: Player)
	for _, connection in playerConnections do
		connection:Disconnect()
	end
	table.clear(playerConnections)
	stopTrackingCharacter()

	hintLabel = ui:WaitForChild("Hint") :: TextLabel
	clearHint()

	table.insert(playerConnections, player.CharacterAdded:Connect(trackCharacter))
	table.insert(playerConnections, player.CharacterRemoving:Connect(function(character)
		if trackedCharacter == character then
			stopTrackingCharacter()
		end
	end))
	if player.Character then
		trackCharacter(player.Character)
	end
end

return module