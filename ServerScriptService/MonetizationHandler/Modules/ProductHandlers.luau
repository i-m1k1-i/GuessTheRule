local ProductHandlers = {}

local ProductsData = require(script.Parent.Parent.Values.MonetizationIDsTable.Value).Products

local LIMITED_VACUUM = "LimitedVacuum"

local cashProducts = {
	[4_500] = ProductsData["Cash1"],
	[35_000] = ProductsData["Cash2"],
	[100_000] = ProductsData["Cash3"],
	[450_000] = ProductsData["Cash4"],
	[990_000] = ProductsData["Cash5"],
}

local function handleCash(player:Player, amount)
	-- add cash
	local somethingWentWrong = false
	
	if somethingWentWrong then
		return false
	end
	
	return true
end

for amount, productId in pairs(cashProducts) do
	ProductHandlers[productId] = function(player) 
		return handleCash(player, amount) 
	end
end

ProductHandlers[ProductsData.EggPack] = function(player: Player)
	
	return true
end

return ProductHandlers
