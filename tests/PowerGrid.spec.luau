--!strict

-- Run from the project root with: lune run tests/PowerGrid.spec.luau

local PowerGrid = require("../src/ReplicatedStorage/Shared/PowerGrid")

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

local Key = PowerGrid.Key

-- Wires: a generator and a machine on the same coil share a network; a wire to the other coil does
-- not join them, because a pole's two coils are separate junctions.
do
	local generator, machine, other, pole = { id = 1 }, { id = 2 }, { id = 3 }, 9
	local coil1, coil2 = { id = pole, coil = 1 }, { id = pole, coil = 2 }
	local keys = { Key(generator), Key(machine), Key(other), Key(coil1), Key(coil2) }
	local networks = PowerGrid.Networks(keys, {
		{ Key(coil1), Key(generator) },
		{ Key(coil1), Key(machine) },
		{ Key(coil2), Key(other) },
	})
	check("same coil shares a network", networks[Key(generator)] == networks[Key(machine)])
	check("the other coil is separate", networks[Key(other)] ~= networks[Key(generator)])
	check("an unwired machine is alone", PowerGrid.Networks({ "m5" }, {})["m5"] == "m5")
end

-- Pole to pole wires carry power across the floor.
do
	local keys = { "m1", "m2", "p7:1", "p8:1" }
	local networks =
		PowerGrid.Networks(keys, { { "m1", "p7:1" }, { "p7:1", "p8:1" }, { "p8:1", "m2" } })
	check("poles chain a far machine", networks.m2 == networks.m1)
	check("network name is stable", networks.m1 == "m1")
end

-- Wires to ends that no longer exist are ignored.
do
	local networks = PowerGrid.Networks({ "m1" }, { { "m1", "p4:1" } })
	check("a dangling wire is ignored", networks.m1 == "m1")
end

-- What may be wired.
do
	local pole, machine = { id = 9, coil = 1 }, { id = 2 }
	check(
		"coil to machine in reach",
		PowerGrid.WireProblem(pole, machine, true, false, 20, 40) == nil
	)
	check(
		"machine to machine refused",
		PowerGrid.WireProblem({ id = 1 }, machine, false, false, 5, 40) ~= nil
	)
	check("too long refused", PowerGrid.WireProblem(pole, machine, true, false, 50, 40) ~= nil)
	check("same end refused", PowerGrid.WireProblem(pole, pole, true, true, 0, 40) ~= nil)
	check(
		"coil to coil of the same pole allowed",
		PowerGrid.WireProblem(pole, { id = 9, coil = 2 }, true, true, 4, 40) == nil
	)
end

-- Enough supply runs everything at full speed.
do
	local balance = PowerGrid.Balance(20, 10, {}, 1)
	check("surplus gives full ratio", balance.ratio == 1)
end

-- A shortfall slows machines in proportion.
do
	local balance = PowerGrid.Balance(5, 20, {}, 1)
	check(
		"shortfall gives a quarter",
		math.abs(balance.ratio - 0.25) < 1e-9,
		tostring(balance.ratio)
	)
end

-- No demand is never a brownout.
do
	check("no demand ratio 1", PowerGrid.Balance(0, 0, {}, 1).ratio == 1)
end

-- Batteries charge from surplus, limited by rate and room.
do
	local battery = { charge = 0, capacity = 100, rate = 10 }
	local balance = PowerGrid.Balance(30, 10, { battery }, 2)
	check("battery charges at its rate", battery.charge == 20, tostring(battery.charge))
	check("flow reported", balance.batteryFlow == 10)
	check("machines still at full speed", balance.ratio == 1)
	local full = { charge = 95, capacity = 100, rate = 10 }
	PowerGrid.Balance(30, 10, { full }, 1)
	check("battery stops at capacity", full.charge == 100, tostring(full.charge))
end

-- Batteries cover a shortfall until they run dry.
do
	local battery = { charge = 50, capacity = 100, rate = 20 }
	local balance = PowerGrid.Balance(0, 10, { battery }, 1)
	check("battery covers the whole demand", balance.ratio == 1)
	check("battery drained by demand", battery.charge == 40, tostring(battery.charge))
	local weak = { charge = 50, capacity = 100, rate = 4 }
	local partial = PowerGrid.Balance(0, 10, { weak }, 1)
	check("battery rate limits help", math.abs(partial.ratio - 0.4) < 1e-9, tostring(partial.ratio))
	local empty = { charge = 0, capacity = 100, rate = 20 }
	check("empty battery cannot help", PowerGrid.Balance(0, 10, { empty }, 1).ratio == 0)
end

print(string.format("\n%d passed, %d failed", passes, failures))
if failures > 0 then
	error("PowerGrid tests failed")
end
