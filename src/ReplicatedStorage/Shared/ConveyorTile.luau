--!strict

-- Builds one 4 stud conveyor tile in the factory style: steel legs, a teal frame, a dark belt,
-- side walls on every closed side, and a yellow chevron showing which way the belt runs.
-- Used by the server for placed tiles and by the client for the placement ghost and hotbar icon.
-- The model's pivot is the cell centre on the floor, and +X is the belt direction before turning.

local ConveyorTile = {}

ConveyorTile.BeltTop = 1.32

local TEAL = Color3.fromRGB(46, 140, 124)
local TEAL_DARK = Color3.fromRGB(31, 92, 84)
local BELT = Color3.fromRGB(40, 42, 44)
local STEEL = Color3.fromRGB(92, 98, 104)
local YELLOW = Color3.fromRGB(244, 186, 66)

local function part(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local item = Instance.new("Part")
	item.Name = name
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

-- `openSides` uses world sides (0 east, 1 north, 2 west, 3 south); walls go on the others.
function ConveyorTile.Build(dir: number, openSides: { [number]: boolean }): Model
	local model = Instance.new("Model")
	model.Name = "ConveyorTile"

	for _, corner in { { 1.4, 1.4 }, { 1.4, -1.4 }, { -1.4, 1.4 }, { -1.4, -1.4 } } do
		part(
			model,
			"Leg",
			Vector3.new(0.3, 0.9, 0.3),
			CFrame.new(corner[1], 0.45, corner[2]),
			STEEL,
			Enum.Material.Metal
		)
	end
	local frame = part(
		model,
		"Frame",
		Vector3.new(3.8, 0.3, 3.8),
		CFrame.new(0, 1.05, 0),
		TEAL_DARK,
		Enum.Material.SmoothPlastic
	)
	-- The frame is what clicks and raycasts hit when removing a tile.
	frame.CanQuery = true
	part(
		model,
		"Belt",
		Vector3.new(3.9, 0.12, 3.9),
		CFrame.new(0, 1.26, 0),
		BELT,
		Enum.Material.Rubber
	)

	-- Walls in local space: side 0 is the front (+X), 1 is -Z, 2 the back (-X), 3 is +Z.
	for localSide = 0, 3 do
		local worldSide = (localSide + dir) % 4
		if not openSides[worldSide] then
			local angle = localSide * math.pi / 2
			local offset = Vector3.new(math.cos(angle), 0, -math.sin(angle)) * 1.85
			local size = if localSide % 2 == 0
				then Vector3.new(0.3, 0.7, 4)
				else Vector3.new(4, 0.7, 0.3)
			part(
				model,
				"Wall",
				size,
				CFrame.new(offset.X, 1.55, offset.Z),
				TEAL,
				Enum.Material.SmoothPlastic
			)
		end
	end

	-- A chevron pointing along +X.
	for _, side in { 1, -1 } do
		part(
			model,
			"Chevron",
			Vector3.new(1.1, 0.05, 0.22),
			CFrame.new(0.05, ConveyorTile.BeltTop + 0.02, side * 0.36)
				* CFrame.Angles(0, side * math.rad(40), 0),
			YELLOW,
			Enum.Material.SmoothPlastic
		)
	end

	-- Turn every part so +X becomes the belt direction.
	local turn = CFrame.Angles(0, dir * math.pi / 2, 0)
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			child.CFrame = turn * child.CFrame
		end
	end
	model.PrimaryPart = frame
	-- The pivot is the cell centre on the floor with no turn, so PivotTo only moves the tile and
	-- never resets its direction.
	frame.PivotOffset = frame.CFrame:Inverse()
	return model
end

return ConveyorTile
