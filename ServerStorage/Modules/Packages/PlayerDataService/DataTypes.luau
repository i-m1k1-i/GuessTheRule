return {
	Integer = {
		Type = "number",
		DefaultValue = 0,
		ClassName = "IntValue",
		Validate = function(value)
			if typeof(value) ~= "number" then
				return false, `Expected number, got {typeof(value)}`
			end
			
			local isInfinite = value == math.huge
			local isNan = value ~= value
			local isDecimal = value ~= math.floor(value)

			if isInfinite then
				return false, "Cannot store infinite"
			elseif isNan then
				return false, "Cannot store NaN"
			elseif isDecimal then
				return false, "Cannot store decimal values (only integers)"
			end

			return true
		end,
	},
	Number = {
		Type = "number",
		DefaultValue = 0,
		ClassName = "NumberValue",
		Validate = function(value)
			if typeof(value) ~= "number" then
				return false, `Expected number, got {typeof(value)}`
			end
			
			local isInfinite = value == math.huge
			local isNan = value ~= value
			local isNumber = typeof(value) == "number"

			if isInfinite then
				return false, "Cannot store infinite"
			elseif isNan then
				return false, "Cannot store NaN"
			elseif not isNumber then
				return false, `Expected number, got {typeof(value)}`
			end

			return true
		end,
	},
	String = {
		Type = "string",
		DefaultValue = "",
		ClassName = "StringValue",
		Validate = function(value)
			if typeof(value) ~= "string" then
				return false, `Expected string, got {typeof(value)}`
			end
			return true
		end,
	},
	Boolean = {
		Type = "boolean",
		DefaultValue = false,
		ClassName = "BoolValue",
		Validate = function(value)
			if typeof(value) ~= "boolean" then
				return false, `Expected boolean, got {typeof(value)}`
			end
			return true
		end,
	},
	Table = {
		Type = "table",
		DefaultValue = {},
		ClassName = "Folder",
		Validate = function(value)
			if typeof(value) ~= "table" then
				return false, `Expected table, got {typeof(value)}`
			end
			return true
		end,
	},
}