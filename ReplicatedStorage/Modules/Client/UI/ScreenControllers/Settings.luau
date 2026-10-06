local Packages = game.ReplicatedStorage.Modules.Packages
local Network = require(Packages.Network)
local UIRefs = require(game.ReplicatedStorage.Modules.Client.UI.UIRefs)

local ExampleScreenController = {}

local _screen = UIRefs.Screens.Shop
local _connections: {RBXScriptConnection} = {}

local function track(connection: RBXScriptConnection)
	table.insert(_connections, connection)
end

local function disconnectAll()
	for _, connection in _connections do
		connection:Disconnect()
	end
	table.clear(_connections)
end

local function refresh(data)

end

function ExampleScreenController.Init()
	_screen:GetPropertyChangedSignal("Enabled"):Connect(function()
		if _screen.Enabled then
			ExampleScreenController.Show()
		else
			ExampleScreenController.Hide()
		end
	end)
end

function ExampleScreenController.Show(data: any?)

end

function ExampleScreenController.Hide()
	disconnectAll()
end


return ExampleScreenController
