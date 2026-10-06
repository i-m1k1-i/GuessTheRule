local ServerPackages = game.ServerStorage.Modules.Packages

local PlayerDataService = require(ServerPackages.PlayerDataService)

local DataSchema = PlayerDataService.DataSchema
local ObjectSchema = PlayerDataService.ObjectSchema

return ObjectSchema.new({
	ProductId = {
		DataType = "Integer",
		DefaultValue = 0
	},
	CurrencySpent = {
		DataType = "Integer",
		DefaultValue = 0
	},
	GrantedAt = {
		DataType = "Number",
		DefaultValue = 0,
	},
})