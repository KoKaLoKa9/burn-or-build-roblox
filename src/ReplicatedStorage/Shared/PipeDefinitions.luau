--!strict

-- Transport the player lays between machine ports, tile by tile. Conveyors carry solid bundles
-- and crates, fluid pipes carry water, gas pipes carry steam, syngas and biogas. A cell holds one
-- tile of any kind. StudsPerSecond is how fast each kind moves its contents. Plain data for Lune.

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
			Carries = "Water from pumps and tanks",
			Ready = true,
			Cost = 8,
			StudsPerSecond = 20,
			Color = { 58, 140, 214 },
			Material = "SmoothPlastic",
			Transparency = 0,
		},
		Gas = {
			DisplayName = "Gas pipe",
			ShortName = "GAS",
			Carries = "Steam from boilers to turbines",
			Ready = true,
			Cost = 8,
			StudsPerSecond = 30,
			Color = { 232, 196, 74 },
			Material = "SmoothPlastic",
			Transparency = 0,
		},
	},
	Diameter = 2.2,
	StudsPerSecond = 8,
	MaxLength = 240,
}
