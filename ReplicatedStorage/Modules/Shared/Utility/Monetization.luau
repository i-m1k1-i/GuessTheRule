local Signals = require(game.ReplicatedStorage.Modules.Packages.Signals)
local Network = require(game.ReplicatedStorage.Modules.Packages.Network)

local TestPurchases = false
local TestGamepasses = false

local module = {}

local function isTest(gamepass: boolean)
	return game["Run Service"]:IsStudio() 
		and (TestPurchases) or (gamepass and TestGamepasses)
end

function module:PromptProductPurchase(player: Player, productId: number)
	if isTest() then
		if game["Run Service"]:IsClient() then
			Network:FireServer("ProductPurchased", productId)
		else
			Signals.ProductPurchased:Fire(player, productId)
		end
	else
		game.MarketplaceService:PromptProductPurchase(player, productId)
	end
end

function module:PromptGamepassPurchase(player: Player, passId: number)
	if isTest() then
		if game["Run Service"]:IsClient() then
			Network:FireServer("GamepassPurchased", passId)
		else
			Signals.GamepassPurchased:Fire(player, passId)
		end
	else
		game.MarketplaceService:PromptGamepassPurchase(player, passId)
	end
end

function module:UserOwnsGamepass(player: Player, passId: number): boolean
	if isTest(true) then
		return true
	end
	
	local success, owns = game.MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	if success then
		return owns
	end
	
	return false
end

return module
