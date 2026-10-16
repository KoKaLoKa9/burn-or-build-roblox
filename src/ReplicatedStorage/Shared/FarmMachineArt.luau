--!strict

-- Part-built stand-in art for the farm machines and the market stall until Blender models are
-- imported. MachineArt
-- falls back to these, so placed machines, the build ghost, and the hotbar previews all share them.
-- Each model's pivot is its bottom center and its front (header, hood) faces +X, the side the
-- build mode rotation hint calls "output faces".

local FarmMachineArt = {}

local TEAL = Color3.fromRGB(46, 140, 124)
local TEAL_DARK = Color3.fromRGB(31, 92, 84)
local RED = Color3.fromRGB(214, 64, 52)
local RED_DARK = Color3.fromRGB(150, 44, 38)
local YELLOW = Color3.fromRGB(244, 186, 66)
local STEEL = Color3.fromRGB(92, 98, 104)
local STEEL_LIGHT = Color3.fromRGB(160, 166, 170)
local RUBBER = Color3.fromRGB(40, 42, 44)
local SEEDLING = Color3.fromRGB(122, 196, 82)
local GLASS = Color3.fromRGB(150, 196, 214)

local function block(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- A wheel whose axle runs along Z. Cylinders spin around their X axis, so turn them a quarter.
local function wheel(model: Model, x: number, z: number, radius: number, width: number)
	local axle = CFrame.Angles(0, math.rad(90), 0)
	block(
		model,
		"Wheel",
		Vector3.new(width, radius * 2, radius * 2),
		CFrame.new(x, radius, z) * axle,
		RUBBER,
		Enum.Material.Rubber,
		Enum.PartType.Cylinder
	)
	block(
		model,
		"Hub",
		Vector3.new(width + 0.1, radius, radius),
		CFrame.new(x, radius, z) * axle,
		YELLOW,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
end

-- Walk-behind style riding transplanter (10 x 6 x 8): a teal body on four wheels, a tilted tray
-- of seedling mats at the back, and planting fingers under the tray.
local function buildTransplanter(model: Model)
	for _, x in { -2.6, 2.6 } do
		for _, z in { -3.2, 3.2 } do
			wheel(model, x, z, 1.3, 0.9)
		end
	end
	block(
		model,
		"Chassis",
		Vector3.new(7, 0.8, 5),
		CFrame.new(0, 1.7, 0),
		STEEL,
		Enum.Material.Metal
	)
	block(
		model,
		"Hood",
		Vector3.new(3, 1.8, 3.6),
		CFrame.new(2.4, 3, 0),
		TEAL,
		Enum.Material.SmoothPlastic
	)
	block(
		model,
		"Grille",
		Vector3.new(0.2, 1.2, 2.6),
		CFrame.new(3.95, 3, 0),
		TEAL_DARK,
		Enum.Material.DiamondPlate
	)
	block(
		model,
		"Seat",
		Vector3.new(1.4, 0.5, 1.6),
		CFrame.new(0, 2.6, 0),
		RUBBER,
		Enum.Material.Fabric
	)
	block(
		model,
		"SeatBack",
		Vector3.new(0.3, 1.2, 1.6),
		CFrame.new(-0.7, 3.3, 0),
		RUBBER,
		Enum.Material.Fabric
	)
	block(
		model,
		"Steering",
		Vector3.new(0.3, 1.8, 0.3),
		CFrame.new(1, 3.2, 0) * CFrame.Angles(0, 0, math.rad(-30)),
		STEEL_LIGHT,
		Enum.Material.Metal
	)
	block(
		model,
		"Wheel",
		Vector3.new(0.2, 1.2, 1.2),
		CFrame.new(1.45, 4, 0),
		RUBBER,
		Enum.Material.Rubber,
		Enum.PartType.Cylinder
	)

	-- The seedling tray leans back over the rear, as on a real transplanter.
	local tilt = CFrame.new(-3.6, 3.6, 0) * CFrame.Angles(0, 0, math.rad(35))
	block(model, "Tray", Vector3.new(0.3, 3.6, 7.6), tilt, TEAL_DARK, Enum.Material.Metal)
	for index = -1, 1 do
		block(
			model,
			"SeedlingMat",
			Vector3.new(0.5, 3.2, 2.2),
			tilt * CFrame.new(0.4, 0, index * 2.5),
			SEEDLING,
			Enum.Material.LeafyGrass
		)
	end
	for index = -2, 2 do
		block(
			model,
			"PlantingFinger",
			Vector3.new(0.3, 1.4, 0.3),
			CFrame.new(-4.4, 0.9, index * 1.6),
			STEEL_LIGHT,
			Enum.Material.Metal
		)
	end
	block(
		model,
		"FingerBar",
		Vector3.new(0.4, 0.4, 7.2),
		CFrame.new(-4.4, 1.6, 0),
		STEEL,
		Enum.Material.Metal
	)
end

-- Combine harvester (14 x 9 x 10): red body on rubber tracks, a yellow cutting header with its
-- reel at the front, a glass cab, a grain tank, and an unloading auger along the side.
local function buildCombine(model: Model)
	for _, z in { -3.6, 3.6 } do
		block(
			model,
			"Track",
			Vector3.new(9, 2, 2.2),
			CFrame.new(-1.2, 1, z),
			RUBBER,
			Enum.Material.Rubber
		)
		for _, x in { -5.2, 2.8 } do
			block(
				model,
				"Sprocket",
				Vector3.new(2.3, 2, 2),
				CFrame.new(x, 1, z) * CFrame.Angles(0, math.rad(90), 0),
				RUBBER,
				Enum.Material.Rubber,
				Enum.PartType.Cylinder
			)
		end
	end
	block(
		model,
		"Body",
		Vector3.new(9, 3.6, 5.6),
		CFrame.new(-1.2, 3.8, 0),
		RED,
		Enum.Material.SmoothPlastic
	)
	block(
		model,
		"Stripe",
		Vector3.new(9.05, 0.4, 5.65),
		CFrame.new(-1.2, 3, 0),
		YELLOW,
		Enum.Material.SmoothPlastic
	)
	block(
		model,
		"GrainTank",
		Vector3.new(4.4, 2, 5),
		CFrame.new(-3.2, 6.6, 0),
		RED_DARK,
		Enum.Material.SmoothPlastic
	)
	block(
		model,
		"Cab",
		Vector3.new(3, 2.8, 3.2),
		CFrame.new(1.6, 7, -0.8),
		GLASS,
		Enum.Material.Glass
	).Transparency =
		0.25
	block(
		model,
		"CabRoof",
		Vector3.new(3.4, 0.3, 3.6),
		CFrame.new(1.6, 8.55, -0.8),
		RED,
		Enum.Material.SmoothPlastic
	)
	block(
		model,
		"Exhaust",
		Vector3.new(0.5, 2, 0.5),
		CFrame.new(-1, 6.6, 2.2),
		STEEL,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	).CFrame = CFrame.new(
		-1,
		6.6,
		2.2
	) * CFrame.Angles(0, 0, math.rad(90))
	block(
		model,
		"Auger",
		Vector3.new(6, 0.7, 0.7),
		CFrame.new(-2.4, 7.4, 4.2) * CFrame.Angles(0, math.rad(12), 0),
		STEEL_LIGHT,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)

	-- The header sweeps the full width of the machine at the front.
	block(
		model,
		"Feeder",
		Vector3.new(2.6, 1.6, 3),
		CFrame.new(4.4, 2, 0) * CFrame.Angles(0, 0, math.rad(-20)),
		RED_DARK,
		Enum.Material.Metal
	)
	block(
		model,
		"Header",
		Vector3.new(2, 1.2, 10),
		CFrame.new(6, 0.9, 0),
		YELLOW,
		Enum.Material.SmoothPlastic
	)
	block(
		model,
		"CutterBar",
		Vector3.new(0.6, 0.2, 10),
		CFrame.new(6.8, 0.3, 0),
		STEEL_LIGHT,
		Enum.Material.Metal
	)
	block(
		model,
		"Reel",
		Vector3.new(9.4, 1.4, 1.4),
		CFrame.new(6.2, 2.3, 0) * CFrame.Angles(0, math.rad(90), 0),
		YELLOW,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	).Transparency =
		0.35
end

-- Market stall (12 x 8 x 10): a wooden counter under a striped awning, with a pellet crate, a
-- biochar sack, and a mushroom basket on show. The IN side is -X.
local function buildMarketStall(model: Model)
	local wood = Color3.fromRGB(150, 108, 70)
	local orange = Color3.fromRGB(226, 120, 58)
	local cream = Color3.fromRGB(244, 232, 206)
	block(
		model,
		"Counter",
		Vector3.new(8, 3, 8),
		CFrame.new(0.5, 1.5, 0),
		wood,
		Enum.Material.WoodPlanks
	)
	block(
		model,
		"CounterTop",
		Vector3.new(8.6, 0.4, 8.6),
		CFrame.new(0.5, 3.2, 0),
		TEAL,
		Enum.Material.SmoothPlastic
	)
	for _, corner in { { -5, -4.4 }, { -5, 4.4 }, { 5, -4.4 }, { 5, 4.4 } } do
		block(
			model,
			"Post",
			Vector3.new(0.4, 7.2, 0.4),
			CFrame.new(corner[1], 3.6, corner[2]),
			wood,
			Enum.Material.Wood
		)
	end
	for index = 0, 5 do
		block(
			model,
			"Awning",
			Vector3.new(11.6, 0.25, 1.75),
			CFrame.new(0, 7.4, -4.4 + 0.875 + index * 1.75) * CFrame.Angles(0, 0, math.rad(-8)),
			if index % 2 == 0 then orange else cream,
			Enum.Material.Fabric
		)
	end
	block(
		model,
		"Sign",
		Vector3.new(0.3, 1.6, 6),
		CFrame.new(5.6, 6.2, 0),
		TEAL_DARK,
		Enum.Material.SmoothPlastic
	)
	block(
		model,
		"Crate",
		Vector3.new(1.8, 1.4, 1.8),
		CFrame.new(1.5, 4.1, -2.4),
		Color3.fromRGB(112, 77, 36),
		Enum.Material.WoodPlanks
	)
	block(
		model,
		"Biochar",
		Vector3.new(1.6, 1.8, 1.6),
		CFrame.new(1.5, 4.3, 0),
		Color3.fromRGB(40, 38, 36),
		Enum.Material.Fabric,
		Enum.PartType.Ball
	)
	block(
		model,
		"Basket",
		Vector3.new(1, 2, 2),
		CFrame.new(1.5, 3.9, 2.4) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(176, 132, 80),
		Enum.Material.Fabric,
		Enum.PartType.Cylinder
	)
	for index = 1, 3 do
		block(
			model,
			"Mushroom",
			Vector3.new(0.7, 0.7, 0.7),
			CFrame.new(1.2 + (index % 2) * 0.6, 4.5, 2 + index * 0.25),
			cream,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
	end
end

local BUILDERS: { [string]: (Model) -> () } = {
	Transplanter = buildTransplanter,
	Combine = buildCombine,
	MarketStall = buildMarketStall,
}

function FarmMachineArt.Has(definitionId: string): boolean
	return BUILDERS[definitionId] ~= nil
end

-- Returns a fresh anchored, non-colliding model with its pivot at the bottom center, or nil for
-- machines that are not farm machines.
function FarmMachineArt.Build(definitionId: string): Model?
	local builder = BUILDERS[definitionId]
	if builder == nil then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Art"
	builder(model)
	model.WorldPivot = CFrame.new()
	return model
end

return FarmMachineArt
