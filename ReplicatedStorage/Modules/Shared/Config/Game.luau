-- Durations in seconds

local GameConfig = {
	GameLoop = {
		LobbyDuration = 5,
		MapLoadingDuration = 2,

		MinimumPlayers = 1,
		MinimumSpawnDistance = 2,
		SpawnAttempts = 24,

		ActiveMapName = "ActiveMap",
	},
	
	Round = {
		MatchDuration =  3 * 60,
		ResultsDuration = 5,
		
		MinRuleLength = 1,
		MaxRuleLength = 4,
		
		RulesToGuess = 4,
		
		ViolationsToForceRuleChange = 3,
	
		PenaltyTable = {50, 100, 200, 200},
		
		BaseGuessWait = 10,
		GuessReward = 100,
		GuessPenalty = 0,
		
		ActionViewDuration = 2,
	},
}

return GameConfig
