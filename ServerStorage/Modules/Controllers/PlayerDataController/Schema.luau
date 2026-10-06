local ServerPackages = game.ServerStorage.Modules.Packages

local PlayerDataService = require(ServerPackages.PlayerDataService)

local DataSchema = PlayerDataService.DataSchema
local ObjectSchema = PlayerDataService.ObjectSchema

local objectSchemas = script.Parent.ObjectSchemas

return DataSchema.new({
	DeveloperProductReceipts = {
		DataType = "Table",
		Schema = require(objectSchemas.DeveloperProductReceipt)
	},
	MainStats = {
		DataType = "Table",
		Schema = DataSchema.new({
			Coins = {
				DataType = "Number",
				DefaultValue = 0,
			},
			Wins = {
				DataType = "Integer",
				DefaultValue = 0
			},
			AllTimeScore = {
				DataType = "Integer",
				DefaultValue = 0
			},
			IsAutoLiftEnabled = {
				DataType = "Boolean",
				DefaultValue = true,
				Save = false
			},
			HasFollowed = {
				DataType = "Boolean",
				DefaultValue = false,
			},
			TimePlayed = {
				DataType = "Integer",
				DefaultValue = 0
			},
		})
	},
	ShutdownInfo = {
		DataType = "Table",
		Schema = DataSchema.new({
			DidLastServerShutdown = {
				DataType = "Boolean",
				DefaultValue = false
			},
			CharacterCFrame = {
				DataType = "Table",
				Schema = DataSchema.new({
					Position = {
						DataType = "String",
						DefaultValue = "0 0 0"
					},
					Yaw = {
						DataType = "Number",
						DefaultValue = 0
					},
				})
			},
			CurrentMap = {
				DataType = "String",
				DefaultValue = ""
			},
		})
	}
})