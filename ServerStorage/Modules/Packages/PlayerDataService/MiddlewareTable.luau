local ServerPackages = game.ServerStorage.Modules.Packages

local DataStoreWrapper = require(ServerPackages.DataStoreWrapper)

local MiddlewareFunction = DataStoreWrapper.MiddlewareFunction

local MiddlewareTable = {}
MiddlewareTable.__index = MiddlewareTable

function MiddlewareTable._oneOffMiddlewareIndexGetter(data)
	if not data or not data._metadata or not data._metadata.OneOffMiddlewareIndex then
		return
	end

	return data._metadata.OneOffMiddlewareIndex
end

function MiddlewareTable._oneOffmiddlewareIndexSetter(data, index)
	if typeof(data) ~= "table" then
		data = {}
	end

	if not data._metadata then
		data._metadata = {}
	end

	data._metadata.OneOffMiddlewareIndex = index
	return data
end

function MiddlewareTable.new()
	local self = setmetatable({}, MiddlewareTable)
	self._middleware = {}
	self._isUsingOneOffMiddleware = false

	return self
end

function MiddlewareTable:IsUsingOneOffMiddleware()
	return self._isUsingOneOffMiddleware
end

function MiddlewareTable:AddFunction(func)
	table.insert(self._middleware, func)
end

function MiddlewareTable:AddMiddlewareFolder(middlewareFolder)
	if typeof(middlewareFolder) ~= "Instance" then
		error(typeof(middlewareFolder) == "Instance", "Expected MiddlewareFolder to be a Folder")
	end	
	local largestIndex = 0
	local folderMiddleware = {}
	for _, module in middlewareFolder:GetChildren() do
		if not module:IsA("ModuleScript") then
			continue
		end

		local middlewareIndex = tonumber(module.Name)
		local middlewareFunction = require(module)

		assert(
			typeof(middlewareIndex) == "number"
				and math.floor(middlewareIndex) == middlewareIndex
				and middlewareIndex >= 1,
			"Expected middleware module names to be positive integers"
		)
		assert(typeof(middlewareFunction) == "table", "Expected middleware module to return a middleware function object")
		largestIndex = math.max(middlewareIndex, largestIndex)

		folderMiddleware[middlewareIndex] = middlewareFunction
	end

	if #folderMiddleware ~= largestIndex then
		error(`Middleware folder does not consist of sequentially named modules`)
	end
	
	for _, middlewareFunction in folderMiddleware do
		table.insert(self._middleware, middlewareFunction)
	end

	return self
end

function MiddlewareTable:AddOneOffMiddlewareFolder(middlewareFolder)
	if typeof(middlewareFolder) ~= "Instance" then
		error(typeof(middlewareFolder) == "Instance", "Expected MiddlewareFolder to be a Folder")
	end
	if self._isUsingOneOffMiddleware then
		error(`You have already added a one off middleware folder`)
	end
	
	local largestIndex = 0
	local folderMiddleware = {}
	for _, module in middlewareFolder:GetChildren() do
		if not module:IsA("ModuleScript") then
			continue
		end

		local middlewareIndex = tonumber(module.Name)
		local middlewareFunction = require(module)

		assert(
			typeof(middlewareIndex) == "number"
				and math.floor(middlewareIndex) == middlewareIndex
				and middlewareIndex >= 1,
			"Expected middleware module names to be positive integers"
		)
		assert(typeof(middlewareFunction) == "table", "Expected middleware module to return a middleware function object")
		largestIndex = math.max(middlewareIndex, largestIndex)
		
		local func = middlewareFunction:GetFunction()

		middlewareFunction:Replace(function(middlewareData)
			local data = middlewareData:GetData()

			local dataMiddlewareIndex = MiddlewareTable._oneOffMiddlewareIndexGetter(data)
			if dataMiddlewareIndex == middlewareIndex then
				return
			end

			func(middlewareData)
			local data = MiddlewareTable._oneOffmiddlewareIndexSetter(
				middlewareData:GetData(),
				middlewareIndex
			)
			
			middlewareData:SetData(data)
		end)

		folderMiddleware[middlewareIndex] = middlewareFunction
	end

	if #folderMiddleware ~= largestIndex then
		error(`Middleware folder does not consist of sequentially named modules`)
	end
	
	-- make sure middle player middleware index is not more than number of modules, if it is, then set it to the highest module number
	table.insert(
		self._middleware,
		MiddlewareFunction.new(function(middlewareData)
			local data = middlewareData:GetData()
			local dataMiddlewareIndex = MiddlewareTable._oneOffMiddlewareIndexGetter(data)
			if not dataMiddlewareIndex then
				MiddlewareTable._oneOffmiddlewareIndexSetter(data, #folderMiddleware)
				dataMiddlewareIndex = #folderMiddleware
			end
			
			if dataMiddlewareIndex > #folderMiddleware then
				MiddlewareTable._oneOffmiddlewareIndexSetter(data, #folderMiddleware)
			end
			
			middlewareData:SetData(data)
		end)
	)
	
	for _, middlewareFunction in folderMiddleware do
		table.insert(self._middleware, middlewareFunction)
	end
	
	self._isUsingOneOffMiddleware = true
	return self
end

function MiddlewareTable:ToTable()
	return self._middleware
end

return MiddlewareTable