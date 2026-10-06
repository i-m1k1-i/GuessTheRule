local RunService = game:GetService("RunService")
local Packages = game.ReplicatedStorage.Modules.Packages

local Promise = require(Packages.Promise)
local GoodSignal = require(Packages.Signals.GoodSignal)

local ModuleLoader = {}
ModuleLoader._clientsLoaded = {}
ModuleLoader._onClientLoaded = GoodSignal.new()
ModuleLoader._loadingProgress = 0
ModuleLoader._hasCalledLoadModules = false
ModuleLoader._isLoaded = false
ModuleLoader.Loaded = GoodSignal.new()
ModuleLoader.LoadingProgressChanged = GoodSignal.new()
ModuleLoader._loadingStates = {}

function ModuleLoader.IsLoaded()
	return ModuleLoader._isLoaded
end

function ModuleLoader.GetLoadingProgress()
	return ModuleLoader._loadingProgress
end

function ModuleLoader.GetLoadingStateText()
	if RunService:IsServer() then
		return
	end

	if ModuleLoader.GetLoadingProgress() == 1 then
		return "Done"
	end

	local highestPriorityState
	for stateName, stateInfo in ModuleLoader._loadingStates do
		if
			highestPriorityState == nil
			or stateInfo.Priority > ModuleLoader._loadingStates[highestPriorityState].Priority
		then
			highestPriorityState = stateName
		end
	end

	if not highestPriorityState then
		return "Loading"
	end

	return ModuleLoader._loadingStates[highestPriorityState].DisplayText
end

function ModuleLoader.SetLoadingState(stateName, displayText, priority)
	if RunService:IsServer() then
		return
	end

	if ModuleLoader._isLoaded then
		return
	end

	if typeof(stateName) ~= "string" then
		error(`Expected state name to be a string, got {typeof(stateName)}`)
	end

	if typeof(displayText) ~= "string" then
		error(`Expected display text to be a string, got {typeof(displayText)}`)
	end

	if priority == nil then
		priority = 0
	elseif typeof(priority) ~= "number" then
		error(`Expected priority to be a number, got {typeof(priority)}`)
	end

	ModuleLoader._loadingStates[stateName] = {
		DisplayText = displayText,
		Priority = priority,
	}
	ModuleLoader.LoadingProgressChanged:Fire()
end

function ModuleLoader.RemoveLoadingState(stateName)
	if RunService:IsServer() then
		return
	end

	ModuleLoader._loadingStates[stateName] = nil
	ModuleLoader.LoadingProgressChanged:Fire()
end

function ModuleLoader.LoadModules(
	listOfModulesFolders: {Folder | ModuleScript},
	priorityModulesFolders: {Folder | ModuleScript}?
)
	if ModuleLoader._hasCalledLoadModules then
		error(`You cannot call ModuleLoader:LoadModules() multiple times in the same context`)
	end
	ModuleLoader._hasCalledLoadModules = true

	task.spawn(function()
		local startTime = os.clock()
		local modulesCount = 0
		local successCount = 0
		
		local success, message = pcall(function()
			if RunService:IsClient() then
				ModuleLoader.SetLoadingState("ModuleLoader.WaitingGameLoad", "Waiting for game to load", -1)

				if not game:IsLoaded() then
					game.Loaded:Wait()
				end

				ModuleLoader.RemoveLoadingState("ModuleLoader.WaitingGameLoad")
			end

			local modulesToLoad = {}
			local priorityModules = {}

			local function collectModules(listOfFolders, targetModules)
				local function handleModule(module: ModuleScript)
					local moduleName = module.Name
					local disabled = string.find(moduleName, "xx")
					if disabled then
						return
					end
					if not modulesToLoad[module] then
						modulesCount += 1
						modulesToLoad[module] = {}
					end
					targetModules[module] = true
				end
				for _, modulesFolder in listOfFolders do
					if modulesFolder:IsA("ModuleScript") then
						handleModule(modulesFolder)
					end
					for _, module in modulesFolder:GetDescendants() do
						if module:IsA("ModuleScript") then
							handleModule(module)
						end
					end
				end
			end

			if priorityModulesFolders then
				collectModules(priorityModulesFolders, priorityModules)
			end
			collectModules(listOfModulesFolders, {})

			local function loadModules()
				local moduleLoadPromises = {}

				local function loadModule(module: Instance | number | string)					
					table.insert(
						moduleLoadPromises,
						Promise.new(function(resolve, reject)
							local startTime = os.clock()
							local success, result = pcall(function()
								return require(module)
							end)
							
							if success then
								if typeof(result) == "table" and typeof(rawget(result, "Init")) == "function" then
									local initSuccess, initErr = pcall(result.Init, result)
									if not initSuccess then
										modulesToLoad[module] = {
											ErrorMessage = `Init failed: {initErr}`,
										}
										resolve()
										return
									end
								end

								local deltaTime = math.floor((os.clock() - startTime) * 1000)
								if false and RunService:IsStudio() and RunService:IsServer() then
									print(`Successfully loaded "{module.Name}" in {deltaTime}ms`)
								end
								successCount += 1
								modulesToLoad[module] = nil
								ModuleLoader._loadingProgress = successCount/modulesCount
								ModuleLoader.LoadingProgressChanged:Fire()
							else
								modulesToLoad[module] = {
									ErrorMessage = result,
								}
							end
							resolve()
						end)
					)
				end

				local function loadModuleGroup(moduleGroup)
					for module in moduleGroup do
						loadModule(module)
					end
					Promise.allSettled(moduleLoadPromises):await()
					table.clear(moduleLoadPromises)
				end

				local regularModules = {}
				for module in modulesToLoad do
					if not priorityModules[module] then
						regularModules[module] = true
					end
				end

				local warnThread = task.delay(10, function()
					local warnMessage = `The following {modulesCount - successCount} modules failed to load within 10 seconds, could yield indefinitely:\n`
					for module, moduleInfo in modulesToLoad do
						warnMessage ..= `\n{module:GetFullName()}`
					end

					warn(warnMessage)
				end)

				loadModuleGroup(priorityModules)
				loadModuleGroup(regularModules)
				task.cancel(warnThread)

				if successCount < modulesCount then
					local errorMessage =  `The following {modulesCount - successCount} modules failed to load:\n`
					for module, moduleInfo in modulesToLoad do
						errorMessage ..= `\n{module:GetFullName()}: {moduleInfo.ErrorMessage}`
					end

					error(errorMessage)
				end
			end

			ModuleLoader.SetLoadingState("ModuleLoader.Loading", "Loading", -1)
			loadModules()
		end)
		
		if not success then
			warn(message)
		end
		
		ModuleLoader._isLoaded = true
		if RunService:IsClient() then
			script.OnClientLoaded:FireServer()
		end
		ModuleLoader.RemoveLoadingState("ModuleLoader.Loading")
		ModuleLoader.Loaded:Fire(success, message)
		
		local deltaTime = math.floor((os.clock() - startTime) * 1000)

		if RunService:IsServer() then
			print(`SERVER: Successfully loaded {modulesCount} modules in {deltaTime}ms`)
		else
			print(`CLIENT: Successfully loaded {modulesCount} modules in {deltaTime}ms`)
		end
	end)
end

local waitingThreads = {}

function ModuleLoader.WaitForClientLoaded(player : Player)
	if RunService:IsClient() then
		error(`Cannot use ModuleLoader:WaitForClientLoaded on client. Use ModuleLoader.Loaded instead`)
	end
	
	if ModuleLoader._clientsLoaded[player.UserId] then
		return
	end
	
	if not player.Parent then
		error(`Player {player.Name} ({player.UserId}) does not exist`)
	end
	
	if not waitingThreads[player.UserId] then
		waitingThreads[player.UserId] = {}
	end
	table.insert(waitingThreads[player.UserId], coroutine.running())
	
	local success, message = coroutine.yield()
	if not success then
		error(message)
	end
end

if RunService:IsServer() then
	script.OnClientLoaded.OnServerEvent:Connect(function(player)
		ModuleLoader._clientsLoaded[player.UserId] = true
		ModuleLoader._onClientLoaded:Fire()
	end)
		
	local function onPlayerAdded(player : Player)
		if ModuleLoader._clientsLoaded[player.UserId] then
			return
		end

		local runningThread = coroutine.running()
		local connections = {}

		table.insert(connections, ModuleLoader._onClientLoaded:Connect(function()
			if ModuleLoader._clientsLoaded[player.UserId] and runningThread then
				task.spawn(runningThread, true)
			end
		end))

		table.insert(connections, player.AncestryChanged:Connect(function()
			if player.Parent == nil and runningThread then
				task.spawn(runningThread, false, `Player {player.Name} ({player.UserId}) left the game before client loaded modules`)
			end
		end))

		local success, message = coroutine.yield()
		for _, connection in connections do
			connection:Disconnect()
		end
		runningThread = nil
		
		if not player.Parent then
			return
		end
		
		if waitingThreads[player.UserId] then
			for _, thread in waitingThreads[player.UserId] do
				task.spawn(thread, success, message)
			end
		end
	end
	
	game.Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in game.Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	
	game.Players.PlayerRemoving:Connect(function(player)
		ModuleLoader._clientsLoaded[player.UserId] = nil
		waitingThreads[player.UserId] = nil
	end)
end

return ModuleLoader