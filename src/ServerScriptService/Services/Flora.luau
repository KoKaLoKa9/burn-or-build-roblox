--!strict

-- Low-poly scenery for the Thai rice-field landscape, built from plain parts in the same flat
-- style as the machines: sugar palms, rain trees, umbrella pines, frangipani, bushes, rocks,
-- straw stacks, a field hut, and power poles. Each builder takes the ground CFrame where the
-- object stands and a Random, and returns an unparented Model. Nothing here is clickable or
-- touchable, so scenery never gets in the way of build mode or prompts.

local Flora = {}

local LEAVES = {
	Color3.fromRGB(74, 128, 52),
	Color3.fromRGB(92, 146, 58),
	Color3.fromRGB(63, 112, 47),
	Color3.fromRGB(108, 156, 64),
}
local PINE_LEAVES = Color3.fromRGB(56, 92, 50)
local PALM_TRUNK = Color3.fromRGB(110, 98, 84)
local DEAD_FROND = Color3.fromRGB(132, 104, 66)
local BARK = Color3.fromRGB(92, 72, 54)
local PINE_BARK = Color3.fromRGB(104, 70, 48)
local PALE_BARK = Color3.fromRGB(150, 140, 122)
local STONE = Color3.fromRGB(128, 124, 114)
local STRAW = Color3.fromRGB(214, 176, 86)
local PLANK = Color3.fromRGB(128, 106, 82)
local RUST = Color3.fromRGB(150, 86, 52)
local CONCRETE = Color3.fromRGB(176, 172, 162)
local WIRE = Color3.fromRGB(34, 32, 30)

local TAU = math.pi * 2
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function part(
	model: Model,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?
): Part
	local item = Instance.new("Part")
	item.Name = name
	item.Shape = shape
	item.Size = size
	item.CFrame = cframe
	item.Color = color
	item.Material = material or Enum.Material.SmoothPlastic
	item.Anchored = true
	item.CanCollide = collide == true
	item.CanQuery = false
	item.CanTouch = false
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = model
	return item
end

-- A cylinder from `a` to `b`: trunks, branches, and wires.
local function beam(
	model: Model,
	name: string,
	a: Vector3,
	b: Vector3,
	diameter: number,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?
): Part
	local length = (b - a).Magnitude
	-- lookAt points -Z at `b`; the quarter turn lays the cylinder's X axis along that line.
	local cframe = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	return part(
		model,
		name,
		Enum.PartType.Cylinder,
		Vector3.new(length, diameter, diameter),
		cframe,
		color,
		material,
		collide
	)
end

local function vary(color: Color3, rng: Random, amount: number): Color3
	local shift = rng:NextNumber(-amount, amount)
	return Color3.new(
		math.clamp(color.R + shift, 0, 1),
		math.clamp(color.G + shift * 1.2, 0, 1),
		math.clamp(color.B + shift * 0.6, 0, 1)
	)
end

local function leafColor(rng: Random): Color3
	return vary(LEAVES[rng:NextInteger(1, #LEAVES)], rng, 0.04)
end

local function newModel(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	return model
end

local function lean(rng: Random, degrees: number): CFrame
	return CFrame.Angles(
		math.rad(rng:NextNumber(-degrees, degrees)),
		0,
		math.rad(rng:NextNumber(-degrees, degrees))
	)
end

-- Sugar palm (Borassus), the tall fan palm that stands alone on paddy bunds all over Thailand.
function Flora.SugarPalm(ground: CFrame, rng: Random): Model
	local model = newModel("SugarPalm")
	local height = rng:NextNumber(26, 40)
	local base = ground * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
	local top = base * lean(rng, 5) * CFrame.new(0, height, 0)
	beam(model, "Trunk", base.Position, top.Position, 1.4, PALM_TRUNK, Enum.Material.Wood, true)
	part(
		model,
		"Foot",
		Enum.PartType.Cylinder,
		Vector3.new(2.4, 2.4, 2.4),
		base * CFrame.new(0, 1, 0) * UPRIGHT,
		PALM_TRUNK,
		Enum.Material.Wood,
		true
	)

	local crown = CFrame.new(top.Position) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
	part(
		model,
		"Skirt",
		Enum.PartType.Ball,
		Vector3.new(4.6, 4.6, 4.6),
		crown * CFrame.new(0, -2.2, 0),
		DEAD_FROND,
		Enum.Material.Grass
	)
	part(model, "Heart", Enum.PartType.Ball, Vector3.new(3.4, 3.4, 3.4), crown, PALM_TRUNK)

	-- A round fan of fronds, mostly reaching up and out, with a few old ones hanging down.
	-- Two rings of fronds, each twisted a little, so the crown reads as a round fan ball.
	local fronds = 16
	for index = 1, fronds do
		local yaw = index * TAU / fronds + rng:NextNumber(-0.15, 0.15)
		local pitch = if index % 2 == 0 then rng:NextNumber(35, 70) else rng:NextNumber(-5, 30)
		local length = rng:NextNumber(5, 7)
		part(
			model,
			"Frond",
			Enum.PartType.Block,
			Vector3.new(rng:NextNumber(3.4, 4.4), 0.3, length),
			crown
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(math.rad(pitch), 0, 0)
				* CFrame.new(0, 0, -length / 2 - 0.8)
				* CFrame.Angles(0, 0, rng:NextNumber(-0.6, 0.6)),
			leafColor(rng)
		)
	end
	for index = 1, 3 do
		local yaw = index * TAU / 3 + rng:NextNumber(-0.4, 0.4)
		part(
			model,
			"OldFrond",
			Enum.PartType.Block,
			Vector3.new(3.4, 0.3, 5.5),
			crown
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(math.rad(-65), 0, 0)
				* CFrame.new(0, 0, -3.6),
			DEAD_FROND
		)
	end
	model.PrimaryPart = model:FindFirstChild("Foot") :: BasePart
	return model
end

-- A wide rain tree with a heavy, low canopy: the big shade tree beside field huts.
function Flora.RainTree(ground: CFrame, rng: Random): Model
	local model = newModel("RainTree")
	local base = ground * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
	local trunkHeight = rng:NextNumber(8, 13)
	local top = base * lean(rng, 6) * CFrame.new(0, trunkHeight, 0)
	beam(
		model,
		"Trunk",
		base.Position,
		top.Position,
		rng:NextNumber(1.8, 2.6),
		BARK,
		Enum.Material.Wood,
		true
	)

	local spread = rng:NextNumber(7, 11)
	local branches = rng:NextInteger(3, 4)
	for index = 1, branches do
		local angle = index * TAU / branches + rng:NextNumber(-0.4, 0.4)
		local reach = spread * rng:NextNumber(0.6, 0.9)
		local tip = top.Position
			+ Vector3.new(math.cos(angle) * reach, rng:NextNumber(3, 6), math.sin(angle) * reach)
		beam(model, "Branch", top.Position, tip, 1.1, BARK, Enum.Material.Wood)
		part(
			model,
			"Leaves",
			Enum.PartType.Ball,
			Vector3.one * rng:NextNumber(9, 13),
			CFrame.new(tip + Vector3.new(0, 1.5, 0)),
			leafColor(rng),
			Enum.Material.Grass
		)
	end
	part(
		model,
		"Crown",
		Enum.PartType.Ball,
		Vector3.one * rng:NextNumber(11, 15),
		CFrame.new(top.Position + Vector3.new(0, 6, 0)),
		leafColor(rng),
		Enum.Material.Grass
	)
	return model
end

-- Umbrella pine with a bare trunk and flat layered crown, like the pines on Phu Kradueng.
function Flora.UmbrellaPine(ground: CFrame, rng: Random): Model
	local model = newModel("UmbrellaPine")
	local base = ground * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
	local height = rng:NextNumber(22, 34)
	local bend = base * lean(rng, 6) * CFrame.new(0, height * 0.55, 0)
	local top = bend * lean(rng, 10) * CFrame.new(0, height * 0.45, 0)
	beam(model, "Trunk", base.Position, bend.Position, 1.3, PINE_BARK, Enum.Material.Wood, true)
	beam(model, "Upper", bend.Position, top.Position, 1, PINE_BARK, Enum.Material.Wood)

	local layers = rng:NextInteger(2, 4)
	for index = 1, layers do
		local offset = Vector3.new(rng:NextNumber(-3, 3), -(index - 1) * 2.6, rng:NextNumber(-3, 3))
		local diameter = rng:NextNumber(10, 17) - (index - 1) * 1.5
		part(
			model,
			"Canopy",
			Enum.PartType.Cylinder,
			Vector3.new(2.2, diameter, diameter),
			CFrame.new(top.Position + offset) * UPRIGHT,
			vary(PINE_LEAVES, rng, 0.03),
			Enum.Material.Grass
		)
		if index > 1 then
			beam(
				model,
				"Bough",
				top.Position + Vector3.new(0, -2, 0),
				top.Position + offset,
				0.6,
				PINE_BARK
			)
		end
	end
	return model
end

-- Frangipani: a short, forked tree with leaf tufts and white flowers at each tip.
function Flora.Frangipani(ground: CFrame, rng: Random): Model
	local model = newModel("Frangipani")
	local base = ground * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
	local fork = base * lean(rng, 8) * CFrame.new(0, rng:NextNumber(4, 6), 0)
	beam(model, "Trunk", base.Position, fork.Position, 1, PALE_BARK, Enum.Material.Wood, true)
	local tips = rng:NextInteger(3, 4)
	for index = 1, tips do
		local angle = index * TAU / tips + rng:NextNumber(-0.3, 0.3)
		local tip = fork.Position
			+ Vector3.new(math.cos(angle) * 3.5, rng:NextNumber(3, 5), math.sin(angle) * 3.5)
		beam(model, "Branch", fork.Position, tip, 0.6, PALE_BARK, Enum.Material.Wood)
		part(
			model,
			"Leaves",
			Enum.PartType.Ball,
			Vector3.one * rng:NextNumber(3.6, 4.8),
			CFrame.new(tip + Vector3.new(0, 1, 0)),
			leafColor(rng),
			Enum.Material.Grass
		)
		for flower = 1, 2 do
			local around = flower * math.pi + angle
			part(
				model,
				"Flower",
				Enum.PartType.Ball,
				Vector3.one * 0.9,
				CFrame.new(tip + Vector3.new(math.cos(around) * 1.6, 2.6, math.sin(around) * 1.6)),
				Color3.fromRGB(250, 246, 226)
			)
		end
	end
	return model
end

function Flora.Bush(ground: CFrame, rng: Random): Model
	local model = newModel("Bush")
	for _ = 1, rng:NextInteger(2, 4) do
		local size = rng:NextNumber(3, 6.5)
		part(
			model,
			"Leaves",
			Enum.PartType.Ball,
			Vector3.one * size,
			ground * CFrame.new(rng:NextNumber(-2, 2), size * 0.3, rng:NextNumber(-2, 2)),
			leafColor(rng),
			Enum.Material.Grass
		)
	end
	return model
end

function Flora.Rock(ground: CFrame, rng: Random, scale: number?): Model
	local model = newModel("Rock")
	local factor = scale or 1
	for index = 1, rng:NextInteger(1, 3) do
		local size = Vector3.new(rng:NextNumber(3, 8), rng:NextNumber(2, 5), rng:NextNumber(3, 7))
			* factor
			* (if index == 1 then 1 else 0.55)
		part(
			model,
			"Stone",
			Enum.PartType.Block,
			size,
			ground
				* CFrame.new(
					rng:NextNumber(-3, 3) * factor,
					size.Y * 0.25,
					rng:NextNumber(-3, 3) * factor
				)
				* CFrame.Angles(
					rng:NextNumber(-0.4, 0.4),
					rng:NextNumber(0, TAU),
					rng:NextNumber(-0.4, 0.4)
				),
			vary(STONE, rng, 0.05),
			Enum.Material.Slate,
			size.Magnitude > 6
		)
	end
	return model
end

-- A rounded stack of baled straw, the way farmers keep it beside the field.
function Flora.StrawStack(ground: CFrame, rng: Random): Model
	local model = newModel("StrawStack")
	local diameter = rng:NextNumber(7, 10)
	local height = rng:NextNumber(4, 6)
	part(
		model,
		"Stack",
		Enum.PartType.Cylinder,
		Vector3.new(height, diameter, diameter),
		ground * CFrame.new(0, height / 2, 0) * UPRIGHT,
		vary(STRAW, rng, 0.03),
		Enum.Material.Grass,
		true
	)
	part(
		model,
		"Top",
		Enum.PartType.Ball,
		Vector3.one * diameter,
		ground * CFrame.new(0, height - diameter * 0.15, 0),
		vary(STRAW, rng, 0.04),
		Enum.Material.Grass
	)
	return model
end

-- A small weathered field hut on short stilts with a rusty corrugated roof.
function Flora.FieldHut(ground: CFrame, rng: Random): Model
	local model = newModel("FieldHut")
	local base = ground * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
	local width, depth, floorY, wallHeight = 11, 8, 2, 6
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		part(
			model,
			"Post",
			Enum.PartType.Block,
			Vector3.new(0.6, floorY + wallHeight + 1, 0.6),
			base
				* CFrame.new(
					corner[1] * width / 2,
					(floorY + wallHeight + 1) / 2,
					corner[2] * depth / 2
				),
			PLANK,
			Enum.Material.Wood,
			true
		)
	end
	part(
		model,
		"Floor",
		Enum.PartType.Block,
		Vector3.new(width, 0.5, depth),
		base * CFrame.new(0, floorY, 0),
		PLANK,
		Enum.Material.WoodPlanks,
		true
	)
	local wallColor = vary(Color3.fromRGB(138, 124, 104), rng, 0.04)
	part(
		model,
		"BackWall",
		Enum.PartType.Block,
		Vector3.new(width, wallHeight, 0.3),
		base * CFrame.new(0, floorY + wallHeight / 2, -depth / 2),
		wallColor,
		Enum.Material.WoodPlanks,
		true
	)
	for side = -1, 1, 2 do
		part(
			model,
			"SideWall",
			Enum.PartType.Block,
			Vector3.new(0.3, wallHeight, depth),
			base * CFrame.new(side * width / 2, floorY + wallHeight / 2, 0),
			wallColor,
			Enum.Material.WoodPlanks,
			true
		)
	end
	part(
		model,
		"HalfWall",
		Enum.PartType.Block,
		Vector3.new(width * 0.45, wallHeight * 0.5, 0.3),
		base * CFrame.new(-width * 0.275, floorY + wallHeight * 0.25, depth / 2),
		wallColor,
		Enum.Material.WoodPlanks,
		true
	)
	local ridgeY = floorY + wallHeight + 2.4
	for side = -1, 1, 2 do
		part(
			model,
			"Roof",
			Enum.PartType.Block,
			Vector3.new(width + 2.5, 0.3, depth / 2 + 2),
			base
				* CFrame.new(0, ridgeY - 1.2, side * (depth / 4 + 0.6))
				* CFrame.Angles(math.rad(side * 24), 0, 0),
			vary(RUST, rng, 0.05),
			Enum.Material.CorrodedMetal,
			true
		)
	end
	return model
end

-- A concrete power pole with a cross arm. Returns the model and its two wire points.
function Flora.PowerPole(ground: CFrame): (Model, Vector3, Vector3)
	local model = newModel("PowerPole")
	local height = 24
	part(
		model,
		"Pole",
		Enum.PartType.Cylinder,
		Vector3.new(height, 0.9, 0.9),
		ground * CFrame.new(0, height / 2, 0) * UPRIGHT,
		CONCRETE,
		Enum.Material.Concrete,
		true
	)
	local arm = ground * CFrame.new(0, height - 1.5, 0)
	part(
		model,
		"Arm",
		Enum.PartType.Block,
		Vector3.new(0.5, 0.5, 7),
		arm,
		CONCRETE,
		Enum.Material.Concrete
	)
	return model, (arm * CFrame.new(0, 0.4, -3)).Position, (arm * CFrame.new(0, 0.4, 3)).Position
end

-- A sagging wire between two points.
function Flora.Wire(model: Model, a: Vector3, b: Vector3)
	local middle = (a + b) / 2 - Vector3.new(0, 1.6, 0)
	beam(model, "Wire", a, middle, 0.12, WIRE)
	beam(model, "Wire", middle, b, 0.12, WIRE)
end

-- A low earth bund (paddy dike) along one edge of a field.
function Flora.Bund(parent: Instance, cframe: CFrame, length: number)
	local model = newModel("Bund")
	part(
		model,
		"Earth",
		Enum.PartType.Block,
		Vector3.new(length, 1.4, 2.2),
		cframe * CFrame.new(0, 0.7, 0),
		Color3.fromRGB(122, 98, 66),
		Enum.Material.Ground
	)
	part(
		model,
		"GrassTop",
		Enum.PartType.Block,
		Vector3.new(length, 0.3, 1.6),
		cframe * CFrame.new(0, 1.5, 0),
		Color3.fromRGB(102, 146, 60),
		Enum.Material.Grass
	)
	model.Parent = parent
end

return Flora
