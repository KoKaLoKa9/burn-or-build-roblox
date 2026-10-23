--!strict

-- Week 6 research. Engineers hired at the cooperative office earn research points; the player
-- picks one project at a time and the points pay for it. Each project unlocks the machines whose
-- MachineDefinitions entry names it in Research. Plain data only (no Roblox types) so Lune can
-- require this file. Costs and rates are balance assumptions, tune in playtests.
return {
	-- One engineer earns a point this often.
	SecondsPerPoint = 15,
	MaxEngineers = 3,
	-- Hiring is cheaper when farmers trust the cooperative: fee = BaseHireFee * (1.5 - trust / 100).
	BaseHireFee = 200,
	-- Each engineer's wage, charged every WageIntervalSeconds while they work.
	WagePerInterval = 5,
	WageIntervalSeconds = 30,

	Order = { "FarmMachines", "Baler", "Market", "Kiln", "Mushroom", "Steam", "Biogas" },
	Projects = {
		FarmMachines = {
			DisplayName = "Farm machines",
			Points = 4,
			Blurb = "Rice transplanter and combine harvester: plant and harvest a paddy on their own.",
		},
		Baler = {
			DisplayName = "Straw baler",
			Points = 4,
			Blurb = "Gathers straw off a paddy into bales, so fields clear without fire.",
		},
		Market = {
			DisplayName = "Market stall",
			Points = 3,
			Blurb = "A small buyer you place at the end of any line. Needed for tier 2 products.",
		},
		Kiln = {
			DisplayName = "Pyrolysis kiln",
			Points = 8,
			Requires = "Market",
			Blurb = "3 shredded straw into 1 biochar sack, a soil improver worth 240 at a market stall.",
		},
		Mushroom = {
			DisplayName = "Mushroom house",
			Points = 8,
			Requires = "Market",
			Blurb = "2 wet straw into 1 basket of straw mushrooms worth 180. No dryer needed.",
		},
		Steam = {
			DisplayName = "Steam power",
			Points = 6,
			Blurb = "Straw boiler and steam turbine: water and dry straw into 50 kW of steam power.",
		},
		Biogas = {
			DisplayName = "Biogas",
			Points = 10,
			Requires = "Steam",
			Blurb = "Cattle shed, anaerobic digester and biogas engine: straw and manure into clean power and fertiliser.",
		},
	},
}
