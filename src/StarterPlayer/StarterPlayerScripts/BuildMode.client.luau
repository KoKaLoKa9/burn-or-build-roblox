--!strict

-- Free placement build mode (spec section 3). The ghost preview is local; the server re-validates
-- every machine and belt tile, so this script never decides credits or machine state.
-- UI: a bottom hotbar of machine slots and transport slots with live 3D previews, a Grid tool,
-- context key hints, a tooltip, and short toasts for server results.
-- Belts are laid tile by tile: click to place one, or hold and drag to lay a line that turns
-- wherever the drag turns. Machine IN/OUT ports only show while building, so the floor stays calm.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MachineDefinitions = require(Shared:WaitForChild("MachineDefinitions"))
local MachineArt = require(Shared:WaitForChild("MachineArt"))
local PipeDefinitions = require(Shared:WaitForChild("PipeDefinitions"))
local PipeRoute = require(Shared:WaitForChild("PipeRoute"))
local ConveyorGrid = require(Shared:WaitForChild("ConveyorGrid"))
local ConveyorTile = require(Shared:WaitForChild("ConveyorTile"))
local PlacementRules = require(Shared:WaitForChild("PlacementRules"))
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

local PORT_NAMES = { InputPort = true, OutputPort = true }
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
		if descendant:IsA("BasePart") and PORT_NAMES[descendant.Name] then
			applyPortVisibility(descendant)
		end
	end
end

world.DescendantAdded:Connect(function(descendant: Instance)
	if descendant:IsA("BasePart") and PORT_NAMES[descendant.Name] then
		applyPortVisibility(descendant)
	elseif
		descendant:IsA("BillboardGui")
		and descendant.Parent
		and PORT_NAMES[descendant.Parent.Name]
	then
		descendant.Enabled = portsVisible
	end
end)
for _, descendant in world:GetDescendants() do
	if descendant:IsA("BasePart") and PORT_NAMES[descendant.Name] then
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
local beltGhostColors: { [BasePart]: Color3 } = {}
local beltGhostTint: Color3? = nil

local function clearBeltGhost()
	if beltGhost then
		beltGhost:Destroy()
		beltGhost = nil
	end
	table.clear(beltGhostColors)
	beltGhostDir = -1
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
	if beltGhost and beltGhostDir == dir then
		return
	end
	clearBeltGhost()
	local model = ConveyorTile.Build(dir, { [dir] = true, [(dir + 2) % 4] = true })
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 0.35
			descendant.CanQuery = false
			beltGhostColors[descendant] = descendant.Color
		end
	end
	beltGhost = model
	beltGhostDir = dir
end

-- Screen --------------------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BuildModeGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

local function isUnlocked(): boolean
	return player:GetAttribute("TutorialComplete") == true
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

type Slot = {
	kind: string,
	id: string,
	button: TextButton,
	stroke: UIStroke,
	viewport: ViewportFrame,
	camera: Camera,
	focus: Vector3,
	radius: number,
	angle: number,
	cost: TextLabel,
	lockOverlay: Frame,
}
local slots: { Slot } = {}
local hoveredSlot: Slot? = nil

local function framePreview(slot: Slot)
	-- A three-quarter view from the input side, like a product shot.
	local direction = Vector3.new(-math.cos(slot.angle), 0.75, math.sin(slot.angle)).Unit
	local distance = slot.radius / math.tan(math.rad(slot.camera.FieldOfView / 2)) * 0.92
	slot.camera.CFrame = CFrame.lookAt(slot.focus + direction * distance, slot.focus)
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

local function createSlotShell(index: number, name: string): (TextButton, UIStroke)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = ""
	button.AutoButtonColor = false
	button.Size = UDim2.fromOffset(76, 76)
	button.BackgroundColor3 = Colors.Raised
	button.BackgroundTransparency = 0.1
	button.BorderSizePixel = 0
	button.LayoutOrder = index
	button.Parent = hotbar
	UITheme.corner(button, 12)
	return button, UITheme.outline(button)
end

local function decorateSlot(
	button: TextButton,
	index: number,
	costText: string,
	lockText: string
): (TextLabel, Frame)
	local keyCap = UITheme.keyCap(button, tostring(index))
	keyCap.Position = UDim2.fromOffset(5, 5)
	keyCap.Size = UDim2.fromOffset(0, 18)
	keyCap.ZIndex = 3
	keyCap.BackgroundTransparency = 0.1

	local cost = UITheme.text(button, {
		name = "Cost",
		text = costText,
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

	local lockOverlay = Instance.new("Frame")
	lockOverlay.Name = "Locked"
	lockOverlay.Size = UDim2.fromScale(1, 1)
	lockOverlay.BackgroundColor3 = Colors.Panel
	lockOverlay.BackgroundTransparency = 0.35
	lockOverlay.ZIndex = 2
	lockOverlay.Visible = false
	lockOverlay.Parent = button
	UITheme.corner(lockOverlay, 12)
	UITheme.text(lockOverlay, {
		name = "Label",
		text = lockText,
		size = UDim2.fromScale(1, 1),
		font = Fonts.Heavy,
		textSize = 12,
		color = Colors.Muted,
		alignX = Enum.TextXAlignment.Center,
	}).ZIndex =
		2
	return cost, lockOverlay
end

local function createMachineSlot(index: number, definitionId: string): Slot
	local definition = MachineDefinitions[definitionId]
	local button, stroke = createSlotShell(index, definitionId)
	local model = MachineArt.Build(definitionId) or MachineArt.BuildPlaceholder(definition)
	local viewport, camera, focus, radius = createViewport(button, model)
	local cost, lockOverlay =
		decorateSlot(button, index, UITheme.formatNumber(definition.Cost), "LOCKED")
	local slot: Slot = {
		kind = "Machine",
		id = definitionId,
		button = button,
		stroke = stroke,
		viewport = viewport,
		camera = camera,
		focus = focus,
		radius = radius,
		angle = math.rad(40),
		cost = cost,
		lockOverlay = lockOverlay,
	}
	framePreview(slot)
	return slot
end

local function createTransportSlot(index: number, pipeId: string): Slot
	local pipe = PipeDefinitions.Types[pipeId]
	local button, stroke = createSlotShell(index, pipeId .. "Transport")
	local preview = if pipeId == "Item" then buildConveyorPreview() else buildPipePreview(pipeId)
	local viewport, camera, focus, radius = createViewport(button, preview)
	local cost, lockOverlay = decorateSlot(button, index, pipe.ShortName, "SOON")
	cost.TextColor3 = if pipeId == "Item"
		then Colors.Gold
		else Color3.fromRGB(table.unpack(pipe.Color))
	local slot: Slot = {
		kind = "Transport",
		id = pipeId,
		button = button,
		stroke = stroke,
		viewport = viewport,
		camera = camera,
		focus = focus,
		radius = radius,
		angle = math.rad(40),
		cost = cost,
		lockOverlay = lockOverlay,
	}
	framePreview(slot)
	return slot
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

for _, definitionId in CATALOG do
	table.insert(slots, createMachineSlot(#slots + 1, definitionId))
end
createDivider(#slots + 0.5)
for _, pipeId in PipeDefinitions.Order do
	table.insert(slots, createTransportSlot(#slots + 1, pipeId))
end
createDivider(50)
-- The Delete tool removes your machines and belt tiles (and pipes once they exist).
local deleteTool = createToolSlot(51, "Delete", "X", function(icon)
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
local gridTool = createToolSlot(52, "Grid", "G", function(icon)
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
	if slot == nil then
		tooltip.Visible = false
		return
	end
	if slot.kind == "Transport" then
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
		if definition.UnlockAfterFirstSale and not isUnlocked() then
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
	if slot.kind == "Transport" then
		return mode == "Conveyor" and slot.id == "Item"
	end
	return mode == "Place" and selectedId == slot.id
end

local function refreshPanel()
	local unlocked = isUnlocked()
	local balance = credits()
	for _, slot in slots do
		local selected = isSelected(slot)
		local locked
		if slot.kind == "Transport" then
			locked = not PipeDefinitions.Types[slot.id].Ready
		else
			local definition = MachineDefinitions[slot.id]
			locked = definition.UnlockAfterFirstSale == true and not unlocked
			slot.cost.TextColor3 = if balance < definition.Cost then Colors.Danger else Colors.Gold
		end
		slot.lockOverlay.Visible = locked
		slot.viewport.ImageColor3 = if locked
			then Color3.fromRGB(110, 110, 110)
			else Color3.new(1, 1, 1)
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
			{ "R", "Rotate, output faces " .. ROTATION_NAMES[rotationSteps + 1] },
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
			{ "R", "Turn, belt runs " .. ROTATION_NAMES[beltDir + 1] },
			{ "RMB", "Remove tile" },
			{ "Q", "Done" },
		})
	else
		if os.clock() - toastShownAt >= 4 then
			hideToast()
		end
		setHints({
			{ "1-" .. #CATALOG, "Build" },
			{ tostring(#CATALOG + 1), "Conveyor" },
			{ "F", "Pause machine" },
			{ "X", "Delete" },
		})
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
		setMode("Conveyor")
	else
		setMode("Place", slot.id)
	end
end

-- Belt requests run one at a time in order, so a fast drag never lands out of sequence.
type BeltRequest = { action: string, x: number, z: number, dir: number }
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
			_, message = placeConveyorRemote:InvokeServer(request.x, request.z, request.dir)
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
	table.insert(beltQueue, { action = action, x = x, z = z, dir = dir })
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
				for _, portName in { "OutputPort", "InputPort" } do
					local port = model:FindFirstChild(portName)
					if port and port:IsA("BasePart") then
						local offset = port.Position - body.Position
						local flat = Vector3.new(offset.X, 0, offset.Z)
						if flat.Magnitude > 1e-3 then
							local facing = flat.Unit
							local point = port.Position + facing * 2
							local ix, iz = ConveyorGrid.CellOf(point.X, point.Z)
							local away = ConveyorGrid.DirectionOf(facing.X, facing.Z)
							local isInput = portName == "InputPort"
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

	local bodyCFrame = PlacementRules.BodyCFrame(definition, position, rotationSteps, floorTopY)
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
		credits(),
		{
			unlocked = isUnlocked(),
			roads = roadRects,
			roadReach = CommitmentDefinitions.Truck.RoadReach,
		}
	)
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
	if slotIndex and slots[slotIndex] then
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

refreshPanel()
