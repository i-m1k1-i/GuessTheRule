local module = {}

export type DataFolder = Folder & {
	DeveloperProductReceipts: Folder & {
		ProductId: IntValue,
		CurrencySpent: IntValue,
		GrantedAt: NumberValue,
	},
	MainStats: Folder & {
		Coins: NumberValue,
		Wins: NumberValue,
		AllTimeScore: NumberValue,
		IsAutoLiftEnabled: BoolValue,
		HasFollowed: BoolValue,
		TimePlayed: IntValue,
	},
	ShutdownInfo: & {
		DidLastServerShutdown: BoolValue,
		CharacterCFrame: {
			Position: StringValue,
			Yaw: StringValue,
		},
		CurrentMap: StringValue,		
	}
}

return module
