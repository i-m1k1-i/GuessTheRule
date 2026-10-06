local PlayerDataUtil = require(game.ReplicatedStorage.Modules.Packages.PlayerDataUtil)
local RoundService = require(game.ServerStorage.Modules.Services.RoundService)

local TraitorAbilityService = {}

local _definitions = {}
local _roundPlayers: {[Player]: boolean} = {}
local _grantedTools: {[Player]: {Tool}} = {}
local _currentTraitor: Player? = nil
local _roundActive = false

local function removeAbilityTools(player: Player)
	for _, tool in _grantedTools[player] or {} do
		tool:Destroy()
		end
	_grantedTools[player] = nil
end

local function hasAccess(player: Player, definition): boolean
	if definition.UnlockedByDefault then
		return true
	end

	local playerData = PlayerDataUtil.GetPlayerDataFolder(player)
	local abilitiesData = playerData and playerData:FindFirstChild("TraitorAbilities")
	local unlockedValue = abilitiesData and abilitiesData:FindFirstChild(definition.Id)
	return unlockedValue ~= nil and unlockedValue:IsA("BoolValue") and unlockedValue.Value
end

local function grantAbility(player: Player, definition)
	if not hasAccess(player, definition) then
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = definition.DisplayName
	tool.ToolTip = definition.Description or definition.DisplayName
	tool.TextureId = definition.Icon or ""
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool:SetAttribute("MapTool", true)
	tool:SetAttribute("CantDelete", true)
	tool:SetAttribute("TraitorAbility", true)
	tool:SetAttribute("AbilityId", definition.Id)

	if definition.MaxUses then
		tool:SetAttribute("AbilityUsesRemaining", definition.MaxUses)
	end

	tool.Activated:Connect(function()
		if not _roundActive or _currentTraitor ~= player or tool.Parent ~= player.Character then
			return
		end

		local usesRemaining = tool:GetAttribute("AbilityUsesRemaining")
		if typeof(usesRemaining) == "number" and usesRemaining <= 0 then
			return
		end

		local now = workspace:GetServerTimeNow()
		local cooldownEndsAt = tool:GetAttribute("AbilityCooldownEndsAt")
		if typeof(cooldownEndsAt) == "number" and cooldownEndsAt > now then
			return
		end

		if definition.Activate(player, tool) == false then
			return
		end

		local cooldown = definition.Cooldown or 0
		if cooldown > 0 then
			tool:SetAttribute("AbilityCooldownEndsAt", now + cooldown)
		end

		if typeof(usesRemaining) == "number" then
			tool:SetAttribute("AbilityUsesRemaining", usesRemaining - 1)
		end
	end)

	tool.Parent = backpack
	_grantedTools[player] = _grantedTools[player] or {}
	table.insert(_grantedTools[player], tool)
end

local function setTraitor(player: Player?)
	if _currentTraitor == player then
		return
	end

	if _currentTraitor then
		removeAbilityTools(_currentTraitor)
	end

	_currentTraitor = player
	if _roundActive and player and _roundPlayers[player] then
		for _, definition in _definitions do
			grantAbility(player, definition)
		end
	end
end

function TraitorAbilityService:StartRound(players: {Player}, traitor: Player?)
	self:EndRound()
	_roundActive = true
	for _, player in players do
		_roundPlayers[player] = true
	end
	setTraitor(traitor)
end

function TraitorAbilityService:EndRound()
	for player in _roundPlayers do
		removeAbilityTools(player)
	end
	table.clear(_roundPlayers)
	_currentTraitor = nil
	_roundActive = false
end

function TraitorAbilityService.Init()
	for _, abilityModule in script.Abilities:GetChildren() do
		if abilityModule:IsA("ModuleScript") then
			local definition = require(abilityModule)
			assert(typeof(definition.Id) == "string", `{abilityModule.Name} must define an Id`)
			assert(typeof(definition.Activate) == "function", `{abilityModule.Name} must define Activate`)
			table.insert(_definitions, definition)
		end
	end

	RoundService.TraitorChanged:Connect(setTraitor)
	game.Players.PlayerRemoving:Connect(function(player)
		removeAbilityTools(player)
		_roundPlayers[player] = nil
		if _currentTraitor == player then
			_currentTraitor = nil
		end
	end)
end

return TraitorAbilityService