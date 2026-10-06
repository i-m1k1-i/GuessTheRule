local Signals = require(script.GoodSignal)

return {
    ProductPurchased = Signals.new(),
	GamepassPurchased = Signals.new(),
	RoomEntered = Signals.new()
}
