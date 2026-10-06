local Schemas = require(script.Parent.Parent.Schemas)

return {
	DataId = {
		DataType = "Integer",
		DefaultValue = 0,
	},
	PlayerName = {
		DataType = "String",
		DefaultValue = ""
	},
	FirstJoinedAt = {
		DataType = "Integer",
		DefaultValue = function()
			return DateTime.now().UnixTimestampMillis
		end,
	},
	LastUpdatedAt = {
		DataType = "Integer",
		DefaultValue = 0
	},
	LeftAt = {
		DataType = "Integer",
		DefaultValue = function()
			return DateTime.now().UnixTimestampMillis
		end,
	},
}
