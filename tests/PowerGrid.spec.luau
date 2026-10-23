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

local function square(id: number, x: number, z: number, half: number, reach: number?)
	return {
		id = id,
		x = x,
		z = z,
		rect = { minX = x - half, maxX = x + half, minZ = z - half, maxZ = z + half },
		reach = reach,
	}
end

-- A machine beside a generator joins its network; a far machine does not.
do
	local networks, edges = PowerGrid.Networks({
		square(1, 0, 0, 2, 16),
		square(2, 20, 0, 8),
		square(3, 80, 0, 8),
	})
	check("near machine joins the generator", networks[2] == networks[1])
	check("far machine stays alone", networks[3] ~= networks[1])
	check("one wire drawn", #edges == 1, tostring(#edges))
end

-- Poles chain power across the floor.
do
	local networks = PowerGrid.Networks({
		square(1, 0, 0, 2, 16),
		square(2, 30, 0, 1, 36),
		square(3, 64, 0, 1, 36),
		square(4, 90, 0, 8),
	})
	check("poles chain a far machine", networks[4] == networks[1])
end

-- Hubs out of each other's reach form two networks.
do
	local networks = PowerGrid.Networks({
		square(1, 0, 0, 2, 16),
		square(2, 100, 0, 2, 16),
	})
	check("separate generators stay separate", networks[1] ~= networks[2])
end

-- A machine wires to its nearest hub only.
do
	local _, edges = PowerGrid.Networks({
		square(1, 0, 0, 1, 36),
		square(2, 10, 0, 1, 36),
		square(3, 14, 0, 2),
	})
	local wiredTo = nil
	for _, edge in edges do
		if edge.b == 3 then
			wiredTo = edge.a
		end
	end
	check("machine wires to the nearest pole", wiredTo == 2, tostring(wiredTo))
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
