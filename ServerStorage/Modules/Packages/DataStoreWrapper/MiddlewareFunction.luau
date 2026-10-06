local MiddlewareData = require("./MiddlewareData")

local MiddlewareFunction = {}
MiddlewareFunction.__index = MiddlewareFunction

function MiddlewareFunction.new(func : (middlewareData: typeof(MiddlewareData.new())) -> ())
	local self = setmetatable({}, MiddlewareFunction)
	self._function = func
	
	return self
end

function MiddlewareFunction:Call(...)
	self._function(...)
end

function MiddlewareFunction:GetFunction()
	return self._function
end

function MiddlewareFunction:Replace(func)
	self._function = func
end

return MiddlewareFunction
