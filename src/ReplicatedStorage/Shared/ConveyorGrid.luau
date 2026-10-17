--!strict

-- Grid rules for conveyor tiles that players lay one by one. Pure Luau with plain numbers, so
-- tests/ConveyorGrid.spec.luau can run it in Lune.
--
-- Cells are 4 studs square and centred on multiples of 4. A tile points one of four directions,
-- matching machine rotation steps: 0 east (+X), 1 north (-Z), 2 west (-X), 3 south (+Z).
-- A belt runs from a machine OUT port's access cell (the cell just outside the port), tile by
-- tile in each tile's direction, and ends on an IN port's access cell pointing into that machine.

local ConveyorGrid = {}

ConveyorGrid.CellSize = 4
ConveyorGrid.Directions = {
	[0] = { x = 1, z = 0 },
	[1] = { x = 0, z = -1 },
	[2] = { x = -1, z = 0 },
	[3] = { x = 0, z = 1 },
}

export type Tile = { ix: number, iz: number, dir: number }
export type Port = { key: string, inward: number, id: any, name: string? }
export type Chain = { cells: { string }, toId: any?, toPort: string?, looped: boolean }

function ConveyorGrid.Key(ix: number, iz: number): string
	return ix .. "," .. iz
end

function ConveyorGrid.CellOf(x: number, z: number): (number, number)
	local size = ConveyorGrid.CellSize
	return math.floor(x / size + 0.5), math.floor(z / size + 0.5)
end

function ConveyorGrid.Center(ix: number, iz: number): (number, number)
	return ix * ConveyorGrid.CellSize, iz * ConveyorGrid.CellSize
end

function ConveyorGrid.Step(ix: number, iz: number, dir: number): (number, number)
	local delta = ConveyorGrid.Directions[dir % 4]
	return ix + delta.x, iz + delta.z
end

-- The direction from one cell to an adjacent cell, or nil when they are not neighbours.
function ConveyorGrid.DirectionBetween(
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number
): number?
	for dir = 0, 3 do
		local delta = ConveyorGrid.Directions[dir]
		if fromX + delta.x == toX and fromZ + delta.z == toZ then
			return dir
		end
	end
	return nil
end

-- The closest of the four directions to a flat world vector.
function ConveyorGrid.DirectionOf(x: number, z: number): number
	if math.abs(x) >= math.abs(z) then
		return if x >= 0 then 0 else 2
	end
	return if z >= 0 then 3 else 1
end

-- Follows tiles from `startKey` until they reach an input pointing into its machine.
-- `inputs` maps an access cell key to the receiving port. `excludeId` skips the sending machine.
-- `toPort` is the receiving port's name, for machines with more than one input.
function ConveyorGrid.Trace(
	tiles: { [string]: Tile },
	startKey: string,
	inputs: { [string]: Port },
	excludeId: any?
): Chain
	local cells: { string } = {}
	local visited: { [string]: boolean } = {}
	local key = startKey
	local tile = tiles[key]
	while tile do
		if visited[key] then
			return { cells = cells, toId = nil, looped = true }
		end
		visited[key] = true
		table.insert(cells, key)
		local port = inputs[key]
		if port and port.id ~= excludeId and tile.dir == port.inward then
			return { cells = cells, toId = port.id, toPort = port.name, looped = false }
		end
		local nextX, nextZ = ConveyorGrid.Step(tile.ix, tile.iz, tile.dir)
		key = ConveyorGrid.Key(nextX, nextZ)
		tile = tiles[key]
	end
	return { cells = cells, toId = nil, looped = false }
end

-- Which world sides of a tile are open (belt enters or leaves there). The rest get side walls.
-- `feedSide` is the side a machine output feeds into this cell from, if any.
function ConveyorGrid.OpenSides(
	tiles: { [string]: Tile },
	tile: Tile,
	feedSide: number?
): { [number]: boolean }
	local open: { [number]: boolean } = { [tile.dir] = true }
	local hasInput = false
	for side = 0, 3 do
		local nx, nz = ConveyorGrid.Step(tile.ix, tile.iz, side)
		local neighbour = tiles[ConveyorGrid.Key(nx, nz)]
		if neighbour and (neighbour.dir + 2) % 4 == side and side ~= tile.dir then
			open[side] = true
			hasInput = true
		end
	end
	if feedSide then
		open[feedSide] = true
		hasInput = true
	end
	if not hasInput then
		-- A loose start still reads as a straight belt.
		open[(tile.dir + 2) % 4] = true
	end
	return open
end

return ConveyorGrid
