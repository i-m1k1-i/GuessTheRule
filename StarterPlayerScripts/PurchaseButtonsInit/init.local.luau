local PurchasableButtons = require(script.PurchaseButtons)
local monetizationIds = require(game.ReplicatedStorage.Modules.Shared.Config.Monetization)

PurchasableButtons.Init(nil, monetizationIds.Gamepasses, monetizationIds.Products)
