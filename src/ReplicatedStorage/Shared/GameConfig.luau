--!strict

local GameConfig = {
	Round = {
		DurationSeconds = 20 * 60,
	},
	Player = {
		-- Enough for a dryer and shredder; the pellet mill needs early income (grain), which is
		-- quickest if the opening straw is burned. That is the farmer's dilemma on day one.
		StartingCredits = 600,
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
				-- Planting window: rows planted within this many seconds of the field clearing get
				-- full grain. Later rows lose LateLossPerMinute of their grain per minute, down to
				-- MinYield. A late crop yields less, which is why farmers race to clear fields.
				WindowSeconds = 60,
				LateLossPerMinute = 0.3,
				MinYield = 0.5,
				-- What burning gives: ash adds AshBonus to the next crop only, while a hand-cleared
				-- field has PestChance of stem borers surviving in the stubble (PestLoss off the
				-- next crop). Real reasons farmers give for burning.
				AshBonus = 0.15,
				PestChance = 0.25,
				PestLoss = 0.15,
			},
		},
	},
	-- Burn and smog (Week 6 burn pass). Balance assumptions, tune in playtests.
	Burn = {
		-- Burn ban once smog season starts: burning during these phases costs a fine.
		BanPhases = { Stress = true, Closing = true },
		FineCredits = 300,
		-- Fire spreads to farm machines this close to a burning field and stops them a while.
		ScorchRange = 24,
		ScorchSeconds = 30,
	},
	Smog = {
		-- Every burn adds its burn potential to a district smog meter that slowly clears.
		DecayPerSecond = 0.4,
		Threshold = 15,
		-- While the air is smoggy, sick workers slow every machine and research.
		MachineSlowdown = 1.25,
		ResearchRate = 0.6,
		-- Each time a player's exposure passes another SchoolStep points, the school closes for
		-- a smog day and farmers lose trust in the cooperative.
		SchoolStep = 40,
		SchoolTrustLoss = 3,
		-- Low trust costs money and partners.
		LowTrust = 30,
		LowTrustPrice = 0.85,
		RefuseTrust = 20,
	},
	-- Village life (Week 6 reactions pass). Balance assumptions.
	Village = {
		-- A cattle farmer buys raw straw as feed: small money, but better than burning it.
		CattleFeedPrice = 8,
		-- Village requests: a new one this long after the last ends, each open this long.
		RequestGapSeconds = 45,
		RequestSeconds = 180,
		-- After this many of your own burns, the cooperative lends you a dryer to try the
		-- other way (once per player).
		LoanAfterBurns = 3,
		-- How long the school stays shut on a smog day.
		SchoolClosedSeconds = 90,
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
