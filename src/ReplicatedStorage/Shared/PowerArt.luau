--!strict

-- Part-built art for the power machines (industry update): hand crank, solar panel, power pole,
-- straw furnace generator, diesel generator, battery bank, and the water and steam machines.
-- MachineArt falls back to these, so placed machines, the build ghost and the hotbar previews
-- share them. Each model's pivot is its bottom center, and fuel goes in on the -X side like every
-- IN port. A part named "WireTop" marks
-- where power wires attach (PowerService).

local PowerArt = {}

local WOOD = Color3.fromRGB(122, 88, 58)
local WOOD_DARK = Color3.fromRGB(86, 62, 42)
local IRON = Color3.fromRGB(64, 66, 70)
local STEEL = Color3.fromRGB(150, 156, 160)
local PANEL = Color3.fromRGB(30, 48, 92)
local BRICK = Color3.fromRGB(150, 74, 48)
local BRICK_DARK = Color3.fromRGB(104, 52, 36)
local YELLOW = Color3.fromRGB(226, 178, 44)
local GREEN = Color3.fromRGB(62, 150, 84)
local PORCELAIN = Color3.fromRGB(232, 232, 224)
local SOOT = Color3.fromRGB(40, 38, 36)
local CONCRETE = Color3.fromRGB(160, 158, 150)
local COPPER = Color3.fromRGB(196, 112, 52)

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

-- An upright cylinder (Roblox cylinders run along X, so stand them up).
local function column(
	model: Model,
	name: string,
	radius: number,
	height: number,
	position: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	return block(
		model,
		name,
		Vector3.new(height, radius * 2, radius * 2),
		CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		Enum.PartType.Cylinder
	)
end

local function wireTop(model: Model, position: Vector3)
	local marker = block(
		model,
		"WireTop",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(position),
		IRON,
		Enum.Material.Metal
	)
	marker.Transparency = 1
end

local function buildHandCrank(model: Model)
	block(
		model,
		"Base",
		Vector3.new(6, 1, 6),
		CFrame.new(0, 0.5, 0),
		WOOD,
		Enum.Material.WoodPlanks
	)
	block(
		model,
		"Dynamo",
		Vector3.new(3.2, 2.4, 2.4),
		CFrame.new(-0.6, 2.2, 0),
		IRON,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	block(
		model,
		"Stand",
		Vector3.new(0.6, 2.4, 2),
		CFrame.new(1.6, 2.2, 0),
		IRON,
		Enum.Material.Metal
	)
	-- The crank wheel faces +X, the handle sticks out from its rim.
	block(
		model,
		"Wheel",
		Vector3.new(0.4, 3.4, 3.4),
		CFrame.new(2.2, 2.6, 0),
		WOOD_DARK,
		Enum.Material.Wood,
		Enum.PartType.Cylinder
	)
	block(
		model,
		"Arm",
		Vector3.new(0.3, 0.4, 1.6),
		CFrame.new(2.5, 3.7, 0),
		STEEL,
		Enum.Material.Metal
	)
	block(
		model,
		"Handle",
		Vector3.new(1.4, 0.5, 0.5),
		CFrame.new(3.1, 4.3, 0),
		WOOD,
		Enum.Material.Wood,
		Enum.PartType.Cylinder
	)
	wireTop(model, Vector3.new(-0.6, 3.5, 0))
end

local function buildSolarPanel(model: Model)
	for _, x in { -2.6, 2.6 } do
		block(
			model,
			"Leg",
			Vector3.new(0.4, 2.6, 0.4),
			CFrame.new(x, 1.3, 2.6),
			STEEL,
			Enum.Material.Metal
		)
		block(
			model,
			"Leg",
			Vector3.new(0.4, 1.2, 0.4),
			CFrame.new(x, 0.6, -2.6),
			STEEL,
			Enum.Material.Metal
		)
	end
	-- Tilted toward the low afternoon sun.
	local tilt = CFrame.new(0, 2.2, 0) * CFrame.Angles(math.rad(-18), 0, 0)
	block(model, "Frame", Vector3.new(8, 0.3, 7.6), tilt, STEEL, Enum.Material.Metal)
	block(
		model,
		"Cells",
		Vector3.new(7.6, 0.12, 7.2),
		tilt * CFrame.new(0, 0.2, 0),
		PANEL,
		Enum.Material.Glass
	)
	for i = -1, 1 do
		block(
			model,
			"Grid",
			Vector3.new(7.6, 0.14, 0.08),
			tilt * CFrame.new(0, 0.22, i * 1.8),
			STEEL,
			Enum.Material.Metal
		)
		block(
			model,
			"Grid",
			Vector3.new(0.08, 0.14, 7.2),
			tilt * CFrame.new(i * 1.9, 0.22, 0),
			STEEL,
			Enum.Material.Metal
		)
	end
	wireTop(model, Vector3.new(0, 3, 0))
end

local function buildPowerPole(model: Model)
	column(model, "Pole", 0.5, 14, Vector3.zero, WOOD_DARK, Enum.Material.Wood)
	block(
		model,
		"Crossarm",
		Vector3.new(0.5, 0.5, 5),
		CFrame.new(0, 12.8, 0),
		WOOD,
		Enum.Material.Wood
	)
	-- Two coils on porcelain insulators, one at each end of the crossarm. Each is its own junction,
	-- and the wrench clicks them (Coil attribute), so they answer raycasts.
	for coil, z in { -2, 2 } do
		column(
			model,
			"Insulator",
			0.25,
			0.8,
			Vector3.new(0, 13.05, z),
			PORCELAIN,
			Enum.Material.SmoothPlastic
		)
		local ring = block(
			model,
			"Coil" .. coil,
			Vector3.new(1.2, 1.2, 1.2),
			CFrame.new(0, 14.2, z),
			COPPER,
			Enum.Material.Metal,
			Enum.PartType.Ball
		)
		ring.CanQuery = true
		ring:SetAttribute("Coil", coil)
	end
end

local function buildStrawGenerator(model: Model)
	-- Brick furnace with a hopper on the fuel side (-X) and a turbine house on the other.
	block(
		model,
		"Furnace",
		Vector3.new(7, 7, 10),
		CFrame.new(-2.5, 3.5, 0),
		BRICK,
		Enum.Material.Brick
	)
	block(
		model,
		"FireDoor",
		Vector3.new(0.3, 2.2, 3),
		CFrame.new(-6.1, 2.2, 0),
		SOOT,
		Enum.Material.Metal
	)
	block(
		model,
		"Hopper",
		Vector3.new(3, 2.4, 4),
		CFrame.new(-5.2, 6.4, 0),
		WOOD,
		Enum.Material.WoodPlanks
	)
	block(model, "Turbine", Vector3.new(6, 5, 8), CFrame.new(4, 2.5, 0), GREEN, Enum.Material.Metal)
	block(
		model,
		"Generator",
		Vector3.new(4, 3, 3),
		CFrame.new(4, 6.2, 0),
		IRON,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	column(model, "Chimney", 1.1, 6, Vector3.new(-1, 6.5, 3), BRICK_DARK, Enum.Material.Brick)
	-- A bag filter keeps most of the smoke in: cleaner than an open field fire.
	block(
		model,
		"Filter",
		Vector3.new(2, 3, 2),
		CFrame.new(-1, 8.5, -2.6),
		STEEL,
		Enum.Material.Metal
	)
	wireTop(model, Vector3.new(4, 8, 0))
end

local function buildDieselGenerator(model: Model)
	block(model, "Skid", Vector3.new(12, 0.6, 8), CFrame.new(0, 0.3, 0), IRON, Enum.Material.Metal)
	block(
		model,
		"Housing",
		Vector3.new(10, 5.4, 7),
		CFrame.new(0.5, 3.3, 0),
		YELLOW,
		Enum.Material.Metal
	)
	for i = -2, 2 do
		block(
			model,
			"Vent",
			Vector3.new(1, 3, 0.2),
			CFrame.new(1 + i * 1.6, 3.3, 3.55),
			IRON,
			Enum.Material.Metal
		)
	end
	column(model, "Exhaust", 0.4, 3, Vector3.new(-4, 6, 0), SOOT, Enum.Material.Metal)
	block(
		model,
		"Tank",
		Vector3.new(3, 1.6, 6),
		CFrame.new(-4.5, 1.4, 0),
		IRON,
		Enum.Material.Metal
	)
	wireTop(model, Vector3.new(3, 6.2, 0))
end

local function buildBattery(model: Model)
	block(model, "Rack", Vector3.new(6, 0.5, 6), CFrame.new(0, 0.25, 0), IRON, Enum.Material.Metal)
	for i = -1, 1 do
		block(
			model,
			"Cell",
			Vector3.new(1.6, 4.6, 5.4),
			CFrame.new(i * 1.9, 2.8, 0),
			GREEN,
			Enum.Material.SmoothPlastic
		)
		column(
			model,
			"Terminal",
			0.25,
			0.6,
			Vector3.new(i * 1.9, 5.1, 1.6),
			STEEL,
			Enum.Material.Metal
		)
		column(
			model,
			"Terminal",
			0.25,
			0.6,
			Vector3.new(i * 1.9, 5.1, -1.6),
			SOOT,
			Enum.Material.Metal
		)
	end
	wireTop(model, Vector3.new(0, 5.6, 0))
end

local WATER = Color3.fromRGB(58, 120, 180)
local TANK = Color3.fromRGB(176, 190, 200)

local function buildWaterPump(model: Model)
	block(
		model,
		"Pad",
		Vector3.new(8, 0.6, 8),
		CFrame.new(0, 0.3, 0),
		CONCRETE,
		Enum.Material.Concrete
	)
	column(model, "Casing", 2, 4, Vector3.new(-1, 0.6, 0), WATER, Enum.Material.Metal)
	block(
		model,
		"Motor",
		Vector3.new(3, 2.4, 2.4),
		CFrame.new(-1, 5.8, 0),
		IRON,
		Enum.Material.Metal
	)
	-- The outlet runs to the east side, where the fluid port is.
	block(
		model,
		"Outlet",
		Vector3.new(4, 1, 1),
		CFrame.new(2, 1.6, 0),
		WATER,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	block(
		model,
		"Gauge",
		Vector3.new(0.3, 1, 1),
		CFrame.new(-2.9, 3, 0),
		PORCELAIN,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	wireTop(model, Vector3.new(-1, 7, 0))
end

local function buildWaterTank(model: Model)
	for _, x in { -2.6, 2.6 } do
		for _, z in { -2.6, 2.6 } do
			block(
				model,
				"Leg",
				Vector3.new(0.5, 3, 0.5),
				CFrame.new(x, 1.5, z),
				STEEL,
				Enum.Material.Metal
			)
		end
	end
	column(model, "Tank", 3.8, 6.6, Vector3.new(0, 3, 0), TANK, Enum.Material.Metal)
	column(model, "Band", 3.9, 0.4, Vector3.new(0, 5.2, 0), WATER, Enum.Material.Metal)
	column(model, "Lid", 3.4, 0.4, Vector3.new(0, 9.6, 0), STEEL, Enum.Material.Metal)
end

local function buildBoiler(model: Model)
	block(
		model,
		"Firebox",
		Vector3.new(8, 5, 10),
		CFrame.new(-2.5, 2.5, 0),
		BRICK,
		Enum.Material.Brick
	)
	block(
		model,
		"FireDoor",
		Vector3.new(0.3, 2, 3),
		CFrame.new(-6.6, 2, 0),
		SOOT,
		Enum.Material.Metal
	)
	-- The water drum lies along X above the fire.
	block(
		model,
		"Drum",
		Vector3.new(11, 4.6, 4.6),
		CFrame.new(0.5, 7.4, 0),
		IRON,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	column(model, "Chimney", 0.9, 6, Vector3.new(-3, 7, 3), BRICK_DARK, Enum.Material.Brick)
	column(model, "SteamDome", 1, 1.6, Vector3.new(3, 9.5, 0), STEEL, Enum.Material.Metal)
	block(
		model,
		"Valve",
		Vector3.new(1.4, 0.3, 1.4),
		CFrame.new(3, 11.2, 0),
		Color3.fromRGB(196, 60, 48),
		Enum.Material.Metal
	)
end

local function buildSteamTurbine(model: Model)
	block(
		model,
		"Bed",
		Vector3.new(14, 1, 8),
		CFrame.new(0, 0.5, 0),
		CONCRETE,
		Enum.Material.Concrete
	)
	block(
		model,
		"Casing",
		Vector3.new(7, 5.4, 5.4),
		CFrame.new(-2.5, 3.7, 0),
		GREEN,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	block(
		model,
		"Shaft",
		Vector3.new(3, 1, 1),
		CFrame.new(2, 3.7, 0),
		STEEL,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	block(
		model,
		"Generator",
		Vector3.new(4, 4.4, 4.4),
		CFrame.new(5, 3.2, 0),
		IRON,
		Enum.Material.Metal
	)
	wireTop(model, Vector3.new(5, 5.6, 0))
end

local THATCH = Color3.fromRGB(176, 140, 76)
local HIDE = Color3.fromRGB(120, 84, 56)

local function buildCattleShed(model: Model)
	block(
		model,
		"Floor",
		Vector3.new(18, 0.4, 14),
		CFrame.new(0, 0.2, 0),
		CONCRETE,
		Enum.Material.Concrete
	)
	for _, x in { -8, 0, 8 } do
		for _, z in { -6, 6 } do
			block(
				model,
				"Post",
				Vector3.new(0.6, 7, 0.6),
				CFrame.new(x, 3.5, z),
				WOOD_DARK,
				Enum.Material.Wood
			)
		end
	end
	-- A pitched roof of two thatched slopes.
	for _, side in { 1, -1 } do
		block(
			model,
			"Roof",
			Vector3.new(19, 0.5, 8.4),
			CFrame.new(0, 8.4, side * 3.6) * CFrame.Angles(side * math.rad(22), 0, 0),
			THATCH,
			Enum.Material.Grass
		)
	end
	block(
		model,
		"Trough",
		Vector3.new(12, 1, 1.6),
		CFrame.new(0, 0.9, -5),
		WOOD,
		Enum.Material.WoodPlanks
	)
	-- Two resting cows.
	for _, x in { -4, 4 } do
		block(
			model,
			"Cow",
			Vector3.new(4, 2.2, 2),
			CFrame.new(x, 1.5, 1),
			HIDE,
			Enum.Material.Fabric
		)
		block(
			model,
			"Head",
			Vector3.new(1.4, 1.4, 1.4),
			CFrame.new(x + 2.4, 2.2, 1),
			HIDE,
			Enum.Material.Fabric
		)
	end
	wireTop(model, Vector3.new(8, 7, 6))
end

local function buildDigester(model: Model)
	block(
		model,
		"Base",
		Vector3.new(16, 0.6, 16),
		CFrame.new(0, 0.3, 0),
		CONCRETE,
		Enum.Material.Concrete
	)
	column(
		model,
		"Tank",
		6.6,
		6,
		Vector3.new(0, 0.6, 0),
		Color3.fromRGB(140, 150, 120),
		Enum.Material.Concrete
	)
	-- The gas holder: a soft green dome on top of the tank.
	block(
		model,
		"Dome",
		Vector3.new(13, 9, 13),
		CFrame.new(0, 6.6, 0),
		Color3.fromRGB(96, 140, 72),
		Enum.Material.Fabric,
		Enum.PartType.Ball
	)
	column(model, "GasValve", 0.5, 2, Vector3.new(0, 10.8, 0), STEEL, Enum.Material.Metal)
	block(model, "Hopper", Vector3.new(3, 3, 3), CFrame.new(-7, 4, 0), STEEL, Enum.Material.Metal)
	wireTop(model, Vector3.new(-7, 5.6, 0))
end

local function buildGasEngine(model: Model)
	block(model, "Skid", Vector3.new(12, 0.6, 8), CFrame.new(0, 0.3, 0), IRON, Enum.Material.Metal)
	block(model, "Engine", Vector3.new(6, 4, 5), CFrame.new(-2, 2.6, 0), GREEN, Enum.Material.Metal)
	for i = -1, 1 do
		block(
			model,
			"Cylinder",
			Vector3.new(1.2, 1.2, 1.2),
			CFrame.new(-2 + i * 1.8, 5.2, 0),
			STEEL,
			Enum.Material.Metal
		)
	end
	block(
		model,
		"Alternator",
		Vector3.new(4, 3.6, 3.6),
		CFrame.new(3.4, 2.6, 0),
		IRON,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	column(model, "Exhaust", 0.35, 3.4, Vector3.new(-4.5, 4.6, 0), SOOT, Enum.Material.Metal)
	wireTop(model, Vector3.new(3.4, 4.6, 0))
end

local BUILDERS: { [string]: (Model) -> () } = {
	CattleShed = buildCattleShed,
	Digester = buildDigester,
	GasEngine = buildGasEngine,
	HandCrank = buildHandCrank,
	SolarPanel = buildSolarPanel,
	PowerPole = buildPowerPole,
	StrawGenerator = buildStrawGenerator,
	DieselGenerator = buildDieselGenerator,
	Battery = buildBattery,
	WaterPump = buildWaterPump,
	WaterTank = buildWaterTank,
	Boiler = buildBoiler,
	SteamTurbine = buildSteamTurbine,
}

function PowerArt.Has(definitionId: string): boolean
	return BUILDERS[definitionId] ~= nil
end

function PowerArt.Build(definitionId: string): Model?
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

return PowerArt
