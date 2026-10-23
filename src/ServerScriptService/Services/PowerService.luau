--!strict

-- Power networks for the factory (industry update, docs/IndustryExpansion.md section 2.2). Every
-- factory machine with PowerKW needs power. Generators, batteries and poles reach out to each other
-- and to machines (Shared/PowerGrid); each connected group shares its generators' output, batteries
-- store the surplus, and a short network slows every machine on it (ProductionLine powerRatio).
--
-- Player attributes the client reads: PowerSupplyKW and PowerDemandKW, summed over every network
-- that holds one of that player's machines.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PowerGrid = require(Shared:WaitForChild("PowerGrid"))

local PowerService = {}

local HUB_KINDS: { [string]: boolean } = { Generator = true, Battery = true, Pole = true }
local WIRE_COLOR = Color3.fromRGB(34, 34, 36)
local WIRE_DEAD_COLOR = Color3.fromRGB(150, 60, 48)
local WIRE_THICKNESS = 0.16

type Member = { id: number, record: any }
type Network = { members: { Member }, owners: { [Player]: boolean } }

local machineService: any
local line: any
local wireFolder: Folder
local networks: { [number]: Network } = {}
local networkOf: { [number]: number } = {}
local wires: { { part: BasePart, network: number } } = {}
local dirty = true

local function notify(player: Player?, message: string)
	machineService:Notify(player, message)
end

local function isPowered(definition: any): boolean
	return HUB_KINDS[definition.Kind] == true or (definition.PowerKW or 0) > 0
end

-- Where wires meet a machine: the art's WireTop marker, else the top of its body.
local function wirePoint(record: any): Vector3
	local marker = record.model:FindFirstChild("WireTop", true)
	if marker and marker:IsA("BasePart") then
		return marker.Position
	end
	local body = record.model.PrimaryPart
	if body then
		return body.Position + Vector3.new(0, body.Size.Y / 2, 0)
	end
	return record.model:GetPivot().Position
end

local function clearWires()
	for _, wire in wires do
		wire.part:Destroy()
	end
	table.clear(wires)
end

local function drawWire(from: Vector3, to: Vector3, network: number)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local part: BasePart = Instance.new("Part")
	part.Name = "PowerWire"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = WIRE_COLOR
	part.Size = Vector3.new(WIRE_THICKNESS, WIRE_THICKNESS, length)
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
	part.Parent = wireFolder
	table.insert(wires, { part = part, network = network })
end

local function rebuild()
	dirty = false
	local records = machineService:GetRecords()
	local elements: { PowerGrid.Element } = {}
	local byId: { [number]: any } = {}
	for id, record in records do
		local definition = record.node.definition
		local rect = machineService:GetFootprint(id)
		if rect and isPowered(definition) then
			table.insert(elements, {
				id = id,
				x = (rect.minX + rect.maxX) / 2,
				z = (rect.minZ + rect.maxZ) / 2,
				rect = rect,
				reach = if HUB_KINDS[definition.Kind] then definition.Reach or 12 else nil,
			})
			byId[id] = record
		end
	end

	local assignment, edges = PowerGrid.Networks(elements)
	table.clear(networks)
	table.clear(networkOf)
	for id, network in assignment do
		local entry = networks[network]
		if entry == nil then
			entry = { members = {}, owners = {} }
			networks[network] = entry
		end
		local record = byId[id]
		table.insert(entry.members, { id = id, record = record })
		if record.owner then
			entry.owners[record.owner] = true
		end
		networkOf[id] = network
	end

	clearWires()
	for _, edge in edges do
		local a, b = byId[edge.a], byId[edge.b]
		if a and b then
			drawWire(wirePoint(a), wirePoint(b), assignment[edge.a])
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
	local starved: { [number]: boolean } = {}
	for networkId, network in networks do
		local supply, demand = 0, 0
		local batteries: { PowerGrid.Battery } = {}
		local batteryNodes = {}
		local consumers = {}
		for _, member in network.members do
			local node = member.record.node
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
			local want = line:PowerDemand(node)
			if want > 0 then
				demand += want
			end
			if (node.definition.PowerKW or 0) > 0 then
				table.insert(consumers, node)
			end
		end
		local balance = PowerGrid.Balance(supply, demand, batteries, dt)
		for index, node in batteryNodes do
			node.charge = batteries[index].charge
		end
		-- An idle network still reports whether it could run its machines, so a machine about
		-- to start a cycle does not stall for a step.
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
		local color = if starved[wire.network] then WIRE_DEAD_COLOR else WIRE_COLOR
		if wire.part.Color ~= color then
			wire.part.Color = color
		end
	end
	for _, player in game:GetService("Players"):GetPlayers() do
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

local function networkText(nodeId: number): string
	local network = networks[networkOf[nodeId] or -1]
	if network == nil then
		return "Not connected"
	end
	local supply, demand = 0, 0
	for _, member in network.members do
		local node = member.record.node
		if node.kind == "Generator" then
			supply += node.powerOutput
		end
		demand += line:PowerDemand(node)
	end
	return string.format("Network %.0f / %.0f kW", demand, supply)
end

function PowerService:Initialize(world: Model, machines: any)
	machineService = machines
	line = machineService:GetLine()
	line:SetPowerEnabled(true)

	local production = world:WaitForChild("Production")
	wireFolder = Instance.new("Folder")
	wireFolder.Name = "PowerWires"
	wireFolder.Parent = production

	machineService:OnMachinesChanged(function()
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
						"Cranked: %d kW for %.0f seconds. Solar panels or a straw furnace keep power on without you.",
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
				networkText(node.id)
			)
		end,
	})
	machineService:RegisterKindHandler("Pole", {
		describe = function(record)
			return networkText(record.node.id)
		end,
	})
end

return PowerService
