--!strict

-- Run from the project root with: lune run tests/ConveyorGrid.spec.luau

local ConveyorGrid = require("../src/ReplicatedStorage/Shared/ConveyorGrid")

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

local function lay(tiles, ix, iz, dir)
	tiles[ConveyorGrid.Key(ix, iz)] = { ix = ix, iz = iz, dir = dir }
end

-- Cells snap to 4 stud centres.
do
	local ix, iz = ConveyorGrid.CellOf(-51, 92)
	check("cell of a point", ix == -13 and iz == 23, ix .. "," .. iz)
	local x, z = ConveyorGrid.Center(ix, iz)
	check("cell centre", x == -52 and z == 92)
	check("direction east", ConveyorGrid.DirectionOf(3, 1) == 0)
	check("direction north", ConveyorGrid.DirectionOf(0.5, -4) == 1)
	check("neighbour direction", ConveyorGrid.DirectionBetween(0, 0, 0, 1) == 3)
	check("not a neighbour", ConveyorGrid.DirectionBetween(0, 0, 2, 0) == nil)
end

-- A straight belt from an output to an input pointing into the machine connects.
do
	local tiles = {}
	for ix = 1, 4 do
		lay(tiles, ix, 0, 0)
	end
	local inputs =
		{ [ConveyorGrid.Key(4, 0)] = { key = ConveyorGrid.Key(4, 0), inward = 0, id = "dryer" } }
	local chain = ConveyorGrid.Trace(tiles, ConveyorGrid.Key(1, 0), inputs, "intake")
	check("straight belt reaches the input", chain.toId == "dryer")
	check("chain lists every tile", #chain.cells == 4, tostring(#chain.cells))
end

-- An L-shaped belt with a turn connects, and a tile pointing the wrong way at the end does not.
do
	local tiles = {}
	lay(tiles, 0, 0, 0)
	lay(tiles, 1, 0, 0)
	lay(tiles, 2, 0, 3)
	lay(tiles, 2, 1, 3)
	local inputs =
		{ [ConveyorGrid.Key(2, 1)] = { key = ConveyorGrid.Key(2, 1), inward = 3, id = "mill" } }
	check(
		"turning belt connects",
		ConveyorGrid.Trace(tiles, ConveyorGrid.Key(0, 0), inputs).toId == "mill"
	)

	lay(tiles, 2, 1, 0)
	local chain = ConveyorGrid.Trace(tiles, ConveyorGrid.Key(0, 0), inputs)
	check("wrong final direction does not connect", chain.toId == nil)
end

-- A gap breaks the belt, and a loop does not run forever.
do
	local tiles = {}
	lay(tiles, 0, 0, 0)
	lay(tiles, 2, 0, 0)
	local inputs =
		{ [ConveyorGrid.Key(2, 0)] = { key = ConveyorGrid.Key(2, 0), inward = 0, id = "x" } }
	check(
		"gap breaks the belt",
		ConveyorGrid.Trace(tiles, ConveyorGrid.Key(0, 0), inputs).toId == nil
	)

	local loop = {}
	lay(loop, 0, 0, 0)
	lay(loop, 1, 0, 3)
	lay(loop, 1, 1, 2)
	lay(loop, 0, 1, 1)
	local chain = ConveyorGrid.Trace(loop, ConveyorGrid.Key(0, 0), {})
	check("loop is detected", chain.looped and #chain.cells == 4)
end

-- The sending machine's own input is never the destination.
do
	local tiles = {}
	lay(tiles, 0, 0, 0)
	local inputs =
		{ [ConveyorGrid.Key(0, 0)] = { key = ConveyorGrid.Key(0, 0), inward = 0, id = "self" } }
	check(
		"no feeding back into itself",
		ConveyorGrid.Trace(tiles, ConveyorGrid.Key(0, 0), inputs, "self").toId == nil
	)
end

-- Corner tiles open the sides where belts join; straight tiles keep their side walls.
do
	local tiles = {}
	lay(tiles, 0, 0, 0)
	lay(tiles, 1, 0, 3)
	local corner = ConveyorGrid.OpenSides(tiles, tiles[ConveyorGrid.Key(1, 0)])
	check("corner opens its exit", corner[3] == true)
	check("corner opens where the belt joins", corner[2] == true)
	check("corner keeps the outer walls", not corner[0] and not corner[1])

	local start = ConveyorGrid.OpenSides(tiles, tiles[ConveyorGrid.Key(0, 0)])
	check("loose start reads as straight", start[0] == true and start[2] == true and not start[1])

	local fed = ConveyorGrid.OpenSides(tiles, tiles[ConveyorGrid.Key(0, 0)], 1)
	check("machine feed side opens", fed[1] == true and not fed[2])
end

print(string.format("\n%d passed, %d failed", passes, failures))
if failures > 0 then
	error("ConveyorGrid tests failed")
end
