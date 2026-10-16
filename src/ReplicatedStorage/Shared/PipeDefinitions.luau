--!strict

-- Transport the player lays between machine ports. Conveyors carry solid bundles and crates
-- today, laid tile by tile. Fluid and gas pipes are reserved for the energy layer (water, liquid fuel, steam,
-- biogas) and are refused until a machine with those ports exists. Plain data for Lune tests.

return {
	Order = { "Item", "Fluid", "Gas" },
	Types = {
		Item = {
			DisplayName = "Conveyor",
			ShortName = "BELT",
			-- Credits per 4 stud tile, refunded when the tile is removed.
			Cost = 5,
			Carries = "Straw bundles and pellet crates",
			Ready = true,
			-- A glass tube, so every bundle stays visible on its way (spec 4.5).
			Color = { 170, 220, 212 },
			Material = "Glass",
			Transparency = 0.38,
		},
		Fluid = {
			DisplayName = "Fluid pipe",
			ShortName = "FLUID",
			Carries = "Water and liquid fuel, for the energy update",
			Ready = false,
			Color = { 58, 140, 214 },
			Material = "SmoothPlastic",
			Transparency = 0,
		},
		Gas = {
			DisplayName = "Gas pipe",
			ShortName = "GAS",
			Carries = "Steam and biogas, for the energy update",
			Ready = false,
			Color = { 232, 196, 74 },
			Material = "SmoothPlastic",
			Transparency = 0,
		},
	},
	Diameter = 2.2,
	StudsPerSecond = 8,
	MaxLength = 240,
}
