--!strict

-- Run from the project root with: lune run tests/FarmMachines.spec.luau
-- Covers the farm machine definitions and the rule that they stand beside a paddy the player
-- may farm. Positions are plain tables because Lune has no Vector3; the rules only read X and Z.

local MachineDefinitions = require("../src/ReplicatedStorage/Shared/MachineDefinitions")
local PlacementRules = require("../src/ReplicatedStorage/Shared/PlacementRules")
local ProductionLine = require("../src/ServerScriptService/Simulation/ProductionLine")

local failures = 0
local passes = 0

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passes += 1
		print("PASS  " .. name)
	else
		failures += 1
		print("FAIL  " .. name .. (if detail then "  (" .. detail .. ")" else ""))
	end
end

local function at(x: number, z: number): any
	return { X = x, Y = 0, Z = z }
end

-- A 50 x 40 paddy centred on the origin, with a sign in front of it at z = -26.
local function paddy(usable: boolean, offsetX: number?): PlacementRules.PaddySite
	local x = offsetX or 0
	return {
		rect = { minX = x - 25, maxX = x + 25, minZ = -20, maxZ = 20 },
		fixtures = { { minX = x - 20, maxX = x - 19, minZ = -26.4, maxZ = -25.6 } },
		usable = usable,
		groundY = 0,
	}
end

-- Far away from both test paddies, so the factory plot check would fail for factory machines.
local FACTORY_PLOT = { minX = 1000, maxX = 1100, minZ = 1000, maxZ = 1100 }

-- Definitions.
do
	for _, id in { "Transplanter", "Combine" } do
		local definition = MachineDefinitions[id]
		check(id .. " is defined", definition ~= nil)
		check(
			id .. " is a placeable farm machine",
			definition.Placeable == true
				and definition.Kind == "Farm"
				and definition.NoPorts == true
		)
		check(id .. " stands beside a paddy", definition.PlaceNear == "Paddy")
		check(id .. " works at a steady pace", definition.WorkSeconds > 0)
		check(id .. " costs credits", definition.Cost > 0)
	end
	check("transplanter plants", MachineDefinitions.Transplanter.FarmAction == "Plant")
	check("combine harvests", MachineDefinitions.Combine.FarmAction == "Harvest")
end

-- Paddy placement.
do
	local definition = MachineDefinitions.Transplanter
	local reach = definition.PaddyReach
	local sites = { paddy(true) }

	-- 10 wide, so a centre at x = 31 leaves a 1 stud gap east of the paddy.
	local beside = PlacementRules.RectAt(definition, at(31, 0), 0)
	local index = PlacementRules.PaddyFor(beside, sites, reach)
	check("a machine beside the paddy finds it", index == 1)

	local onField = PlacementRules.RectAt(definition, at(20, 0), 0)
	local none, reason = PlacementRules.PaddyFor(onField, sites, reach)
	check(
		"a machine on the paddy is refused",
		none == nil and string.find(reason, "not on it") ~= nil
	)

	local far = PlacementRules.RectAt(definition, at(60, 0), 0)
	none, reason = PlacementRules.PaddyFor(far, sites, reach)
	check(
		"a machine out of reach is refused",
		none == nil and string.find(reason, "beside a paddy") ~= nil,
		reason
	)

	local onSign = PlacementRules.RectAt(definition, at(-19, -27), 0)
	none, reason = PlacementRules.PaddyFor(onSign, sites, reach)
	check(
		"a machine on the paddy sign is refused",
		none == nil and string.find(reason, "blocks") ~= nil
	)

	none, reason = PlacementRules.PaddyFor(beside, { paddy(false) }, reach)
	check(
		"another player's paddy is refused",
		none == nil and string.find(reason, "another player") ~= nil
	)

	-- Between two paddies, the closer one wins even if it is listed second.
	local between = PlacementRules.RectAt(definition, at(34, 0), 0)
	index = PlacementRules.PaddyFor(between, { paddy(true, 0), paddy(true, 66) }, reach)
	check("the closest paddy is chosen", index == 2, tostring(index))
end

-- Full validation.
do
	local definition = MachineDefinitions.Combine
	local ok, reason = PlacementRules.Validate(
		definition,
		at(33, 0),
		0,
		FACTORY_PLOT,
		{},
		1000,
		{ paddies = { paddy(true) } }
	)
	check("a combine beside a paddy needs no factory plot", ok, reason)

	ok, reason = PlacementRules.Validate(definition, at(33, 0), 0, FACTORY_PLOT, {}, 1000, {})
	check("a combine with no paddy nearby is refused", not ok, reason)

	ok, reason = PlacementRules.Validate(
		definition,
		at(33, 0),
		0,
		FACTORY_PLOT,
		{},
		definition.Cost - 1,
		{ paddies = { paddy(true) } }
	)
	check("a combine still costs credits", not ok and string.find(reason, "credits") ~= nil)

	ok = PlacementRules.Validate(
		definition,
		at(33, 0),
		0,
		FACTORY_PLOT,
		{ { minX = 30, maxX = 36, minZ = -2, maxZ = 2 } },
		1000,
		{ paddies = { paddy(true) } }
	)
	check("a combine cannot overlap another machine", not ok)

	ok = PlacementRules.Validate(
		MachineDefinitions.Dryer,
		at(33, 0),
		0,
		FACTORY_PLOT,
		{},
		1000,
		{ paddies = { paddy(true) } }
	)
	check("factory machines still stay on the factory plot", not ok)
end

-- Farm machines sit in the production line without ports and can be dismantled.
do
	local line = ProductionLine.new(MachineDefinitions)
	local transplanter = line:AddNode("Transplanter", "player")
	local combine = line:AddNode("Combine", "player")
	line:Step(2)
	check("farm machines step without items", line:CountItems() == 0)
	check("farm machines are empty", line:IsEmpty(transplanter) and line:IsEmpty(combine))
	local ok = line:RemoveNode(combine.id)
	check("a farm machine can be dismantled", ok)
end

print(string.format("\n%d passed, %d failed", passes, failures))
if failures > 0 then
	error("FarmMachines tests failed")
end
