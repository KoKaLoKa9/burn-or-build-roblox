--!strict

-- Power networks (industry update, docs/IndustryExpansion.md section 2.2). Plain data only, so the
-- Lune tests can require it.
--
-- Like Industrialist, power only flows along wires the player strings with the wrench. A wire joins
-- two ends: a coil on a power pole ("p<id>:<coil>") and a machine ("m<id>"), or two pole coils. The
-- two coils on one pole are separate junctions. Every group of ends joined by wires is one network:
-- its generators share their power with every machine on it, and its batteries soak up any surplus
-- and cover shortfalls. A machine with no wire is a network of its own.

local PowerGrid = {}

export type End = { id: number, coil: number? }

function PowerGrid.Key(point: End): string
	return if point.coil then "p" .. point.id .. ":" .. point.coil else "m" .. point.id
end

-- Groups ends into networks. Returns each key's network: the smallest key in its group, so the
-- result does not depend on the order of wires.
function PowerGrid.Networks(keys: { string }, wires: { { string } }): { [string]: string }
	local parent: { [string]: string } = {}
	local function find(key: string): string
		local root = key
		while parent[root] ~= root do
			root = parent[root]
		end
		while parent[key] ~= root do
			local nextKey = parent[key]
			parent[key] = root
			key = nextKey
		end
		return root
	end
	for _, key in keys do
		parent[key] = key
	end
	for _, wire in wires do
		local a, b = wire[1], wire[2]
		if parent[a] and parent[b] then
			local ra, rb = find(a), find(b)
			if ra ~= rb then
				if ra < rb then
					parent[rb] = ra
				else
					parent[ra] = rb
				end
			end
		end
	end
	local networks: { [string]: string } = {}
	for _, key in keys do
		networks[key] = find(key)
	end
	return networks
end

-- Why a wire may not be strung, or nil when it may. `aPole` and `bPole` say whether each end is a
-- pole coil, `reach` is the longest wire the poles involved allow, `length` the wire's length.
function PowerGrid.WireProblem(
	a: End,
	b: End,
	aPole: boolean,
	bPole: boolean,
	length: number,
	reach: number
): string?
	if PowerGrid.Key(a) == PowerGrid.Key(b) then
		return "Pick two different ends."
	end
	if a.id == b.id and not (aPole and bPole) then
		return "Pick two different ends."
	end
	if not aPole and not bPole then
		return "Wires run through a power pole: click a pole coil first."
	end
	if length > reach then
		return string.format("Too far: %d studs, a wire reaches %d.", math.floor(length), reach)
	end
	return nil
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
