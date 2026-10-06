export type MapDefinition = {
	Name: string,
	Weight: number,
}

local Maps = {}

local MAP_DEFINITIONS: {MapDefinition} = {
	{
		Name = "Forest",
		Weight = 1,
	},
}

function Maps.GetDefinitions(): {MapDefinition}
	return table.clone(MAP_DEFINITIONS)
end

function Maps.GetRandomMap(): MapDefinition
	local totalWeight = 0
	for _, mapDefinition in MAP_DEFINITIONS do
		totalWeight += mapDefinition.Weight
	end

	assert(totalWeight > 0, "Maps config must contain at least one map with positive weight")
	local roll = math.random() * totalWeight
	for _, mapDefinition in MAP_DEFINITIONS do
		roll -= mapDefinition.Weight
		if roll <= 0 then
			return mapDefinition
		end
	end

	return MAP_DEFINITIONS[#MAP_DEFINITIONS]
end

return Maps
