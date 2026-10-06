local TraitorService = {}
local _baitedPlayers: {[Player]: number} = {}

local function getEligiblePlayers(players: {Player}): {Player}
	local eligiblePlayers = {}
	local seen = {}
	for _, player in players do
		if typeof(player) == "Instance" and player:IsA("Player") and player.Parent == game.Players and not seen[player] then
			seen[player] = true
			table.insert(eligiblePlayers, player)
		end
	end
	return eligiblePlayers
end

function TraitorService.SelectTraitor(players: {Player}): Player?
	local eligiblePlayers = getEligiblePlayers(players)
	if #eligiblePlayers == 0 then
		return nil
	end

	table.clear(_baitedPlayers)
	return eligiblePlayers[math.random(1, #eligiblePlayers)]
end

function TraitorService.OnPlayerBaited(traitor: Player?, victim: Player): boolean
	if not traitor or traitor == victim or traitor.Parent ~= game.Players then
		return false
	end

	_baitedPlayers[victim] = (_baitedPlayers[victim] or 0) + 1
	return true
end

function TraitorService.GetBaitedCount(player: Player): number
	return _baitedPlayers[player] or 0
end

function TraitorService.Clear()
	table.clear(_baitedPlayers)
end

return TraitorService
