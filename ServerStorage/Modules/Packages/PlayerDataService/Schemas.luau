local DataTypes = require(script.Parent.DataTypes)

export type SchemaObject = {
	DataType: "String" | "Number" | "Table" | "Boolean" | "Integer",
	Schema: Schema?,
	DefaultValue: (string | number | boolean)?,
	Save: boolean?,
	ServerOnly: boolean?,
}

export type Schema = {
	[string]: SchemaObject
}

local DataSchema = {}
local ObjectSchema = {}

local function processSchema(schema, path)
	if schema._processed then
		return
	end
	
	for dataName, schemaDataInfo : SchemaObject in schema:GetSchema() do
		if typeof(dataName) ~= "string" then
			error(`Expected schema data name "{dataName}" to be a string, got {typeof(dataName)}`)
		end
		if typeof(schemaDataInfo) ~= "table" then
			error(`Expected schema data "{dataName}" to be a table, got {typeof(schemaDataInfo)}`)
		end

		local dataTypeInfo = DataTypes[schemaDataInfo.DataType]
		if not dataTypeInfo then
			error(`{schemaDataInfo.DataType} is not a valid datatype for {dataName}`)
		end

		if schemaDataInfo.DataType == "Table" and schemaDataInfo.ServerOnly == true then
			error(`Cannot set {dataName} server only to true because it is a Table`)
		end

		schemaDataInfo.Path = `{path}/{dataName}`
		
		if schemaDataInfo.DataType == "Table" then
			if schemaDataInfo.Schema:GetType() == "ObjectSchema" and schemaDataInfo.ServerOnly then
				error(`Cannot have a object schema of server only values. Make sure that server only values are not placed within ObjectSchemas. Path: {schemaDataInfo.Path}`)
			end
		end

		if dataTypeInfo.Type == "table" then
			processSchema(schemaDataInfo.Schema, schemaDataInfo.Path)
		else
			if typeof(schemaDataInfo.DefaultValue) == "function" then
				local success, message = dataTypeInfo.Validate(schemaDataInfo.DefaultValue())
				if not success then
					error(`Schema default value validation failed for "{dataName}": {message}`)
				end
			else
				local success, message = dataTypeInfo.Validate(schemaDataInfo.DefaultValue)
				if not success then
					error(`Schema default value validation failed for "{dataName}": {message}`)
				end
			end
		end
	end
	
	schema._processed = true
end

DataSchema.__index = DataSchema

function DataSchema.new(schema : Schema)
	local self = setmetatable({}, DataSchema)
	self._type = "DataSchema"
	self._schema = schema
	
	return self
end

function DataSchema.Combine(...)
	local newSchema = {}
	for _, schema in {...} do
		for k, v in schema:GetSchema() do
			newSchema[k] = v
		end
	end
	
	return DataSchema.new(newSchema)
end

function DataSchema:GetType()
	return self._type
end

function DataSchema:GetSchema()
	return self._schema
end

function DataSchema:Process()
	processSchema(self)
end

ObjectSchema.__index = ObjectSchema

function ObjectSchema.new(schema : Schema)
	local self = setmetatable({}, ObjectSchema)
	self._type = "ObjectSchema"
	self._schema = schema
	self._processed = false
	
	processSchema(self, "")

	return self
end

function ObjectSchema.Combine(...)
	local newSchema = {}
	for _, schema in {...} do
		for k, v in schema:GetSchema() do
			newSchema[k] = v
		end
	end

	return ObjectSchema.new(newSchema)
end

function ObjectSchema:GetType()
	return self._type
end

function ObjectSchema:GetSchema()
	return self._schema
end

function ObjectSchema:CreateInstance(dataObjectName)
	if not self._processed then
		error("Object schema is not processed yet, cannot create instance")
	end
	assert(typeof(dataObjectName) == "string", "Expected string data object name")

	local function createDataInstances(dataObjectName)
		local folder = Instance.new("Folder")
		folder.Name = dataObjectName

		for childDataName, childSchemaDataInfo in self._schema do
			local dataTypeInfo = DataTypes[childSchemaDataInfo.DataType]
			if childSchemaDataInfo.DataType == "Table" then
				local childFolder = createDataInstances(childDataName)
				childFolder.Parent = folder
			else
				local defaultValue
				if typeof(childSchemaDataInfo.DefaultValue) == "function" then
					defaultValue = childSchemaDataInfo.DefaultValue()
				elseif childSchemaDataInfo.DefaultValue ~= nil then
					defaultValue = childSchemaDataInfo.DefaultValue
				elseif typeof(dataTypeInfo.DefaultValue) == "function" then
					defaultValue = dataTypeInfo.DefaultValue()
				else
					defaultValue = dataTypeInfo.DefaultValue
				end

				local dataInstance = Instance.new(dataTypeInfo.ClassName)
				dataInstance.Name = childDataName
				dataInstance.Value = defaultValue
				dataInstance.Parent = folder
			end
		end

		return folder
	end

	local dataFolder = createDataInstances(dataObjectName)
	return dataFolder
end


return {
	DataSchema = DataSchema,
	ObjectSchema = ObjectSchema
}


