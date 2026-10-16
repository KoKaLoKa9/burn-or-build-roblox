--!strict

-- Neighboring farm commitments (spec v0.2 section 10) and the simplified truck route (7.4).
-- Plain data only (no Roblox types) so the Lune tests can require this file.
-- Values marked "balance assumption" are not fixed by spec v0.2 and may be tuned.
return {
	-- Balance assumption: one extension adds three minutes and costs a fee (spec 12.3 lists it).
	ExtensionSeconds = 3 * 60,
	ExtensionFee = 50,
	Farms = {
		FarmB = {
			ModelName = "Farm_B",
			DisplayName = "Nearby farm B",
			ShortName = "Farm B",
			Bundles = 12,
			DeadlineSeconds = 10 * 60,
			RouteFee = 50,
			TravelSeconds = 15,
			BurnExposure = 35,
			-- Spec 10.4 trust values.
			CompleteTrust = 10,
			MissTrust = -15,
			RejectTrust = 0,
			-- Balance assumption: spec 10.2 grants a reliability bonus without naming an amount.
			ReliabilityBonus = 100,
		},
		FarmC = {
			ModelName = "Farm_C",
			DisplayName = "Distant farm C",
			ShortName = "Farm C",
			Bundles = 16,
			DeadlineSeconds = 16 * 60,
			RouteFee = 80,
			TravelSeconds = 25,
			BurnExposure = 50,
			CompleteTrust = 10,
			MissTrust = -15,
			RejectTrust = 0,
			ReliabilityBonus = 150,
		},
	},
	FarmOrder = { "FarmB", "FarmC" },
	Truck = {
		Capacity = 8,
		LoadSeconds = 4,
		UnloadSecondsPerBundle = 0.5,
		-- How long a truck waits at an empty or closed farm stop before returning.
		BlockedSeconds = 3,
		-- The terminal must sit within this many studs of a road (spec 7.4 placement rule).
		RoadReach = 20,
	},
	-- Spec 10.3: every burn source record names who was responsible.
	Responsibility = {
		MissedCommitment = "Missed commitment",
		Rejected = "Rejected by the cooperative, no promise broken",
		NoAgreement = "No agreement made",
		PlayerAuthorized = "Early burn authorized by the player",
		PlayerFarmDeadline = "Your field deadline expired",
	},
}
