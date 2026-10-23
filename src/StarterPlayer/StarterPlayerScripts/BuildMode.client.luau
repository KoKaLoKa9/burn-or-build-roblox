--!strict

-- Free placement build mode (spec section 3). The ghost preview is local; the server re-validates
-- every machine and belt tile, so this script never decides credits or machine state.
-- UI: a bottom hotbar of machine slots and transport slots with live 3D previews, a Grid tool,
-- context key hints, a tooltip, and short toasts for server results.
-- Belts are laid tile by tile: click to place one, or hold and drag to lay a line that turns
-- wherever the drag turns. Machine IN/OUT ports only show while building, so the floor stays calm.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MachineDefinitions = require(Shared:WaitForChild("MachineDefinitions"))
local ItemDefinitions = require(Shared:WaitForChild("ItemDefinitions"))
local ResearchDefinitions = require(Shared:WaitForChild("ResearchDefinitions"))
local MachineArt = require(Shared:WaitForChild("MachineArt"))
local PipeDefinitions = require(Shared:WaitForChild("PipeDefinitions"))
local PipeRoute = require(Shared:WaitForChild("PipeRoute"))
local ConveyorGrid = require(Shared:WaitForChild("ConveyorGrid"))
local ConveyorTile = require(Shared:WaitForChild("ConveyorTile"))
local PipeTile = require(Shared:WaitForChild("PipeTile"))
local PlacementRules = require(Shared:WaitForChild("PlacementRules"))
local PaddySites = require(Shared:WaitForChild("PaddySites"))
local CommitmentDefinitions = require(Shared:WaitForChild("CommitmentDefinitions"))
local UITheme = require(script.Parent:WaitForChild("UITheme"))

local Colors = UITheme.Colors
local Fonts = UITheme.Fonts

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local placeRemote = remotes:WaitForChild("PlaceMachine") :: RemoteFunction
local placeConveyorRemote = remotes:WaitForChild("PlaceConveyor") :: RemoteFunction
local removeConveyorRemote = remotes:WaitForChild("RemoveConveyor") :: RemoteFunction
local deleteMachineRemote = remotes:WaitForChild("DeleteMachine") :: RemoteFunction
local noticeEvent = remotes:WaitForChild("Notice") :: RemoteEvent

local player = Players.LocalPlayer
local world = workspace:WaitForChild("BurnOrBuildWorld")
local factory = world:WaitForChild("CooperativeFactory")
local floor = factory:WaitForChild("FactoryFloor") :: BasePart
local production = world:WaitForChild("Production")
local conveyorFolder = production:WaitForChild("Conveyors")

local SLOT_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}
-- Hotbar order: machines first, then transport. Each slot takes the next number key.
local CATALOG = { "Dryer", "Shredder", "PelletMill", "CoveredStorage", "TruckTerminal" }
-- Farm machines stand beside a paddy (Farm A or a bought plot) instead of on the factory floor.
local FARM_CATALOG = { "Transplanter", "Combine", "Baler" }
-- Week 6: the office runs research; tier 2 machines unlock through it.
local OFFICE_CATALOG = { "CooperativeOffice" }
local TIER2_CATALOG =
	{ "MarketStall", "PyrolysisKiln", "MushroomHouse", "CattleShed", "Digester", "GasEngine" }
-- Industry update: every factory machine needs power from these.
local POWER_CATALOG = {
	"HandCrank",
	"SolarPanel",
	"PowerPole",
	"Battery",
	"StrawGenerator",
	"DieselGenerator",
	"WaterPump",
	"WaterTank",
	"Boiler",
	"SteamTurbine",
}

type ItemInfo = { recipe: string, detail: string }
local ITEM_INFO: { [string]: ItemInfo } = {
	Dryer = { recipe = "Wet straw  ->  Dry straw", detail = "8 bundles per minute" },
	Shredder = { recipe = "Dry straw  ->  Shredded straw", detail = "10 bundles per minute" },
	PelletMill = {
		recipe = "2 Shredded  ->  1 Pellet crate",
		detail = "3 crates per minute, 30 credits running cost each",
	},
	CoveredStorage = {
		recipe = "Holds 12 bundles of one type",
		detail = "Keeps straw dry and absorbs uneven machine speeds",
	},
	TruckTerminal = {
		recipe = "Hauls straw from Farm B or C",
		detail = "8 bundles per trip, place beside a road",
	},
	Transplanter = {
		recipe = "Plants empty paddy rows",
		detail = "One row every 4 s at the usual seed cost, place beside your paddy",
	},
	Combine = {
		recipe = "Harvests ripe paddy rows",
		detail = "One row every 5 s for the usual grain, straw still lands on the field",
	},
	Baler = {
		recipe = "Bales the straw lying on a paddy",
		detail = "One sheaf every 3 s, no fire needed. Take the bales with E",
	},
	CooperativeOffice = {
		recipe = "Hire engineers, earn research points",
		detail = "One per player. Hire with T, pick a project with E",
	},
	MarketStall = {
		recipe = "Buys pellets 135, biochar 240, mushrooms 180, digestate 60",
		detail = "Place at the end of any line",
	},
	PyrolysisKiln = {
		recipe = "3 Shredded  ->  1 Biochar sack",
		detail = "One sack every 30 s, 10 credits running cost. Syngas is flared",
	},
	MushroomHouse = {
		recipe = "2 Wet straw  ->  1 Mushroom basket",
		detail = "One basket every 45 s. Soaked straw, no dryer needed",
	},
	HandCrank = {
		recipe = "Hold E: 8 kW for 20 s",
		detail = "Free power while you turn it, up to a minute banked",
	},
	SolarPanel = {
		recipe = "3 kW from the sun",
		detail = "Runs on its own. Smog halves it",
	},
	PowerPole = {
		recipe = "Carries power 32 studs",
		detail = "Links generators, batteries and machines into one network",
	},
	Battery = {
		recipe = "Stores 3,000 kJ",
		detail = "Soaks up spare power and covers shortfalls",
	},
	StrawGenerator = {
		recipe = "1 Dry straw  ->  25 kW for 12 s",
		detail = "A closed, filtered furnace: a little smog, far less than a field fire",
	},
	DieselGenerator = {
		recipe = "20 kW, 5 credits every 10 s",
		detail = "Bought fuel. Easy power that costs money and adds smog",
	},
	CattleShed = {
		recipe = "2 Wet straw + 1 Water  ->  1 Manure",
		detail = "Every 20 s. Water by fluid pipe",
	},
	Digester = {
		recipe = "1 Shredded + 1 Manure + 2 Water  ->  4 Biogas + 1 Digestate",
		detail = "Every 30 s. Biogas leaves by gas pipe; belt the digestate away or it stops",
	},
	GasEngine = {
		recipe = "1 Biogas  ->  40 kW for 4 s",
		detail = "Two digesters keep one engine running. Barely any smog",
	},
	WaterPump = {
		recipe = "Pumps 1 water every 2 s",
		detail = "Works anywhere. Needs 2 kW and a fluid pipe out",
	},
	WaterTank = {
		recipe = "Holds 30 water",
		detail = "Evens out pumps and boilers. Fluid pipes in and out",
	},
	Boiler = {
		recipe = "1 Dry straw + 2 Water  ->  5 Steam",
		detail = "Every 10 s. Water by fluid pipe, steam out by gas pipe",
	},
	SteamTurbine = {
		recipe = "1 Steam  ->  50 kW for 1 s",
		detail = "Two boilers keep one turbine spinning",
	},
}
local ROTATION_NAMES = { "east", "north", "west", "south" }

local roadRects: { PlacementRules.Rect } = {}
for _, roadName in { "MainRoad", "FactoryRoad" } do
	local road = world:FindFirstChild(roadName)
	if road and road:IsA("BasePart") then
		table.insert(roadRects, PlacementRules.RectFromPart(road))
	end
end

local mode = "None"
-- What the Conveyor tool lays: Item (belts), Fluid or Gas (pipes).
local transportMedium = "Item"
local selectedId: string? = nil
local rotationSteps = 0
local snapEnabled = true
local ghostValid = false
local ghostPosition: Vector3? = nil
local requestInFlight = false

local floorTopY = floor.Position.Y + floor.Size.Y / 2

-- Belt laying state.
local lastPlaced: { number }? = nil
-- Set by R: the next tile uses the turned direction instead of guessing.
local manualTurn = false
-- Defined with the belt start and end cells and the Delete tool further down.
local clearDeleteTarget: () -> ()
local refreshAccessCells: () -> ()
local clearAccessCells: () -> ()
local beltDir = 0
local dragging = false
local lastCell: { number }? = nil
local hoveredCell: { number }? = nil

-- Port visibility -----------------------------------------------------------------------------

-- Primary ports are InputPort and OutputPort; extra ports add their name, such as OutputPortGas.
local function isPortName(name: string): boolean
	return string.match(name, "^InputPort") ~= nil or string.match(name, "^OutputPort") ~= nil
end
local portsVisible = false

local function applyPortVisibility(port: BasePart)
	port.Transparency = if portsVisible then 0 else 1
	for _, child in port:GetChildren() do
		if child:IsA("BillboardGui") then
			child.Enabled = portsVisible
		end
	end
end

local function setPortsVisible(visible: boolean)
	if portsVisible == visible then
		return
	end
	portsVisible = visible
	for _, descendant in world:GetDescendants() do
		if descendant:IsA("BasePart") and isPortName(descendant.Name) then
			applyPortVisibility(descendant)
		end
	end
end

world.DescendantAdded:Connect(function(descendant: Instance)
	if descendant:IsA("BasePart") and isPortName(descendant.Name) then
		applyPortVisibility(descendant)
	elseif
		descendant:IsA("BillboardGui")
		and descendant.Parent
		and isPortName(descendant.Parent.Name)
	then
		descendant.Enabled = portsVisible
	end
end)
for _, descendant in world:GetDescendants() do
	if descendant:IsA("BasePart") and isPortName(descendant.Name) then
		applyPortVisibility(descendant)
	end
end

-- Machine ghost -------------------------------------------------------------------------------

local ghostBox = Instance.new("Part")
ghostBox.Name = "BuildGhost"
ghostBox.Anchored = true
ghostBox.CanCollide = false
ghostBox.CanQuery = false
ghostBox.CanTouch = false
ghostBox.Transparency = 0.45
ghostBox.Material = Enum.Material.ForceField

local ghostOutput = Instance.new("Part")
ghostOutput.Name = "BuildGhostOutput"
ghostOutput.Anchored = true
ghostOutput.CanCollide = false
ghostOutput.CanQuery = false
ghostOutput.CanTouch = false
ghostOutput.Size = Vector3.new(2, 2, 5)
ghostOutput.Material = Enum.Material.Neon
ghostOutput.Color = Colors.Teal

-- With imported art the ghost is the real machine, its colors washed toward green or red.
local ghostArt: Model? = nil
local ghostColors: { [BasePart]: Color3 } = {}
local ghostTintColor: Color3? = nil

local function clearGhost()
	ghostBox.Parent = nil
	ghostOutput.Parent = nil
	table.clear(ghostColors)
	ghostTintColor = nil
	if ghostArt then
		ghostArt:Destroy()
		ghostArt = nil
	end
end

local function prepareGhost(definitionId: string)
	clearGhost()
	local definition = MachineDefinitions[definitionId]
	local art = MachineArt.Build(definitionId)
	if art then
		for _, descendant in art:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Transparency = math.max(descendant.Transparency, 0.3)
				ghostColors[descendant] = descendant.Color
			end
		end
		ghostArt = art
	else
		ghostBox.Size = Vector3.new(definition.Size.X, definition.Size.Y, definition.Size.Z)
	end
end

local function tintGhost(tint: Color3)
	ghostBox.Color = tint
	if ghostTintColor == tint then
		return
	end
	ghostTintColor = tint
	for part, original in ghostColors do
		part.Color = original:Lerp(tint, 0.6)
	end
end

local function showGhost(visible: boolean)
	local definition = if selectedId then MachineDefinitions[selectedId] else nil
	if ghostArt then
		ghostArt.Parent = if visible then workspace else nil
	else
		ghostBox.Parent = if visible then workspace else nil
	end
	ghostOutput.Parent = if visible
			and definition
			and not definition.NoPorts
		then workspace
		else nil
end

-- Belt ghost ------------------------------------------------------------------------------------

local beltGhost: Model? = nil
local beltGhostDir = -1
local beltGhostMedium = ""
local beltGhostColors: { [BasePart]: Color3 } = {}
local beltGhostTint: Color3? = nil

local function clearBeltGhost()
	if beltGhost then
		beltGhost:Destroy()
		beltGhost = nil
	end
	table.clear(beltGhostColors)
	beltGhostDir = -1
	beltGhostMedium = ""
	beltGhostTint = nil
end

local function tintBeltGhost(tint: Color3)
	if beltGhost == nil or beltGhostTint == tint then
		return
	end
	beltGhostTint = tint
	for part, original in beltGhostColors do
		part.Color = original:Lerp(tint, 0.5)
	end
end

local function ensureBeltGhost(dir: number)
	if beltGhost and beltGhostDir == dir and beltGhostMedium == transportMedium then
		return
	end
	clearBeltGhost()
	local straight = { [dir] = true, [(dir + 2) % 4] = true }
	local model = if transportMedium == "Item"
		then ConveyorTile.Build(dir, straight)
		else PipeTile.Build(transportMedium, dir, straight)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 0.35
			descendant.CanQuery = false
			beltGhostColors[descendant] = descendant.Color
		end
	end
	beltGhost = model
	beltGhostDir = dir
	beltGhostMedium = transportMedium
end

-- Screen --------------------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BuildModeGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
-- Above the tutorial card, so the shop and inventory are never covered.
screenGui.DisplayOrder = 3
screenGui.Parent = player:WaitForChild("PlayerGui")

local function itemName(itemId: string?): string
	local item = if itemId then ItemDefinitions[itemId] else nil
	return if item then item.DisplayName else tostring(itemId)
end

local function isUnlocked(): boolean
	return player:GetAttribute("TutorialComplete") == true
end

-- The research project a machine still waits on, if any.
local function researchNeeded(definition: any): string?
	local projectId = definition.Research
	if projectId == nil or player:GetAttribute("Research_" .. projectId) == true then
		return nil
	end
	local project = ResearchDefinitions.Projects[projectId]
	return if project then project.DisplayName else projectId
end

local function machineLocked(definition: any): boolean
	return (definition.UnlockAfterFirstSale == true and not isUnlocked())
		or researchNeeded(definition) ~= nil
end

local function credits(): number
	local value = player:GetAttribute("Credits")
	return if typeof(value) == "number" then value else 0
end

-- Hotbar ---------------------------------------------------------------------------------------

local hotbar = Instance.new("Frame")
hotbar.Name = "Hotbar"
hotbar.AnchorPoint = Vector2.new(0.5, 1)
hotbar.Position = UDim2.new(0.5, 0, 1, -14)
hotbar.Size = UDim2.fromOffset(0, 96)
hotbar.AutomaticSize = Enum.AutomaticSize.X
hotbar.BackgroundColor3 = Colors.Panel
hotbar.BackgroundTransparency = 0.12
hotbar.BorderSizePixel = 0
hotbar.Parent = screenGui
UITheme.corner(hotbar, 16)
UITheme.outline(hotbar)
UITheme.padding(hotbar, 10, 10)
local hotbarLayout = UITheme.list(hotbar, 8, true)
hotbarLayout.VerticalAlignment = Enum.VerticalAlignment.Center

-- Everything the player can put on the hotbar. Research items are shown but locked until the
-- tier system arrives.
type Item = {
	key: string,
	kind: string,
	id: string,
	name: string,
	category: string,
	blurb: string?,
}
local ITEMS: { Item } = {}
local ITEM_BY_KEY: { [string]: Item } = {}
local function addItem(item: Item)
	table.insert(ITEMS, item)
	ITEM_BY_KEY[item.key] = item
end
for _, definitionId in CATALOG do
	addItem({
		key = "Machine:" .. definitionId,
		kind = "Machine",
		id = definitionId,
		name = MachineDefinitions[definitionId].DisplayName,
		category = "Machines",
	})
end
for _, definitionId in OFFICE_CATALOG do
	addItem({
		key = "Machine:" .. definitionId,
		kind = "Machine",
		id = definitionId,
		name = MachineDefinitions[definitionId].DisplayName,
		category = "Machines",
	})
end
for _, definitionId in POWER_CATALOG do
	addItem({
		key = "Machine:" .. definitionId,
		kind = "Machine",
		id = definitionId,
		name = MachineDefinitions[definitionId].DisplayName,
		category = "Power",
	})
end
for _, definitionId in FARM_CATALOG do
	addItem({
		key = "Machine:" .. definitionId,
		kind = "Machine",
		id = definitionId,
		name = MachineDefinitions[definitionId].DisplayName,
		category = "Farm",
	})
end
for _, definitionId in TIER2_CATALOG do
	addItem({
		key = "Machine:" .. definitionId,
		kind = "Machine",
		id = definitionId,
		name = MachineDefinitions[definitionId].DisplayName,
		category = "Research",
	})
end
for _, pipeId in PipeDefinitions.Order do
	addItem({
		key = "Transport:" .. pipeId,
		kind = "Transport",
		id = pipeId,
		name = PipeDefinitions.Types[pipeId].DisplayName,
		category = "Transport",
	})
end

-- The player's own layout for keys 1 to 9. "" is an empty slot.
local HOTBAR_SIZE = 9
local hotbarItems: { string } = {
	"Machine:Dryer",
	"Machine:Shredder",
	"Machine:PelletMill",
	-- The starting power kit sits right beside the first line it has to run.
	"Machine:HandCrank",
	"Machine:SolarPanel",
	"Transport:Item",
	"Machine:PowerPole",
	"Machine:StrawGenerator",
	-- The office is where research starts, so it gets the last key.
	"Machine:CooperativeOffice",
}

type Slot = {
	index: number,
	kind: string,
	id: string,
	itemKey: string,
	button: TextButton,
	stroke: UIStroke,
	content: Frame,
	viewport: ViewportFrame?,
	camera: Camera?,
	focus: Vector3,
	radius: number,
	angle: number,
	cost: TextLabel?,
	lockOverlay: Frame?,
}
local slots: { Slot } = {}
local hoveredSlot: Slot? = nil

type Preview = { camera: Camera?, focus: Vector3, radius: number, angle: number }

local function framePreview(preview: Preview)
	local camera = preview.camera
	if camera == nil then
		return
	end
	-- A three-quarter view from the input side, like a product shot.
	local direction = Vector3.new(-math.cos(preview.angle), 0.75, math.sin(preview.angle)).Unit
	local distance = preview.radius / math.tan(math.rad(camera.FieldOfView / 2)) * 0.92
	camera.CFrame = CFrame.lookAt(preview.focus + direction * distance, preview.focus)
end

local function createViewport(
	parent: GuiObject,
	model: Model
): (ViewportFrame, Camera, Vector3, number)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.Size = UDim2.new(1, -8, 1, -8)
	viewport.Position = UDim2.fromOffset(4, 4)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(170, 176, 172)
	viewport.LightColor = Color3.fromRGB(255, 248, 235)
	viewport.LightDirection = Vector3.new(-0.6, -1, -0.4)
	viewport.Parent = parent

	model:PivotTo(CFrame.new())
	model.Parent = viewport
	local boxCFrame, boxSize = model:GetBoundingBox()

	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport, camera, boxCFrame.Position, boxSize.Magnitude / 2
end

-- Conveyor slot icon: a short belt that turns a corner, built from the real tile pieces.
local function buildConveyorPreview(): Model
	local model = Instance.new("Model")
	model.Name = "ConveyorPreview"
	type PreviewCell = { x: number, z: number, dir: number, open: { [number]: boolean } }
	local layout: { PreviewCell } = {
		{ x = 0, z = 0, dir = 0, open = { [0] = true, [2] = true } },
		{ x = 1, z = 0, dir = 3, open = { [3] = true, [2] = true } },
		{ x = 1, z = 1, dir = 3, open = { [3] = true, [1] = true } },
	}
	for _, cell in layout do
		local tile = ConveyorTile.Build(cell.dir, cell.open)
		tile:PivotTo(CFrame.new(cell.x * 4, 0, cell.z * 4))
		tile.Parent = model
	end
	local bundle = Instance.new("Part")
	bundle.Size = Vector3.new(1.3, 1.1, 1.3)
	bundle.CFrame = CFrame.new(0, ConveyorTile.BeltTop + 0.55, 0)
	bundle.Color = Color3.fromRGB(226, 185, 83)
	bundle.Anchored = true
	bundle.Parent = model
	return model
end

-- Fluid and gas lines keep a pipe look, styled like the real pipe will be.
local function buildPipePreview(pipeId: string): Model
	local pipe = PipeDefinitions.Types[pipeId]
	local model = Instance.new("Model")
	model.Name = "PipePreview"
	local legs, joints = PipeRoute.Build({
		Vector3.new(-4, 0, 2),
		Vector3.new(1.5, 0, 2),
		Vector3.new(1.5, 0, -3.5),
	}, PipeDefinitions.Diameter, model)
	for _, leg in legs do
		leg.Color = Color3.fromRGB(table.unpack(pipe.Color))
		leg.Material = (Enum.Material :: any)[pipe.Material]
		leg.Transparency = math.min(pipe.Transparency, 0.45)
	end
	for _, joint in joints do
		joint.Color = Color3.fromRGB(150, 158, 162)
		joint.Material = Enum.Material.Metal
	end
	return model
end

local function previewModelFor(item: Item): Model
	if item.kind == "Machine" then
		return MachineArt.Build(item.id) or MachineArt.BuildPlaceholder(MachineDefinitions[item.id])
	elseif item.kind == "Transport" then
		return if item.id == "Item" then buildConveyorPreview() else buildPipePreview(item.id)
	end
	local art = MachineArt.Build(item.id)
	if art then
		return art
	end
	local fallback = Instance.new("Model")
	local block = Instance.new("Part")
	block.Size = Vector3.new(8, 6, 8)
	block.Anchored = true
	block.Parent = fallback
	return fallback
end

local function priceText(item: Item): string
	if item.kind == "Machine" then
		return UITheme.formatNumber(MachineDefinitions[item.id].Cost)
	elseif item.kind == "Transport" then
		return PipeDefinitions.Types[item.id].ShortName
	end
	-- Research items already say SOON on their cover.
	return ""
end

-- Fills a frame with an item's 3D preview, its price tag, and a lock cover.
local function buildItemVisual(
	parent: Frame,
	item: Item
): (ViewportFrame, Camera, Vector3, number, TextLabel, Frame)
	local viewport, camera, focus, radius = createViewport(parent, previewModelFor(item))
	local cost = UITheme.text(parent, {
		name = "Cost",
		text = priceText(item),
		size = UDim2.new(1, -10, 0, 16),
		font = Fonts.Heavy,
		textSize = 13,
		color = Colors.Gold,
		alignX = Enum.TextXAlignment.Right,
	})
	cost.Position = UDim2.new(0, 5, 1, -19)
	cost.ZIndex = 3
	cost.TextStrokeTransparency = 0.4
	cost.TextStrokeColor3 = Colors.Panel
	if item.kind == "Transport" and item.id ~= "Item" then
		cost.TextColor3 = Color3.fromRGB(table.unpack(PipeDefinitions.Types[item.id].Color))
	elseif item.kind == "Future" then
		cost.TextColor3 = Colors.Muted
	end

	local lockOverlay = Instance.new("Frame")
	lockOverlay.Name = "Locked"
	lockOverlay.Size = UDim2.fromScale(1, 1)
	lockOverlay.BackgroundColor3 = Colors.Panel
	lockOverlay.BackgroundTransparency = 0.35
	lockOverlay.ZIndex = 2
	lockOverlay.Visible = false
	lockOverlay.Parent = parent
	UITheme.corner(lockOverlay, 12)
	UITheme.text(lockOverlay, {
		name = "Label",
		text = if item.kind == "Machine" then "LOCKED" else "SOON",
		size = UDim2.fromScale(1, 1),
		font = Fonts.Heavy,
		textSize = 12,
		color = Colors.Muted,
		alignX = Enum.TextXAlignment.Center,
	}).ZIndex =
		2
	return viewport, camera, focus, radius, cost, lockOverlay
end

local function setSlotItem(slot: Slot, itemKey: string)
	if slot.itemKey == itemKey and slot.viewport ~= nil then
		return
	end
	slot.content:ClearAllChildren()
	slot.itemKey = itemKey
	slot.viewport, slot.camera, slot.cost, slot.lockOverlay = nil, nil, nil, nil
	local item = ITEM_BY_KEY[itemKey]
	if item == nil then
		slot.kind, slot.id = "Empty", ""
		return
	end
	slot.kind, slot.id = item.kind, item.id
	local viewport, camera, focus, radius, cost, lockOverlay = buildItemVisual(slot.content, item)
	slot.viewport, slot.camera, slot.focus, slot.radius = viewport, camera, focus, radius
	slot.cost, slot.lockOverlay = cost, lockOverlay
	slot.angle = math.rad(40)
	framePreview(slot)
end

local function createDivider(order: number)
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.fromOffset(1, 56)
	divider.BackgroundColor3 = Colors.Outline
	divider.BackgroundTransparency = 0.85
	divider.BorderSizePixel = 0
	divider.LayoutOrder = order
	divider.Parent = hotbar
end

type ToolSlot = { button: TextButton, stroke: UIStroke, caption: TextLabel }

-- Tool slots draw their icon from small frames so no image upload is needed.
local function createToolSlot(
	order: number,
	name: string,
	key: string,
	drawIcon: (Frame) -> ()
): ToolSlot
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = ""
	button.AutoButtonColor = false
	button.Size = UDim2.fromOffset(64, 76)
	button.BackgroundColor3 = Colors.Raised
	button.BackgroundTransparency = 0.1
	button.BorderSizePixel = 0
	button.LayoutOrder = order
	button.Parent = hotbar
	UITheme.corner(button, 12)
	local stroke = UITheme.outline(button)

	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 22)
	icon.Size = UDim2.fromOffset(30, 26)
	icon.BackgroundTransparency = 1
	icon.Parent = button
	drawIcon(icon)

	local keyCap = UITheme.keyCap(button, key)
	keyCap.Position = UDim2.fromOffset(5, 5)
	keyCap.Size = UDim2.fromOffset(0, 18)

	local caption = UITheme.text(button, {
		name = "Caption",
		text = string.upper(name),
		size = UDim2.new(1, 0, 0, 14),
		font = Fonts.Heavy,
		textSize = 10,
		color = Colors.Muted,
		alignX = Enum.TextXAlignment.Center,
	})
	caption.Position = UDim2.new(0, 0, 1, -19)
	return { button = button, stroke = stroke, caption = caption }
end

local function iconBlock(parent: Frame, position: UDim2, size: UDim2, color: Color3)
	local block = Instance.new("Frame")
	block.Position = position
	block.Size = size
	block.BackgroundColor3 = color
	block.BorderSizePixel = 0
	block.Parent = parent
	UITheme.corner(block, 3)
end

for index = 1, HOTBAR_SIZE do
	local button = Instance.new("TextButton")
	button.Name = "Slot" .. index
	button.Text = ""
	button.AutoButtonColor = false
	button.Size = UDim2.fromOffset(76, 76)
	button.BackgroundColor3 = Colors.Raised
	button.BackgroundTransparency = 0.1
	button.BorderSizePixel = 0
	button.LayoutOrder = index
	button.Parent = hotbar
	UITheme.corner(button, 12)
	local stroke = UITheme.outline(button)

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.fromScale(1, 1)
	content.BackgroundTransparency = 1
	content.Parent = button

	local keyCap = UITheme.keyCap(button, tostring(index))
	keyCap.Position = UDim2.fromOffset(5, 5)
	keyCap.Size = UDim2.fromOffset(0, 18)
	keyCap.ZIndex = 3
	keyCap.BackgroundTransparency = 0.1

	local slot: Slot = {
		index = index,
		kind = "Empty",
		id = "",
		itemKey = "",
		button = button,
		stroke = stroke,
		content = content,
		viewport = nil,
		camera = nil,
		focus = Vector3.zero,
		radius = 1,
		angle = math.rad(40),
		cost = nil,
		lockOverlay = nil,
	}
	table.insert(slots, slot)
	setSlotItem(slot, hotbarItems[index])
end
createDivider(50)
-- The cart opens the shop: buy machines and read their details there.
local shopTool = createToolSlot(51, "Shop", "M", function(icon)
	local basket = Instance.new("Frame")
	basket.Name = "Basket"
	basket.AnchorPoint = Vector2.new(0.5, 0)
	basket.Position = UDim2.new(0.5, 2, 0, 4)
	basket.Size = UDim2.fromOffset(22, 12)
	basket.BackgroundColor3 = Colors.Teal
	basket.BorderSizePixel = 0
	basket.Parent = icon
	UITheme.corner(basket, 3)
	local handle = Instance.new("Frame")
	handle.Name = "Handle"
	handle.Position = UDim2.fromOffset(1, 0)
	handle.Size = UDim2.fromOffset(6, 3)
	handle.BackgroundColor3 = Colors.Teal
	handle.BorderSizePixel = 0
	handle.Parent = icon
	for _, x in { 9, 21 } do
		local wheel = Instance.new("Frame")
		wheel.Name = "Wheel"
		wheel.Position = UDim2.fromOffset(x, 19)
		wheel.Size = UDim2.fromOffset(6, 6)
		wheel.BackgroundColor3 = Colors.Gold
		wheel.BorderSizePixel = 0
		wheel.Parent = icon
		UITheme.corner(wheel, 3)
	end
end)
-- The bag opens the inventory: what you own.
local bagTool = createToolSlot(52, "Bag", "B", function(icon)
	local body = Instance.new("Frame")
	body.Name = "BagBody"
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.fromScale(0.5, 1)
	body.Size = UDim2.fromOffset(24, 18)
	body.BackgroundColor3 = Colors.Straw
	body.BorderSizePixel = 0
	body.Parent = icon
	UITheme.corner(body, 5)
	local flap = Instance.new("Frame")
	flap.Name = "BagFlap"
	flap.Position = UDim2.fromOffset(0, 0)
	flap.Size = UDim2.new(1, 0, 0, 6)
	flap.BackgroundColor3 = Color3.fromRGB(188, 140, 52)
	flap.BorderSizePixel = 0
	flap.Parent = body
	UITheme.corner(flap, 4)
	local handle = Instance.new("Frame")
	handle.Name = "BagHandle"
	handle.AnchorPoint = Vector2.new(0.5, 1)
	handle.Position = UDim2.new(0.5, 0, 1, -16)
	handle.Size = UDim2.fromOffset(14, 10)
	handle.BackgroundTransparency = 1
	handle.Parent = icon
	UITheme.corner(handle, 5)
	UITheme.outline(handle, Colors.Straw, 0, 2.5)
end)
-- The Delete tool removes your machines and belt tiles (and pipes once they exist).
local deleteTool = createToolSlot(53, "Delete", "X", function(icon)
	for _, angle in { 45, -45 } do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromOffset(26, 5)
		bar.Rotation = angle
		bar.BackgroundColor3 = Colors.Danger
		bar.BorderSizePixel = 0
		bar.Parent = icon
		UITheme.corner(bar, 2)
	end
end)
local gridTool = createToolSlot(54, "Grid", "G", function(icon)
	for row = 0, 2 do
		for columnIndex = 0, 2 do
			iconBlock(
				icon,
				UDim2.fromOffset(4 + columnIndex * 8, 2 + row * 8),
				UDim2.fromOffset(6, 6),
				Colors.Text
			)
		end
	end
end)

-- Tooltip ---------------------------------------------------------------------------------------

local tooltip = UITheme.card("Tooltip", screenGui, 236)
tooltip.AnchorPoint = Vector2.new(0.5, 1)
tooltip.Visible = false
tooltip.ZIndex = 10
UITheme.padding(tooltip, 10, 12)
UITheme.list(tooltip, 3)
local tooltipName =
	UITheme.text(tooltip, { name = "Name", font = Fonts.Heavy, textSize = 16, order = 1 })
local tooltipRecipe = UITheme.text(
	tooltip,
	{ name = "Recipe", font = Fonts.Bold, textSize = 13, color = Colors.Teal, order = 2 }
)
local tooltipDetail = UITheme.text(tooltip, {
	name = "Detail",
	size = UDim2.fromScale(1, 0),
	textSize = 12,
	color = Colors.Muted,
	order = 3,
	wrap = true,
})
tooltipDetail.AutomaticSize = Enum.AutomaticSize.Y
local tooltipStatus =
	UITheme.text(tooltip, { name = "Status", font = Fonts.Bold, textSize = 12, order = 4 })
for _, child in tooltip:GetDescendants() do
	if child:IsA("GuiObject") then
		child.ZIndex = 10
	end
end

local function showTooltip(slot: Slot?)
	if slot == nil or slot.kind == "Empty" then
		tooltip.Visible = false
		return
	end
	if slot.kind == "Future" then
		local item = ITEM_BY_KEY[slot.itemKey]
		tooltipName.Text = item.name
		tooltipRecipe.Text = item.blurb or ""
		tooltipDetail.Text = "Unlocks through research in the coming tier update."
		tooltipStatus.Text = "Coming soon"
		tooltipStatus.TextColor3 = Colors.Muted
	elseif slot.kind == "Transport" then
		local pipe = PipeDefinitions.Types[slot.id]
		tooltipName.Text = pipe.DisplayName
		tooltipRecipe.Text = pipe.Carries
		if pipe.Ready then
			tooltipDetail.Text =
				"Lay tiles from a machine OUT to the next machine IN. Hold and drag to lay a line."
			tooltipStatus.Text = string.format("%d credits per tile", pipe.Cost or 0)
			tooltipStatus.TextColor3 = Colors.Gold
		else
			tooltipDetail.Text = "For the coming energy machines."
			tooltipStatus.Text = "Arrives with the energy update"
			tooltipStatus.TextColor3 = Colors.Muted
		end
	else
		local definition = MachineDefinitions[slot.id]
		local info = ITEM_INFO[slot.id] or { recipe = "", detail = "" }
		tooltipName.Text = definition.DisplayName
		tooltipRecipe.Text = info.recipe
		tooltipDetail.Text = info.detail
		local research = researchNeeded(definition)
		if research then
			tooltipStatus.Text = string.format("Research %s at the office", string.lower(research))
			tooltipStatus.TextColor3 = Colors.Muted
		elseif definition.UnlockAfterFirstSale and not isUnlocked() then
			tooltipStatus.Text = "Unlocks after your first pellet sale"
			tooltipStatus.TextColor3 = Colors.Muted
		elseif credits() < definition.Cost then
			tooltipStatus.Text =
				string.format("Needs %s credits", UITheme.formatNumber(definition.Cost))
			tooltipStatus.TextColor3 = Colors.Danger
		else
			tooltipStatus.Text = string.format("%s credits", UITheme.formatNumber(definition.Cost))
			tooltipStatus.TextColor3 = Colors.Gold
		end
	end
	local position = slot.button.AbsolutePosition
	local size = slot.button.AbsoluteSize
	-- Sit above the key hint bar so the two never overlap.
	tooltip.Position = UDim2.fromOffset(position.X + size.X / 2, position.Y - 58)
	tooltip.Visible = true
end

-- Key hints and toast ----------------------------------------------------------------------------

local hints = Instance.new("Frame")
hints.Name = "Hints"
hints.AnchorPoint = Vector2.new(0.5, 1)
hints.Position = UDim2.new(0.5, 0, 1, -120)
hints.Size = UDim2.fromOffset(0, 32)
hints.AutomaticSize = Enum.AutomaticSize.X
hints.BackgroundColor3 = Colors.Panel
hints.BackgroundTransparency = 0.25
hints.BorderSizePixel = 0
hints.Parent = screenGui
UITheme.corner(hints, 16)
UITheme.padding(hints, 0, 12)
local hintsLayout = UITheme.list(hints, 12, true)
hintsLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local currentHints = ""
local function setHints(entries: { { string } })
	-- With no tool active there is nothing to explain, so the bar disappears.
	hints.Visible = #entries > 0
	local signature = ""
	for _, entry in entries do
		signature ..= entry[1] .. entry[2]
	end
	if signature == currentHints then
		return
	end
	currentHints = signature
	for _, child in hints:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for index, entry in entries do
		local group = Instance.new("Frame")
		group.Name = "Hint" .. index
		group.Size = UDim2.fromOffset(0, 22)
		group.AutomaticSize = Enum.AutomaticSize.X
		group.BackgroundTransparency = 1
		group.LayoutOrder = index
		group.Parent = hints
		local groupLayout = UITheme.list(group, 6, true)
		groupLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		UITheme.keyCap(group, entry[1], 1)
		local label = UITheme.text(group, {
			name = "Label",
			text = entry[2],
			size = UDim2.fromScale(0, 1),
			font = Fonts.Bold,
			textSize = 13,
			order = 2,
		})
		label.AutomaticSize = Enum.AutomaticSize.X
	end
end

local toast = Instance.new("Frame")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -162)
toast.Size = UDim2.fromOffset(0, 34)
toast.AutomaticSize = Enum.AutomaticSize.X
toast.BackgroundColor3 = Colors.Panel
toast.BackgroundTransparency = 0.1
toast.BorderSizePixel = 0
toast.Visible = false
toast.Parent = screenGui
UITheme.corner(toast, 17)
UITheme.padding(toast, 0, 16)
local toastStroke = UITheme.outline(toast, Colors.Teal, 0.3, 1)
local toastText = UITheme.text(toast, {
	name = "Text",
	size = UDim2.fromScale(0, 1),
	font = Fonts.Bold,
	textSize = 14,
	alignX = Enum.TextXAlignment.Center,
})
toastText.AutomaticSize = Enum.AutomaticSize.X

local ERROR_PREFIXES = {
	"Not ",
	"Invalid",
	"You ",
	"Route blocked",
	"Empty ",
	"Another ",
	"This ",
	"Click ",
	"Nothing ",
	"Belt not",
	"Belts must",
	"A machine",
	"That belt",
	"There is",
}
local function isErrorText(text: string): boolean
	for _, prefix in ERROR_PREFIXES do
		if string.sub(text, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local toastVersion = 0
local toastShownAt = 0

local function setToast(text: string, isError: boolean)
	toast.Visible = true
	toastText.Text = text
	toastText.TextColor3 = if isError then Color3.fromRGB(255, 196, 184) else Colors.Text
	toastStroke.Color = if isError then Colors.Danger else Colors.Teal
	toast.BackgroundTransparency = 0.1
	toastText.TextTransparency = 0
	toastStroke.Transparency = 0.3
end

local function hideToast()
	toast.Visible = false
end

local function showMessage(text: string)
	if text == "" then
		return
	end
	toastVersion += 1
	toastShownAt = os.clock()
	local version = toastVersion
	setToast(text, isErrorText(text))
	task.delay(4, function()
		if toastVersion ~= version then
			return
		end
		local fade = TweenInfo.new(0.4)
		TweenService:Create(toast, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(toastText, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(toastStroke, fade, { Transparency = 1 }):Play()
		task.delay(0.4, function()
			if toastVersion == version then
				hideToast()
			end
		end)
	end)
end

-- Refresh -----------------------------------------------------------------------------------------

local function isSelected(slot: Slot): boolean
	if slot.kind == "Empty" or slot.kind == "Future" then
		return false
	end
	if slot.kind == "Transport" then
		return mode == "Conveyor" and slot.id == transportMedium
	end
	return mode == "Place" and selectedId == slot.id
end

local function refreshPanel()
	local balance = credits()
	for _, slot in slots do
		local selected = isSelected(slot)
		local locked = false
		if slot.kind == "Transport" then
			locked = not PipeDefinitions.Types[slot.id].Ready
		elseif slot.kind == "Future" then
			locked = true
		elseif slot.kind == "Machine" then
			local definition = MachineDefinitions[slot.id]
			locked = machineLocked(definition)
			if slot.cost then
				local stock = player:GetAttribute("Owned_" .. slot.id)
				if typeof(stock) == "number" and stock > 0 then
					slot.cost.Text = "x" .. stock
					slot.cost.TextColor3 = Colors.Good
				else
					slot.cost.Text = UITheme.formatNumber(definition.Cost)
					slot.cost.TextColor3 = if balance < definition.Cost
						then Colors.Danger
						else Colors.Gold
				end
			end
		end
		if slot.lockOverlay then
			slot.lockOverlay.Visible = locked
		end
		if slot.viewport then
			slot.viewport.ImageColor3 = if locked
				then Color3.fromRGB(110, 110, 110)
				else Color3.new(1, 1, 1)
		end
		slot.stroke.Color = if selected then Colors.Gold else Colors.Outline
		slot.stroke.Transparency = if selected then 0 else 0.88
		slot.stroke.Thickness = if selected then 2 else 1
		slot.button.BackgroundColor3 = if selected or hoveredSlot == slot
			then Colors.Hover
			else Colors.Raised
	end

	local deleting = mode == "Delete"
	deleteTool.stroke.Color = if deleting then Colors.Danger else Colors.Outline
	deleteTool.stroke.Transparency = if deleting then 0 else 0.88
	deleteTool.stroke.Thickness = if deleting then 2 else 1
	deleteTool.caption.TextColor3 = if deleting then Colors.Danger else Colors.Muted

	gridTool.caption.Text = if snapEnabled then "GRID ON" else "GRID OFF"
	gridTool.caption.TextColor3 = if snapEnabled then Colors.Teal else Colors.Muted

	if mode == "Place" and selectedId then
		setHints({
			{ "LMB", "Place" },
			{
				"R",
				-- Machines without ports (farm machines, the truck terminal) have no output side.
				if MachineDefinitions[selectedId].NoPorts
					then "Rotate"
					else "Rotate, output faces " .. ROTATION_NAMES[rotationSteps + 1],
			},
			{ "G", "Grid" },
			{ "Q", "Cancel" },
		})
	elseif mode == "Delete" then
		setHints({
			{ "LMB", "Delete, drag across belts to clear a run" },
			{ "Q", "Done" },
		})
	elseif mode == "Conveyor" then
		setHints({
			{ "LMB", "Place, drag to lay a line" },
			{
				"R",
				string.format(
					"Turn, %s runs %s",
					if transportMedium == "Item" then "belt" else "pipe",
					ROTATION_NAMES[beltDir + 1]
				),
			},
			{ "RMB", "Remove tile" },
			{ "Q", "Done" },
		})
	else
		if os.clock() - toastShownAt >= 4 then
			hideToast()
		end
		setHints({})
	end
end

-- Helpers -------------------------------------------------------------------------------------

local function mouseRaycast(): RaycastResult?
	local camera = workspace.CurrentCamera
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { ghostBox, ghostOutput }
	if ghostArt then
		table.insert(ignore, ghostArt)
	end
	if beltGhost then
		table.insert(ignore, beltGhost)
	end
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	return workspace:Raycast(ray.Origin, ray.Direction * 600, params)
end

local function collectBlockers(): { PlacementRules.Rect }
	local rects = {}
	for _, container in { production, factory } do
		for _, child in container:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("MachineId") ~= nil then
				local body = child:FindFirstChild("Body")
				if body and body:IsA("BasePart") then
					table.insert(rects, PlacementRules.RectFromPart(body))
				end
			end
		end
	end
	return rects
end

local function tileBlockers(): { PlacementRules.Rect }
	local rects = {}
	for _, tile in conveyorFolder:GetChildren() do
		if tile:IsA("Model") and tile.PrimaryPart then
			table.insert(rects, PlacementRules.RectFromPart(tile.PrimaryPart))
		end
	end
	return rects
end

local function setMode(newMode: string, id: string?)
	mode = newMode
	selectedId = if newMode == "Place" then id else nil
	dragging = false
	lastCell = nil
	if mode == "Place" and selectedId then
		prepareGhost(selectedId)
		showGhost(true)
	else
		clearGhost()
		ghostPosition = nil
	end
	if mode == "Conveyor" then
		lastPlaced = nil
		manualTurn = false
		refreshAccessCells()
	else
		clearBeltGhost()
		clearAccessCells()
	end
	if mode ~= "Delete" then
		clearDeleteTarget()
	end
	setPortsVisible(mode == "Place" or mode == "Conveyor")
	refreshPanel()
end

local function activateSlot(slot: Slot)
	if slot.kind == "Empty" then
		showMessage(
			"Empty slot. Press M for the shop or B for your inventory and drag an item here."
		)
		return
	elseif slot.kind == "Future" then
		showMessage("This machine unlocks through research in the coming tier update.")
		return
	end
	if isSelected(slot) then
		setMode("None")
	elseif slot.kind == "Transport" then
		local pipe = PipeDefinitions.Types[slot.id]
		if not pipe.Ready then
			showMessage(
				string.format(
					"%ss arrive with the energy update. No machine uses them yet.",
					pipe.DisplayName
				)
			)
			return
		end
		transportMedium = slot.id
		setMode("Conveyor")
	else
		setMode("Place", slot.id)
	end
end

-- The shop and inventory live in their own scope: the script's top level is close to Luau's limit
-- of 200 locals. The rest of the script reaches them through `panels`.
local panels: any = {}
do
	-- Shop and inventory ---------------------------------------------------------------------------
	-- M or the cart opens the shop: every buildable item in a scrolling list, with an index pane that
	-- shows the selected item's stats and lets the player buy it into their inventory. B or the bag
	-- opens the inventory: what the player actually owns (machines in storage, carried straw, what is
	-- placed, plots, engineers, research). Items drag from either panel onto hotbar slots 1 to 9, hotbar
	-- items drag between slots to swap, and dragging one off the hotbar puts it away. Hovering an item
	-- and pressing 1 to 9 also assigns it.

	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local buyRemote = Remotes:WaitForChild("BuyItem") :: RemoteFunction
	local sellRemote = Remotes:WaitForChild("SellItem") :: RemoteFunction

	local PANEL_WIDTH = 760
	local PANEL_HEIGHT = 380
	local LIST_WIDTH = 432

	local openPanel: string? = nil -- "Shop", "Inventory", or nil
	local hoveredCard: Item? = nil
	local selectedItem: Item? = nil

	local function ownedCount(definitionId: string): number
		local value = player:GetAttribute("Owned_" .. definitionId)
		return if typeof(value) == "number" then value else 0
	end

	-- A fixed-size dark panel that sits above the hotbar, so it never covers it.
	local function createPanel(name: string, title: string, hint: string): (Frame, TextButton)
		local panel = UITheme.card(name, screenGui, PANEL_WIDTH)
		panel.AutomaticSize = Enum.AutomaticSize.None
		panel.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
		panel.AnchorPoint = Vector2.new(0.5, 1)
		panel.Position = UDim2.new(0.5, 0, 1, -128)
		panel.Visible = false
		panel.ZIndex = 20
		UITheme.padding(panel, 12, 14)

		local header = Instance.new("Frame")
		header.Name = "Header"
		header.Size = UDim2.new(1, 0, 0, 34)
		header.BackgroundTransparency = 1
		header.Parent = panel
		UITheme.text(header, {
			name = "Title",
			text = title,
			size = UDim2.new(1, -40, 0, 20),
			font = Fonts.Heavy,
			textSize = 17,
			color = Colors.Gold,
		})
		UITheme.text(header, {
			name = "Hint",
			text = hint,
			size = UDim2.new(1, -40, 0, 14),
			textSize = 12,
			color = Colors.Muted,
		}).Position =
			UDim2.fromOffset(0, 20)

		local close = Instance.new("TextButton")
		close.Name = "Close"
		close.AnchorPoint = Vector2.new(1, 0)
		close.Position = UDim2.fromScale(1, 0)
		close.Size = UDim2.fromOffset(28, 28)
		close.BackgroundColor3 = Colors.Raised
		close.Text = "X"
		close.FontFace = Fonts.Heavy
		close.TextSize = 16
		close.TextColor3 = Colors.Text
		close.AutoButtonColor = true
		close.Parent = header
		UITheme.corner(close, 8)
		return panel, close
	end

	local function createScroller(
		parent: Instance,
		name: string,
		size: UDim2,
		position: UDim2
	): ScrollingFrame
		local scroller = Instance.new("ScrollingFrame")
		scroller.Name = name
		scroller.Size = size
		scroller.Position = position
		scroller.BackgroundTransparency = 1
		scroller.BorderSizePixel = 0
		scroller.ScrollBarThickness = 6
		scroller.ScrollBarImageColor3 = Colors.Muted
		scroller.CanvasSize = UDim2.new()
		scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroller.ScrollingDirection = Enum.ScrollingDirection.Y
		scroller.Parent = parent
		UITheme.list(scroller, 8)
		local padding = Instance.new("UIPadding")
		padding.PaddingRight = UDim.new(0, 10)
		padding.Parent = scroller
		return scroller
	end

	local function createSection(parent: Instance, order: number, title: string): Frame
		UITheme.text(parent, {
			name = title .. "Title",
			text = string.upper(title),
			size = UDim2.new(1, 0, 0, 16),
			font = Fonts.Heavy,
			textSize = 12,
			color = Colors.Muted,
			order = order,
		})
		local grid = Instance.new("Frame")
		grid.Name = title .. "Grid"
		grid.Size = UDim2.fromScale(1, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.BackgroundTransparency = 1
		grid.LayoutOrder = order + 1
		grid.Parent = parent
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(76, 92)
		layout.CellPadding = UDim2.fromOffset(8, 8)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		return grid
	end

	type Card = {
		item: Item,
		button: TextButton,
		badge: TextLabel,
		preview: Preview,
		lockOverlay: Frame,
		cost: TextLabel,
		stroke: UIStroke,
	}

	-- One item card: preview, name, price (or owned count), hotbar key badge, and lock cover.
	local function createCard(parent: Instance, item: Item, order: number): Card
		local button = Instance.new("TextButton")
		button.Name = item.key
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundColor3 = Colors.Raised
		button.BackgroundTransparency = 0.1
		button.BorderSizePixel = 0
		button.LayoutOrder = order
		button.Parent = parent
		UITheme.corner(button, 12)
		local stroke = UITheme.outline(button)

		local visual = Instance.new("Frame")
		visual.Name = "Visual"
		visual.Size = UDim2.fromOffset(76, 68)
		visual.BackgroundTransparency = 1
		visual.Parent = button
		local _, camera, focus, radius, cost, lockOverlay = buildItemVisual(visual, item)

		UITheme.text(button, {
			name = "Name",
			text = item.name,
			size = UDim2.new(1, -6, 0, 20),
			font = Fonts.Bold,
			textSize = 10,
			alignX = Enum.TextXAlignment.Center,
			wrap = true,
		}).Position =
			UDim2.new(0, 3, 1, -22)

		local badge = UITheme.text(button, {
			name = "Badge",
			size = UDim2.fromOffset(20, 20),
			font = Fonts.Heavy,
			textSize = 12,
			color = Colors.Panel,
			alignX = Enum.TextXAlignment.Center,
		})
		badge.Position = UDim2.fromOffset(6, 6)
		badge.BackgroundColor3 = Colors.Gold
		badge.BackgroundTransparency = 0
		badge.Visible = false
		UITheme.corner(badge, 10)

		local card: Card = {
			item = item,
			button = button,
			badge = badge,
			preview = { camera = camera, focus = focus, radius = radius, angle = math.rad(40) },
			lockOverlay = lockOverlay,
			cost = cost,
			stroke = stroke,
		}
		framePreview(card.preview)
		return card
	end

	local function raise(root: Instance)
		for _, descendant in root:GetDescendants() do
			if descendant:IsA("GuiObject") then
				descendant.ZIndex = math.max(descendant.ZIndex, 20)
					+ (if descendant.Name == "Badge" then 2 else 0)
			end
		end
	end

	local function itemLocked(item: Item): boolean
		return item.kind == "Future"
			or (item.kind == "Transport" and not PipeDefinitions.Types[item.id].Ready)
			or (item.kind == "Machine" and machineLocked(MachineDefinitions[item.id]))
	end

	-- Shop ----------------------------------------------------------------------------------------

	local shop, shopClose = createPanel(
		"Shop",
		"SHOP",
		"Click an item for its details. Buy it into your inventory, or drag it onto your hotbar."
	)
	local shopList =
		createScroller(shop, "List", UDim2.new(0, LIST_WIDTH, 1, -42), UDim2.fromOffset(0, 42))

	local shopCards: { Card } = {}
	local sectionGrids: { [string]: Frame } = {
		Machines = createSection(shopList, 10, "Machines"),
		Power = createSection(shopList, 12, "Power"),
		Farm = createSection(shopList, 15, "Farm machines"),
		Transport = createSection(shopList, 20, "Transport"),
		Research = createSection(shopList, 30, "Tier 2 (research)"),
	}
	for order, item in ITEMS do
		table.insert(shopCards, createCard(sectionGrids[item.category], item, order))
	end

	-- Index: the details of the selected item.
	local indexPane = Instance.new("Frame")
	indexPane.Name = "Index"
	indexPane.Position = UDim2.fromOffset(LIST_WIDTH + 12, 42)
	indexPane.Size = UDim2.new(1, -(LIST_WIDTH + 12), 1, -42)
	indexPane.BackgroundColor3 = Colors.Raised
	indexPane.BackgroundTransparency = 0.25
	indexPane.BorderSizePixel = 0
	indexPane.Parent = shop
	UITheme.corner(indexPane, 12)

	local indexView = Instance.new("Frame")
	indexView.Name = "Preview"
	indexView.Size = UDim2.new(1, 0, 0, 110)
	indexView.BackgroundTransparency = 1
	indexView.Parent = indexPane
	local indexPreview: Preview? = nil

	local indexBody =
		createScroller(indexPane, "Body", UDim2.new(1, -12, 1, -158), UDim2.fromOffset(12, 112))
	local indexName = UITheme.text(indexBody, {
		name = "Name",
		size = UDim2.new(1, 0, 0, 20),
		font = Fonts.Heavy,
		textSize = 17,
		order = 1,
	})
	local indexStatus = UITheme.text(indexBody, {
		name = "Status",
		size = UDim2.new(1, 0, 0, 16),
		font = Fonts.Bold,
		textSize = 12,
		order = 2,
	})
	local indexStats = UITheme.text(indexBody, {
		name = "Stats",
		size = UDim2.fromScale(1, 0),
		textSize = 12,
		wrap = true,
		order = 3,
		alignY = Enum.TextYAlignment.Top,
	})
	indexStats.AutomaticSize = Enum.AutomaticSize.Y
	indexStats.RichText = true
	local indexBlurb = UITheme.text(indexBody, {
		name = "Blurb",
		size = UDim2.fromScale(1, 0),
		textSize = 12,
		color = Colors.Muted,
		wrap = true,
		order = 4,
	})
	indexBlurb.AutomaticSize = Enum.AutomaticSize.Y

	local buyRow = Instance.new("Frame")
	buyRow.Name = "Buy"
	buyRow.AnchorPoint = Vector2.new(0, 1)
	buyRow.Position = UDim2.new(0, 10, 1, -8)
	buyRow.Size = UDim2.new(1, -20, 0, 32)
	buyRow.BackgroundTransparency = 1
	buyRow.Parent = indexPane
	local ownedLabel = UITheme.text(buyRow, {
		name = "Owned",
		size = UDim2.fromScale(0.34, 1),
		font = Fonts.Bold,
		textSize = 12,
		color = Colors.Muted,
	})

	local function buyButton(name: string, text: string, position: UDim2): TextButton
		local button = Instance.new("TextButton")
		button.Name = name
		button.AnchorPoint = Vector2.new(1, 0)
		button.Position = position
		button.Size = UDim2.fromScale(0.31, 1)
		button.BackgroundColor3 = Colors.Teal
		button.Text = text
		button.FontFace = Fonts.Heavy
		button.TextSize = 12
		button.TextColor3 = Colors.Panel
		button.AutoButtonColor = true
		button.Parent = buyRow
		UITheme.corner(button, 8)
		return button
	end
	local buyOne = buyButton("BuyOne", "BUY 1", UDim2.fromScale(0.66, 0))
	local buyFive = buyButton("BuyFive", "BUY 5", UDim2.fromScale(1, 0))

	local function per(value: number, seconds: number): string
		local perMinute = value * 60 / seconds
		return if perMinute == math.floor(perMinute)
			then string.format("%d", perMinute)
			else string.format("%.1f", perMinute)
	end

	-- The machine's numbers, read straight from its definition so the index never goes stale.
	local function statsFor(item: Item): string
		local lines: { string } = {}
		local function add(label: string, value: string)
			table.insert(lines, string.format('<font color="#92A49D">%s</font>  %s', label, value))
		end
		if item.kind == "Transport" then
			local pipe = PipeDefinitions.Types[item.id]
			add("Carries", pipe.Carries)
			if pipe.Ready then
				add(
					"Price",
					string.format("%d credits per tile, paid as you lay it", pipe.Cost or 0)
				)
			else
				add("Status", "Arrives with the energy update")
			end
			return table.concat(lines, "\n")
		end
		local definition = MachineDefinitions[item.id]
		if definition == nil then
			return ""
		end
		add("Price", string.format("%s credits", UITheme.formatNumber(definition.Cost or 0)))
		add("Footprint", string.format("%d x %d studs", definition.Size.X, definition.Size.Z))
		local kind = definition.Kind
		if (definition.PowerKW or 0) > 0 then
			add("Power use", string.format("%d kW while working", definition.PowerKW))
		end
		if kind == "Processor" then
			add(
				"Input",
				string.format("%d %s", definition.InputPerCycle, itemName(definition.InputItem))
			)
			add(
				"Output",
				string.format("%d %s", definition.OutputPerCycle, itemName(definition.OutputItem))
			)
			for _, port in definition.ExtraPorts or {} do
				if port.Item then
					add(
						if port.Direction == "In" then "Also takes" else "Also makes",
						string.format(
							"%d %s (%s port)",
							port.PerCycle or 1,
							itemName(port.Item),
							string.lower(port.Medium or "item")
						)
					)
				end
			end
			add("Cycle", string.format("%.1f s", definition.CycleSeconds))
			add(
				"Speed",
				string.format(
					"%s %s per minute",
					per(definition.OutputPerCycle, definition.CycleSeconds),
					itemName(definition.OutputItem)
				)
			)
			if definition.OperatingCostPerCycle then
				add(
					"Running cost",
					string.format("%d credits per cycle", definition.OperatingCostPerCycle)
				)
			end
			add(
				"Buffers",
				string.format("in %d, out %d", definition.InputCapacity, definition.OutputCapacity)
			)
		elseif kind == "Storage" then
			add("Holds", string.format("%d bundles of one straw type", definition.Capacity))
		elseif kind == "Sink" then
			local prices = {}
			for itemId, price in definition.Prices or {} do
				table.insert(prices, string.format("%s %d", itemName(itemId), price))
			end
			table.sort(prices)
			add("Buys", table.concat(prices, ", "))
		elseif kind == "Terminal" then
			add("Truck", "Carries 8 bundles a trip from Farm B or C")
			add("Placement", "Beside a road")
		elseif kind == "Farm" then
			local action = if definition.FarmAction == "Plant"
				then "Plants an empty row"
				elseif definition.FarmAction == "Harvest" then "Harvests a ripe row"
				else "Bales one straw sheaf"
			add("Work", string.format("%s every %d s", action, definition.WorkSeconds))
			add(
				"Placement",
				string.format("Beside a paddy, within %d studs", definition.PaddyReach or 12)
			)
			if definition.Capacity then
				add("Holds", string.format("%d bundles until you take them", definition.Capacity))
			end
		elseif kind == "Generator" then
			add("Makes", string.format("%d kW", definition.PowerOutputKW))
			if definition.Fuel == "Sun" then
				add("Fuel", "Sunlight, dimmed by smog")
			elseif definition.Fuel == "Crank" then
				add(
					"Fuel",
					string.format(
						"You: hold E for %d s of power, up to %d s banked",
						definition.CrankSeconds,
						definition.MaxCrankSeconds
					)
				)
			elseif definition.Fuel == "Diesel" then
				add(
					"Fuel",
					string.format(
						"Diesel, %d credits every %d s",
						definition.OperatingCostPerCycle,
						definition.CycleSeconds
					)
				)
			else
				add(
					"Fuel",
					string.format(
						"%d %s every %d s (conveyor in)",
						definition.InputPerCycle,
						itemName(definition.InputItem),
						definition.CycleSeconds
					)
				)
			end
			if definition.SmogPerCycle then
				add("Smog", "Adds a little to the district smog while it runs")
			end
			add("Reach", string.format("%d studs to poles and machines", definition.Reach))
		elseif kind == "Battery" then
			add("Stores", string.format("%s kJ", UITheme.formatNumber(definition.CapacityKJ)))
			add("Rate", string.format("%d kW in or out", definition.RateKW))
			add("Reach", string.format("%d studs", definition.Reach))
		elseif kind == "Pole" then
			add("Reach", string.format("%d studs to poles and machines", definition.Reach))
		elseif kind == "Office" then
			add("Staff", string.format("Up to %d engineers", ResearchDefinitions.MaxEngineers))
			add(
				"Research",
				string.format(
					"1 point per engineer every %d s",
					ResearchDefinitions.SecondsPerPoint
				)
			)
		end
		if definition.MaxPerPlayer then
			add("Limit", string.format("%d per player", definition.MaxPerPlayer))
		end
		if definition.Research then
			local project = ResearchDefinitions.Projects[definition.Research]
			add("Research", if project then project.DisplayName else definition.Research)
		end
		return table.concat(lines, "\n")
	end

	local function refreshIndex()
		local item = selectedItem
		if item == nil then
			indexName.Text = "Pick an item"
			indexStatus.Text = ""
			indexStats.Text =
				"Click any card on the left to see what it does, what it costs, and how fast it works."
			indexBlurb.Text = ""
			buyRow.Visible = false
			return
		end
		indexName.Text = item.name
		local info = ITEM_INFO[item.id]
		indexBlurb.Text = if info
			then info.recipe .. ". " .. info.detail .. "."
			else (item.blurb or "")
		indexStats.Text = statsFor(item)
		local locked = itemLocked(item)
		local definition = if item.kind == "Machine" then MachineDefinitions[item.id] else nil
		if definition then
			local research = researchNeeded(definition)
			indexStatus.Text = if research
				then string.format("Research %s at the office", string.lower(research))
				elseif locked then "Unlocks after your first sale"
				else "Available"
			indexStatus.TextColor3 = if locked then Colors.Muted else Colors.Good
			buyRow.Visible = true
			local count = ownedCount(item.id)
			ownedLabel.Text = string.format("In inventory: %d", count)
			buyOne.Text = string.format("BUY 1  %s", UITheme.formatNumber(definition.Cost))
			buyFive.Text = "BUY 5"
			for _, button in { buyOne, buyFive } do
				button.Active = not locked
				button.AutoButtonColor = not locked
				button.BackgroundColor3 = if locked then Colors.Track else Colors.Teal
			end
		else
			indexStatus.Text = if locked
				then "Coming later"
				else "Laid tile by tile from the hotbar"
			indexStatus.TextColor3 = if locked then Colors.Muted else Colors.Good
			buyRow.Visible = false
		end
	end

	local function selectItem(item: Item)
		selectedItem = item
		indexView:ClearAllChildren()
		local _, camera, focus, radius = createViewport(indexView, previewModelFor(item))
		indexPreview = { camera = camera, focus = focus, radius = radius, angle = math.rad(40) }
		framePreview(indexPreview :: Preview)
		raise(indexPane)
		for _, card in shopCards do
			local chosen = card.item == item
			card.stroke.Color = if chosen then Colors.Gold else Colors.Outline
			card.stroke.Transparency = if chosen then 0 else 0.88
			card.stroke.Thickness = if chosen then 2 else 1
		end
		refreshIndex()
	end

	local function buy(count: number)
		local item = selectedItem
		if item == nil or item.kind ~= "Machine" or itemLocked(item) then
			return
		end
		local ok, message = buyRemote:InvokeServer(item.id, count)
		showMessage(
			if typeof(message) == "string"
				then message
				else if ok then "Bought." else "Could not buy that."
		)
		refreshIndex()
	end
	buyOne.Activated:Connect(function()
		buy(1)
	end)
	buyFive.Activated:Connect(function()
		buy(5)
	end)
	raise(shop)

	-- Inventory -----------------------------------------------------------------------------------

	local inventory, inventoryClose = createPanel("Inventory", "INVENTORY", "")
	-- Only machine cards live here, so the panel is shorter than the shop; it scrolls when full.
	inventory.Size = UDim2.fromOffset(PANEL_WIDTH, 250)
	local inventoryList =
		createScroller(inventory, "List", UDim2.new(1, 0, 1, -42), UDim2.fromOffset(0, 42))

	local storageGrid = Instance.new("Frame")
	storageGrid.Name = "StorageGrid"
	storageGrid.Size = UDim2.fromScale(1, 0)
	storageGrid.AutomaticSize = Enum.AutomaticSize.Y
	storageGrid.BackgroundTransparency = 1
	storageGrid.LayoutOrder = 2
	storageGrid.Parent = inventoryList
	local storageLayout = Instance.new("UIGridLayout")
	storageLayout.CellSize = UDim2.fromOffset(76, 116)
	storageLayout.CellPadding = UDim2.fromOffset(8, 8)
	storageLayout.SortOrder = Enum.SortOrder.LayoutOrder
	storageLayout.Parent = storageGrid
	local storageEmpty = UITheme.text(inventoryList, {
		name = "StorageEmpty",
		text = "No machines yet.",
		size = UDim2.fromScale(1, 0),
		textSize = 12,
		color = Colors.Muted,
		wrap = true,
		order = 3,
	})
	storageEmpty.AutomaticSize = Enum.AutomaticSize.Y

	type StorageCard = { card: Card, sell: TextButton }
	local storageCards: { [string]: StorageCard } = {}

	for order, item in ITEMS do
		if item.kind ~= "Machine" then
			continue
		end
		local card = createCard(storageGrid, item, order)
		card.button.Size = UDim2.fromOffset(76, 116)
		local sell = Instance.new("TextButton")
		sell.Name = "Sell"
		sell.AnchorPoint = Vector2.new(0.5, 1)
		sell.Position = UDim2.new(0.5, 0, 1, -4)
		sell.Size = UDim2.new(1, -10, 0, 20)
		sell.BackgroundColor3 = Colors.Hover
		sell.FontFace = Fonts.Heavy
		sell.TextSize = 10
		sell.TextColor3 = Colors.Text
		sell.AutoButtonColor = true
		sell.Parent = card.button
		UITheme.corner(sell, 6)
		-- The name sits above the sell button on these taller cards.
		local name = card.button:FindFirstChild("Name")
		if name and name:IsA("TextLabel") then
			name.Position = UDim2.new(0, 3, 1, -46)
		end
		sell.Activated:Connect(function()
			local ok, message = sellRemote:InvokeServer(item.id)
			showMessage(
				if typeof(message) == "string"
					then message
					else if ok then "Sold." else "Could not sell that."
			)
		end)
		storageCards[item.id] = { card = card, sell = sell }
	end
	raise(inventory)

	local function refreshInventory()
		local refund = if isUnlocked() then 0.7 else 1
		local any = false
		for definitionId, entry in storageCards do
			local count = ownedCount(definitionId)
			entry.card.button.Visible = count > 0
			any = any or count > 0
			entry.card.cost.Text = "x" .. count
			entry.card.cost.TextColor3 = Colors.Good
			entry.sell.Text = string.format(
				"SELL %s",
				UITheme.formatNumber(math.floor(MachineDefinitions[definitionId].Cost * refund))
			)
		end
		storageEmpty.Visible = not any
	end

	local function refreshCards()
		for _, card in shopCards do
			local slotIndex = table.find(hotbarItems, card.item.key)
			card.badge.Visible = slotIndex ~= nil
			card.badge.Text = if slotIndex then tostring(slotIndex) else ""
			card.lockOverlay.Visible = itemLocked(card.item)
		end
		for _, entry in storageCards do
			local slotIndex = table.find(hotbarItems, entry.card.item.key)
			entry.card.badge.Visible = slotIndex ~= nil
			entry.card.badge.Text = if slotIndex then tostring(slotIndex) else ""
		end
		if openPanel == "Shop" then
			refreshIndex()
		elseif openPanel == "Inventory" then
			refreshInventory()
		end
	end

	local function applyHotbar()
		for slotIndex, slot in slots do
			setSlotItem(slot, hotbarItems[slotIndex])
		end
		refreshCards()
		refreshPanel()
	end

	-- Puts an item on a slot. An item already on the hotbar moves, swapping with what was there.
	local function assignToSlot(slotIndex: number, itemKey: string, fromIndex: number?)
		local origin = fromIndex or table.find(hotbarItems, itemKey)
		if origin == slotIndex then
			return
		end
		if origin then
			hotbarItems[origin] = hotbarItems[slotIndex]
		end
		hotbarItems[slotIndex] = itemKey
		applyHotbar()
	end

	local function clearSlot(slotIndex: number)
		hotbarItems[slotIndex] = ""
		applyHotbar()
	end

	local function setTool(tool: ToolSlot, active: boolean)
		tool.stroke.Color = if active then Colors.Gold else Colors.Outline
		tool.stroke.Transparency = if active then 0 else 0.88
		tool.stroke.Thickness = if active then 2 else 1
	end

	local function setOpenPanel(name: string?)
		openPanel = name
		shop.Visible = name == "Shop"
		inventory.Visible = name == "Inventory"
		hoveredCard = nil
		if name then
			setMode("None")
			showTooltip(nil)
			refreshCards()
			if name == "Shop" and selectedItem == nil then
				refreshIndex()
			end
		end
		setTool(shopTool, name == "Shop")
		setTool(bagTool, name == "Inventory")
	end

	local function togglePanel(name: string)
		setOpenPanel(if openPanel == name then nil else name)
	end

	-- Ownership, carried straw, and research all change what the inventory and index show.
	player.AttributeChanged:Connect(function(attribute)
		if openPanel == nil then
			return
		end
		if
			string.sub(attribute, 1, 6) == "Owned_"
			or attribute == "StrawBundles"
			or attribute == "Engineers"
			or attribute == "Credits"
			or attribute == "TutorialComplete"
		then
			refreshCards()
		end
	end)

	-- Dragging --------------------------------------------------------------------------------------

	type Drag = { itemKey: string, fromIndex: number?, start: Vector2, ghost: Frame?, card: Card? }
	local drag: Drag? = nil

	local function guiMouse(): Vector2
		return UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	end

	local function inside(gui: GuiObject, point: Vector2): boolean
		local position, size = gui.AbsolutePosition, gui.AbsoluteSize
		return point.X >= position.X
			and point.X <= position.X + size.X
			and point.Y >= position.Y
			and point.Y <= position.Y + size.Y
	end

	local function makeGhost(itemKey: string): Frame
		local item = ITEM_BY_KEY[itemKey]
		local ghost = Instance.new("Frame")
		ghost.Name = "DragGhost"
		ghost.AnchorPoint = Vector2.new(0.5, 0.5)
		ghost.Size = UDim2.fromOffset(72, 72)
		ghost.BackgroundColor3 = Colors.Hover
		ghost.BackgroundTransparency = 0.15
		ghost.ZIndex = 60
		ghost.Parent = screenGui
		UITheme.corner(ghost, 12)
		UITheme.outline(ghost, Colors.Gold, 0, 2)
		local _, camera, focus, radius = buildItemVisual(ghost, item)
		framePreview({ camera = camera, focus = focus, radius = radius, angle = math.rad(40) })
		for _, descendant in ghost:GetDescendants() do
			if descendant:IsA("GuiObject") then
				descendant.ZIndex = 61
			end
		end
		return ghost
	end

	local function beginDrag(itemKey: string, fromIndex: number?, card: Card?)
		if itemKey == "" then
			return
		end
		drag = {
			itemKey = itemKey,
			fromIndex = fromIndex,
			start = guiMouse(),
			ghost = nil,
			card = card,
		}
	end

	local function finishDrag()
		local current = drag
		drag = nil
		if current == nil then
			return
		end
		if current.ghost == nil then
			-- A click without moving: in the shop it opens the item's details.
			local card = current.card
			if card and openPanel == "Shop" then
				selectItem(card.item)
			elseif current.fromIndex == nil then
				local empty = table.find(hotbarItems, "")
				if table.find(hotbarItems, current.itemKey) then
					showMessage("That item is already on your hotbar.")
				elseif empty then
					assignToSlot(empty, current.itemKey)
				else
					showMessage("Your hotbar is full. Drag the item onto a slot to replace it.")
				end
			end
			return
		end
		current.ghost:Destroy()
		local point = guiMouse()
		for slotIndex, slot in slots do
			if inside(slot.button, point) then
				assignToSlot(slotIndex, current.itemKey, current.fromIndex)
				return
			end
		end
		if current.fromIndex and not inside(hotbar, point) then
			clearSlot(current.fromIndex)
		end
	end

	RunService.RenderStepped:Connect(function(deltaTime: number)
		local current = drag
		if current then
			local point = guiMouse()
			if current.ghost == nil and (point - current.start).Magnitude > 6 then
				current.ghost = makeGhost(current.itemKey)
			end
			if current.ghost then
				current.ghost.Position = UDim2.fromOffset(point.X, point.Y)
			end
		end
		if openPanel == "Shop" then
			for _, card in shopCards do
				if card.item == hoveredCard then
					card.preview.angle += deltaTime * 0.9
					framePreview(card.preview)
				end
			end
			local preview = indexPreview
			if preview then
				preview.angle += deltaTime * 0.6
				framePreview(preview)
			end
		end
	end)

	local function hookCard(card: Card)
		card.button.MouseEnter:Connect(function()
			hoveredCard = card.item
		end)
		card.button.MouseLeave:Connect(function()
			if hoveredCard == card.item then
				hoveredCard = nil
			end
		end)
		card.button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				beginDrag(card.item.key, nil, card)
			end
		end)
	end
	for _, card in shopCards do
		hookCard(card)
	end
	for _, entry in storageCards do
		hookCard(entry.card)
	end
	for slotIndex, slot in slots do
		slot.button.InputBegan:Connect(function(input)
			-- Rearranging the hotbar only happens while a panel is open, so a normal click on a slot
			-- still just selects it.
			if openPanel and input.UserInputType == Enum.UserInputType.MouseButton1 then
				beginDrag(slot.itemKey, slotIndex)
			end
		end)
	end
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			finishDrag()
		end
	end)
	shopClose.Activated:Connect(function()
		setOpenPanel(nil)
	end)
	inventoryClose.Activated:Connect(function()
		setOpenPanel(nil)
	end)
	shopTool.button.Activated:Connect(function()
		togglePanel("Shop")
	end)
	bagTool.button.Activated:Connect(function()
		togglePanel("Inventory")
	end)

	panels.toggle = togglePanel
	panels.close = function()
		setOpenPanel(nil)
	end
	panels.isOpen = function(): boolean
		return openPanel ~= nil
	end
	panels.hovered = function(): Item?
		return hoveredCard
	end
	panels.assign = assignToSlot
	panels.refreshCards = refreshCards
end

-- Belt requests run one at a time in order, so a fast drag never lands out of sequence.
type BeltRequest = { action: string, x: number, z: number, dir: number, medium: string }
local beltQueue: { BeltRequest } = {}
local beltWorker = false

local function runBeltQueue()
	if beltWorker then
		return
	end
	beltWorker = true
	while #beltQueue > 0 do
		local request = table.remove(beltQueue, 1) :: BeltRequest
		local _, message
		if request.action == "place" then
			_, message =
				placeConveyorRemote:InvokeServer(request.x, request.z, request.dir, request.medium)
		else
			_, message = removeConveyorRemote:InvokeServer(request.x, request.z)
		end
		if typeof(message) == "string" then
			showMessage(message)
		end
	end
	beltWorker = false
end

local function queueBelt(action: string, x: number, z: number, dir: number)
	table.insert(beltQueue, { action = action, x = x, z = z, dir = dir, medium = transportMedium })
	task.spawn(runBeltQueue)
end

-- Belt start and end cells ---------------------------------------------------------------------
-- Every machine OUT has a start cell just outside it and every IN has an end cell. While laying
-- belts these show on the floor (teal start, gold end, with the arrow the tile needs), and tiles
-- placed on them take that direction automatically.

type Access = { dir: number, isInput: boolean }
local accessCells: { [string]: Access } = {}
local markerFolder: Folder? = nil

local START_COLOR = Color3.fromRGB(64, 200, 176)
local END_COLOR = Color3.fromRGB(246, 190, 72)

local function markerPart(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	transparency: number
)
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
end

local function buildMarker(parent: Instance, ix: number, iz: number, dir: number, isInput: boolean)
	local x, z = ConveyorGrid.Center(ix, iz)
	local color = if isInput then END_COLOR else START_COLOR
	local base = CFrame.new(x, floorTopY + 0.06, z) * CFrame.Angles(0, dir * math.pi / 2, 0)
	markerPart(parent, Vector3.new(3.7, 0.08, 3.7), base, color, 0.6)
	-- A big chevron pointing the way the tile must run.
	for _, side in { 1, -1 } do
		markerPart(
			parent,
			Vector3.new(1.9, 0.1, 0.35),
			base * CFrame.new(0.2, 0.05, side * 0.6) * CFrame.Angles(0, side * math.rad(40), 0),
			Color3.new(1, 1, 1),
			0.1
		)
	end
end

refreshAccessCells = function()
	table.clear(accessCells)
	if markerFolder then
		markerFolder:Destroy()
		markerFolder = nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "BeltTargets"
	for _, container in { production, factory, world } do
		for _, model in container:GetChildren() do
			local body = if model:IsA("Model") then model.PrimaryPart else nil
			if body and model:GetAttribute("MachineId") ~= nil then
				-- Every port of the medium being laid is a line end: item ports for belts,
				-- fluid or gas ports for pipes.
				for _, port in model:GetChildren() do
					if
						port:IsA("BasePart")
						and port:GetAttribute("PortMedium") == transportMedium
					then
						local offset = port.Position - body.Position
						local flat = Vector3.new(offset.X, 0, offset.Z)
						if flat.Magnitude > 1e-3 then
							local facing = flat.Unit
							local point = port.Position + facing * 2
							local ix, iz = ConveyorGrid.CellOf(point.X, point.Z)
							local away = ConveyorGrid.DirectionOf(facing.X, facing.Z)
							local isInput = port:GetAttribute("PortDirection") == "In"
							local dir = if isInput then (away + 2) % 4 else away
							accessCells[ConveyorGrid.Key(ix, iz)] = { dir = dir, isInput = isInput }
							buildMarker(folder, ix, iz, dir, isInput)
						end
					end
				end
			end
		end
	end
	folder.Parent = workspace
	markerFolder = folder
end

clearAccessCells = function()
	table.clear(accessCells)
	if markerFolder then
		markerFolder:Destroy()
		markerFolder = nil
	end
end

local function isEndCell(ix: number, iz: number): boolean
	local access = accessCells[ConveyorGrid.Key(ix, iz)]
	return access ~= nil and access.isInput
end

-- The direction a tile at this cell will get, and the direction to turn the previous tile so the
-- two join (nil when they do not touch).
local function predictDirection(ix: number, iz: number): (number, number?)
	if manualTurn then
		return beltDir, nil
	end
	local access = accessCells[ConveyorGrid.Key(ix, iz)]
	local last = lastPlaced
	local joinDir = if last then ConveyorGrid.DirectionBetween(last[1], last[2], ix, iz) else nil
	if joinDir and last and isEndCell(last[1], last[2]) then
		-- Never turn a tile that already points into a machine.
		joinDir = nil
	end
	if access and access.isInput then
		return access.dir, joinDir
	end
	if joinDir then
		return joinDir, joinDir
	end
	if access then
		return access.dir, nil
	end
	return beltDir, nil
end

local function placeTile(ix: number, iz: number)
	local dir, joinDir = predictDirection(ix, iz)
	local last = lastPlaced
	if joinDir and last then
		queueBelt("place", last[1], last[2], joinDir)
	end
	queueBelt("place", ix, iz, dir)
	beltDir = dir
	manualTurn = false
	lastPlaced = { ix, iz }
end

-- Delete tool ----------------------------------------------------------------------------------
-- Hover your machine or belt tile to see it outlined red, click to delete it, or hold and drag
-- across belt tiles to clear a run. The server refunds and refuses anything still holding items.

local deleteHighlight = Instance.new("Highlight")
deleteHighlight.Name = "DeleteTarget"
deleteHighlight.FillColor = Colors.Danger
deleteHighlight.OutlineColor = Colors.Danger
deleteHighlight.FillTransparency = 0.55
deleteHighlight.OutlineTransparency = 0
deleteHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
local deleteTarget: Model? = nil
local deletedCells: { [string]: boolean } = {}

clearDeleteTarget = function()
	deleteTarget = nil
	deleteHighlight.Adornee = nil
	deleteHighlight.Parent = nil
end

local function findDeletable(instance: Instance?): Model?
	local current = instance
	while current and current ~= world do
		if current:IsA("Model") then
			local isTile = current.Parent == conveyorFolder
			if isTile or current:GetAttribute("MachineId") ~= nil then
				-- Only your own things; the collection point and buyer have no owner.
				return if current:GetAttribute("OwnerUserId") == player.UserId then current else nil
			end
		end
		current = current.Parent
	end
	return nil
end

local function deleteModel(model: Model)
	if model.Parent == conveyorFolder then
		local x, z = model:GetAttribute("CellX"), model:GetAttribute("CellZ")
		if typeof(x) == "number" and typeof(z) == "number" then
			local key = ConveyorGrid.Key(x, z)
			if not deletedCells[key] then
				deletedCells[key] = true
				queueBelt("remove", x, z, 0)
			end
		end
		return
	end
	local id = model:GetAttribute("MachineId")
	if typeof(id) == "number" then
		task.spawn(function()
			deleteMachineRemote:InvokeServer(id)
		end)
	end
end

local function updateDeleteTarget()
	local result = mouseRaycast()
	local target = findDeletable(if result then result.Instance else nil)
	if target ~= deleteTarget then
		deleteTarget = target
		deleteHighlight.Adornee = target
		deleteHighlight.Parent = target
	end
	if dragging and target and target.Parent == conveyorFolder then
		deleteModel(target)
	end
end

-- Lays tiles from the last cell to the hovered cell, one neighbour at a time, turning the previous
-- tile so the line bends with the drag.
local function extendDrag(toX: number, toZ: number)
	local current = lastCell
	if current == nil then
		return
	end
	local x, z = current[1], current[2]
	local guard = 0
	while (x ~= toX or z ~= toZ) and guard < 64 do
		guard += 1
		local nextX, nextZ = x, z
		if x ~= toX then
			nextX = x + (if toX > x then 1 else -1)
		else
			nextZ = z + (if toZ > z then 1 else -1)
		end
		lastPlaced = { x, z }
		manualTurn = false
		placeTile(nextX, nextZ)
		x, z = nextX, nextZ
	end
	lastCell = { x, z }
	refreshPanel()
end

-- Ghost preview -------------------------------------------------------------------------------

local plotRect = PlacementRules.RectFromPart(floor)
local VALID_COLOR = Color3.fromRGB(88, 214, 141)
local INVALID_COLOR = Color3.fromRGB(226, 76, 60)

local function overlapsAny(rect: PlacementRules.Rect, others: { PlacementRules.Rect }): boolean
	for _, other in others do
		if
			rect.minX < other.maxX
			and rect.maxX > other.minX
			and rect.minZ < other.maxZ
			and rect.maxZ > other.minZ
		then
			return true
		end
	end
	return false
end

local function updateBeltGhost()
	local result = mouseRaycast()
	if result == nil then
		hoveredCell = nil
		if beltGhost then
			beltGhost.Parent = nil
		end
		return
	end
	local ix, iz = ConveyorGrid.CellOf(result.Position.X, result.Position.Z)
	hoveredCell = { ix, iz }
	local previous = lastCell
	if dragging and previous and (previous[1] ~= ix or previous[2] ~= iz) then
		extendDrag(ix, iz)
	end

	-- The ghost shows the arrow this tile will really get.
	local ghostDir = if dragging then beltDir else (predictDirection(ix, iz))
	ensureBeltGhost(ghostDir)
	local ghost = beltGhost :: Model
	local x, z = ConveyorGrid.Center(ix, iz)
	ghost:PivotTo(CFrame.new(x, floorTopY + 0.05, z))
	ghost.Parent = workspace

	local half = ConveyorGrid.CellSize / 2 - 0.05
	local rect = { minX = x - half, maxX = x + half, minZ = z - half, maxZ = z + half }
	tintBeltGhost(if overlapsAny(rect, collectBlockers()) then INVALID_COLOR else VALID_COLOR)
end

RunService.RenderStepped:Connect(function(deltaTime: number)
	-- Slowly turn the hovered or selected preview so the slot feels alive.
	for _, slot in slots do
		if slot == hoveredSlot or isSelected(slot) then
			slot.angle += deltaTime * 0.9
			framePreview(slot)
		end
	end

	if mode == "Delete" then
		updateDeleteTarget()
		return
	end
	if mode == "Conveyor" then
		updateBeltGhost()
		return
	end
	if mode ~= "Place" or selectedId == nil then
		return
	end
	local definition = MachineDefinitions[selectedId]
	local result = mouseRaycast()
	if result == nil then
		ghostPosition = nil
		ghostValid = false
		showGhost(false)
		return
	end
	showGhost(true)

	local position = result.Position
	if snapEnabled then
		position = PlacementRules.Snap(position)
	end
	ghostPosition = position

	-- Farm machines stand on the ground beside the paddy they would work.
	local paddies: { PlacementRules.PaddySite } = {}
	local groundY = floorTopY
	if definition.PlaceNear == "Paddy" then
		paddies = PaddySites.Collect(player.UserId)
		local index = PlacementRules.PaddyFor(
			PlacementRules.RectAt(definition, position, rotationSteps),
			paddies,
			definition.PaddyReach or 12
		)
		groundY = if index then paddies[index].groundY else result.Position.Y
	end
	local bodyCFrame = PlacementRules.BodyCFrame(definition, position, rotationSteps, groundY)
	if ghostArt then
		ghostArt:PivotTo(bodyCFrame * CFrame.new(0, -definition.Size.Y / 2, 0))
	else
		ghostBox.CFrame = bodyCFrame
	end
	ghostOutput.CFrame = bodyCFrame
		* CFrame.new(definition.Size.X / 2 + 1, -definition.Size.Y / 2 + 1.5, 0)

	local blockers = collectBlockers()
	for _, rect in tileBlockers() do
		table.insert(blockers, rect)
	end
	local valid, reason = PlacementRules.Validate(
		definition,
		position,
		rotationSteps,
		plotRect,
		blockers,
		if (player:GetAttribute("Owned_" .. selectedId) or 0) > 0 then math.huge else credits(),
		{
			unlocked = isUnlocked(),
			roads = roadRects,
			roadReach = CommitmentDefinitions.Truck.RoadReach,
			paddies = paddies,
		}
	)
	local research = researchNeeded(definition)
	if research then
		valid, reason =
			false,
			string.format("Research %s at the cooperative office first.", string.lower(research))
	end
	ghostValid = valid
	-- Spec 3.2: green means valid, red means invalid, and the reason is always shown as text.
	tintGhost(if valid then VALID_COLOR else INVALID_COLOR)
	if os.clock() - toastShownAt < 3 then
		-- Keep server results readable before the live preview text takes over again.
		return
	end
	if valid then
		setToast(
			string.format(
				"%s  |  %s credits",
				definition.DisplayName,
				UITheme.formatNumber(definition.Cost)
			),
			false
		)
	else
		setToast(reason, true)
	end
end)

-- Input ---------------------------------------------------------------------------------------

local function tryPlace()
	if requestInFlight or selectedId == nil or ghostPosition == nil then
		return
	end
	if not ghostValid then
		return
	end
	requestInFlight = true
	local ok, message = placeRemote:InvokeServer(selectedId, ghostPosition, rotationSteps)
	requestInFlight = false
	showMessage(if ok then message else "Not placed: " .. tostring(message))
end

local function toggleGrid()
	snapEnabled = not snapEnabled
	refreshPanel()
end

for _, slot in slots do
	slot.button.MouseEnter:Connect(function()
		hoveredSlot = slot
		showTooltip(slot)
		refreshPanel()
	end)
	slot.button.MouseLeave:Connect(function()
		if hoveredSlot == slot then
			hoveredSlot = nil
			showTooltip(nil)
			refreshPanel()
		end
	end)
	slot.button.Activated:Connect(function()
		activateSlot(slot)
	end)
end
gridTool.button.Activated:Connect(toggleGrid)
deleteTool.button.Activated:Connect(function()
	setMode(if mode == "Delete" then "None" else "Delete")
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	local slotIndex = table.find(SLOT_KEYS, input.KeyCode)
	local cell = hoveredCell
	local card = panels.hovered()
	local panelOpen = panels.isOpen()
	if input.KeyCode == Enum.KeyCode.B then
		panels.toggle("Inventory")
	elseif input.KeyCode == Enum.KeyCode.M then
		panels.toggle("Shop")
	elseif slotIndex and panelOpen then
		-- Hover a shop or inventory item and press a number to put it on that slot.
		if card then
			panels.assign(slotIndex, card.key)
		end
	elseif
		panelOpen and (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape)
	then
		panels.close()
	elseif panelOpen then
		return
	elseif slotIndex and slots[slotIndex] then
		activateSlot(slots[slotIndex])
	elseif input.KeyCode == Enum.KeyCode.R and mode == "Place" then
		rotationSteps = (rotationSteps + 1) % 4
		refreshPanel()
	elseif input.KeyCode == Enum.KeyCode.R and mode == "Conveyor" then
		local hovered = hoveredCell
		local current = if hovered then (predictDirection(hovered[1], hovered[2])) else beltDir
		beltDir = (current + 1) % 4
		manualTurn = true
		refreshPanel()
	elseif input.KeyCode == Enum.KeyCode.G then
		toggleGrid()
	elseif input.KeyCode == Enum.KeyCode.X then
		setMode(if mode == "Delete" then "None" else "Delete")
	elseif input.KeyCode == Enum.KeyCode.Q then
		setMode("None")
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		if mode == "Place" then
			task.spawn(tryPlace)
		elseif mode == "Delete" then
			dragging = true
			table.clear(deletedCells)
			local target = deleteTarget
			if target then
				deleteModel(target)
			end
		elseif mode == "Conveyor" and cell then
			dragging = true
			lastCell = { cell[1], cell[2] }
			placeTile(cell[1], cell[2])
			refreshPanel()
		end
	elseif
		input.UserInputType == Enum.UserInputType.MouseButton2
		and mode == "Conveyor"
		and cell
	then
		queueBelt("remove", cell[1], cell[2], 0)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
		lastCell = nil
	end
end)

noticeEvent.OnClientEvent:Connect(function(message: string)
	showMessage(message)
end)

for _, signal in { production.ChildAdded, production.ChildRemoved } do
	signal:Connect(function()
		if mode == "Conveyor" then
			task.defer(refreshAccessCells)
		end
	end)
end

for _, attribute in { "TutorialComplete", "Credits" } do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		refreshPanel()
		if hoveredSlot then
			showTooltip(hoveredSlot)
		end
	end)
end
-- A finished research project unlocks machines on the hotbar and in the inventory.
player.AttributeChanged:Connect(function(attribute)
	if string.sub(attribute, 1, 9) == "Research_" then
		refreshPanel()
		panels.refreshCards()
	end
end)

refreshPanel()
