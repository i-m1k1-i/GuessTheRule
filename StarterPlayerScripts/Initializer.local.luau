local ModuleLoader = require(game.ReplicatedStorage.Modules.Packages.ModuleLoader)
local Modules = game.ReplicatedStorage.Modules

ModuleLoader.LoadModules(
	{
		Modules.Client,
		Modules.Shared,
	}
)
