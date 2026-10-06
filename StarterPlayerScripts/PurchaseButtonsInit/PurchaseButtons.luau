-- Collects buttons by tags "Product"/"Gamepass", attribute "Id" — key.
-- Supports Init(idMap) / Init(nil, passMap, productMap) / Init({ idMap=..., gamepasses=..., products=... })
local DEBOUNCE_TIME = 0.5

local PurchaseButtons = {}
PurchaseButtons._connections = {}
PurchaseButtons._buttonMap = {} -- [Instance] = { tagType="Product"/"Gamepass", conn=RBXScriptConnection }
-- attribute = Id: string

local player = game.Players.LocalPlayer

local function isGuiButton(inst)
	return inst and typeof(inst) == "Instance" and inst:IsA("GuiButton")
end

local function disconnectButton(button)
	local rec = PurchaseButtons._buttonMap[button]
	if rec then
		if rec.conn then
			rec.conn:Disconnect()
		end
		PurchaseButtons._buttonMap[button] = nil
	end
end

local function resolveIdFor(button, tagType, maps)
	local key = button:GetAttribute("Id")
	if key == nil then
		warn((`[PurchasableButtons] missing Attribute 'Id' on {button:GetFullName()}`))
		return nil
	end
	if tagType == "Gamepass" then
		if maps.gamepasses and maps.gamepasses[key] then
			return maps.gamepasses[key]
		end
	elseif tagType == "Product" then
		if maps.products and maps.products[key] then
			return maps.products[key]
		end
	end
	if maps.idMap and maps.idMap[key] then
		return maps.idMap[key]
	end

	warn((`[PurchasableButtons] id not found for key {tostring(key)} (tag={tagType}) on {button:GetFullName()}`))
	return nil
end

local function attach(button, tagType, maps)
	if not isGuiButton(button) then
		warn((`[PurchasableButtons] instance is not a GuiButton: {button:GetFullName()}`))
		return
	end

	local realId = resolveIdFor(button, tagType, maps)
	if typeof(realId) ~= "number" then
		disconnectButton(button)
		return
	end

	if PurchaseButtons._buttonMap[button] then
		disconnectButton(button)
	end

	local debounce = false
	local conn = button.Activated:Connect(function()
		if debounce then return end
		debounce = true
		task.delay(DEBOUNCE_TIME, function()
			debounce = false
		end)
		
		if tagType == "Product" then
			game.MarketplaceService:PromptProductPurchase(player, realId)   -- Dev Product
		else
			game.MarketplaceService:PromptGamePassPurchase(player, realId) -- Gamepass
		end
	end)

	PurchaseButtons._buttonMap[button] = { tagType = tagType, conn = conn }
end

local function scanAndAttach(tagType, maps)
	for _, inst in ipairs(game.CollectionService:GetTagged(tagType)) do
		attach(inst, tagType, maps)
	end
end

local function connectTagSignals(tagType, maps)
	local addedConn = game.CollectionService:GetInstanceAddedSignal(tagType):Connect(function(inst)
		attach(inst, tagType, maps)
	end)
	local removedConn = game.CollectionService:GetInstanceRemovedSignal(tagType):Connect(function(inst)
		disconnectButton(inst)
	end)
	table.insert(PurchaseButtons._connections, addedConn)
	table.insert(PurchaseButtons._connections, removedConn)
end

local function normalizeArgs(arg1, arg2, arg3)
	local maps = { idMap = nil, gamepasses = nil, products = nil }
	if typeof(arg1) == "table" and (arg1.idMap or arg1.gamepasses or arg1.products) then
		maps.idMap = arg1.idMap
		maps.gamepasses = arg1.gamepasses
		maps.products = arg1.products
	elseif typeof(arg1) == "table" and (arg2 == nil and arg3 == nil) then
		maps.idMap = arg1
	else
		maps.gamepasses = arg2
		maps.products = arg3
		maps.idMap = arg1
	end
	return maps
end

function PurchaseButtons.Init(arg1, passMap, productMap)
	for _, c in ipairs(PurchaseButtons._connections) do
		c:Disconnect()
	end
	PurchaseButtons._connections = {}
	for btn, _ in pairs(PurchaseButtons._buttonMap) do
		disconnectButton(btn)
	end

	local maps = normalizeArgs(arg1, passMap, productMap)

	scanAndAttach("Product", maps)
	scanAndAttach("Gamepass", maps)
	connectTagSignals("Product", maps)
	connectTagSignals("Gamepass", maps)

	return {
		Refresh = function(newArg1, newPass, newProd)
			local newMaps = normalizeArgs(newArg1, newPass, newProd)
			for btn, rec in pairs(PurchaseButtons._buttonMap) do
				attach(btn, rec.tagType, newMaps)
			end
			maps = newMaps
		end,
		DisconnectAll = function()
			for _, c in ipairs(PurchaseButtons._connections) do
				c:Disconnect()
			end
			PurchaseButtons._connections = {}
			for btn, _ in pairs(PurchaseButtons._buttonMap) do
				disconnectButton(btn)
			end
		end,
	}
end

return PurchaseButtons
