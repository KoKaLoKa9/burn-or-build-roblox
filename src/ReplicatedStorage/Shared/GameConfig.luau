--!strict

local GameConfig = {
	Round = {
		DurationSeconds = 20 * 60,
	},
	Player = {
		StartingCredits = 1_000,
		StartingTrust = 50,
	},
	Wind = {
		Direction = Vector3.new(1, 0, 0),
		Label = "East",
		PlumeDistance = 390,
		PlumeTravelSeconds = 12,
	},
	Fields = {
		FarmA = {
			ModelName = "Farm_A",
			DisplayName = "Your rice field",
			Bundles = 8,
			DeadlineSeconds = 4 * 60,
			BurnExposure = 20,
			BurnTrustLoss = 5,
			NextCropValue = 300,
		},
	},
}

return GameConfig
