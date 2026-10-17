--!strict

-- Server-authoritative production simulation for the P0 straw pellet line.
-- Pure Luau with no Roblox instances, so tests/ProductionLine.spec.luau can run it in Lune.
-- Follows spec v0.2 section 4.3 (machine cycle logic), 4.5 (conveyor item behavior), and
-- 7.3 (covered buffer storage).
--
-- Machines have ports (docs/MachinePorts.md). Every machine with ports gets a primary "In" and
-- "Out" port from its catalog fields (InputItem, OutputItem, InputPerCycle, ...), and ExtraPorts
-- adds more. Each port carries one link. A processor recipe consumes PerCycle units at every In
-- port and fills every Out port, and it starts only when every input is present and every output
-- has room. An Out port with Vent set releases its units into the air while nothing is connected,
-- so an unpiped gas never blocks the machine.

local ProductionLine = {}
ProductionLine.__index = ProductionLine

local BELT_SPACING_SECONDS = 2
local MAX_SUBSTEP = 0.1

-- owner is the player whose machine created the unit; sales pay that player.
export type Unit = { id: number, item: string, owner: any }

-- Catalog shape of a port. Side and Offset place it on the model (MachineService).
export type PortSpec = {
	Name: string,
	Direction: string,
	Medium: string?,
	Item: string?,
	PerCycle: number?,
	Capacity: number?,
	Vent: boolean?,
	Side: string?,
	Offset: number?,
}

export type Port = {
	name: string,
	direction: string,
	medium: string,
	-- nil means the machine decides: storage keeps one straw type, a sink buys its listed items.
	item: string?,
	perCycle: number,
	capacity: number,
	vent: boolean,
	link: Link?,
}

export type Link = {
	id: number,
	from: any,
	to: any,
	fromPort: Port,
	toPort: Port,
	travelSeconds: number,
	items: { { unit: Unit, elapsed: number } },
	state: string,
	reason: string,
}

export type Node = {
	id: number,
	definitionId: string,
	definition: any,
	kind: string,
	owner: any,
	ports: { Port },
	input: { Unit },
	output: { Unit },
	held: { Unit },
	reserved: { Unit },
	cycling: boolean,
	progress: number,
	paused: boolean,
	state: string,
	reason: string,
	completedCycles: number,
	-- Storage only: material chosen by the player. Stored items also lock the type (spec 7.3).
	filter: string?,
	-- The links on the primary "Out" and "In" ports, kept for single-port machines.
	outLink: Link?,
	inLink: Link?,
}

export type Event = {
	type: string,
	nodeId: number,
	owner: any,
	unitId: number?,
	amount: number?,
	item: string?,
}

local PORTLESS_KINDS: { [string]: boolean } = { Terminal = true, Farm = true, Office = true }

-- Every port a machine definition has, in order: primary In, primary Out, then ExtraPorts.
function ProductionLine.PortSpecs(definition: any): { PortSpec }
	if definition.NoPorts or PORTLESS_KINDS[definition.Kind] then
		return {}
	end
	local isProcessor = definition.Kind == "Processor"
	local specs: { PortSpec } = {
		{
			Name = "In",
			Direction = "In",
			Medium = "Item",
			Item = if isProcessor then definition.InputItem else nil,
			PerCycle = definition.InputPerCycle,
			Capacity = definition.InputCapacity,
			Side = "West",
			Offset = 0,
		},
	}
	if definition.Kind ~= "Sink" and not definition.InputOnly then
		table.insert(specs, {
			Name = "Out",
			Direction = "Out",
			Medium = "Item",
			Item = if isProcessor then definition.OutputItem else nil,
			PerCycle = definition.OutputPerCycle,
			Capacity = definition.OutputCapacity,
			Side = "East",
			Offset = 0,
		})
	end
	for _, extra in definition.ExtraPorts or {} do
		table.insert(specs, extra)
	end
	return specs
end

local function buildPorts(definition: any): { Port }
	local ports: { Port } = {}
	for _, spec in ProductionLine.PortSpecs(definition) do
		table.insert(ports, {
			name = spec.Name,
			direction = spec.Direction,
			medium = spec.Medium or "Item",
			item = spec.Item,
			perCycle = spec.PerCycle or 0,
			capacity = spec.Capacity or math.huge,
			vent = spec.Vent == true,
			link = nil,
		})
	end
	return ports
end

function ProductionLine.new(definitions: { [string]: any })
	local self = setmetatable({}, ProductionLine)
	self.definitions = definitions
	self.nodes = {} :: { [number]: Node }
	self.links = {} :: { [number]: Link }
	self.soldUnits = {} :: { [number]: boolean }
	self.nextNodeId = 1
	self.nextLinkId = 1
	self.nextUnitId = 1
	self.events = {} :: { Event }
	-- Weather can stretch a machine type's cycle time (spec 11.3: rain slows drying).
	self.cycleMultipliers = {} :: { [string]: number }
	self.globalMultiplier = 1
	return self
end

-- A multiplier of 1 restores the catalog cycle time. Progress already made is kept.
-- Slows (or speeds) every machine at once, on top of any per-machine multiplier. Smog uses it.
function ProductionLine:SetGlobalCycleMultiplier(multiplier: number)
	self.globalMultiplier = multiplier
end

function ProductionLine:SetCycleMultiplier(definitionId: string, multiplier: number)
	self.cycleMultipliers[definitionId] = if multiplier == 1 then nil else multiplier
end

function ProductionLine:CycleSeconds(node: Node): number
	return node.definition.CycleSeconds
		* (self.cycleMultipliers[node.definitionId] or 1)
		* (self.globalMultiplier or 1)
end

-- Every unit still inside the line: machine buffers, cycles in progress, and belts.
-- Vented gas has left the line, so it is not counted.
function ProductionLine:CountItems(): number
	local total = 0
	for _, node in self.nodes do
		total += #node.input + #node.output + #node.held + #node.reserved
	end
	for _, link in self.links do
		total += #link.items
	end
	return total
end

function ProductionLine:_newUnit(item: string, owner: any): Unit
	local id: number = self.nextUnitId
	local unit = { id = id, item = item, owner = owner }
	self.nextUnitId = id + 1
	return unit
end

function ProductionLine:_emit(event: Event)
	table.insert(self.events, event)
end

local function portsOf(node: Node, direction: string): { Port }
	local list = {}
	for _, port in node.ports do
		if port.direction == direction then
			table.insert(list, port)
		end
	end
	return list
end

function ProductionLine:GetPort(node: Node, name: string): Port?
	for _, port in node.ports do
		if port.name == name then
			return port
		end
	end
	return nil
end

-- Every link attached to a node, on any port.
function ProductionLine:LinksOf(node: Node): { Link }
	local links = {}
	for _, port in node.ports do
		if port.link then
			table.insert(links, port.link)
		end
	end
	return links
end

local function countItem(units: { Unit }, item: string?): number
	if item == nil then
		return #units
	end
	local count = 0
	for _, unit in units do
		if unit.item == item then
			count += 1
		end
	end
	return count
end

-- Removes and returns the first unit of that item (any item when nil).
local function takeItem(units: { Unit }, item: string?): Unit?
	for index, unit in units do
		if item == nil or unit.item == item then
			return table.remove(units, index)
		end
	end
	return nil
end

-- The material a storage node is locked to: the player's choice, else its stored contents.
local function storageItem(node: Node): string?
	if node.filter then
		return node.filter
	end
	local first = node.output[1]
	return if first then first.item else nil
end

local function processorAccepts(node: Node, item: string): boolean
	for _, port in node.ports do
		if port.direction == "In" and port.item == item then
			return true
		end
	end
	return false
end

local function acceptsType(node: Node, item: string): boolean
	if node.kind == "Storage" then
		local locked = storageItem(node)
		if locked then
			return locked == item
		end
		return table.find(node.definition.StoresItems, item) ~= nil
	elseif node.kind == "Terminal" then
		return false
	elseif node.kind == "Sink" and node.definition.Prices then
		-- A market buys every product it lists a price for.
		return node.definition.Prices[item] ~= nil
	elseif node.kind == "Processor" then
		return processorAccepts(node, item)
	end
	return node.definition.AcceptsItem == item
end

-- Whether one In port takes this material. A port without its own item follows the machine.
local function portAccepts(node: Node, port: Port, item: string): boolean
	if port.item then
		return port.item == item and acceptsType(node, item)
	end
	return acceptsType(node, item)
end

local function requiredItemText(node: Node, port: Port?): string
	if port and port.item then
		return port.item
	elseif node.kind == "Storage" then
		return storageItem(node) or "straw"
	elseif node.kind == "Sink" and node.definition.Prices then
		local items = {}
		for item in node.definition.Prices do
			table.insert(items, item)
		end
		table.sort(items)
		return table.concat(items, " or ")
	elseif node.kind == "Processor" then
		local items = {}
		for _, inPort in portsOf(node, "In") do
			table.insert(items, tostring(inPort.item))
		end
		return table.concat(items, " or ")
	end
	return tostring(node.definition.AcceptsItem)
end

-- Every material one Out port could release. An empty, unfiltered storage could release any straw.
local function portItems(node: Node, port: Port): { string }
	if port.item then
		return { port.item }
	elseif node.kind == "Storage" then
		local locked = storageItem(node)
		return if locked then { locked } else node.definition.StoresItems
	end
	local item = node.definition.OutputItem
	return if item then { item } else {}
end

local function canAccept(node: Node, port: Port, item: string): boolean
	if not portAccepts(node, port, item) then
		return false
	end
	if node.kind == "Processor" then
		return countItem(node.input, port.item) < port.capacity
	elseif node.kind == "Source" then
		return #node.output < node.definition.OutputCapacity
	elseif node.kind == "Storage" then
		return #node.output < node.definition.Capacity
	end
	return true
end

local function setPortLink(node: Node, port: Port, link: Link?)
	port.link = link
	if port.name == "In" then
		node.inLink = link
	elseif port.name == "Out" then
		node.outLink = link
	end
end

function ProductionLine:AddNode(definitionId: string, owner: any?): Node
	local definition = self.definitions[definitionId]
	assert(definition, "Unknown machine definition " .. tostring(definitionId))

	local node: Node = {
		id = self.nextNodeId,
		definitionId = definitionId,
		definition = definition,
		kind = definition.Kind,
		owner = owner,
		ports = buildPorts(definition),
		input = {},
		output = {},
		held = {},
		reserved = {},
		cycling = false,
		progress = 0,
		paused = false,
		state = "Idle",
		reason = "Ready",
		completedCycles = 0,
		filter = nil,
		outLink = nil,
		inLink = nil,
	}
	self.nextNodeId += 1
	self.nodes[node.id] = node
	return node
end

function ProductionLine:GetNode(nodeId: number): Node?
	return self.nodes[nodeId]
end

function ProductionLine:IsEmpty(node: Node): boolean
	if #node.input > 0 or #node.output > 0 or #node.held > 0 or #node.reserved > 0 then
		return false
	end
	for _, link in self:LinksOf(node) do
		if #link.items > 0 then
			return false
		end
	end
	return true
end

function ProductionLine:RemoveNode(nodeId: number): (boolean, string)
	local node = self.nodes[nodeId]
	if node == nil then
		return false, "That machine no longer exists."
	end
	-- Spec 15.1: stored items must never be erased. Until recovery crates exist,
	-- dismantling is only allowed when the machine and its belts are empty.
	if not self:IsEmpty(node) then
		return false, "Empty this machine and its conveyors before dismantling."
	end
	for _, link in self:LinksOf(node) do
		self:_removeLink(link)
	end
	self.nodes[nodeId] = nil
	return true, "Dismantled."
end

function ProductionLine:_removeLink(link: Link)
	if link.fromPort.link == link then
		setPortLink(link.from, link.fromPort, nil)
	end
	if link.toPort.link == link then
		setPortLink(link.to, link.toPort, nil)
	end
	self.links[link.id] = nil
end

-- Removes a link when its belt is broken. Items are never deleted (spec 15.1), so a link that
-- still carries items stays until it is empty.
function ProductionLine:Disconnect(linkId: number): (boolean, string)
	local link = self.links[linkId]
	if link == nil then
		return true, "Already disconnected."
	end
	if #link.items > 0 then
		return false, "This belt is still carrying items."
	end
	self:_removeLink(link)
	return true, "Disconnected."
end

-- Links an Out port of one machine to an In port of another. Without port names, the first free
-- pair that can carry a shared material is used, so a single-port machine needs no names.
function ProductionLine:Connect(
	fromId: number,
	toId: number,
	travelSeconds: number,
	fromPortName: string?,
	toPortName: string?
): (Link?, string)
	local from = self.nodes[fromId]
	local to = self.nodes[toId]
	if from == nil or to == nil then
		return nil, "Select two existing machines."
	end
	if from == to then
		return nil, "A machine cannot feed itself."
	end
	local outPorts: { Port } = {}
	for _, port in portsOf(from, "Out") do
		if (fromPortName == nil or port.name == fromPortName) and #portItems(from, port) > 0 then
			table.insert(outPorts, port)
		end
	end
	if #outPorts == 0 then
		return nil, from.definition.DisplayName .. " has no output port."
	end
	local hasInput = to.kind == "Processor" or to.kind == "Sink" or to.kind == "Storage"
	if not hasInput and not (to.kind == "Source" and from.kind == "Source") then
		return nil, to.definition.DisplayName .. " has no input for that line."
	end
	local inPorts: { Port } = {}
	for _, port in portsOf(to, "In") do
		if toPortName == nil or port.name == toPortName then
			table.insert(inPorts, port)
		end
	end
	if #inPorts == 0 then
		return nil, to.definition.DisplayName .. " has no input for that line."
	end

	local typeMatch, outFree = false, false
	local fromPort: Port?, toPort: Port? = nil, nil
	for _, outPort in outPorts do
		for _, item in portItems(from, outPort) do
			for _, inPort in inPorts do
				if outPort.medium == inPort.medium and portAccepts(to, inPort, item) then
					typeMatch = true
					if outPort.link == nil then
						outFree = true
						if inPort.link == nil then
							fromPort, toPort = outPort, inPort
							break
						end
					end
				end
			end
			if fromPort then
				break
			end
		end
		if fromPort then
			break
		end
	end
	if not typeMatch then
		return nil,
			string.format(
				"This port cannot carry that material. %s needs %s, but %s outputs %s.",
				to.definition.DisplayName,
				requiredItemText(to, if toPortName then inPorts[1] else nil),
				from.definition.DisplayName,
				portItems(from, outPorts[1])[1]
			)
	end
	if not outFree then
		return nil, "This output already feeds a line. A splitter is required for a second line."
	end
	if fromPort == nil or toPort == nil then
		return nil, to.definition.DisplayName .. " input is already connected."
	end

	local link: Link = {
		id = self.nextLinkId,
		from = from,
		to = to,
		fromPort = fromPort,
		toPort = toPort,
		travelSeconds = math.max(0.5, travelSeconds),
		items = {},
		state = "Empty",
		reason = "",
	}
	self.nextLinkId += 1
	self.links[link.id] = link
	setPortLink(from, fromPort, link)
	setPortLink(to, toPort, link)
	return link, "Connected."
end

function ProductionLine:Deposit(nodeId: number, count: number, owner: any?): number
	local node = self.nodes[nodeId]
	if node == nil or node.kind ~= "Source" then
		return 0
	end
	local accepted = 0
	local item = node.definition.AcceptsItem
	while accepted < count and #node.output < node.definition.OutputCapacity do
		table.insert(node.output, self:_newUnit(item, owner or node.owner))
		accepted += 1
	end
	return accepted
end

function ProductionLine:SetPaused(nodeId: number, paused: boolean)
	local node = self.nodes[nodeId]
	if node then
		node.paused = paused
	end
end

-- Spec 7.3: the player sets the accepted material. Passing nil clears the choice, but stored
-- items keep the type locked until the storage is empty.
function ProductionLine:SetStorageFilter(nodeId: number, item: string?): (boolean, string)
	local node = self.nodes[nodeId]
	if node == nil or node.kind ~= "Storage" then
		return false, "Only storage has a material setting."
	end
	if item == nil then
		node.filter = nil
		local locked = storageItem(node)
		return true,
			if locked then "Locked to " .. locked .. " until empty" else "Accepts any straw"
	end
	if table.find(node.definition.StoresItems, item) == nil then
		return false, node.definition.DisplayName .. " cannot store " .. item .. "."
	end
	local first = node.output[1]
	if first and first.item ~= item then
		return false,
			string.format("Empty the storage before switching from %s to %s.", first.item, item)
	end
	node.filter = item
	return true, "Accepts " .. item
end

-- Delivers a unit straight into a node. Used by links and by the sale-once test.
function ProductionLine:_deliver(node: Node, unit: Unit)
	if node.kind == "Sink" then
		-- Spec 15.3: a sale pays only once per crate identifier.
		if self.soldUnits[unit.id] then
			return
		end
		self.soldUnits[unit.id] = true
		node.completedCycles += 1
		self:_emit({
			type = "Sale",
			nodeId = node.id,
			owner = unit.owner,
			unitId = unit.id,
			amount = if node.definition.Prices
				then node.definition.Prices[unit.item] or 0
				else node.definition.SalePrice,
			item = unit.item,
		})
	elseif node.kind == "Source" or node.kind == "Storage" then
		table.insert(node.output, unit)
	else
		table.insert(node.input, unit)
	end
end

local function canEnter(link: Link): boolean
	local last = link.items[#link.items]
	return last == nil or last.elapsed >= BELT_SPACING_SECONDS
end

function ProductionLine:_stepLink(link: Link, dt: number)
	local limit = link.travelSeconds
	for _, entry in link.items do
		entry.elapsed = math.min(entry.elapsed + dt, limit)
		-- Items keep order and queue behind a stopped head (spec 4.5).
		limit = math.max(0, entry.elapsed - BELT_SPACING_SECONDS)
	end

	local head = link.items[1]
	if head == nil then
		link.state, link.reason = "Empty", ""
		return
	end
	if head.elapsed < link.travelSeconds then
		link.state, link.reason = "Moving", ""
		return
	end
	if not portAccepts(link.to, link.toPort, head.unit.item) then
		-- Spec 15.1: hold the wrong item at the port and name both materials.
		link.state = "InvalidItem"
		link.reason = string.format(
			"%s needs %s, received %s",
			link.to.definition.DisplayName,
			requiredItemText(link.to, link.toPort),
			head.unit.item
		)
		return
	end
	if canAccept(link.to, link.toPort, head.unit.item) then
		table.remove(link.items, 1)
		self:_deliver(link.to, head.unit)
		link.state, link.reason = if #link.items > 0 then "Moving" else "Empty", ""
	else
		link.state = "BackedUp"
		link.reason = link.to.definition.DisplayName .. " input is full"
	end
end

-- An Out port that vents while unconnected never holds anything.
local function venting(port: Port): boolean
	return port.vent and port.link == nil
end

local function outPortFor(node: Node, item: string): Port?
	for _, port in node.ports do
		if port.direction == "Out" and port.item == item then
			return port
		end
	end
	return nil
end

-- Moves finished units into the output buffer while their port has room.
local function flushHeld(node: Node)
	local index = 1
	while index <= #node.held do
		local unit = node.held[index]
		local port = outPortFor(node, unit.item)
		local capacity = if port then port.capacity else node.definition.OutputCapacity
		if countItem(node.output, unit.item) < capacity then
			table.insert(node.output, table.remove(node.held, index) :: Unit)
		else
			index += 1
		end
	end
end

-- Why a processor cannot start: the first Out port without room, else the missing inputs.
local function blockedReason(node: Node): string?
	for _, port in portsOf(node, "Out") do
		if port.perCycle > 0 and not venting(port) then
			local room = port.capacity - countItem(node.output, port.item)
			if countItem(node.held, port.item) > 0 or room < port.perCycle then
				if port.name ~= "Out" then
					return string.format("%s output full", tostring(port.item))
				end
				return if port.link
					then "Output full, conveyor backed up"
					else "Output full, no conveyor connected"
			end
		end
	end
	return nil
end

local function starvedReason(node: Node): string?
	local missing = {}
	for _, port in portsOf(node, "In") do
		local short = port.perCycle - countItem(node.input, port.item)
		if short > 0 then
			table.insert(missing, string.format("%d %s", short, tostring(port.item)))
		end
	end
	return if #missing > 0 then "Missing " .. table.concat(missing, ", ") else nil
end

function ProductionLine:_finishCycle(node: Node)
	local definition = node.definition
	node.cycling = false
	node.progress = 0
	table.clear(node.reserved)
	for _, port in portsOf(node, "Out") do
		local item = port.item
		if item then
			for _ = 1, port.perCycle do
				local unit = self:_newUnit(item, node.owner)
				if venting(port) then
					-- Unpiped gas is flared off (the kiln's flame); it never blocks the machine.
					self:_emit({
						type = "Vented",
						nodeId = node.id,
						owner = node.owner,
						unitId = unit.id,
						item = item,
					})
				else
					table.insert(node.held, unit)
				end
			end
		end
	end
	node.completedCycles += 1
	self:_emit({
		type = "CycleComplete",
		nodeId = node.id,
		owner = node.owner,
		item = definition.OutputItem,
	})
	if definition.OperatingCostPerCycle then
		self:_emit({
			type = "OperatingCost",
			nodeId = node.id,
			owner = node.owner,
			amount = definition.OperatingCostPerCycle,
		})
	end
	flushHeld(node)
end

function ProductionLine:_stepProcessor(node: Node, dt: number)
	local cycleSeconds = self:CycleSeconds(node)
	if node.paused then
		-- Pausing preserves progress and stored items (spec 4.3).
		node.state, node.reason = "Paused", "Paused by player"
		return
	end

	flushHeld(node)

	if node.cycling then
		node.progress += dt
		if node.progress >= cycleSeconds then
			self:_finishCycle(node)
		else
			node.state = "Processing"
			node.reason = string.format("%.0fs remaining", cycleSeconds - node.progress)
			return
		end
	end

	local blocked = blockedReason(node)
	local starved = if blocked then nil else starvedReason(node)
	if blocked then
		node.state, node.reason = "Blocked", blocked
	elseif starved then
		node.state, node.reason = "Starved", starved
	else
		for _, port in portsOf(node, "In") do
			for _ = 1, port.perCycle do
				table.insert(node.reserved, takeItem(node.input, port.item) :: Unit)
			end
		end
		node.cycling = true
		node.progress = 0
		node.state = "Processing"
		node.reason = string.format("%.0fs remaining", cycleSeconds)
	end
end

function ProductionLine:_pushOutput(node: Node)
	if node.paused or #node.output == 0 then
		return
	end
	for _, port in portsOf(node, "Out") do
		local link = port.link
		if link and canEnter(link) then
			local unit: Unit? = nil
			if port.item then
				unit = takeItem(node.output, port.item)
			elseif node.kind == "Storage" then
				-- Storage only releases an item the destination accepts, so belts never fill with
				-- wrong items.
				local first = node.output[1]
				if first and portAccepts(link.to, link.toPort, first.item) then
					unit = table.remove(node.output, 1)
				end
			else
				unit = table.remove(node.output, 1)
			end
			if unit then
				table.insert(link.items, { unit = unit, elapsed = 0 })
			end
		end
	end
end

-- Spec 7.3 operating states: Empty, Filling, Releasing, Full, Output Blocked, Wrong Item, Paused.
function ProductionLine:_stepStorage(node: Node)
	local count = #node.output
	local capacity = node.definition.Capacity
	local inLink = node.inLink
	local outLink = node.outLink
	if inLink and inLink.state == "InvalidItem" then
		node.state, node.reason = "WrongItem", inLink.reason
	elseif node.paused then
		node.state, node.reason = "Paused", "Output paused by player"
	elseif count >= capacity then
		node.state, node.reason = "Full", string.format("Full, %d of %d bundles", count, capacity)
	elseif count == 0 then
		local locked = storageItem(node)
		node.state = "Empty"
		node.reason = if locked then "Accepts " .. locked else "Accepts any straw"
	elseif outLink == nil then
		node.state, node.reason = "Filling", "Storing, no output conveyor"
	elseif not portAccepts(outLink.to, outLink.toPort, node.output[1].item) then
		node.state = "OutputBlocked"
		node.reason = string.format(
			"%s needs %s",
			outLink.to.definition.DisplayName,
			requiredItemText(outLink.to, outLink.toPort)
		)
	elseif outLink.state == "BackedUp" then
		node.state, node.reason = "OutputBlocked", "Output conveyor backed up"
	else
		node.state, node.reason = "Releasing", ""
	end
end

function ProductionLine:_stepSource(node: Node)
	if node.paused then
		node.state, node.reason = "Paused", "Paused by player"
	elseif #node.output == 0 then
		node.state, node.reason = "Empty", "Deposit wet straw here"
	elseif node.outLink == nil then
		node.state, node.reason = "OutputBlocked", "No conveyor connected"
	elseif #node.output >= node.definition.OutputCapacity then
		node.state, node.reason = "Full", "Full"
	else
		node.state, node.reason = "Releasing", ""
	end
end

function ProductionLine:_substep(dt: number)
	for _, link in self.links do
		self:_stepLink(link, dt)
	end
	for _, node in self.nodes do
		if node.kind == "Processor" then
			self:_stepProcessor(node, dt)
		elseif node.kind == "Source" then
			self:_stepSource(node)
		elseif node.kind == "Storage" then
			self:_stepStorage(node)
		else
			node.state, node.reason = "Waiting", ""
		end
		self:_pushOutput(node)
	end
end

-- Advances the simulation and returns the events produced during this step.
function ProductionLine:Step(dt: number): { Event }
	local remaining = dt
	while remaining > 1e-9 do
		local step = math.min(MAX_SUBSTEP, remaining)
		self:_substep(step)
		remaining -= step
	end
	local events = self.events
	self.events = {}
	return events
end

return ProductionLine
