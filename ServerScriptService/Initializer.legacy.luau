local ModuleLoader = require(game.ReplicatedStorage.Modules.Packages.ModuleLoader)

ModuleLoader.LoadModules(
	{
		game.ReplicatedStorage.Modules.Shared,
		game.ServerStorage.Modules,
	}, 
	{
		game.ServerStorage.Modules.Services.PlayerDataBootstrap
	}
)
