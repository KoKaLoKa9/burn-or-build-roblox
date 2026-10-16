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
			-- Week 5 replanting. Balance assumptions, tune in playtests.
			Planting = {
				SeedCost = 5, -- credits per row
				-- Soil health (balance pass). Burning straw strips the soil of organic matter and
				-- nitrogen, so each burn drops a paddy one level: rice then grows slower and yields
				-- less grain. Each clean clear (all straw collected) restores one level.
				Soil = {
					{ Name = "Poor", GrowSeconds = 170, GrainCredits = 18 },
					{ Name = "Fair", GrowSeconds = 145, GrainCredits = 24 },
					{ Name = "Good", GrowSeconds = 120, GrainCredits = 30 },
				},
				-- Burned straw lies charred this long before the rows can be replanted.
				BurnClearSeconds = 6,
			},
		},
	},
	-- Week 5: paddy plots the player can buy and farm like their own field. Balance assumptions.
	Plots = {
		Price = 300,
		Rows = 5,
		Width = 50,
		Depth = 40,
		-- Lots on open land between the main road and the factory, near the start. Front is the
		-- side the row ends, sign, and burn spot face (-1 is north, toward the road).
		Lots = {
			{ Name = "Plot 1", X = -120, Z = 106, Front = -1 },
			{ Name = "Plot 2", X = -186, Z = 106, Front = -1 },
			{ Name = "Plot 3", X = -153, Z = 168, Front = -1 },
		},
	},
}

return GameConfig
