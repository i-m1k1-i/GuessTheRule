return function (instance: Instance, className: string)
	if not instance then
		error("Instance is nil")
	end
	
	if not className then
		error("className is nil")
	end

	if typeof(instance) ~= "Instance" then
		return false
	end

	return instance:IsA(className)
end
