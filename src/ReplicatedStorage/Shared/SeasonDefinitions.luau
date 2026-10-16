--!strict

-- The season loop: phases (spec v0.2 section 2.3), the one forecast weather event (11.3), and
-- result settings (12.3 to 12.5). Plain data only (no Roblox types) so Lune can require this file
-- and the HUD can read the same text. Values marked "balance assumption" are not fixed by v0.2.
return {
	-- Phase start minutes are written for the 20 minute round in spec 2.3. A shorter or longer
	-- GameConfig.Round.DurationSeconds stretches every phase by the same ratio.
	BaseMinutes = 20,
	Phases = {
		{
			Id = "Harvest",
			Name = "Harvest",
			StartMinute = 0,
			Goal = "Collect your first straw and check the field deadline.",
		},
		{
			Id = "FirstLine",
			Name = "First line",
			StartMinute = 3,
			Goal = "Build a dryer, shredder, and pellet mill. Sell one crate.",
		},
		{
			Id = "Expansion",
			Name = "Expansion",
			StartMinute = 8,
			Goal = "Take on neighboring farm work and grow your capacity.",
		},
		{
			Id = "Stress",
			Name = "Weather stress",
			StartMinute = 14,
			Goal = "Respond to the forecast weather.",
		},
		{
			Id = "Closing",
			Name = "Closing",
			StartMinute = 18,
			Goal = "Finish or settle your remaining commitments.",
		},
	},
	-- Shown after the clock runs out.
	ResultsPhase = {
		Id = "Results",
		Name = "Season results",
		Goal = "Review Profit, Clean Air, and Trust.",
	},

	Weather = {
		-- The forecast appears this long before the event (spec 11.3: early enough to react).
		ForecastLeadSeconds = 120,
		-- Balance assumption: the event starts one minute into the stress phase (minute 15).
		StartAfterStressSeconds = 60,
		EventKinds = { "Rain", "WindShift" },
		Rain = {
			Name = "Rain",
			-- Balance assumption: two and a half minutes of rain.
			DurationSeconds = 150,
			-- Balance assumption: wet straw takes 50 percent longer per dryer cycle while it rains.
			DryerCycleMultiplier = 1.5,
			Forecast = "Rain expected. Dryers will slow down and straw left in fields stays wet. Collect early or add dryer capacity.",
			Active = "Raining. Dryer cycles take 50 percent longer and loose field straw stays wet.",
			Cleared = "The rain has passed. Dryers are back to normal speed.",
		},
		WindShift = {
			Name = "Wind shift",
			-- Balance assumption: the wind turns west and stays there for the rest of the season.
			Label = "West",
			X = -1,
			Z = 0,
			Destination = "Open land",
			Forecast = "Wind shift expected. Smoke will drift west, away from the village. Pollution from any burn still counts.",
			Active = "The wind now blows west. New smoke drifts away from the village, but burns still pollute.",
			Cleared = "The wind stays west for the rest of the season.",
		},
		-- The starting wind matches GameConfig.Wind.
		BaseWind = { Label = "East", Destination = "Village" },
	},

	Results = {
		-- Spec 12.3: cooperative value counts 70 percent of purchased infrastructure.
		InfrastructureCreditRate = 0.7,
		-- A machine that stays Blocked this long is named as the first bottleneck (spec 12.5).
		BottleneckSeconds = 15,
		Disclaimer = "Exposure points are a teaching scale for cause and effect. They are not measured PM2.5 concentrations.",
	},

	SoftEnd = {
		-- Spec 12.5: once every field is settled and no straw is left anywhere, the season
		-- advances to the results after this many seconds. Only from the stress phase onward,
		-- so every player meets the weather event first.
		IdleSeconds = 45,
	},
}
