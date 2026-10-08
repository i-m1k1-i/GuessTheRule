local ServerPackages = game.ServerStorage.Modules.Packages
local PlayerDataService = require(ServerPackages.PlayerDataService)
local DataSchema = PlayerDataService.DataSchema

return {
	DataType = "Table",
	Schema = DataSchema.new({
		FakeCoin = {
			DataType = "Boolean",
			DefaultValue = false,
		},
	}),
}
