--!strict

-- Power networks for the factory (industry update, docs/IndustryExpansion.md section 2.2). Every
-- factory machine with PowerKW needs power. Like Industrialist, power only travels along wires the
-- player strings with the wrench: a wire joins a power pole coil to a machine, or two coils. Each
-- pole has two coils that are separate junctions. Every wired group shares its generators' output,
-- batteries store the surplus, and a short network slows every machine on it (ProductionLine
-- powerRatio). See Shared/PowerGrid for the rules.
--
-- Remote PowerWire(aId, aCoil, bId, bCoil) strings a wire, or removes it if it is already there.
-- Player attributes the client reads: PowerSupplyKW and PowerDemandKW, summed over every network
-- that holds one of that player's machines, and Wires, how many wires they have strung.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PowerGrid = require(Shared:WaitForChild("PowerGrid"))

local PowerService = {}

local WIRE_COLOR = Color3.fromRGB(34, 34, 36)
local WIRE_DEAD_COLOR = Color3.fromRGB(150, 60, 48)
local WIRE_THICKNESS = 0.16
local POWERED_KINDS: { [string]: boolean } = { Generator = true, Battery = true }

type Wire = { a: PowerGrid.End, b: PowerGrid.End, owner: Player, part: BasePart? }
type Network = { members: { any }, owners: { [Player]: boolean } }

local machineService: any
local line: any
local wireFolder: Folder
local wires: { Wire } = {}
local networks: { [string]: Network } = {}
local networkOfKey: { [string]: string } = {}
local dirty = true

local function notify(player: Player?, message: string)
	machineService:Notify(player, message)
end

local function isPole(record: any): boolean
	return record.node.kind == "Pole"
end

-- Machines that can carry a wire: generators, batteries, and anything that uses power.
local function isPowered(record: any): boolean
	local definition = record.node.definition
	return POWERED_KINDS[definition.Kind] == true or (definition.PowerKW or 0) > 0
end

-- Where a wire meets an end: the pole's coil, the art's WireTop marker, or the top of the body.
local function endPoint(record: any, coil: number?): Vector3
	local name = if coil then "Coil" .. coil else "WireTop"
	local marker = record.model:FindFirstChild(name, true)
	if marker and marker:IsA("BasePart") then
		return marker.Position
	end
	local body = record.model.PrimaryPart
	if body then
		return body.Position + Vector3.new(0, body.Size.Y / 2, 0)
	end
	return record.model:GetPivot().Position
end

local function sameWire(wire: Wire, a: PowerGrid.End, b: PowerGrid.End): boolean
	local ka, kb = PowerGrid.Key(a), PowerGrid.Key(b)
	local wa, wb = PowerGrid.Key(wire.a), PowerGrid.Key(wire.b)
	return (wa == ka and wb == kb) or (wa == kb and wb == ka)
end

local function drawWire(wire: Wire)
	local records = machineService:GetRecords()
	local from = endPoint(records[wire.a.id], wire.a.coil)
	local to = endPoint(records[wire.b.id], wire.b.coil)
	local length = (to - from).Magnitude
	local part = Instance.new("Part")
	part.Name = "PowerWire"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = WIRE_COLOR
	part.Size = Vector3.new(WIRE_THICKNESS, WIRE_THICKNESS, math.max(length, 0.1))
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
	part.Parent = wireFolder
	wire.part = part
end

local function countWires(player: Player)
	local count = 0
	for _, wire in wires do
		if wire.owner == player then
			count += 1
		end
	end
	player:SetAttribute("Wires", count)
end

local function removeWireAt(index: number)
	local wire = table.remove(wires, index) :: Wire
	if wire.part then
		wire.part:Destroy()
	end
	if wire.owner.Parent then
		countWires(wire.owner)
	end
end

-- Takes down wires whose pole or machine is gone.
local function pruneWires()
	local records = machineService:GetRecords()
	for index = #wires, 1, -1 do
		local wire = wires[index]
		if records[wire.a.id] == nil or records[wire.b.id] == nil then
			removeWireAt(index)
		end
	end
end

-- Regroups networks after wires or machines change.
local function rebuild()
	dirty = false
	pruneWires()
	local records = machineService:GetRecords()

	local keys: { string } = {}
	local byKey: { [string]: any } = {}
	for id, record in records do
		if isPole(record) then
			for coil = 1, record.node.definition.Coils or 2 do
				table.insert(keys, PowerGrid.Key({ id = id, coil = coil }))
			end
		elseif isPowered(record) then
			local key = PowerGrid.Key({ id = id })
			table.insert(keys, key)
			byKey[key] = record
		end
	end
	local joined: { { string } } = {}
	for _, wire in wires do
		table.insert(joined, { PowerGrid.Key(wire.a), PowerGrid.Key(wire.b) })
	end
	networkOfKey = PowerGrid.Networks(keys, joined)
	table.clear(networks)
	for key, network in networkOfKey do
		local entry = networks[network]
		if entry == nil then
			entry = { members = {}, owners = {} }
			networks[network] = entry
		end
		local record = byKey[key]
		if record then
			table.insert(entry.members, record)
			if record.owner then
				entry.owners[record.owner] = true
			end
		end
	end
end

-- Shares each network's power for this step and reports totals to each player.
local function share(dt: number)
	if dirty then
		rebuild()
	end
	local supplyBy: { [Player]: number } = {}
	local demandBy: { [Player]: number } = {}
	local starved: { [string]: boolean } = {}
	for networkId, network in networks do
		local supply, demand = 0, 0
		local batteries: { PowerGrid.Battery } = {}
		local batteryNodes = {}
		local consumers = {}
		for _, record in network.members do
			local node = record.node
			if node.kind == "Generator" then
				supply += node.powerOutput
			elseif node.kind == "Battery" then
				table.insert(batteries, {
					charge = node.charge,
					capacity = node.definition.CapacityKJ,
					rate = node.definition.RateKW,
				})
				table.insert(batteryNodes, node)
			end
			demand += line:PowerDemand(node)
			if (node.definition.PowerKW or 0) > 0 then
				table.insert(consumers, node)
			end
		end
		local balance = PowerGrid.Balance(supply, demand, batteries, dt)
		for index, node in batteryNodes do
			node.charge = batteries[index].charge
		end
		-- An idle network still reports whether it could run its machines, so a machine about to
		-- start a cycle does not stall for a step.
		local ratio = if demand > 0
			then balance.ratio
			elseif supply > 0 or #batteries > 0 then 1
			else 0
		for _, node in consumers do
			line:SetPowerRatio(node.id, ratio)
		end
		starved[networkId] = demand > 0 and balance.ratio < 0.999
		for owner in network.owners do
			supplyBy[owner] = (supplyBy[owner] or 0) + supply
			demandBy[owner] = (demandBy[owner] or 0) + demand
		end
	end

	for _, wire in wires do
		local part = wire.part
		if part then
			local network = networkOfKey[PowerGrid.Key(wire.a)]
			local color = if network and starved[network] then WIRE_DEAD_COLOR else WIRE_COLOR
			if part.Color ~= color then
				part.Color = color
			end
		end
	end
	for _, player in Players:GetPlayers() do
		local supply = math.floor((supplyBy[player] or 0) * 10 + 0.5) / 10
		local demand = math.floor((demandBy[player] or 0) * 10 + 0.5) / 10
		if player:GetAttribute("PowerSupplyKW") ~= supply then
			player:SetAttribute("PowerSupplyKW", supply)
		end
		if player:GetAttribute("PowerDemandKW") ~= demand then
			player:SetAttribute("PowerDemandKW", demand)
		end
	end
end

local function networkText(key: string): string
	local network = networks[networkOfKey[key] or ""]
	if network == nil or #network.members == 0 then
		return "not wired"
	end
	local supply, demand = 0, 0
	for _, record in network.members do
		local node = record.node
		if node.kind == "Generator" then
			supply += node.powerOutput
		end
		demand += line:PowerDemand(node)
	end
	return string.format("%.0f / %.0f kW", demand, supply)
end

-- Strings a wire between two ends, or removes it when it is already there.
local function toggleWire(player: Player, a: PowerGrid.End, b: PowerGrid.End): (boolean, string)
	local records = machineService:GetRecords()
	local ra, rb = records[a.id], records[b.id]
	if ra == nil or rb == nil then
		return false, "That is no longer there."
	end
	if ra.owner ~= player or rb.owner ~= player then
		return false, "You can only wire your own machines."
	end
	local aPole, bPole = isPole(ra), isPole(rb)
	-- A pole end must name a real coil; a machine end must use power and has no coil.
	local function checkEnd(point: PowerGrid.End, record: any, pole: boolean): string?
		if pole then
			local coils = record.node.definition.Coils or 2
			if point.coil == nil or point.coil < 1 or point.coil > coils then
				return "Click one of the pole's coils."
			end
		else
			point.coil = nil
			if not isPowered(record) then
				return record.node.definition.DisplayName .. " does not use power."
			end
		end
		return nil
	end
	local endProblem = checkEnd(a, ra, aPole) or checkEnd(b, rb, bPole)
	if endProblem then
		return false, endProblem
	end
	for index, wire in wires do
		if sameWire(wire, a, b) then
			removeWireAt(index)
			dirty = true
			return true, "Wire removed."
		end
	end
	local reach = math.max(
		if aPole then ra.node.definition.Reach or 32 else 0,
		if bPole then rb.node.definition.Reach or 32 else 0
	)
	local length = (endPoint(ra, a.coil) - endPoint(rb, b.coil)).Magnitude
	local problem = PowerGrid.WireProblem(a, b, aPole, bPole, length, reach)
	if problem then
		return false, problem
	end
	local wire: Wire = { a = a, b = b, owner = player, part = nil }
	table.insert(wires, wire)
	drawWire(wire)
	countWires(player)
	dirty = true
	return true,
		string.format(
			"Wired %s to %s.",
			string.lower(ra.node.definition.DisplayName),
			string.lower(rb.node.definition.DisplayName)
		)
end

local function readEnd(rawId: unknown, rawCoil: unknown): PowerGrid.End?
	if typeof(rawId) ~= "number" or rawId ~= rawId then
		return nil
	end
	local coil = if typeof(rawCoil) == "number" and rawCoil == rawCoil
		then math.floor(rawCoil)
		else nil
	return { id = math.floor(rawId), coil = coil }
end

-- The wires a player strung, naming machines by their place in `nodeIds` (a saved layout).
function PowerService:ExportWires(player: Player, nodeIds: { number }): { any }
	local indexOf: { [number]: number } = {}
	for index, nodeId in nodeIds do
		indexOf[nodeId] = index
	end
	local saved = {}
	for _, wire in wires do
		local ai, bi = indexOf[wire.a.id], indexOf[wire.b.id]
		if wire.owner == player and ai and bi then
			table.insert(saved, { a = ai, ac = wire.a.coil, b = bi, bc = wire.b.coil })
		end
	end
	return saved
end

-- Restrings saved wires once their machines are rebuilt (`newIds` maps list place to machine id).
function PowerService:ImportWires(player: Player, saved: any, newIds: { [number]: number })
	if typeof(saved) ~= "table" then
		return
	end
	for _, entry in saved do
		local a, b = newIds[entry.a], newIds[entry.b]
		if a and b then
			toggleWire(player, { id = a, coil = entry.ac }, { id = b, coil = entry.bc })
		end
	end
end

-- Strings a wire without the remote (Studio scenarios).
function PowerService:Connect(player: Player, a: PowerGrid.End, b: PowerGrid.End): (boolean, string)
	return toggleWire(player, a, b)
end

function PowerService:Initialize(world: Model, machines: any)
	machineService = machines
	line = machineService:GetLine()
	line:SetPowerEnabled(true)

	local production = world:WaitForChild("Production")
	wireFolder = Instance.new("Folder")
	wireFolder.Name = "PowerWires"
	wireFolder.Parent = production

	local remote = Instance.new("RemoteFunction")
	remote.Name = "PowerWire"
	remote.OnServerInvoke = function(
		player: Player,
		aId: unknown,
		aCoil: unknown,
		bId: unknown,
		bCoil: unknown
	): (boolean, string)
		local a, b = readEnd(aId, aCoil), readEnd(bId, bCoil)
		if a == nil or b == nil then
			return false, "Invalid wire."
		end
		return toggleWire(player, a, b)
	end
	remote.Parent = ReplicatedStorage:WaitForChild("Remotes")

	machineService:OnMachinesChanged(function()
		pruneWires()
		dirty = true
	end)
	machineService:OnBeforeStep(share)

	machineService:RegisterKindHandler("Generator", {
		onPlaced = function(record)
			local definition = record.node.definition
			if definition.Fuel ~= "Crank" then
				return
			end
			local body = record.model.PrimaryPart
			if body == nil then
				return
			end
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "CrankPrompt"
			prompt.ActionText = "Crank"
			prompt.ObjectText = definition.DisplayName
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0.8
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.UIOffset = Vector2.new(0, 56)
			prompt.Parent = body
			prompt.Triggered:Connect(function(player)
				line:Crank(record.node.id, definition.CrankSeconds)
				notify(
					player,
					string.format(
						"Cranked: %d kW for %.0f seconds. Wire it to a pole coil to use it.",
						definition.PowerOutputKW,
						record.node.crankSeconds
					)
				)
			end)
		end,
	})
	machineService:RegisterKindHandler("Battery", {
		describe = function(record)
			local node: any = record.node
			local percent = math.floor(node.charge / node.definition.CapacityKJ * 100 + 0.5)
			return string.format(
				'%s\n<font color="#68D88E">%d%% charged</font>\n%s',
				node.definition.DisplayName,
				percent,
				networkText(PowerGrid.Key({ id = node.id }))
			)
		end,
	})
	machineService:RegisterKindHandler("Pole", {
		describe = function(record)
			local lines = {}
			for coil = 1, record.node.definition.Coils or 2 do
				table.insert(
					lines,
					string.format(
						"Coil %d: %s",
						coil,
						networkText(PowerGrid.Key({ id = record.node.id, coil = coil }))
					)
				)
			end
			return table.concat(lines, "\n")
		end,
	})
end

return PowerService
