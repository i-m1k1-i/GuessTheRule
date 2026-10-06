--local DataService = require(game.ServerStorage.Data.DataService)
local productsData = require(script.Values.MonetizationIDsTable.Value)
local ProductHandlers = require(script.Modules.ProductHandlers)
local GamepassHandlers = require(script.Modules.GamepassHandlers)
local Signals = require(game.ReplicatedStorage.Modules.Packages.Signals)
local Network = require(game.ReplicatedStorage.Modules.Packages.Network)

local passes = productsData.Gamepasses
local ProductPriceCache = {}

local function GetProductPrice(productId)
	if ProductPriceCache[productId] then
		return ProductPriceCache[productId]
	end

	local success, result = pcall(function()
		return game.MarketplaceService:GetProductInfoAsync(productId, Enum.InfoType.Product)
	end)

	if success and result then
		ProductPriceCache[productId] = result.PriceInRobux or 0
		return result.PriceInRobux or 0
	end

	return 0
end

local function ProcessReceipt(ReceiptInfo)
	local player = game.Players:GetPlayerByUserId(ReceiptInfo.PlayerId)
	if player then
		local handler = ProductHandlers[ReceiptInfo.ProductId]
		local success, handleResult = pcall(handler, player)
		if success and handleResult then
			task.spawn(function()
				local robuxAmount = GetProductPrice(ReceiptInfo.ProductId)

				--local profile = DataService.GetProfile(Player)
				--if profile and profile.Stats then
				--	profile.Stats.Robux = (profile.Stats.Robux or 0) + robuxAmount
				--end
			end)
			
			Network:FireClient(player, "PurchaseSuccess")
			return Enum.ProductPurchaseDecision.PurchaseGranted
		elseif not success then
			warn("Failed to process receipt for ProductId:", ReceiptInfo.ProductId, "Error:", handleResult)
		elseif success and handleResult == nil then
			error(`{ReceiptInfo.ProductId} handler returned nil`)
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function onGamepassPurchase(player: Player, passId: number, wasPurchased: boolean)
	if not wasPurchased then
		return
	end
	
	local handler = GamepassHandlers[passId]
	handler(player)
	Network:FireClient(player, "PurchaseSuccess")
end

local function LoadGamepasses(player: Player)
	for _, id in pairs(passes) do
		local ok, hasPass = pcall(function()
			return game.MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
		end)
		if ok and hasPass then
			local handler = GamepassHandlers[id]
			if handler then
				handler(player, true)
			end
		end
	end
end


local function Init()
	game.MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamepassPurchase)
	game.MarketplaceService.ProcessReceipt = ProcessReceipt

	game.Players.PlayerAdded:Connect(function(player)
		LoadGamepasses(player)
	end)


	-- TEST
	Signals.ProductPurchased:Connect(function(player: Player, productId: number)
		local result = ProcessReceipt({
			PlayerId = player.UserId,
			ProductId = productId
		})

		print(`{player.Name} purchased {productId}: result - {result}`)
	end)

	Signals.GamepassPurchased:Connect(function(player: Player, passId: number)
		onGamepassPurchase(player, passId, true)
	end)

	Network:BindEvents({
		ProductPurchased = function(player, productId)
			local result = ProcessReceipt({
				PlayerId = player.UserId,
				ProductId = productId
			})

			print(`{player.Name} purchased {productId}: result - {result}`)
		end,

		GamepasPurchased = function(player, passId)
			onGamepassPurchase(player, passId, true)
		end,
	})
end


Init()
