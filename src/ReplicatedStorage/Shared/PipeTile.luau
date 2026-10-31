--!strict

-- Builds one 4 stud fluid or gas pipe tile: a pipe run from the cell centre to every open side,
-- a joint in the middle, a short support, and a small arrow showing the flow. Colors come from
-- PipeDefinitions so ports, pipes and the shop agree. Used by the server for placed tiles and by
-- the client for the placement ghost. Same pivot rules as ConveyorTile: the cell centre on the
-- floor, and `openSides` uses world sides (0 east, 1 north, 2 west, 3 south). Uses the textured
-- conveyor kit when it is imported (ConveyorKit).

local ConveyorKit = require(script.Parent:WaitForChild("ConveyorKit"))
local PipeDefinitions = require(script.Parent:WaitForChild("PipeDefinitions"))

local PipeTile = {}

-- Pipe centre height above the floor, level with the machine ports.
PipeTile.Height = 1.5

local STEEL = Color3.fromRGB(92, 98, 104)
local WHITE = Color3.fromRGB(240, 240, 236)

local function part(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local item = Instance.new("Part")
	item.Name = name
	if shape then
		item.Shape = shape
	end
	item.Size = size
	item.CFrame = cframe
	item.Color = color
	item.Material = material
	item.Anchored = true
	item.CanCollide = false
	item.CanTouch = false
	item.CanQuery = false
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = model
	return item
end

-- With the textured kit: the piece whose ends fit the open sides, tinted for the medium, with a
-- flow arrow clamped on top, over an invisible support to click.
local function buildFromKit(color: Color3, dir: number, openSides: { [number]: boolean }): Model?
	local name, turn = ConveyorKit.PipePiece(dir, openSides)
	local art = ConveyorKit.Place(name, CFrame.Angles(0, turn * math.pi / 2, 0))
	if art == nil then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "PipeTile"
	ConveyorKit.Tint(art, color)
	art.Name = "Art"
	art.Parent = model
	local arrow = ConveyorKit.Place("PP_FlowArrow", CFrame.Angles(0, dir * math.pi / 2, 0))
	if arrow then
		arrow.Name = "FlowArrow"
		arrow.Parent = model
	end
	local y = PipeTile.Height
	local support = part(
		model,
		"Support",
		Vector3.new(1.4, y + 0.7, 1.4),
		CFrame.new(0, (y + 0.7) / 2, 0),
		STEEL,
		Enum.Material.Metal
	)
	support.Transparency = 1
	support.CanQuery = true
	model.PrimaryPart = support
	support.PivotOffset = CFrame.new(0, -(y + 0.7) / 2, 0)
	return model
end

function PipeTile.Build(medium: string, dir: number, openSides: { [number]: boolean }): Model
	local pipe = PipeDefinitions.Types[medium] or PipeDefinitions.Types.Fluid
	local color = Color3.fromRGB(table.unpack(pipe.Color))
	local textured = buildFromKit(color, dir, openSides)
	if textured then
		return textured
	end
	local model = Instance.new("Model")
	model.Name = "PipeTile"
	local y = PipeTile.Height
	local diameter = if medium == "Gas" then 1.3 else 1.1

	-- The support is what clicks and raycasts hit when removing a tile.
	local support = part(
		model,
		"Support",
		Vector3.new(0.5, y, 0.5),
		CFrame.new(0, y / 2, 0),
		STEEL,
		Enum.Material.Metal
	)
	support.CanQuery = true
	part(
		model,
		"Joint",
		Vector3.new(diameter + 0.3, diameter + 0.3, diameter + 0.3),
		CFrame.new(0, y, 0),
		color,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	for side = 0, 3 do
		if openSides[side] then
			local angle = side * math.pi / 2
			local offset = Vector3.new(math.cos(angle), 0, -math.sin(angle))
			-- Cylinders run along their X axis, so turn each run toward its side.
			part(
				model,
				"Run",
				Vector3.new(2, diameter, diameter),
				CFrame.new(offset * 1 + Vector3.new(0, y, 0)) * CFrame.Angles(0, angle, 0),
				color,
				Enum.Material.SmoothPlastic,
				Enum.PartType.Cylinder
			)
			part(
				model,
				"Flange",
				Vector3.new(0.25, diameter + 0.35, diameter + 0.35),
				CFrame.new(offset * 1.9 + Vector3.new(0, y, 0)) * CFrame.Angles(0, angle, 0),
				STEEL,
				Enum.Material.Metal,
				Enum.PartType.Cylinder
			)
		end
	end
	-- A white chevron on top of the joint points the way the pipe flows.
	local flow = CFrame.new(0, y + diameter / 2 + 0.2, 0) * CFrame.Angles(0, dir * math.pi / 2, 0)
	for _, side in { 1, -1 } do
		part(
			model,
			"Arrow",
			Vector3.new(0.8, 0.08, 0.16),
			flow * CFrame.new(0.15, 0, side * 0.24) * CFrame.Angles(0, side * math.rad(40), 0),
			WHITE,
			Enum.Material.SmoothPlastic
		)
	end
	model.PrimaryPart = support
	support.PivotOffset = CFrame.new(0, -y / 2, 0)
	return model
end

return PipeTile
