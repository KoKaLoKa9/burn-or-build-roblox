--!strict

-- Power networks (industry update, docs/IndustryExpansion.md section 2.2). Plain data only, so the
-- Lune tests can require it and the client can show reach while placing.
--
-- Hubs (power poles, generators, batteries) have a Reach in studs. Two hubs join when their centres
-- are within the larger of their reaches. A machine joins a hub when the closest point of its
-- footprint is within that hub's reach. Every connected group is one network: its generators share
-- their power with every machine on it, and its batteries soak up any surplus and cover shortfalls.

local PowerGrid = {}

export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }

export type Element = {
	id: number,
	x: number,
	z: number,
	rect: Rect,
	-- Hubs only: how far they reach to poles, generators, batteries and machines.
	reach: number?,
}

export type Edge = { a: number, b: number }

local function rectDistance(rect: Rect, x: number, z: number): number
	local dx = math.max(rect.minX - x, 0, x - rect.maxX)
	local dz = math.max(rect.minZ - z, 0, z - rect.maxZ)
	return math.sqrt(dx * dx + dz * dz)
end
PowerGrid.RectDistance = rectDistance

-- Groups elements into networks. Returns the network number of every element id (elements with no
-- connection still get their own number) and the edges, for drawing wires.
function PowerGrid.Networks(elements: { Element }): ({ [number]: number }, { Edge })
	local parent: { [number]: number } = {}
	local function find(id: number): number
		local root = id
		while parent[root] ~= root do
			root = parent[root]
		end
		while parent[id] ~= root do
			local nextId = parent[id]
			parent[id] = root
			id = nextId
		end
		return root
	end
	local function union(a: number, b: number)
		local ra, rb = find(a), find(b)
		if ra ~= rb then
			parent[math.max(ra, rb)] = math.min(ra, rb)
		end
	end

	local hubs: { Element } = {}
	for _, element in elements do
		parent[element.id] = element.id
		if element.reach and element.reach > 0 then
			table.insert(hubs, element)
		end
	end

	local edges: { Edge } = {}
	for i, hub in hubs do
		for j = i + 1, #hubs do
			local other = hubs[j]
			local reach = math.max(hub.reach :: number, other.reach :: number)
			local dx, dz = hub.x - other.x, hub.z - other.z
			if dx * dx + dz * dz <= reach * reach then
				union(hub.id, other.id)
				table.insert(edges, { a = hub.id, b = other.id })
			end
		end
	end
	for _, element in elements do
		if element.reach == nil or element.reach <= 0 then
			-- A machine wires to its nearest hub in reach only, so the drawing stays tidy.
			local best: Element? = nil
			local bestDistance = math.huge
			for _, hub in hubs do
				local distance = rectDistance(element.rect, hub.x, hub.z)
				if distance <= (hub.reach :: number) and distance < bestDistance then
					best, bestDistance = hub, distance
				end
			end
			if best then
				union(element.id, best.id)
				table.insert(edges, { a = best.id, b = element.id })
			end
		end
	end

	local networks: { [number]: number } = {}
	for _, element in elements do
		networks[element.id] = find(element.id)
	end
	return networks, edges
end

export type Battery = { charge: number, capacity: number, rate: number }

export type Balance = {
	supply: number,
	demand: number,
	-- 0 to 1: the share of their power that machines on this network get.
	ratio: number,
	-- Power that went into (positive) or came out of (negative) batteries, in kW.
	batteryFlow: number,
}

-- Shares one network's power for dt seconds. Generators supply kW, machines demand kW, and
-- batteries (charge and capacity in kJ, rate in kW) store surplus and cover shortfalls. Battery
-- charges are updated in place.
function PowerGrid.Balance(
	supply: number,
	demand: number,
	batteries: { Battery },
	dt: number
): Balance
	local surplus = supply - demand
	local flow = 0
	if surplus > 0 then
		local left = surplus
		for _, battery in batteries do
			local room = (battery.capacity - battery.charge) / math.max(dt, 1e-6)
			local take = math.min(left, battery.rate, room)
			if take > 0 then
				battery.charge += take * dt
				left -= take
				flow += take
			end
		end
	elseif surplus < 0 then
		local need = -surplus
		for _, battery in batteries do
			local available = battery.charge / math.max(dt, 1e-6)
			local give = math.min(need, battery.rate, available)
			if give > 0 then
				battery.charge -= give * dt
				need -= give
				flow -= give
			end
		end
	end
	local delivered = supply - math.max(flow, 0) + math.max(-flow, 0)
	local ratio = if demand <= 0 then 1 else math.clamp(delivered / demand, 0, 1)
	return { supply = supply, demand = demand, ratio = ratio, batteryFlow = flow }
end

return PowerGrid
