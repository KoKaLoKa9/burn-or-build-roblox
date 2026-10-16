--!strict

-- Server-authoritative production simulation for the P0 straw pellet line.
-- Pure Luau with no Roblox instances, so tests/ProductionLine.spec.luau can run it in Lune.
-- Follows spec v0.2 section 4.3 (machine cycle logic), 4.5 (conveyor item behavior), and
-- 7.3 (covered buffer storage).

local ProductionLine = {}
ProductionLine.__index = ProductionLine

local BELT_SPACING_SECONDS = 2
local MAX_SUBSTEP = 0.1

-- owner is the player whose machine created the unit; sales pay that player.
export type Unit = { id: number, item: string, owner: any }

export type Link = {
	id: number,
	from: any,
	to: any,
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
	return self
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

local function acceptedItem(node: Node): string?
	local definition = node.definition
	if node.kind == "Processor" then
		return definition.InputItem
	end
	return definition.AcceptsItem
end

-- The material a storage node is locked to: the player's choice, else its stored contents.
local function storageItem(node: Node): string?
	if node.filter then
		return node.filter
	end
	local first = node.output[1]
	return if first then first.item else nil
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
	end
	return acceptedItem(node) == item
end

local function requiredItemText(node: Node): string
	if node.kind == "Storage" then
		return storageItem(node) or "straw"
	end
	return tostring(acceptedItem(node))
end

-- Every material this node could release. An empty, unfiltered storage could release any straw.
local function outputItems(node: Node): { string }
	if node.kind == "Sink" or node.kind == "Terminal" then
		return {}
	elseif node.kind == "Storage" then
		local locked = storageItem(node)
		return if locked then { locked } else node.definition.StoresItems
	end
	local item = node.definition.OutputItem
	return if item then { item } else {}
end

local function canAccept(node: Node, item: string): boolean
	if not acceptsType(node, item) then
		return false
	end
	if node.kind == "Processor" then
		return #node.input < node.definition.InputCapacity
	elseif node.kind == "Source" then
		return #node.output < node.definition.OutputCapacity
	elseif node.kind == "Storage" then
		return #node.output < node.definition.Capacity
	end
	return true
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
	return #node.input == 0
		and #node.output == 0
		and #node.held == 0
		and #node.reserved == 0
		and (node.inLink == nil or #(node.inLink :: Link).items == 0)
		and (node.outLink == nil or #(node.outLink :: Link).items == 0)
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
	if node.inLink then
		self:_removeLink(node.inLink)
	end
	if node.outLink then
		self:_removeLink(node.outLink)
	end
	self.nodes[nodeId] = nil
	return true, "Dismantled."
end

function ProductionLine:_removeLink(link: Link)
	if link.from.outLink == link then
		link.from.outLink = nil
	end
	if link.to.inLink == link then
		link.to.inLink = nil
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

function ProductionLine:Connect(
	fromId: number,
	toId: number,
	travelSeconds: number
): (Link?, string)
	local from = self.nodes[fromId]
	local to = self.nodes[toId]
	if from == nil or to == nil then
		return nil, "Select two existing machines."
	end
	if from == to then
		return nil, "A machine cannot feed itself."
	end
	local candidates = outputItems(from)
	if #candidates == 0 then
		return nil, from.definition.DisplayName .. " has no output port."
	end
	local hasInput = to.kind == "Processor" or to.kind == "Sink" or to.kind == "Storage"
	if not hasInput and not (to.kind == "Source" and from.kind == "Source") then
		return nil, to.definition.DisplayName .. " has no input for that line."
	end
	local item: string? = nil
	for _, candidate in candidates do
		if acceptsType(to, candidate) then
			item = candidate
			break
		end
	end
	if item == nil then
		return nil,
			string.format(
				"This port cannot carry that material. %s needs %s, but %s outputs %s.",
				to.definition.DisplayName,
				requiredItemText(to),
				from.definition.DisplayName,
				candidates[1]
			)
	end
	if from.outLink then
		return nil, "This output already feeds a line. A splitter is required for a second line."
	end
	if to.inLink then
		return nil, to.definition.DisplayName .. " input is already connected."
	end

	local link: Link = {
		id = self.nextLinkId,
		from = from,
		to = to,
		travelSeconds = math.max(0.5, travelSeconds),
		items = {},
		state = "Empty",
		reason = "",
	}
	self.nextLinkId += 1
	self.links[link.id] = link
	from.outLink = link
	to.inLink = link
	return link, "Connected."
end

function ProductionLine:Deposit(nodeId: number, count: number, owner: any?): number
	local node = self.nodes[nodeId]
	if node == nil or node.kind ~= "Source" then
		return 0
	end
	local accepted = 0
	local item = node.definition.AcceptsItem
	while accepted < count and canAccept(node, item) do
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
			amount = node.definition.SalePrice,
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
	if not acceptsType(link.to, head.unit.item) then
		-- Spec 15.1: hold the wrong item at the port and name both materials.
		link.state = "InvalidItem"
		link.reason = string.format(
			"%s needs %s, received %s",
			link.to.definition.DisplayName,
			requiredItemText(link.to),
			head.unit.item
		)
		return
	end
	if canAccept(link.to, head.unit.item) then
		table.remove(link.items, 1)
		self:_deliver(link.to, head.unit)
		link.state, link.reason = if #link.items > 0 then "Moving" else "Empty", ""
	else
		link.state = "BackedUp"
		link.reason = link.to.definition.DisplayName .. " input is full"
	end
end

local function flushHeld(node: Node)
	while #node.held > 0 and #node.output < node.definition.OutputCapacity do
		table.insert(node.output, table.remove(node.held, 1) :: Unit)
	end
end

function ProductionLine:_stepProcessor(node: Node, dt: number)
	local definition = node.definition
	if node.paused then
		-- Pausing preserves progress and stored items (spec 4.3).
		node.state, node.reason = "Paused", "Paused by player"
		return
	end

	flushHeld(node)

	if node.cycling then
		node.progress += dt
		if node.progress >= definition.CycleSeconds then
			node.cycling = false
			node.progress = 0
			table.clear(node.reserved)
			for _ = 1, definition.OutputPerCycle do
				table.insert(node.held, self:_newUnit(definition.OutputItem, node.owner))
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
		else
			node.state = "Processing"
			node.reason = string.format("%.0fs remaining", definition.CycleSeconds - node.progress)
			return
		end
	end

	local outputRoom = definition.OutputCapacity - #node.output
	if #node.held > 0 or outputRoom < definition.OutputPerCycle then
		node.state = "Blocked"
		node.reason = if node.outLink
			then "Output full, conveyor backed up"
			else "Output full, no conveyor connected"
	elseif #node.input < definition.InputPerCycle then
		node.state = "Starved"
		node.reason = string.format(
			"Missing %d %s",
			definition.InputPerCycle - #node.input,
			definition.InputItem
		)
	else
		for _ = 1, definition.InputPerCycle do
			table.insert(node.reserved, table.remove(node.input, 1) :: Unit)
		end
		node.cycling = true
		node.progress = 0
		node.state = "Processing"
		node.reason = string.format("%.0fs remaining", definition.CycleSeconds)
	end
end

function ProductionLine:_pushOutput(node: Node)
	local link = node.outLink
	if node.paused or link == nil or #node.output == 0 then
		return
	end
	-- Storage only releases an item the destination accepts, so belts never fill with wrong items.
	if node.kind == "Storage" and not acceptsType(link.to, node.output[1].item) then
		return
	end
	if canEnter(link) then
		table.insert(link.items, { unit = table.remove(node.output, 1) :: Unit, elapsed = 0 })
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
	elseif not acceptsType(outLink.to, node.output[1].item) then
		node.state = "OutputBlocked"
		node.reason = string.format(
			"%s needs %s",
			outLink.to.definition.DisplayName,
			requiredItemText(outLink.to)
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
