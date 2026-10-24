--!strict

-- Free placement build mode (spec section 3). The ghost preview is local; the server re-validates
-- every machine and belt tile, so this script never decides credits or machine state.
-- UI: a bottom tool bar (1 build menu, 2 wrench, 3 delete, 4 grid), the build menu, context key
-- hints, and short toasts for server results.
-- Belts are laid tile by tile: click to place one, or hold and drag to lay a line that turns
-- wherever the drag turns. Machine IN/OUT ports only show while building, so the floor stays calm.

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

-- Everything the build menu offers, in menu order: id, menu category, and tier (the I to IV tabs).
-- Tier I is the opening factory and its power; II farm machines and tier 2 products; III steam;
-- IV biogas. Research still gates what can be placed inside a tier.
type CatalogEntry = { id: string, category: string, tier: number, transport: boolean? }
local BUILD_CATALOG: { CatalogEntry } = {
	{ id = "HandCrank", category = "Power", tier = 1 },
	{ id = "SolarPanel", category = "Power", tier = 1 },
	{ id = "PowerPole", category = "Power", tier = 1 },
	{ id = "Battery", category = "Power", tier = 1 },
	{ id = "StrawGenerator", category = "Power", tier = 1 },
	{ id = "DieselGenerator", category = "Power", tier = 1 },
	{ id = "WaterPump", category = "Extractors", tier = 1 },
	{ id = "Dryer", category = "Factories", tier = 1 },
	{ id = "Shredder", category = "Factories", tier = 1 },
	{ id = "PelletMill", category = "Factories", tier = 1 },
	{ id = "Item", category = "Logistics", tier = 1, transport = true },
	{ id = "Fluid", category = "Logistics", tier = 1, transport = true },
	{ id = "Gas", category = "Logistics", tier = 1, transport = true },
	{ id = "CoveredStorage", category = "Logistics", tier = 1 },
	{ id = "WaterTank", category = "Logistics", tier = 1 },
	{ id = "TruckTerminal", category = "Logistics", tier = 1 },
	{ id = "CooperativeOffice", category = "Research", tier = 1 },
	{ id = "Transplanter", category = "Farm", tier = 2 },
	{ id = "Combine", category = "Farm", tier = 2 },
	{ id = "Baler", category = "Farm", tier = 2 },
	{ id = "PyrolysisKiln", category = "Factories", tier = 2 },
	{ id = "MushroomHouse", category = "Factories", tier = 2 },
	{ id = "MarketStall", category = "Selling", tier = 2 },
	{ id = "Boiler", category = "Power", tier = 3 },
	{ id = "SteamTurbine", category = "Power", tier = 3 },
	{ id = "CattleShed", category = "Farm", tier = 4 },
	{ id = "Digester", category = "Factories", tier = 4 },
	{ id = "GasEngine", category = "Power", tier = 4 },
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

-- Everything the player can build or put on the hotbar.
type Item = {
	key: string,
	kind: string,
	id: string,
	name: string,
	category: string,
	tier: number?,
	blurb: string?,
}
local ITEMS: { Item } = {}
local ITEM_BY_KEY: { [string]: Item } = {}
for _, entry in BUILD_CATALOG do
	local kind = if entry.transport then "Transport" else "Machine"
	local item: Item = {
		key = kind .. ":" .. entry.id,
		kind = kind,
		id = entry.id,
		name = if entry.transport
			then PipeDefinitions.Types[entry.id].DisplayName
			else MachineDefinitions[entry.id].DisplayName,
		category = entry.category,
		tier = entry.tier,
	}
	table.insert(ITEMS, item)
	ITEM_BY_KEY[item.key] = item
end

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

local function iconBlock(parent: Frame, position: UDim2, size: UDim2, color: Color3): Frame
	local block = Instance.new("Frame")
	block.Position = position
	block.Size = size
	block.BackgroundColor3 = color
	block.BorderSizePixel = 0
	block.Parent = parent
	UITheme.corner(block, 3)
	return block
end

-- Build opens the build menu (B): every machine and pipe, by tier and category.
local buildTool = createToolSlot(51, "Build", "1", function(icon)
	for row = 0, 1 do
		for columnIndex = 0, 1 do
			iconBlock(
				icon,
				UDim2.fromOffset(3 + columnIndex * 13, 3 + row * 13),
				UDim2.fromOffset(11, 11),
				if row == columnIndex then Colors.Good else Colors.Text
			)
		end
	end
end)
-- The wrench (V) strings power wires between pole coils and machines.
local wrenchTool = createToolSlot(52, "Wrench", "2", function(icon)
	local handle = iconBlock(icon, UDim2.fromOffset(12, 6), UDim2.fromOffset(5, 22), Colors.Text)
	handle.Rotation = 45
	local head = iconBlock(icon, UDim2.fromOffset(16, 1), UDim2.fromOffset(12, 9), Colors.Gold)
	head.Rotation = 45
end)
-- The Delete tool removes your machines and belt tiles (and pipes once they exist).
local deleteTool = createToolSlot(53, "Delete", "3", function(icon)
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
local gridTool = createToolSlot(54, "Grid", "4", function(icon)
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

local function refreshPanel()
	local deleting = mode == "Delete"
	deleteTool.stroke.Color = if deleting then Colors.Danger else Colors.Outline
	deleteTool.stroke.Transparency = if deleting then 0 else 0.88
	deleteTool.stroke.Thickness = if deleting then 2 else 1
	deleteTool.caption.TextColor3 = if deleting then Colors.Danger else Colors.Muted

	local wiring = mode == "Wire"
	wrenchTool.stroke.Color = if wiring then Colors.Gold else Colors.Outline
	wrenchTool.stroke.Transparency = if wiring then 0 else 0.88
	wrenchTool.stroke.Thickness = if wiring then 2 else 1
	wrenchTool.caption.TextColor3 = if wiring then Colors.Gold else Colors.Muted

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
	elseif mode == "Wire" then
		setHints({
			{ "LMB", "Click a pole coil, then a machine or another coil" },
			{ "RMB", "Let go of the wire" },
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

-- Filled in by the wrench section below.
local wrench: any = {}

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
	if mode ~= "Wire" then
		wrench.clear()
	end
	setPortsVisible(mode == "Place" or mode == "Conveyor")
	refreshPanel()
end

-- Lay belts or pipes of one kind.
local function beginTransport(medium: string)
	transportMedium = medium
	setMode("Conveyor")
end

-- The build menu lives in its own scope: the script's top level is close to Luau's limit of 200
-- locals. The rest of the script reaches it through `panels`.
local panels: any = {}
do
	-- Build menu ------------------------------------------------------------------------------------
	-- B or the Build button opens it, laid out like Industrialist's: the selected item on the left
	-- (its picture, what it does, its price and Start Placing [T]), every item on the right in
	-- collapsible categories, and tier tabs I to IV down the right edge. Search [R] filters every
	-- tier at once. Click an item to read about it, click it again (or press T) to place it.
	-- There is no inventory: placing pays the price, and removing a machine pays it all back.
	-- Machines from the starting kit show their free count on the tile and are used first.

	local MENU_WIDTH = 1000
	local MENU_HEIGHT = 560
	local LEFT_WIDTH = 280
	local TIER_WIDTH = 64
	local TILE_WIDTH = 128
	local TILE_HEIGHT = 120
	local TIER_NAMES = { "I", "II", "III", "IV" }
	local CATEGORY_ORDER =
		{ "Power", "Extractors", "Factories", "Farm", "Logistics", "Selling", "Research" }

	local function setTool(tool: ToolSlot, active: boolean)
		tool.stroke.Color = if active then Colors.Text else Colors.Outline
		tool.stroke.Transparency = if active then 0 else 0.88
		tool.stroke.Thickness = if active then 2 else 1
	end

	local isOpen = false
	local hoveredItem: Item? = nil
	local selectedItem: Item? = nil
	local selectedTier = 1
	local searchText = ""
	local collapsed: { [string]: boolean } = {}

	local function freeCount(item: Item): number
		if item.kind ~= "Machine" then
			return 0
		end
		local value = player:GetAttribute("Owned_" .. item.id)
		return if typeof(value) == "number" then value else 0
	end

	local function itemLocked(item: Item): boolean
		return item.kind == "Future"
			or (item.kind == "Transport" and not PipeDefinitions.Types[item.id].Ready)
			or (item.kind == "Machine" and machineLocked(MachineDefinitions[item.id]))
	end

	local function bevel(frame: GuiObject, top: Color3, bottom: Color3)
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new(top, bottom)
		gradient.Parent = frame
	end

	local function label(
		parent: Instance,
		name: string,
		text: string,
		size: UDim2,
		textSize: number
	): TextLabel
		return UITheme.text(parent, {
			name = name,
			text = text,
			size = size,
			font = Fonts.Bold,
			textSize = textSize,
			alignX = Enum.TextXAlignment.Center,
		})
	end

	local menu = Instance.new("Frame")
	menu.Name = "BuildMenu"
	menu.AnchorPoint = Vector2.new(0.5, 0.5)
	menu.Position = UDim2.new(0.5, 0, 0.5, -30)
	menu.Size = UDim2.fromOffset(MENU_WIDTH, MENU_HEIGHT)
	menu.BackgroundTransparency = 1
	menu.Visible = false
	menu.ZIndex = 20
	menu.Parent = screenGui

	-- Centred over the item list, between the search box and the close button.
	local title = label(menu, "Title", "Build", UDim2.fromOffset(140, 44), 30)
	title.Position = UDim2.fromOffset(LEFT_WIDTH + 12 + 260, 0)
	title.TextStrokeTransparency = 0.6

	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.Position = UDim2.fromOffset(LEFT_WIDTH + 14, 6)
	search.Size = UDim2.fromOffset(240, 32)
	search.BackgroundColor3 = Colors.Panel
	search.BackgroundTransparency = 0.1
	search.PlaceholderText = "Search [R]"
	search.PlaceholderColor3 = Colors.Muted
	search.Text = ""
	search.ClearTextOnFocus = false
	search.FontFace = Fonts.Regular
	search.TextSize = 17
	search.TextColor3 = Colors.Text
	search.TextXAlignment = Enum.TextXAlignment.Left
	search.Parent = menu
	UITheme.corner(search, 8)
	UITheme.outline(search, Colors.Outline, 0.75)
	UITheme.padding(search, 0, 10)

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -TIER_WIDTH - 6, 0, 6)
	close.Size = UDim2.fromOffset(130, 30)
	close.BackgroundColor3 = Colors.Danger
	close.Text = "X"
	close.FontFace = Fonts.Heavy
	close.TextSize = 18
	close.TextColor3 = Colors.Text
	close.AutoButtonColor = true
	close.Parent = menu
	UITheme.corner(close, 8)
	bevel(close, Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))

	local function panel(name: string, position: UDim2, size: UDim2): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.Position = position
		frame.Size = size
		frame.BackgroundColor3 = Colors.Panel
		frame.BackgroundTransparency = 0.04
		frame.BorderSizePixel = 0
		frame.Parent = menu
		UITheme.corner(frame, 14)
		UITheme.outline(frame, Colors.Outline, 0.8)
		return frame
	end

	-- Left: the selected item ----------------------------------------------------------------------

	local left =
		panel("Item", UDim2.fromOffset(0, 50), UDim2.fromOffset(LEFT_WIDTH, MENU_HEIGHT - 50))
	UITheme.padding(left, 12, 12)

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.new(1, 0, 0, 200)
	card.BackgroundColor3 = Colors.Raised
	card.BorderSizePixel = 0
	card.Parent = left
	UITheme.corner(card, 12)
	UITheme.outline(card, Colors.Outline, 0.85)
	bevel(card, Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
	local cardName = label(card, "Name", "", UDim2.new(1, -12, 0, 34), 22)
	cardName.Position = UDim2.fromOffset(6, 4)
	cardName.TextScaled = true
	local cardView = Instance.new("Frame")
	cardView.Name = "View"
	cardView.Position = UDim2.fromOffset(10, 40)
	cardView.Size = UDim2.new(1, -20, 1, -50)
	cardView.BackgroundTransparency = 1
	cardView.Parent = card
	local cardPreview: Preview? = nil

	local about = Instance.new("ScrollingFrame")
	about.Name = "About"
	about.Position = UDim2.fromOffset(0, 212)
	about.Size = UDim2.new(1, 0, 1, -212 - 76)
	about.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
	about.BackgroundTransparency = 0.2
	about.BorderSizePixel = 0
	about.ScrollBarThickness = 5
	about.ScrollBarImageColor3 = Colors.Muted
	about.AutomaticCanvasSize = Enum.AutomaticSize.Y
	about.CanvasSize = UDim2.new()
	about.Parent = left
	UITheme.corner(about, 10)
	UITheme.padding(about, 10, 10)
	UITheme.list(about, 8)
	local job = UITheme.text(about, {
		name = "Job",
		size = UDim2.fromScale(1, 0),
		font = Fonts.Regular,
		textSize = 16,
		alignX = Enum.TextXAlignment.Center,
		wrap = true,
		order = 1,
	})
	job.AutomaticSize = Enum.AutomaticSize.Y
	local stats = UITheme.text(about, {
		name = "Stats",
		size = UDim2.fromScale(1, 0),
		textSize = 13,
		color = Colors.Muted,
		wrap = true,
		order = 2,
		alignY = Enum.TextYAlignment.Top,
	})
	stats.AutomaticSize = Enum.AutomaticSize.Y
	stats.RichText = true

	local price = label(left, "Price", "", UDim2.new(1, 0, 0, 24), 20)
	price.AnchorPoint = Vector2.new(0, 1)
	price.Position = UDim2.new(0, 0, 1, -42)
	price.TextColor3 = Colors.Good

	local place = Instance.new("TextButton")
	place.Name = "StartPlacing"
	place.AnchorPoint = Vector2.new(0, 1)
	place.Position = UDim2.fromScale(0, 1)
	place.Size = UDim2.new(1, 0, 0, 38)
	place.BackgroundColor3 = Colors.Good
	place.Text = "Start Placing [T]"
	place.FontFace = Fonts.Bold
	place.TextSize = 19
	place.TextColor3 = Color3.fromRGB(16, 40, 16)
	place.AutoButtonColor = true
	place.Parent = left
	UITheme.corner(place, 10)
	bevel(place, Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))

	-- Right: categories of item tiles --------------------------------------------------------------

	local rightX = LEFT_WIDTH + 12
	local right = panel(
		"Items",
		UDim2.fromOffset(rightX, 50),
		UDim2.fromOffset(MENU_WIDTH - rightX - TIER_WIDTH - 10, MENU_HEIGHT - 50)
	)
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = Colors.Muted
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = right
	UITheme.padding(list, 12, 14)
	UITheme.list(list, 10)

	type Tile = {
		item: Item,
		button: TextButton,
		count: TextLabel,
		lock: TextLabel,
		stroke: UIStroke,
		preview: Preview,
	}
	type Section = {
		name: string,
		header: TextButton,
		arrow: TextLabel,
		grid: Frame,
		tiles: { Tile },
	}
	local sections: { [string]: Section } = {}
	local tiles: { Tile } = {}

	local function createSection(name: string, order: number): Section
		local header = Instance.new("TextButton")
		header.Name = name .. "Header"
		header.Size = UDim2.new(1, 0, 0, 50)
		header.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
		header.BackgroundTransparency = 0.1
		header.Text = ""
		header.AutoButtonColor = true
		header.LayoutOrder = order * 2
		header.Parent = list
		UITheme.corner(header, 12)
		UITheme.outline(header, Colors.Outline, 0.9)
		label(header, "Title", name, UDim2.fromScale(1, 1), 28)
		local arrow = label(header, "Arrow", "▼", UDim2.fromOffset(40, 50), 22)
		arrow.AnchorPoint = Vector2.new(1, 0)
		arrow.Position = UDim2.new(1, -8, 0, 0)

		local grid = Instance.new("Frame")
		grid.Name = name .. "Grid"
		grid.Size = UDim2.fromScale(1, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.BackgroundTransparency = 1
		grid.LayoutOrder = order * 2 + 1
		grid.Parent = list
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(TILE_WIDTH, TILE_HEIGHT)
		layout.CellPadding = UDim2.fromOffset(8, 8)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 8)
		padding.Parent = grid

		local section = { name = name, header = header, arrow = arrow, grid = grid, tiles = {} }
		header.Activated:Connect(function()
			collapsed[name] = not collapsed[name]
			panels.refresh()
		end)
		return section
	end
	for order, name in CATEGORY_ORDER do
		sections[name] = createSection(name, order)
	end

	local function createTile(item: Item, order: number): Tile
		local section = sections[item.category] or sections.Factories
		local button = Instance.new("TextButton")
		button.Name = item.key
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundColor3 = Colors.Raised
		button.BorderSizePixel = 0
		button.LayoutOrder = order
		button.Parent = section.grid
		UITheme.corner(button, 10)
		local stroke = UITheme.outline(button, Colors.Outline, 0.85)
		bevel(button, Color3.new(1, 1, 1), Color3.fromRGB(130, 130, 130))

		local view = Instance.new("Frame")
		view.Name = "View"
		view.Position = UDim2.fromOffset(6, 26)
		view.Size = UDim2.new(1, -12, 1, -44)
		view.BackgroundTransparency = 1
		view.Parent = button
		local _, camera, focus, radius = createViewport(view, previewModelFor(item))

		local name = label(button, "Name", item.name, UDim2.new(1, -8, 0, 22), 15)
		name.Position = UDim2.fromOffset(4, 3)
		name.TextScaled = true
		local count = UITheme.text(button, {
			name = "Count",
			size = UDim2.fromOffset(60, 16),
			font = Fonts.Bold,
			textSize = 13,
		})
		count.Position = UDim2.new(0, 7, 1, -19)
		local cost = UITheme.text(button, {
			name = "Cost",
			text = if item.kind == "Machine"
				then UITheme.formatNumber(MachineDefinitions[item.id].Cost)
				else UITheme.formatNumber(PipeDefinitions.Types[item.id].Cost or 0) .. "/tile",
			size = UDim2.fromOffset(70, 16),
			font = Fonts.Bold,
			textSize = 13,
			color = Colors.Good,
			alignX = Enum.TextXAlignment.Right,
		})
		cost.AnchorPoint = Vector2.new(1, 0)
		cost.Position = UDim2.new(1, -7, 1, -19)

		local lock = label(button, "Lock", "LOCKED", UDim2.fromScale(1, 1), 16)
		lock.BackgroundColor3 = Colors.Panel
		lock.BackgroundTransparency = 0.35
		lock.TextColor3 = Colors.Muted
		lock.Visible = false
		UITheme.corner(lock, 10)

		local tile: Tile = {
			item = item,
			button = button,
			count = count,
			lock = lock,
			stroke = stroke,
			preview = { camera = camera, focus = focus, radius = radius, angle = math.rad(40) },
		}
		framePreview(tile.preview)
		table.insert(section.tiles, tile)
		return tile
	end
	for order, item in ITEMS do
		table.insert(tiles, createTile(item, order))
	end

	-- Tier tabs ------------------------------------------------------------------------------------

	local tierColumn =
		panel("Tiers", UDim2.new(1, -TIER_WIDTH, 0, 60), UDim2.fromOffset(TIER_WIDTH, 4 * 58 + 10))
	UITheme.padding(tierColumn, 6, 6)
	UITheme.list(tierColumn, 6)
	local tierButtons: { TextButton } = {}
	for tier, tierName in TIER_NAMES do
		local button = Instance.new("TextButton")
		button.Name = "Tier" .. tier
		button.Size = UDim2.fromOffset(TIER_WIDTH - 12, 52)
		button.BackgroundColor3 = Colors.Raised
		button.Text = tierName
		button.FontFace = Fonts.Bold
		button.TextSize = 26
		button.TextColor3 = Colors.Text
		button.AutoButtonColor = true
		button.LayoutOrder = tier
		button.Parent = tierColumn
		UITheme.corner(button, 10)
		UITheme.outline(button, Colors.Outline, 0.85)
		bevel(button, Color3.new(1, 1, 1), Color3.fromRGB(140, 140, 140))
		button.Activated:Connect(function()
			selectedTier = tier
			search.Text = ""
			panels.refresh()
		end)
		tierButtons[tier] = button
	end

	-- Everything inside the menu draws above the world UI.
	for _, descendant in menu:GetDescendants() do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = math.max(descendant.ZIndex, 20)
				+ (if descendant.Name == "Lock" then 3 else 0)
		end
	end

	-- Details --------------------------------------------------------------------------------------

	local function per(value: number, seconds: number): string
		local perMinute = value * 60 / seconds
		return if perMinute == math.floor(perMinute)
			then string.format("%d", perMinute)
			else string.format("%.1f", perMinute)
	end

	-- The item's numbers, read straight from its definition so the menu never goes stale.
	local function statsFor(item: Item): string
		local lines: { string } = {}
		local function add(name: string, value: string)
			table.insert(lines, string.format('<font color="#E6E6E6">%s</font>  %s', name, value))
		end
		if item.kind == "Transport" then
			local pipe = PipeDefinitions.Types[item.id]
			add("Carries", pipe.Carries)
			add("Speed", string.format("%d studs per second", pipe.StudsPerSecond or 8))
			return table.concat(lines, "\n")
		end
		local definition = MachineDefinitions[item.id]
		if definition == nil then
			return ""
		end
		add("Footprint", string.format("%d x %d studs", definition.Size.X, definition.Size.Z))
		local kind = definition.Kind
		if (definition.PowerKW or 0) > 0 then
			add("Power", string.format("uses %d kW while working", definition.PowerKW))
		end
		if kind == "Processor" then
			if definition.InputItem then
				add(
					"Input",
					string.format("%d %s", definition.InputPerCycle, itemName(definition.InputItem))
				)
			end
			add(
				"Output",
				string.format("%d %s", definition.OutputPerCycle, itemName(definition.OutputItem))
			)
			for _, port in definition.ExtraPorts or {} do
				if port.Item then
					add(
						if port.Direction == "In" then "Also takes" else "Also makes",
						string.format(
							"%d %s (%s)",
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
		elseif kind == "Storage" then
			add("Holds", string.format("%d units", definition.Capacity))
		elseif kind == "Sink" then
			local prices = {}
			for itemId, value in definition.Prices or {} do
				table.insert(prices, string.format("%s %d", itemName(itemId), value))
			end
			table.sort(prices)
			add("Buys", table.concat(prices, ", "))
		elseif kind == "Terminal" then
			add("Truck", "Carries 8 bundles a trip from Farm B or C")
			add("Placement", "Beside a road")
		elseif kind == "Farm" then
			add(
				"Placement",
				string.format("Beside a paddy, within %d studs", definition.PaddyReach or 12)
			)
		elseif kind == "Generator" then
			add("Makes", string.format("%d kW", definition.PowerOutputKW))
			if definition.SmogPerCycle then
				add("Smog", "A little while it runs")
			end
		elseif kind == "Battery" then
			add("Stores", string.format("%s kJ", UITheme.formatNumber(definition.CapacityKJ)))
			add("Rate", string.format("%d kW in or out", definition.RateKW))
		elseif kind == "Pole" then
			add("Coils", string.format("%d, wire each with the wrench (V)", definition.Coils or 2))
			add("Wire reach", string.format("%d studs", definition.Reach))
		elseif kind == "Office" then
			add("Staff", string.format("Up to %d engineers", ResearchDefinitions.MaxEngineers))
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

	local function refreshDetails()
		local item = selectedItem
		if item == nil then
			cardName.Text = "Build"
			job.Text = "Pick an item on the right to see what it does."
			stats.Text = ""
			price.Text = ""
			place.Visible = false
			return
		end
		cardName.Text = item.name
		local info = ITEM_INFO[item.id]
		job.Text = if info then info.recipe .. "\n" .. info.detail else (item.blurb or "")
		stats.Text = statsFor(item)
		place.Visible = true
		local locked = itemLocked(item)
		local free = freeCount(item)
		if item.kind == "Machine" then
			local definition = MachineDefinitions[item.id]
			local research = researchNeeded(definition)
			price.Text = if research
				then "Research " .. string.lower(research)
				elseif locked then "Unlocks after your first sale"
				elseif free > 0 then string.format("Free (%d left)", free)
				else UITheme.formatNumber(definition.Cost) .. " credits"
			price.TextColor3 = if locked
				then Colors.Danger
				elseif free > 0 or credits() >= definition.Cost then Colors.Good
				else Colors.Danger
		else
			price.Text =
				string.format("%d credits per tile", PipeDefinitions.Types[item.id].Cost or 0)
			price.TextColor3 = Colors.Good
		end
		place.BackgroundColor3 = if locked then Colors.Track else Colors.Good
		place.AutoButtonColor = not locked
	end

	local function selectItem(item: Item)
		selectedItem = item
		cardView:ClearAllChildren()
		local viewport, camera, focus, radius = createViewport(cardView, previewModelFor(item))
		viewport.ZIndex = 21
		cardPreview = { camera = camera, focus = focus, radius = radius, angle = math.rad(40) }
		framePreview(cardPreview :: Preview)
		for _, tile in tiles do
			local chosen = tile.item == item
			tile.stroke.Color = if chosen then Colors.Text else Colors.Outline
			tile.stroke.Transparency = if chosen then 0 else 0.85
			tile.stroke.Thickness = if chosen then 2 else 1
		end
		refreshDetails()
	end

	local function matches(item: Item): boolean
		if searchText ~= "" then
			return string.find(string.lower(item.name), searchText, 1, true) ~= nil
		end
		return (item.tier or 1) == selectedTier
	end

	local function refresh()
		for _, tile in tiles do
			local locked = itemLocked(tile.item)
			tile.lock.Visible = locked
			tile.lock.Text = if tile.item.kind == "Machine"
					and researchNeeded(MachineDefinitions[tile.item.id])
				then "RESEARCH"
				else "LOCKED"
			local free = freeCount(tile.item)
			tile.count.Text = tostring(free)
			tile.button.Visible = matches(tile.item)
		end
		for name, section in sections do
			local any = false
			for _, tile in section.tiles do
				if tile.button.Visible then
					any = true
				end
			end
			section.header.Visible = any
			section.grid.Visible = any and not collapsed[name]
			section.arrow.Rotation = if collapsed[name] then -90 else 0
		end
		for tier, button in tierButtons do
			local chosen = tier == selectedTier and searchText == ""
			button.BackgroundColor3 = if chosen then Colors.Hover else Colors.Raised
			local stroke = button:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = if chosen then 0 else 0.85
			end
		end
		refreshDetails()
	end

	search:GetPropertyChangedSignal("Text"):Connect(function()
		searchText = string.lower(search.Text)
		refresh()
	end)

	local function setOpen(open: boolean)
		isOpen = open
		menu.Visible = open
		hoveredItem = nil
		setTool(buildTool, open)
		if open then
			setMode("None")
			if selectedItem == nil then
				local first = ITEMS[1]
				if first then
					selectItem(first)
				end
			end
			refresh()
		else
			search:ReleaseFocus()
		end
	end

	local function startPlacing()
		local item = selectedItem
		if item == nil or itemLocked(item) then
			if item then
				showMessage(price.Text)
			end
			return
		end
		setOpen(false)
		if item.kind == "Transport" then
			beginTransport(item.id)
		else
			setMode("Place", item.id)
		end
	end
	place.Activated:Connect(startPlacing)
	close.Activated:Connect(function()
		setOpen(false)
	end)

	player.AttributeChanged:Connect(function(attribute)
		if
			isOpen
			and (
				string.sub(attribute, 1, 6) == "Owned_"
				or attribute == "Credits"
				or string.sub(attribute, 1, 9) == "Research_"
				or attribute == "TutorialComplete"
			)
		then
			refresh()
		end
	end)

	RunService.RenderStepped:Connect(function(deltaTime: number)
		if not isOpen then
			return
		end
		for _, tile in tiles do
			if tile.item == hoveredItem then
				tile.preview.angle += deltaTime * 0.9
				framePreview(tile.preview)
			end
		end
		local preview = cardPreview
		if preview then
			preview.angle += deltaTime * 0.6
			framePreview(preview)
		end
	end)

	for _, tile in tiles do
		tile.button.MouseEnter:Connect(function()
			hoveredItem = tile.item
		end)
		tile.button.MouseLeave:Connect(function()
			if hoveredItem == tile.item then
				hoveredItem = nil
			end
		end)
		tile.button.Activated:Connect(function()
			if selectedItem == tile.item then
				startPlacing()
			else
				selectItem(tile.item)
			end
		end)
	end
	buildTool.button.Activated:Connect(function()
		setOpen(not isOpen)
	end)

	panels.toggle = function()
		setOpen(not isOpen)
	end
	panels.close = function()
		setOpen(false)
	end
	panels.isOpen = function(): boolean
		return isOpen
	end
	panels.focusSearch = function()
		search:CaptureFocus()
	end
	panels.startPlacing = startPlacing
	panels.refresh = refresh
	panels.refreshCards = refresh
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

-- Wrench ---------------------------------------------------------------------------------------
-- Strings power wires like Industrialist's wrench: click one of a pole's two coils, then a
-- generator, battery or machine (or another coil). Clicking the same two ends again takes the wire
-- down. The server checks ownership, reach and coils (PowerService).

do
	local powerWireRemote = remotes:WaitForChild("PowerWire") :: RemoteFunction

	type WireEnd = { id: number, coil: number?, part: BasePart, model: Model }
	local first: WireEnd? = nil
	local hovered: WireEnd? = nil
	local busy = false

	local function newHighlight(name: string, color: Color3): Highlight
		local highlight = Instance.new("Highlight")
		highlight.Name = name
		highlight.FillColor = color
		highlight.OutlineColor = color
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		return highlight
	end
	local hoverHighlight = newHighlight("WireTarget", Colors.Good)
	local firstHighlight = newHighlight("WireStart", Colors.Gold)

	local preview = Instance.new("Part")
	preview.Name = "WirePreview"
	preview.Anchored = true
	preview.CanCollide = false
	preview.CanQuery = false
	preview.CanTouch = false
	preview.CastShadow = false
	preview.Material = Enum.Material.Neon
	preview.Color = Colors.Gold

	local function mark(highlight: Highlight, target: WireEnd?)
		local adornee: Instance? = if target
			then (if target.coil then target.part else target.model)
			else nil
		highlight.Adornee = adornee
		highlight.Parent = adornee
	end

	local function endPosition(target: WireEnd): Vector3
		if target.coil then
			return target.part.Position
		end
		local marker = target.model:FindFirstChild("WireTop", true)
		if marker and marker:IsA("BasePart") then
			return marker.Position
		end
		return target.part.Position + Vector3.new(0, target.part.Size.Y / 2, 0)
	end

	-- What a click on this part would wire to, or why it cannot.
	local function resolve(instance: Instance?): (WireEnd?, string?)
		local coil = if instance then instance:GetAttribute("Coil") else nil
		local current = instance
		while current and current ~= world do
			if current:IsA("Model") and current:GetAttribute("MachineId") ~= nil then
				break
			end
			current = current.Parent
		end
		if current == nil or current == world or not current:IsA("Model") then
			return nil, nil
		end
		local model = current :: Model
		if model:GetAttribute("OwnerUserId") ~= player.UserId then
			return nil, nil
		end
		local id = model:GetAttribute("MachineId") :: number
		local definition = MachineDefinitions[model:GetAttribute("DefinitionId") :: string]
		if definition == nil then
			return nil, nil
		end
		if definition.Kind == "Pole" then
			if typeof(coil) == "number" and instance and instance:IsA("BasePart") then
				return { id = id, coil = coil, part = instance, model = model }, nil
			end
			return nil, "Click one of the pole's two coils."
		end
		local powered = definition.Kind == "Generator"
			or definition.Kind == "Battery"
			or (definition.PowerKW or 0) > 0
		local body = model.PrimaryPart
		if powered and body then
			return { id = id, coil = nil, part = body, model = model }, nil
		end
		return nil, definition.DisplayName .. " does not use power."
	end

	wrench.update = function()
		local result = mouseRaycast()
		local target, why = resolve(if result then result.Instance else nil)
		if hovered == nil or target == nil or hovered.part ~= target.part then
			hovered = target
			mark(hoverHighlight, target)
		end
		local start = first
		if start then
			local from = endPosition(start)
			local to = if target then endPosition(target) elseif result then result.Position else nil
			if to and (to - from).Magnitude > 0.1 then
				preview.Size = Vector3.new(0.18, 0.18, (to - from).Magnitude)
				preview.CFrame = CFrame.lookAt((from + to) / 2, to)
				preview.Parent = workspace
			else
				preview.Parent = nil
			end
		end
		if why and os.clock() - toastShownAt >= 3 then
			setToast(why, true)
		end
	end

	wrench.cancel = function()
		first = nil
		mark(firstHighlight, nil)
		preview.Parent = nil
	end

	wrench.click = function()
		local target = hovered
		if target == nil or busy then
			return
		end
		local start = first
		if start == nil then
			first = target
			mark(firstHighlight, target)
			showMessage("Now click the other end of the wire.")
			return
		end
		wrench.cancel()
		busy = true
		task.spawn(function()
			local _, message =
				powerWireRemote:InvokeServer(start.id, start.coil, target.id, target.coil)
			busy = false
			if typeof(message) == "string" then
				showMessage(message)
			end
		end)
	end

	wrench.clear = function()
		wrench.cancel()
		hovered = nil
		mark(hoverHighlight, nil)
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

RunService.RenderStepped:Connect(function()
	if mode == "Wire" then
		wrench.update()
		return
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

local function toggleWrench()
	setMode(if mode == "Wire" then "None" else "Wire")
end

gridTool.button.Activated:Connect(toggleGrid)
wrenchTool.button.Activated:Connect(toggleWrench)
deleteTool.button.Activated:Connect(function()
	setMode(if mode == "Delete" then "None" else "Delete")
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	local cell = hoveredCell
	local panelOpen = panels.isOpen()
	-- Tool keys: 1 build menu, 2 wrench, 3 delete, 4 grid (B, V, X and G also work).
	if input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.B then
		panels.toggle()
	elseif panelOpen and input.KeyCode == Enum.KeyCode.R then
		panels.focusSearch()
	elseif panelOpen and input.KeyCode == Enum.KeyCode.T then
		panels.startPlacing()
	elseif
		panelOpen and (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape)
	then
		panels.close()
	elseif panelOpen then
		return
	elseif input.KeyCode == Enum.KeyCode.Two or input.KeyCode == Enum.KeyCode.V then
		toggleWrench()
	elseif input.KeyCode == Enum.KeyCode.Three or input.KeyCode == Enum.KeyCode.X then
		setMode(if mode == "Delete" then "None" else "Delete")
	elseif input.KeyCode == Enum.KeyCode.Four or input.KeyCode == Enum.KeyCode.G then
		toggleGrid()
	elseif input.KeyCode == Enum.KeyCode.R and mode == "Place" then
		rotationSteps = (rotationSteps + 1) % 4
		refreshPanel()
	elseif input.KeyCode == Enum.KeyCode.R and mode == "Conveyor" then
		local hovered = hoveredCell
		local current = if hovered then (predictDirection(hovered[1], hovered[2])) else beltDir
		beltDir = (current + 1) % 4
		manualTurn = true
		refreshPanel()
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
		elseif mode == "Wire" then
			wrench.click()
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 and mode == "Wire" then
		wrench.cancel()
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
	end)
end
-- A finished research project unlocks machines in the build menu.
player.AttributeChanged:Connect(function(attribute)
	if string.sub(attribute, 1, 9) == "Research_" then
		refreshPanel()
		panels.refreshCards()
	end
end)

refreshPanel()
