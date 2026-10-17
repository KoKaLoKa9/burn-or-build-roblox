--!strict

-- Owns the live production line: placement, conveyors, intake deposits, sales, and machine visuals.
-- All counts live in the ProductionLine simulation; the parts here only display that state.
-- Other services extend a machine kind (for example the truck terminal) through kind handlers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemDefinitions = require(Shared:WaitForChild("ItemDefinitions"))
local MachineArt = require(Shared:WaitForChild("MachineArt"))
local PipeDefinitions = require(Shared:WaitForChild("PipeDefinitions"))
local PipeRoute = require(Shared:WaitForChild("PipeRoute"))
local ConveyorGrid = require(Shared:WaitForChild("ConveyorGrid"))
local ConveyorTile = require(Shared:WaitForChild("ConveyorTile"))
local MachineDefinitions = require(Shared:WaitForChild("MachineDefinitions"))
local ResearchDefinitions = require(Shared:WaitForChild("ResearchDefinitions"))
local PlacementRules = require(Shared:WaitForChild("PlacementRules"))
local PaddySites = require(Shared:WaitForChild("PaddySites"))

local CommitmentDefinitions = require(Shared:WaitForChild("CommitmentDefinitions"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local Simulation = script.Parent.Parent:WaitForChild("Simulation")
local ProductionLine = require(Simulation:WaitForChild("ProductionLine"))

local MachineService = {}

local TICK_SECONDS = 0.2
local NORMAL_REFUND_RATE = 0.7
-- Placed so its OUT port lines up with a conveyor cell.
local INTAKE_POSITION = Vector3.new(-60, 1.5, 92)
local ROAD_NAMES = { "MainRoad", "FactoryRoad" }
local STORAGE_FILTER_CYCLE: { string } = { "WetStraw", "DryStraw", "ShreddedStraw" }
-- The graybox's fixed machine placeholders. Players build their own line, so they are removed.
local PLACEHOLDER_NAMES = { "DryerPlaceholder", "ShredderPlaceholder", "PelletMillPlaceholder" }

type MachineRecord = {
	node: any,
	model: Model,
	statusLabel: TextLabel,
	cost: number,
	owner: Player?,
	exhaust: ParticleEmitter?,
	-- Farm machines only: the paddy the machine works.
	paddy: Model?,
}

-- Hooks another service registers for a machine Kind.
type KindHandler = {
	onPlaced: ((record: MachineRecord) -> ())?,
	canDismantle: ((record: MachineRecord) -> (boolean, string))?,
	onRemoved: ((record: MachineRecord) -> ())?,
	describe: ((record: MachineRecord) -> string)?,
}

type PipeVisual = {
	legs: { BasePart },
	joints: { BasePart },
	points: { Vector3 },
	length: number,
	baseColor: Color3,
	label: TextLabel,
	itemParts: { BasePart },
}

local line = ProductionLine.new(MachineDefinitions)
local records: { [number]: MachineRecord } = {}
local belts: { [number]: PipeVisual } = {}
local blockers: { [number]: PlacementRules.Rect } = {}
local kindHandlers: { [string]: KindHandler } = {}
local roadRects: { PlacementRules.Rect } = {}
local intakeNodeId = 0

type TileRecord = { ix: number, iz: number, dir: number, owner: Player?, model: Model? }
type BeltLink = { linkId: number, toId: number, toPort: string, signature: string }
local tiles: { [string]: TileRecord } = {}
-- Keyed by "<machine id>:<port name>" of the output port the belt starts at.
local conveyorLinks: { [string]: BeltLink } = {}
-- A traced chain of tiles from one output port to one input port.
type BeltWant = {
	fromId: number,
	fromPort: string,
	toId: number,
	toPort: string,
	cells: { string },
	port: BasePart,
}
local conveyorFolder: Folder
-- Filled in by the conveyor section below. A placed or removed machine can complete or break belts.
local onMachinesChanged: () -> () = function() end
local tileRects: () -> { PlacementRules.Rect } = function()
	return {}
end

local playerState: any
local productionFolder: Folder
local beltFolder: Folder
local plotRect: PlacementRules.Rect
local floorTopY = 1
local noticeEvent: RemoteEvent

local function notify(player: Player?, message: string)
	if player and player.Parent then
		noticeEvent:FireClient(player, message)
	end
end

local function readable(state: string): string
	return (string.gsub(state, "(%l)(%u)", "%1 %2"))
end

local function itemName(itemId: string?): string
	local item = if itemId then ItemDefinitions[itemId] else nil
	return if item then item.DisplayName else "any straw"
end

-- Text capacity bar so fill level never relies on color alone (spec 14.3).
local function capacityBar(count: number, capacity: number): string
	local filled = math.clamp(count, 0, capacity)
	return "[" .. string.rep("#", filled) .. string.rep(".", capacity - filled) .. "]"
end

local function newPart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	parent: Instance
): Part
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.CFrame = cframe
	item.Anchored = true
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Material = Enum.Material.SmoothPlastic
	item.Color = color
	item.Parent = parent
	return item
end

local function createBillboard(
	parent: BasePart,
	size: UDim2,
	offsetY: number,
	textSize: number?
): TextLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Status"
	billboard.Size = size
	billboard.StudsOffset = Vector3.new(0, offsetY, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 160
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 29, 25)
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(247, 241, 220)
	if textSize then
		label.TextSize = textSize
	else
		label.TextScaled = true
	end
	label.TextWrapped = true
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	return label
end

-- Labels on the factory floor are sized in studs, so they shrink with distance like the
-- machines do, and they are not drawn through other machines. This keeps a busy floor readable.
local function createWorldLabel(
	parent: BasePart,
	widthStuds: number,
	heightStuds: number,
	offsetY: number,
	maxDistance: number
): TextLabel
	local label = createBillboard(parent, UDim2.fromScale(widthStuds, heightStuds), offsetY)
	label.RichText = true
	local billboard = label.Parent :: BillboardGui
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = maxDistance
	return label
end

-- Ports carry a word as well as a color so input and output never rely on color alone (spec 14.3).
-- Attributes name the simulation port, so belts and the build tool can find every port.
local PORT_COLORS: { [string]: Color3 } = {
	Item = Color3.fromRGB(54, 157, 145),
	Fluid = Color3.fromRGB(table.unpack(PipeDefinitions.Types.Fluid.Color)),
	Gas = Color3.fromRGB(table.unpack(PipeDefinitions.Types.Gas.Color)),
}

local function createPort(
	model: Model,
	name: string,
	cframe: CFrame,
	text: string,
	spec: ProductionLine.PortSpec
): Part
	local medium = spec.Medium or "Item"
	local port = newPart(name, Vector3.new(2, 2, 5), cframe, PORT_COLORS[medium], model)
	port.Material = Enum.Material.Neon
	port.CanCollide = false
	port.CanQuery = false
	port:SetAttribute("PortName", spec.Name)
	port:SetAttribute("PortDirection", spec.Direction)
	port:SetAttribute("PortMedium", medium)
	createWorldLabel(port, 2.6, 1.3, 2, 60).Text = text
	return port
end

-- The primary ports keep their old part names; extra ports add their name, such as OutputPortGas.
local function portPartName(spec: ProductionLine.PortSpec): string
	local base = if spec.Direction == "In" then "InputPort" else "OutputPort"
	if spec.Name == "In" or spec.Name == "Out" then
		return base
	end
	return base .. spec.Name
end

local function portText(spec: ProductionLine.PortSpec): string
	if spec.Medium and spec.Medium ~= "Item" then
		return string.upper(spec.Medium)
	end
	return if spec.Direction == "In" then "IN" else "OUT"
end

-- A port sits just outside one side of the body, Offset studs along that side, low on the wall.
-- North and South ports turn so their long edge runs along the wall.
local function portCFrame(bodyCFrame: CFrame, size: Vector3, spec: ProductionLine.PortSpec): CFrame
	local side = spec.Side or (if spec.Direction == "In" then "West" else "East")
	local offset = spec.Offset or 0
	local height = -size.Y / 2 + 1.5
	if side == "North" or side == "South" then
		local z = if side == "North" then -size.Z / 2 - 1 else size.Z / 2 + 1
		return bodyCFrame * CFrame.new(offset, height, z) * CFrame.Angles(0, math.rad(90), 0)
	end
	local x = if side == "West" then -size.X / 2 - 1 else size.X / 2 + 1
	return bodyCFrame * CFrame.new(x, height, offset)
end

local function createMachinePorts(model: Model, bodyCFrame: CFrame, size: Vector3, definition: any)
	for _, spec in ProductionLine.PortSpecs(definition) do
		local cframe = portCFrame(bodyCFrame, size, spec)
		createPort(model, portPartName(spec), cframe, portText(spec), spec)
	end
end

local function createPrompt(
	parent: BasePart,
	name: string,
	actionText: string,
	objectText: string,
	key: Enum.KeyCode,
	holdDuration: number
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = key
	prompt.HoldDuration = holdDuration
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

-- Prompts on the same part draw on top of each other, so stack them in creation order,
-- first prompt on top.
local PROMPT_SPACING = 80

local function stackPrompts(prompts: { ProximityPrompt })
	local middle = (#prompts + 1) / 2
	for index, prompt in prompts do
		-- Positive Y moves a prompt up, so earlier prompts get the larger offset.
		prompt.UIOffset = Vector2.new(0, (middle - index) * PROMPT_SPACING)
	end
end

-- Every port part on a machine model.
local function portParts(record: MachineRecord): { BasePart }
	local list = {}
	for _, child in record.model:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("PortDirection") ~= nil then
			table.insert(list, child)
		end
	end
	return list
end

local function register(
	node: any,
	model: Model,
	statusLabel: TextLabel,
	cost: number,
	owner: Player?
)
	model:SetAttribute("MachineId", node.id)
	model:SetAttribute("DefinitionId", node.definitionId)
	model:SetAttribute("OwnerUserId", if owner then owner.UserId else 0)
	records[node.id] = {
		node = node,
		model = model,
		statusLabel = statusLabel,
		cost = cost,
		owner = owner,
	}
end

local function removeBelt(linkId: number)
	local visual = belts[linkId]
	if visual then
		for _, list in { visual.legs, visual.joints, visual.itemParts } do
			for _, part in list do
				part:Destroy()
			end
		end
		belts[linkId] = nil
	end
end

-- Inventory: machines a player has bought but not placed. Stored as Owned_<DefinitionId> player
-- attributes, so the client inventory and hotbar can show the counts.
local MAX_BUY = 10

local function owned(player: Player, definitionId: string): number
	local value = player:GetAttribute("Owned_" .. definitionId)
	return if typeof(value) == "number" then value else 0
end

local function setOwned(player: Player, definitionId: string, count: number)
	player:SetAttribute("Owned_" .. definitionId, math.max(0, count))
end

local function refundRate(player: Player): number
	-- Spec 3.2: full value back during the tutorial, 70 percent afterwards.
	return if player:GetAttribute("TutorialComplete") then NORMAL_REFUND_RATE else 1
end

-- Why this player may not have another of this machine right now, if anything stops it.
local function purchaseBlock(player: Player, definitionId: string, extra: number): string?
	local definition = MachineDefinitions[definitionId]
	if definition == nil or not definition.Placeable then
		return "That item is not for sale."
	end
	if definition.Research and player:GetAttribute("Research_" .. definition.Research) ~= true then
		local project = ResearchDefinitions.Projects[definition.Research]
		return string.format(
			"Research %s at the cooperative office first.",
			if project then string.lower(project.DisplayName) else definition.Research
		)
	end
	if definition.UnlockAfterFirstSale and player:GetAttribute("TutorialComplete") ~= true then
		return definition.DisplayName .. " unlocks after your first sale."
	end
	if definition.MaxPerPlayer then
		local total = owned(player, definitionId) + extra
		for _, record in records do
			if record.owner == player and record.node.definitionId == definitionId then
				total += 1
			end
		end
		if total > definition.MaxPerPlayer then
			return string.format(
				"You can have only %d %s.",
				definition.MaxPerPlayer,
				string.lower(definition.DisplayName)
			)
		end
	end
	return nil
end

local function buyItem(player: Player, definitionId: unknown, count: unknown): (boolean, string)
	if typeof(definitionId) ~= "string" or typeof(count) ~= "number" then
		return false, "Invalid purchase."
	end
	local amount = math.clamp(math.floor(count), 1, MAX_BUY)
	local blocked = purchaseBlock(player, definitionId, amount)
	if blocked then
		return false, blocked
	end
	local definition = MachineDefinitions[definitionId]
	local price = definition.Cost * amount
	if playerState:GetCredits(player) < price then
		return false, string.format("That costs %d credits.", price)
	end
	playerState:AdjustCredits(player, -price, "Construction")
	setOwned(player, definitionId, owned(player, definitionId) + amount)
	return true,
		string.format(
			"Bought %d %s for %d credits. Find it in your inventory (B).",
			amount,
			string.lower(definition.DisplayName),
			price
		)
end

local function sellItem(player: Player, definitionId: unknown): (boolean, string)
	if typeof(definitionId) ~= "string" or MachineDefinitions[definitionId] == nil then
		return false, "Invalid sale."
	end
	if owned(player, definitionId) <= 0 then
		return false, "You have none of those in your inventory."
	end
	local definition = MachineDefinitions[definitionId]
	local refund = math.floor(definition.Cost * refundRate(player))
	setOwned(player, definitionId, owned(player, definitionId) - 1)
	playerState:AdjustCredits(player, refund, "Refund")
	return true,
		string.format("Sold a %s for %d credits.", string.lower(definition.DisplayName), refund)
end

local function dismantle(player: Player, nodeId: number)
	local record = records[nodeId]
	if record == nil or record.owner ~= player then
		notify(player, "You can only dismantle your own machines.")
		return
	end
	local handler = kindHandlers[record.node.kind]
	if handler and handler.canDismantle then
		local allowed, reason = handler.canDismantle(record)
		if not allowed then
			notify(player, reason)
			return
		end
	end
	local linkIds = {}
	for _, link in line:LinksOf(record.node) do
		table.insert(linkIds, link.id)
	end
	local ok, message = line:RemoveNode(nodeId)
	if not ok then
		notify(player, message)
		return
	end
	for _, linkId in linkIds do
		removeBelt(linkId)
	end
	-- The machine goes back into the inventory, ready to place again or sell.
	setOwned(player, record.node.definitionId, owned(player, record.node.definitionId) + 1)
	if handler and handler.onRemoved then
		handler.onRemoved(record)
	end
	record.model:Destroy()
	records[nodeId] = nil
	onMachinesChanged()
	blockers[nodeId] = nil
	notify(
		player,
		string.format(
			"Picked up the %s. It is back in your inventory (B).",
			string.lower(record.node.definition.DisplayName)
		)
	)
end

local function togglePause(player: Player, nodeId: number)
	local record = records[nodeId]
	if record == nil or record.owner ~= player then
		notify(player, "You can only pause your own machines.")
		return
	end
	local paused = not record.node.paused
	line:SetPaused(nodeId, paused)
	notify(
		player,
		string.format(
			"%s %s.",
			record.node.definition.DisplayName,
			if paused then "paused" else "resumed"
		)
	)
end

-- Spec 7.3: the player chooses the accepted material. Cycles through each straw type, then any.
local function cycleStorageFilter(player: Player, nodeId: number)
	local record = records[nodeId]
	if record == nil or record.owner ~= player then
		notify(player, "You can only configure your own storage.")
		return
	end
	-- Stored items lock the type, so a filled storage only toggles between that type and any.
	local stored = record.node.output[1]
	local options = if stored then { stored.item } else STORAGE_FILTER_CYCLE
	local current = record.node.filter
	local index = if current then table.find(options, current) or 0 else 0
	local ok, message = line:SetStorageFilter(nodeId, options[index + 1])
	notify(
		player,
		if ok
			then "Covered storage now accepts " .. itemName(
				record.node.filter or (if stored then stored.item else nil)
			) .. "."
			else message
	)
end

-- Working machines breathe a little white steam from their stack: a thin wisp while they wait
-- for straw, a steady plume while they process. It is steam, not PM2.5, so it adds no exposure.
local EXHAUST_RATE: { [string]: number } = {
	Processing = 7,
	Starved = 2.5,
	Blocked = 2.5,
	Idle = 2.5,
	Paused = 0,
}

local function createExhaust(body: BasePart, definition: any): ParticleEmitter?
	local offset = definition.ExhaustOffset
	local position: Vector3? = if offset
		then Vector3.new(offset.X, offset.Y - body.Size.Y / 2, offset.Z)
		else nil
	if position == nil and definition.ExhaustPart and body.Parent then
		-- No fixed offset: rise from the top of the named part of the imported model.
		local stack = body.Parent:FindFirstChild(definition.ExhaustPart, true)
		if stack and stack:IsA("BasePart") then
			position =
				body.CFrame:PointToObjectSpace(stack.Position + Vector3.new(0, stack.Size.Y / 2, 0))
		end
	end
	if position == nil then
		return nil
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "Exhaust"
	attachment.Position = position
	attachment.Parent = body

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Steam"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(238, 238, 232))
	emitter.LightInfluence = 0.6
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 5),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.2, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(2.5, 4)
	emitter.Speed = NumberRange.new(3, 5)
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-20, 20)
	-- Drifts east with the district wind.
	emitter.Acceleration = Vector3.new(1.2, 0.6, 0)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = 0
	if definition.Flare then
		-- Syngas is flared off for now: a warm, smoky plume instead of white steam.
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 170, 90), Color3.fromRGB(90, 84, 78))
		emitter.LightEmission = 0.4
	end
	emitter.Parent = attachment
	return emitter
end

-- Imported Blender models come from the shared MachineArt library. Without one, the machine
-- keeps its graybox body, so art never blocks gameplay.
local function attachArt(definitionId: string, model: Model, body: BasePart)
	local art = MachineArt.Build(definitionId)
	if art == nil then
		return
	end
	-- The invisible body stays the collision and click target.
	art:PivotTo(body.CFrame * CFrame.new(0, -body.Size.Y / 2, 0))
	art.Parent = model
	body.Transparency = 1
end

local function buildMachineModel(
	definition: any,
	bodyCFrame: CFrame,
	definitionId: string?
): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = definition.DisplayName
	local size = Vector3.new(definition.Size.X, definition.Size.Y, definition.Size.Z)
	local body =
		newPart("Body", size, bodyCFrame, Color3.fromRGB(table.unpack(definition.Color)), model)
	body.Material = Enum.Material.Metal
	model.PrimaryPart = body
	if definitionId then
		attachArt(definitionId, model, body)
	end
	createMachinePorts(model, bodyCFrame, size, definition)
	return model, body
end

local function placeMachine(
	player: Player,
	definitionId: unknown,
	position: unknown,
	rotation: unknown
): (boolean, string)
	if
		typeof(definitionId) ~= "string"
		or typeof(position) ~= "Vector3"
		or typeof(rotation) ~= "number"
	then
		return false, "Invalid placement request."
	end
	local definition = MachineDefinitions[definitionId]
	if definition == nil or not definition.Placeable then
		return false, "That object cannot be placed."
	end
	if position.X ~= position.X or position.Z ~= position.Z then
		return false, "Invalid placement request."
	end
	local rotationSteps = math.floor(rotation) % 4
	local fromInventory = owned(player, definitionId) > 0
	-- Week 6: research unlocks, and a cap on how many of a machine one player may own.
	if definition.Research and player:GetAttribute("Research_" .. definition.Research) ~= true then
		local project = ResearchDefinitions.Projects[definition.Research]
		return false,
			string.format(
				"Research %s at the cooperative office first.",
				if project then string.lower(project.DisplayName) else definition.Research
			)
	end
	if definition.MaxPerPlayer then
		local placedCount = 0
		for _, record in records do
			if record.owner == player and record.node.definitionId == definitionId then
				placedCount += 1
			end
		end
		if placedCount >= definition.MaxPerPlayer and not fromInventory then
			return false,
				string.format("You already have a %s.", string.lower(definition.DisplayName))
		end
	end

	local blockerList = {}
	for _, rect in blockers do
		table.insert(blockerList, rect)
	end
	for _, rect in tileRects() do
		table.insert(blockerList, rect)
	end
	local paddies, paddyModels = PaddySites.Collect(player.UserId)
	local ok, message = PlacementRules.Validate(
		definition,
		position,
		rotationSteps,
		plotRect,
		blockerList,
		-- A machine already in the inventory is paid for.
		if fromInventory then math.huge else playerState:GetCredits(player),
		{
			unlocked = player:GetAttribute("TutorialComplete") == true,
			roads = roadRects,
			roadReach = CommitmentDefinitions.Truck.RoadReach,
			paddies = paddies,
		}
	)
	if not ok then
		return false, message
	end
	-- Farm machines stand on the ground beside their paddy and remember which one they work.
	local groundY = floorTopY
	local paddy: Model? = nil
	if definition.PlaceNear == "Paddy" then
		local rect = PlacementRules.RectAt(definition, position, rotationSteps)
		local index, reason = PlacementRules.PaddyFor(rect, paddies, definition.PaddyReach or 12)
		if index == nil then
			return false, reason
		end
		groundY = paddies[index].groundY
		paddy = paddyModels[index]
	end

	if fromInventory then
		setOwned(player, definitionId, owned(player, definitionId) - 1)
	else
		playerState:AdjustCredits(player, -definition.Cost, "Construction")
	end
	local node = line:AddNode(definitionId, player)
	local bodyCFrame = PlacementRules.BodyCFrame(definition, position, rotationSteps, groundY)
	local model, body = buildMachineModel(definition, bodyCFrame, definitionId)
	local compact = definition.Kind == "Processor"
	local statusLabel = createWorldLabel(
		body,
		if compact then 11 else 15,
		if compact then 3.4 else 5.4,
		definition.Size.Y / 2 + 3,
		90
	)
	register(node, model, statusLabel, definition.Cost, player)
	records[node.id].paddy = paddy
	if compact then
		records[node.id].exhaust = createExhaust(body, definition)
	end
	blockers[node.id] = PlacementRules.RectAt(definition, position, rotationSteps)

	local prompts: { ProximityPrompt } = {}
	if definition.Kind == "Storage" then
		local materialPrompt = createPrompt(
			body,
			"MaterialPrompt",
			"Set material",
			definition.DisplayName,
			Enum.KeyCode.E,
			0
		)
		materialPrompt.Triggered:Connect(function(triggeringPlayer)
			cycleStorageFilter(triggeringPlayer, node.id)
		end)
		table.insert(prompts, materialPrompt)
	end
	if
		definition.Kind == "Processor"
		or definition.Kind == "Storage"
		or definition.Kind == "Farm"
	then
		local action = if definition.Kind == "Storage"
			then "Pause / resume output"
			else "Pause / resume"
		local pausePrompt =
			createPrompt(body, "PausePrompt", action, definition.DisplayName, Enum.KeyCode.F, 0)
		pausePrompt.Triggered:Connect(function(triggeringPlayer)
			togglePause(triggeringPlayer, node.id)
		end)
		table.insert(prompts, pausePrompt)
	end
	-- Dismantling happens through the Delete tool (X) in build mode, not a prompt.
	stackPrompts(prompts)

	model.Parent = productionFolder
	onMachinesChanged()
	local handler = kindHandlers[definition.Kind]
	if handler and handler.onPlaced then
		handler.onPlaced(records[node.id])
	end
	if fromInventory then
		return true, string.format("Placed %s from your inventory.", definition.DisplayName)
	end
	return true, string.format("Placed %s for %d credits.", definition.DisplayName, definition.Cost)
end

-- The direction a port faces, pointing away from its machine.
local function portDirection(record: MachineRecord, port: BasePart): Vector3
	local center = if record.model.PrimaryPart
		then record.model.PrimaryPart.Position
		else record.model:GetPivot().Position
	local offset = port.Position - center
	local horizontal = Vector3.new(offset.X, 0, offset.Z)
	return if horizontal.Magnitude > 1e-3 then horizontal.Unit else Vector3.xAxis
end

-- Conveyors ---------------------------------------------------------------------------------------
-- Players lay belts one tile at a time. Whenever tiles or machines change, every machine output is
-- traced along the tiles; a chain that ends pointing into an input becomes a simulation link.

local TILE_COST = PipeDefinitions.Types.Item.Cost
local PLOT_MARGIN = 2

local function itemHeight(): number
	return floorTopY + ConveyorTile.BeltTop + 0.55
end

-- The cell just outside a port, and the side of that cell that faces the machine.
local function accessCell(record: MachineRecord, port: BasePart): (string, number)
	local facing = portDirection(record, port)
	local point = port.Position + facing * 2
	local ix, iz = ConveyorGrid.CellOf(point.X, point.Z)
	local towardMachine = (ConveyorGrid.DirectionOf(facing.X, facing.Z) + 2) % 4
	return ConveyorGrid.Key(ix, iz), towardMachine
end

local function portKey(id: number, portName: string): string
	return tostring(id) .. ":" .. portName
end

type PortMaps = {
	outputs: { { record: MachineRecord, key: string, port: BasePart, name: string } },
	inputs: { [string]: { key: string, inward: number, id: number, name: string } },
	feedSides: { [string]: number },
	-- Keyed by portKey(machine id, port name).
	inputPorts: { [string]: BasePart },
}

-- Belt ends: every item port on every machine. Fluid and gas ports wait for their pipes.
local function collectPorts(): PortMaps
	local maps: PortMaps = { outputs = {}, inputs = {}, feedSides = {}, inputPorts = {} }
	for id, record in records do
		for _, port in portParts(record) do
			if port:GetAttribute("PortMedium") ~= "Item" then
				continue
			end
			local name = tostring(port:GetAttribute("PortName"))
			local key, side = accessCell(record, port)
			if port:GetAttribute("PortDirection") == "Out" then
				table.insert(maps.outputs, { record = record, key = key, port = port, name = name })
				maps.feedSides[key] = side
			else
				maps.inputs[key] = { key = key, inward = side, id = id, name = name }
				maps.inputPorts[portKey(id, name)] = port
			end
		end
	end
	return maps
end

local function renderTile(key: string, feedSides: { [string]: number })
	local tile = tiles[key]
	if tile == nil then
		return
	end
	if tile.model then
		tile.model:Destroy()
	end
	local open = ConveyorGrid.OpenSides(tiles :: any, tile :: any, feedSides[key])
	local model = ConveyorTile.Build(tile.dir, open)
	local x, z = ConveyorGrid.Center(tile.ix, tile.iz)
	model:PivotTo(CFrame.new(x, floorTopY, z))
	model:SetAttribute("CellX", tile.ix)
	model:SetAttribute("CellZ", tile.iz)
	model:SetAttribute("Dir", tile.dir)
	model:SetAttribute("OwnerUserId", if tile.owner then tile.owner.UserId else 0)
	model.Parent = conveyorFolder
	tile.model = model
end

local function renderAround(ix: number, iz: number, feedSides: { [string]: number })
	renderTile(ConveyorGrid.Key(ix, iz), feedSides)
	for side = 0, 3 do
		local nx, nz = ConveyorGrid.Step(ix, iz, side)
		renderTile(ConveyorGrid.Key(nx, nz), feedSides)
	end
end

local function cellRect(ix: number, iz: number): PlacementRules.Rect
	local x, z = ConveyorGrid.Center(ix, iz)
	local half = ConveyorGrid.CellSize / 2 - 0.05
	return { minX = x - half, maxX = x + half, minZ = z - half, maxZ = z + half }
end

tileRects = function(): { PlacementRules.Rect }
	local rects = {}
	for _, tile in tiles do
		table.insert(rects, cellRect(tile.ix, tile.iz))
	end
	return rects
end

local function inside(outer: PlacementRules.Rect, rect: PlacementRules.Rect): boolean
	return rect.minX >= outer.minX
		and rect.maxX <= outer.maxX
		and rect.minZ >= outer.minZ
		and rect.maxZ <= outer.maxZ
end

local function overlaps(a: PlacementRules.Rect, b: PlacementRules.Rect): boolean
	return a.minX < b.maxX and a.maxX > b.minX and a.minZ < b.maxZ and a.maxZ > b.minZ
end

-- Belts may run anywhere on the factory plot, plus a corridor out to the fixed pellet buyer.
local function buyerCorridor(): PlacementRules.Rect
	return { minX = plotRect.maxX - 8, maxX = 152, minZ = 118, maxZ = 172 }
end

local function signatureOf(cells: { string }): string
	return table.concat(cells, ";")
end

-- Re-traces every belt and keeps simulation links in step. Returns messages worth telling the
-- player, such as a belt that reached a machine that cannot take that material.
local function recomputeBelts(): { string }
	local maps = collectPorts()
	local messages: { string } = {}
	local wanted: { [string]: BeltWant } = {}
	for _, output in maps.outputs do
		local fromId = output.record.node.id
		local chain = ConveyorGrid.Trace(tiles :: any, output.key, maps.inputs :: any, fromId)
		if chain.toId and chain.toPort then
			wanted[portKey(fromId, output.name)] = {
				fromId = fromId,
				fromPort = output.name,
				toId = chain.toId,
				toPort = chain.toPort,
				cells = chain.cells,
				port = output.port,
			}
		end
	end

	for key, entry in conveyorLinks do
		local want = wanted[key]
		local alive = line.links[entry.linkId] ~= nil
		local same = want ~= nil
			and want.toId == entry.toId
			and want.toPort == entry.toPort
			and signatureOf(want.cells) == entry.signature
		if not alive then
			conveyorLinks[key] = nil
		elseif not same then
			local ok = line:Disconnect(entry.linkId)
			if ok then
				removeBelt(entry.linkId)
				conveyorLinks[key] = nil
			end
		end
	end

	for key, want in wanted do
		local fromId = want.fromId
		if conveyorLinks[key] == nil then
			local height = itemHeight()
			local points: { Vector3 } = {
				Vector3.new(want.port.Position.X, height, want.port.Position.Z),
			}
			for _, cell in want.cells do
				local tile = tiles[cell]
				local x, z = ConveyorGrid.Center(tile.ix, tile.iz)
				table.insert(points, Vector3.new(x, height, z))
			end
			local inPort = maps.inputPorts[portKey(want.toId, want.toPort)]
			table.insert(points, Vector3.new(inPort.Position.X, height, inPort.Position.Z))
			local length = PipeRoute.Length(points)

			local link, message = line:Connect(
				fromId,
				want.toId,
				length / PipeDefinitions.StudsPerSecond,
				want.fromPort,
				want.toPort
			)
			if link then
				conveyorLinks[key] = {
					linkId = link.id,
					toId = want.toId,
					toPort = want.toPort,
					signature = signatureOf(want.cells),
				}
				local middle = tiles[want.cells[math.max(1, math.ceil(#want.cells / 2))]]
				local anchor = if middle.model then middle.model.PrimaryPart else nil
				local label = createBillboard(
					anchor or (records[want.toId].model.PrimaryPart :: BasePart),
					UDim2.fromOffset(220, 40),
					3,
					15
				)
				label.TextColor3 = Color3.fromRGB(255, 196, 120)
				label.Visible = false
				belts[link.id] = {
					legs = {},
					joints = {},
					points = points,
					length = length,
					baseColor = Color3.new(1, 1, 1),
					label = label,
					itemParts = {},
				}
				table.insert(
					messages,
					string.format(
						"Belt connected: %s to %s.",
						records[fromId].node.definition.DisplayName,
						records[want.toId].node.definition.DisplayName
					)
				)
			else
				table.insert(messages, "Belt not connected: " .. message)
			end
		end
	end
	return messages
end

local function renderAllTiles()
	local maps = collectPorts()
	for key in tiles do
		renderTile(key, maps.feedSides)
	end
end

onMachinesChanged = function()
	renderAllTiles()
	recomputeBelts()
end

local function cellArguments(rawX: unknown, rawZ: unknown): (number?, number?)
	if typeof(rawX) ~= "number" or typeof(rawZ) ~= "number" then
		return nil, nil
	end
	if rawX ~= rawX or rawZ ~= rawZ or math.abs(rawX) > 1000 or math.abs(rawZ) > 1000 then
		return nil, nil
	end
	return math.floor(rawX), math.floor(rawZ)
end

local function placeConveyor(
	player: Player,
	rawX: unknown,
	rawZ: unknown,
	rawDir: unknown
): (boolean, string)
	local ix, iz = cellArguments(rawX, rawZ)
	if ix == nil or iz == nil or typeof(rawDir) ~= "number" then
		return false, "Invalid belt request."
	end
	local dir = math.floor(rawDir) % 4
	local key = ConveyorGrid.Key(ix, iz)
	local existing = tiles[key]
	if existing then
		if existing.owner ~= player then
			return false, "That belt belongs to another player."
		end
		if existing.dir == dir then
			return true, ""
		end
		existing.dir = dir
	else
		local rect = cellRect(ix, iz)
		local plotInner = {
			minX = plotRect.minX + PLOT_MARGIN,
			maxX = plotRect.maxX - PLOT_MARGIN,
			minZ = plotRect.minZ + PLOT_MARGIN,
			maxZ = plotRect.maxZ - PLOT_MARGIN,
		}
		if not inside(plotInner, rect) and not inside(buyerCorridor(), rect) then
			return false, "Belts must stay on the factory plot or the path to the buyer."
		end
		for _, blocker in blockers do
			if overlaps(rect, blocker) then
				return false, "A machine is in the way."
			end
		end
		if playerState:GetCredits(player) < TILE_COST then
			return false, "You need more credits for another belt tile."
		end
		playerState:AdjustCredits(player, -TILE_COST, "Construction")
		tiles[key] = { ix = ix, iz = iz, dir = dir, owner = player, model = nil }
	end

	local maps = collectPorts()
	renderAround(ix, iz, maps.feedSides)
	local messages = recomputeBelts()
	return true, if #messages > 0 then messages[#messages] else ""
end

local function removeConveyor(player: Player, rawX: unknown, rawZ: unknown): (boolean, string)
	local ix, iz = cellArguments(rawX, rawZ)
	if ix == nil or iz == nil then
		return false, "Invalid belt request."
	end
	local key = ConveyorGrid.Key(ix, iz)
	local tile = tiles[key]
	if tile == nil then
		return false, "There is no belt there."
	end
	if tile.owner ~= player then
		return false, "That belt belongs to another player."
	end
	-- Spec 15.1: never delete items in transit.
	for _, entry in conveyorLinks do
		local link = line.links[entry.linkId]
		local onPath = string.find(";" .. entry.signature .. ";", ";" .. key .. ";", 1, true)
		if link and #link.items > 0 and onPath then
			return false,
				"This belt is carrying straw. Pause the machine feeding it and let it clear."
		end
	end
	if tile.model then
		tile.model:Destroy()
	end
	tiles[key] = nil
	playerState:AdjustCredits(player, TILE_COST, "Refund")
	local maps = collectPorts()
	renderAround(ix, iz, maps.feedSides)
	recomputeBelts()
	return true, ""
end

local function createIntake(factory: Model)
	local definition = MachineDefinitions.CollectionPoint
	local model = Instance.new("Model")
	model.Name = "FactoryIntake"
	local body = newPart(
		"Body",
		Vector3.new(12, 1, 12),
		CFrame.new(INTAKE_POSITION),
		Color3.fromRGB(47, 155, 123),
		model
	)
	body.Material = Enum.Material.Neon
	model.PrimaryPart = body
	createPort(
		model,
		"OutputPort",
		CFrame.new(INTAKE_POSITION + Vector3.new(7, 0.5, 0)),
		"OUT",
		{ Name = "Out", Direction = "Out", Medium = "Item" }
	)

	local node = line:AddNode("CollectionPoint", nil)
	intakeNodeId = node.id
	-- The covered drop-off model replaces the plain green pad when it has been imported.
	attachArt("CollectionPoint", model, body)
	-- The count board floats just above the shed roof.
	local statusLabel = createWorldLabel(body, 6, 2.6, 11.2, 140)
	register(node, model, statusLabel, 0, nil)
	blockers[node.id] = PlacementRules.RectFromPart(body)

	createPrompt(
		body,
		"DepositPrompt",
		"Deposit straw",
		definition.DisplayName,
		Enum.KeyCode.E,
		0.25
	).Triggered:Connect(function(player)
		local rawCarried = player:GetAttribute("StrawBundles")
		local carried: number = if typeof(rawCarried) == "number" then rawCarried else 0
		if carried <= 0 then
			notify(player, "You are not carrying straw. Collect bundles at your rice field first.")
			return
		end
		local accepted = line:Deposit(node.id, carried, player)
		playerState:AddStraw(player, -accepted)
		if accepted < carried then
			notify(player, string.format("Deposited %d. The collection point is full.", accepted))
		else
			notify(
				player,
				string.format(
					"Deposited %d wet straw %s.",
					accepted,
					if accepted == 1 then "bundle" else "bundles"
				)
			)
		end
	end)
	model.Parent = factory
end

local function createBuyer(world: Model)
	local buyer = world:FindFirstChild("PelletBuyer")
	assert(buyer and buyer:IsA("Model"), "PelletBuyer model is missing from the graybox")
	local body = buyer:FindFirstChild("Body")
	assert(body and body:IsA("BasePart"), "PelletBuyer Body is missing")

	-- A saved place may still hold ports from an older run; the catalog decides the bays now.
	for _, child in buyer:GetChildren() do
		if child:IsA("BasePart") and string.match(child.Name, "^InputPort") then
			child:Destroy()
		end
	end
	createMachinePorts(buyer, body.CFrame, body.Size, MachineDefinitions.BuyerDepot)

	local node = line:AddNode("BuyerDepot", nil)
	-- Sized for the enlarged depot so the board reads as part of the landmark.
	local statusLabel = createWorldLabel(body, 36, 10.8, body.Size.Y / 2 + 7, 220)
	register(node, buyer, statusLabel, 0, nil)
end

-- The graybox placeholders and the neon grid lines are removed: the plot reads as a clean floor,
-- and grid snapping still works without the lines.
local function clearFactoryFloor(factory: Model)
	for _, name in PLACEHOLDER_NAMES do
		local placeholder = factory:FindFirstChild(name)
		if placeholder then
			placeholder:Destroy()
		end
	end
	for _, child in factory:GetChildren() do
		if child.Name == "GridLine" then
			child:Destroy()
		end
	end
end

local PROCESSOR_STATE_WORDS: { [string]: string } = {
	Processing = "Working",
	Starved = "Waiting for straw",
	Blocked = "Output full",
	Paused = "Paused",
	Idle = "Ready",
}
local PROCESSOR_STATE_COLORS: { [string]: string } = {
	Processing = "#68D88E",
	Starved = "#F6BE48",
	Blocked = "#F06246",
	Paused = "#92A49D",
	Idle = "#92A49D",
}

local function describe(record: MachineRecord): string
	local node = record.node
	local definition = node.definition
	local name = definition.DisplayName
	local handler = kindHandlers[node.kind]
	if handler and handler.describe then
		return handler.describe(record)
	end
	if node.kind == "Storage" then
		local stored = node.output[1]
		return string.format(
			"%s: %s\n%s\n%s %d/%d %s",
			name,
			string.upper(readable(node.state)),
			node.reason,
			capacityBar(#node.output, definition.Capacity),
			#node.output,
			definition.Capacity,
			itemName(node.filter or (if stored then stored.item else nil))
		)
	end
	if node.kind == "Source" then
		-- The floating arrow explains what this is; the board only counts.
		local full = #node.output >= definition.OutputCapacity
		return string.format(
			'<font color="%s">%d</font> / %d',
			if full then "#F6BE48" else "#F0EEE4",
			#node.output,
			definition.OutputCapacity
		)
	elseif node.kind == "Sink" and definition.Placeable then
		-- A market stall lists what it buys.
		local prices = {}
		for item, price in definition.Prices do
			table.insert(prices, string.format("%s %d", itemName(item), price))
		end
		table.sort(prices)
		return string.format(
			"%s\n%s\nSold: %d",
			name,
			table.concat(prices, "\n"),
			node.completedCycles
		)
	elseif node.kind == "Sink" then
		return string.format(
			"%s\n%d credits per crate\nCrates sold: %d",
			name,
			definition.SalePrice,
			node.completedCycles
		)
	end
	local word = PROCESSOR_STATE_WORDS[node.state] or readable(node.state)
	local color = PROCESSOR_STATE_COLORS[node.state] or "#F0EEE4"
	return string.format('%s\n<font color="%s">%s</font>', name, color, word)
end

local function refreshVisuals()
	for _, record in records do
		record.statusLabel.Text = describe(record)
		local exhaust = record.exhaust
		if exhaust then
			local rate = EXHAUST_RATE[record.node.state] or 0
			if exhaust.Rate ~= rate then
				exhaust.Rate = rate
			end
		end
	end

	for linkId, visual in belts do
		local link = line.links[linkId]
		if link == nil then
			removeBelt(linkId)
			continue
		end

		while #visual.itemParts < #link.items do
			local itemPart = newPart(
				"PipeItem",
				Vector3.new(1.3, 1.1, 1.3),
				CFrame.new(visual.points[1]),
				Color3.new(1, 1, 1),
				beltFolder
			)
			itemPart.CanCollide = false
			itemPart.CanQuery = false
			table.insert(visual.itemParts, itemPart)
		end
		while #visual.itemParts > #link.items do
			(table.remove(visual.itemParts) :: BasePart):Destroy()
		end

		-- Each visible bundle is one simulation unit (spec 4.5).
		for index, entry in link.items do
			local itemPart = visual.itemParts[index]
			local alpha = math.clamp(entry.elapsed / link.travelSeconds, 0, 1)
			itemPart.Position = PipeRoute.Sample(visual.points, alpha * visual.length)
			local item = ItemDefinitions[entry.unit.item]
			itemPart.Color = if item then item.Color else Color3.new(1, 0, 1)
			-- Sized to fit inside the glass pipe.
			itemPart.Size = if entry.unit.item == "PelletCrate"
				then Vector3.new(1.5, 1.4, 1.5)
				else Vector3.new(1.3, 1.1, 1.3)
		end

		-- A queue behind a busy machine is normal, so it only tints the pipe. Text is kept for
		-- real faults such as a wrong item.
		local warning = link.state == "BackedUp" or link.state == "InvalidItem"
		local fault = link.state == "InvalidItem"
		visual.label.Visible = fault
		visual.label.Text = if fault then readable(link.state) .. ": " .. link.reason else ""
		local tint = if warning
			then visual.baseColor:Lerp(Color3.fromRGB(240, 140, 70), 0.6)
			else visual.baseColor
		for _, leg in visual.legs do
			if leg.Color ~= tint then
				leg.Color = tint
			end
		end
	end
end

local function handleEvents(events: { any })
	for _, event in events do
		local owner = event.owner
		if typeof(owner) ~= "Instance" or not owner:IsA("Player") or owner.Parent == nil then
			continue
		end
		if event.type == "Sale" then
			local smog = GameConfig.Smog
			local distrusted = playerState:GetTrust(owner) < smog.LowTrust
			local amount = if distrusted
				then math.floor(event.amount * smog.LowTrustPrice + 0.5)
				else event.amount
			event.amount = amount
			playerState:AdjustCredits(owner, amount, "Sales")
			local firstSale = not owner:GetAttribute("TutorialComplete")
			playerState:RecordSale(owner)
			if firstSale then
				notify(
					owner,
					string.format(
						"First sale: +%d credits. Covered storage and the truck terminal are unlocked. Refunds are now 70 percent.",
						amount
					)
				)
			else
				notify(
					owner,
					string.format(
						"%s sold: +%d credits.%s",
						itemName(event.item),
						amount,
						if distrusted
							then " Low farmer trust cost you the clean-straw premium."
							else ""
					)
				)
			end
		elseif event.type == "OperatingCost" then
			playerState:AdjustCredits(owner, -event.amount, "Processing")
		end
	end
end

function MachineService:RegisterKindHandler(kind: string, handler: KindHandler)
	kindHandlers[kind] = handler
end

function MachineService:Notify(player: Player?, message: string)
	notify(player, message)
end

function MachineService:NotifyAll(message: string)
	noticeEvent:FireAllClients(message)
end

-- Weather hook (spec 11.3): stretches every machine of one type, for example dryers in rain.
function MachineService:SetGlobalCycleMultiplier(multiplier: number)
	line:SetGlobalCycleMultiplier(multiplier)
end

function MachineService:SetCycleMultiplier(definitionId: string, multiplier: number)
	line:SetCycleMultiplier(definitionId, multiplier)
end

-- Units anywhere in the line, used to tell when the factory has nothing left to do.
function MachineService:CountItems(): number
	return line:CountItems()
end

-- Spec 12.3: the original purchase price of everything this player still owns.
function MachineService:GetInfrastructureValue(player: Player): number
	local total = 0
	for _, record in records do
		if record.owner == player then
			total += record.cost
		end
	end
	for _, tile in tiles do
		if tile.owner == player then
			total += TILE_COST
		end
	end
	local catalog: { [string]: any } = MachineDefinitions
	for definitionId, definition in catalog do
		if definition.Cost then
			total += owned(player, definitionId) * definition.Cost
		end
	end
	return total
end

-- Current state of every placed processor, keyed by machine id, for bottleneck tracking.
function MachineService:GetProcessorStates(): { [number]: { name: string, state: string } }
	local samples = {}
	for nodeId, record in records do
		if record.node.kind == "Processor" then
			samples[nodeId] =
				{ name = record.node.definition.DisplayName, state = record.node.state }
		end
	end
	return samples
end

-- Unloads truck cargo into the fixed factory intake. Returns how many bundles fit.
function MachineService:DepositToIntake(count: number, owner: Player?): number
	return line:Deposit(intakeNodeId, count, owner)
end

function MachineService:Initialize(world: Model, playerStateService: any)
	playerState = playerStateService

	for _, roadName in ROAD_NAMES do
		local road = world:FindFirstChild(roadName)
		if road and road:IsA("BasePart") then
			table.insert(roadRects, PlacementRules.RectFromPart(road))
		end
	end

	local factory = world:FindFirstChild("CooperativeFactory")
	assert(factory and factory:IsA("Model"), "CooperativeFactory is missing from the graybox")
	local floor = factory:FindFirstChild("FactoryFloor")
	assert(floor and floor:IsA("BasePart"), "FactoryFloor is missing from the graybox")
	plotRect = PlacementRules.RectFromPart(floor)
	floorTopY = floor.Position.Y + floor.Size.Y / 2

	local remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	local placeRemote = Instance.new("RemoteFunction")
	placeRemote.Name = "PlaceMachine"
	placeRemote.Parent = remotes
	local placeConveyorRemote = Instance.new("RemoteFunction")
	placeConveyorRemote.Name = "PlaceConveyor"
	placeConveyorRemote.Parent = remotes
	local removeConveyorRemote = Instance.new("RemoteFunction")
	removeConveyorRemote.Name = "RemoveConveyor"
	removeConveyorRemote.Parent = remotes
	local deleteMachineRemote = Instance.new("RemoteFunction")
	deleteMachineRemote.Name = "DeleteMachine"
	deleteMachineRemote.Parent = remotes
	local buyRemote = Instance.new("RemoteFunction")
	buyRemote.Name = "BuyItem"
	buyRemote.Parent = remotes
	local sellRemote = Instance.new("RemoteFunction")
	sellRemote.Name = "SellItem"
	sellRemote.Parent = remotes
	noticeEvent = Instance.new("RemoteEvent")
	noticeEvent.Name = "Notice"
	noticeEvent.Parent = remotes
	remotes.Parent = ReplicatedStorage

	local existing = world:FindFirstChild("Production")
	if existing then
		existing:Destroy()
	end
	productionFolder = Instance.new("Folder")
	productionFolder.Name = "Production"
	productionFolder.Parent = world
	conveyorFolder = Instance.new("Folder")
	conveyorFolder.Name = "Conveyors"
	conveyorFolder.Parent = productionFolder
	beltFolder = Instance.new("Folder")
	beltFolder.Name = "Pipes"
	beltFolder.Parent = productionFolder

	clearFactoryFloor(factory)
	local factorySign = floor:FindFirstChild("MapLabel")
	if factorySign and factorySign:IsA("BillboardGui") then
		-- The road and spawn are on the -Z side, so the sign greets players at that edge.
		factorySign.StudsOffset = Vector3.zero
		factorySign.Size = UDim2.fromScale(18, 3.6)
		factorySign.StudsOffsetWorldSpace = Vector3.new(0, 12, -floor.Size.Z / 2 + 2)
		factorySign.AlwaysOnTop = false
		factorySign.LightInfluence = 0
		local signText = factorySign:FindFirstChildWhichIsA("TextLabel")
		if signText then
			signText.Text = "COOPERATIVE FACTORY"
		end
	end
	createIntake(factory)
	createBuyer(world)

	placeRemote.OnServerInvoke = placeMachine
	buyRemote.OnServerInvoke = buyItem
	sellRemote.OnServerInvoke = sellItem
	placeConveyorRemote.OnServerInvoke = placeConveyor
	removeConveyorRemote.OnServerInvoke = removeConveyor
	-- The Delete tool. dismantle() checks ownership and emptiness and tells the player the result.
	deleteMachineRemote.OnServerInvoke = function(player: Player, nodeId: unknown): boolean
		if typeof(nodeId) ~= "number" then
			return false
		end
		dismantle(player, nodeId)
		return true
	end

	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < TICK_SECONDS then
			return
		end
		local step = accumulated
		accumulated = 0
		handleEvents(line:Step(step))
		refreshVisuals()
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- Machines stay in the world but stop paying a player who has left (spec 15.1).
		for _, record in records do
			if record.owner == player then
				line:SetPaused(record.node.id, true)
			end
		end
	end)

	refreshVisuals()
end

return MachineService
