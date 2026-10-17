--!strict

-- Rural Thai houses for the landscape, built from parts in the same flat style as the machines:
-- a raised wooden stilt house, a single-storey concrete house with a porch, a two-storey
-- shophouse, and a small farmhouse. Every builder picks its own wall and roof colours, so a row
-- of houses never looks copied. Each takes the ground CFrame (front door facing -Z) and a Random,
-- and returns an unparented Model.

local Houses = {}

local WALLS = {
	Color3.fromRGB(238, 226, 196), -- cream
	Color3.fromRGB(196, 222, 214), -- mint
	Color3.fromRGB(206, 220, 236), -- pale blue
	Color3.fromRGB(240, 206, 178), -- peach
	Color3.fromRGB(232, 232, 222), -- white
}
local ROOFS = {
	Color3.fromRGB(150, 86, 52), -- rust tin
	Color3.fromRGB(178, 62, 46), -- red tile
	Color3.fromRGB(62, 96, 132), -- blue tin
	Color3.fromRGB(76, 120, 90), -- green tin
	Color3.fromRGB(110, 110, 112), -- grey tin
}
local TEAK = Color3.fromRGB(122, 84, 52)
local TEAK_DARK = Color3.fromRGB(88, 60, 38)
local GLASS = Color3.fromRGB(70, 92, 100)
local TRIM = Color3.fromRGB(246, 244, 236)
local CONCRETE = Color3.fromRGB(178, 174, 166)

local function pick<T>(list: { T }, rng: Random): T
	return list[rng:NextInteger(1, #list)]
end

local function part(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?
): BasePart
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.CFrame = cframe
	item.Color = color
	item.Material = material or Enum.Material.SmoothPlastic
	item.Anchored = true
	item.CanCollide = collide ~= false
	item.CanQuery = false
	item.CanTouch = false
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = model
	return item
end

-- A gable roof: a triangular prism whose ridge runs along X, made of two wedges back to back.
-- A wedge stands tall on its +Z face and slopes down to -Z, so the second one is turned around.
local function gableRoof(
	model: Model,
	base: CFrame,
	length: number,
	width: number,
	height: number,
	color: Color3,
	material: Enum.Material
)
	for side = -1, 1, 2 do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Roof"
		wedge.Size = Vector3.new(length, height, width / 2)
		wedge.CFrame = base
			* CFrame.new(0, height / 2, side * width / 4)
			* (if side == 1 then CFrame.Angles(0, math.pi, 0) else CFrame.new())
		wedge.Color = color
		wedge.Material = material
		wedge.Anchored = true
		wedge.CanQuery = false
		wedge.CanTouch = false
		wedge.Parent = model
	end
	-- A thin ridge cap hides the seam.
	part(
		model,
		"Ridge",
		Vector3.new(length + 0.2, 0.4, 0.8),
		base * CFrame.new(0, height, 0),
		color:Lerp(Color3.new(0, 0, 0), 0.2),
		material
	)
end

-- A window with a white frame on a wall face. `face` is the wall's outer face CFrame (looking out).
local function window(model: Model, face: CFrame, width: number, height: number)
	part(
		model,
		"Frame",
		Vector3.new(width + 0.5, height + 0.5, 0.2),
		face * CFrame.new(0, 0, -0.05),
		TRIM,
		nil,
		false
	)
	part(
		model,
		"Glass",
		Vector3.new(width, height, 0.25),
		face * CFrame.new(0, 0, -0.08),
		GLASS,
		Enum.Material.Glass,
		false
	).Transparency =
		0.15
end

local function door(model: Model, face: CFrame, color: Color3)
	part(
		model,
		"Door",
		Vector3.new(3, 6.5, 0.3),
		face * CFrame.new(0, 3.25, -0.1),
		color,
		Enum.Material.WoodPlanks,
		false
	)
end

local function newModel(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	return model
end

-- A traditional Thai house raised on stilts, with a shaded space underneath, a wooden stair, and
-- a steep gable roof. The living floor sits high to stay dry in the wet season.
function Houses.StiltHouse(ground: CFrame, rng: Random): Model
	local model = newModel("StiltHouse")
	local length, depth, raise, wallHeight = rng:NextNumber(20, 26), rng:NextNumber(15, 18), 6, 7
	local wood = TEAK:Lerp(Color3.fromRGB(160, 120, 80), rng:NextNumber(0, 0.4))
	for _, x in { -1, -1 / 3, 1 / 3, 1 } do
		for _, z in { -1, 1 } do
			part(
				model,
				"Stilt",
				Vector3.new(0.9, raise, 0.9),
				ground * CFrame.new(x * (length / 2 - 0.6), raise / 2, z * (depth / 2 - 0.6)),
				TEAK_DARK,
				Enum.Material.Wood
			)
		end
	end
	part(
		model,
		"Floor",
		Vector3.new(length + 1, 0.8, depth + 3),
		ground * CFrame.new(0, raise, -1.5),
		wood,
		Enum.Material.WoodPlanks
	)
	local walls = ground * CFrame.new(0, raise + 0.4 + wallHeight / 2, 0)
	part(
		model,
		"Walls",
		Vector3.new(length, wallHeight, depth - 2),
		walls * CFrame.new(0, 0, 1),
		wood,
		Enum.Material.WoodPlanks
	)
	local front = walls * CFrame.new(0, 0, -depth / 2 + 1)
	window(model, front * CFrame.new(-length / 4, 0.6, 0), 3.4, 2.6)
	window(model, front * CFrame.new(length / 4, 0.6, 0), 3.4, 2.6)
	door(model, front * CFrame.new(0, -wallHeight / 2, 0), TEAK_DARK)
	-- Veranda rail along the open front of the floor.
	part(
		model,
		"Rail",
		Vector3.new(length + 1, 0.3, 0.3),
		ground * CFrame.new(0, raise + 2.6, -depth / 2 - 2.6),
		TEAK_DARK,
		Enum.Material.Wood
	)
	-- Stair from the ground up to the veranda.
	for step = 1, 6 do
		part(
			model,
			"Step",
			Vector3.new(3.2, 0.4, 1.2),
			ground * CFrame.new(length / 2 - 2.5, step, -depth / 2 - 3 - (6 - step) * 1.1),
			wood,
			Enum.Material.WoodPlanks
		)
	end
	gableRoof(
		model,
		ground * CFrame.new(0, raise + 0.4 + wallHeight, 0.5),
		length + 3,
		depth + 2,
		rng:NextNumber(6, 8),
		pick(ROOFS, rng),
		Enum.Material.CorrodedMetal
	)
	return model
end

-- A single-storey concrete house painted in a pastel colour, with a tin roof and a shaded porch.
function Houses.ConcreteHouse(ground: CFrame, rng: Random): Model
	local model = newModel("ConcreteHouse")
	local length, depth, wallHeight = rng:NextNumber(18, 24), rng:NextNumber(13, 16), 8
	local wall = pick(WALLS, rng)
	part(
		model,
		"Plinth",
		Vector3.new(length + 1, 0.8, depth + 6),
		ground * CFrame.new(0, 0.4, -2.5),
		CONCRETE,
		Enum.Material.Concrete
	)
	local walls = ground * CFrame.new(0, 0.8 + wallHeight / 2, 0)
	part(model, "Walls", Vector3.new(length, wallHeight, depth), walls, wall, Enum.Material.Plaster)
	local front = walls * CFrame.new(0, 0, -depth / 2)
	window(model, front * CFrame.new(-length / 3, 0.8, 0), 3.6, 3)
	window(model, front * CFrame.new(length / 3, 0.8, 0), 3.6, 3)
	door(
		model,
		front * CFrame.new(0, -wallHeight / 2, 0),
		pick({ TEAK, Color3.fromRGB(70, 90, 110) }, rng)
	)
	-- Porch: two posts and a lean-to roof over the plinth in front of the door.
	for side = -1, 1, 2 do
		part(
			model,
			"Post",
			Vector3.new(0.6, wallHeight - 0.6, 0.6),
			ground
				* CFrame.new(
					side * (length / 2 - 1),
					0.8 + (wallHeight - 0.6) / 2,
					-depth / 2 - 4.5
				),
			TRIM,
			Enum.Material.Concrete
		)
	end
	local roofColor = pick(ROOFS, rng)
	part(
		model,
		"Porch",
		Vector3.new(length + 1, 0.3, 5.6),
		ground
			* CFrame.new(0, 0.8 + wallHeight - 0.3, -depth / 2 - 2.6)
			* CFrame.Angles(math.rad(-8), 0, 0),
		roofColor,
		Enum.Material.CorrodedMetal
	)
	gableRoof(
		model,
		ground * CFrame.new(0, 0.8 + wallHeight, 0),
		length + 2,
		depth + 2,
		rng:NextNumber(5, 6.5),
		roofColor,
		Enum.Material.CorrodedMetal
	)
	return model
end

-- A two-storey shophouse: a shop front with a rolling shutter and awning below, living space
-- with a balcony above, and a flat roof behind a parapet. They stand along the roads.
function Houses.Shophouse(ground: CFrame, rng: Random): Model
	local model = newModel("Shophouse")
	local length, depth, storey = rng:NextNumber(14, 18), rng:NextNumber(14, 17), 7.5
	local wall = pick(WALLS, rng)
	local walls = ground * CFrame.new(0, storey, 0)
	part(model, "Walls", Vector3.new(length, storey * 2, depth), walls, wall, Enum.Material.Plaster)
	local front = ground * CFrame.new(0, 0, -depth / 2)
	part(
		model,
		"Shutter",
		Vector3.new(length - 3, storey - 1.5, 0.3),
		front * CFrame.new(0, (storey - 1.5) / 2, -0.1),
		Color3.fromRGB(150, 156, 160),
		Enum.Material.DiamondPlate,
		false
	)
	part(
		model,
		"Awning",
		Vector3.new(length + 0.6, 0.3, 3.4),
		ground * CFrame.new(0, storey + 0.2, -depth / 2 - 1.6) * CFrame.Angles(math.rad(-10), 0, 0),
		pick(ROOFS, rng),
		Enum.Material.Fabric
	)
	window(model, front * CFrame.new(-length / 4, storey * 1.5, 0), 3, 3.2)
	window(model, front * CFrame.new(length / 4, storey * 1.5, 0), 3, 3.2)
	part(
		model,
		"Balcony",
		Vector3.new(length - 2, 0.4, 2.4),
		ground * CFrame.new(0, storey + 1.4, -depth / 2 - 1.2),
		CONCRETE,
		Enum.Material.Concrete
	)
	part(
		model,
		"BalconyRail",
		Vector3.new(length - 2, 1.6, 0.25),
		ground * CFrame.new(0, storey + 2.4, -depth / 2 - 2.3),
		TRIM,
		Enum.Material.Metal
	)
	part(
		model,
		"Parapet",
		Vector3.new(length + 0.4, 1.4, depth + 0.4),
		ground * CFrame.new(0, storey * 2 + 0.7, 0),
		wall:Lerp(Color3.new(1, 1, 1), 0.3),
		Enum.Material.Plaster
	)
	-- A sign board over the shutter.
	part(
		model,
		"Sign",
		Vector3.new(length * 0.6, 1.4, 0.3),
		front * CFrame.new(0, storey - 0.4, -0.25),
		pick({
			Color3.fromRGB(214, 64, 52),
			Color3.fromRGB(46, 140, 124),
			Color3.fromRGB(244, 186, 66),
		}, rng),
		nil,
		false
	)
	return model
end

-- A small farmhouse: one room under a deep, low roof that shades a wide porch, with a water jar
-- by the door.
function Houses.Farmhouse(ground: CFrame, rng: Random): Model
	local model = newModel("Farmhouse")
	local length, depth, wallHeight = rng:NextNumber(14, 18), rng:NextNumber(10, 12), 6.5
	local wood = TEAK:Lerp(Color3.fromRGB(176, 150, 120), rng:NextNumber(0.2, 0.7))
	part(
		model,
		"Floor",
		Vector3.new(length + 4, 1, depth + 5),
		ground * CFrame.new(0, 0.5, -1.5),
		wood,
		Enum.Material.WoodPlanks
	)
	local walls = ground * CFrame.new(0, 1 + wallHeight / 2, 0.8)
	part(
		model,
		"Walls",
		Vector3.new(length, wallHeight, depth - 1.6),
		walls,
		wood,
		Enum.Material.WoodPlanks
	)
	local front = walls * CFrame.new(0, 0, -(depth - 1.6) / 2)
	window(model, front * CFrame.new(-length / 4, 0.4, 0), 2.8, 2.2)
	door(model, front * CFrame.new(length / 6, -wallHeight / 2, 0), TEAK_DARK)
	gableRoof(
		model,
		ground * CFrame.new(0, 1 + wallHeight, -1),
		length + 5,
		depth + 7,
		rng:NextNumber(4.5, 5.5),
		pick(ROOFS, rng),
		Enum.Material.CorrodedMetal
	)
	for side = -1, 1, 2 do
		part(
			model,
			"Post",
			Vector3.new(0.6, wallHeight, 0.6),
			ground * CFrame.new(side * (length / 2 + 1.5), 1 + wallHeight / 2, -depth / 2 - 3),
			TEAK_DARK,
			Enum.Material.Wood
		)
	end
	local jar = part(
		model,
		"WaterJar",
		Vector3.new(2.6, 2.6, 2.6),
		ground * CFrame.new(-length / 2 - 0.5, 2.3, -depth / 2 - 2),
		Color3.fromRGB(122, 74, 44),
		Enum.Material.Slate
	) :: Part
	jar.Shape = Enum.PartType.Ball
	return model
end

-- A rural Thai school campus (about 80 x 44 studs, gate on the -Z side): a two-storey classroom
-- block with an open corridor, a single-storey block, an open-sided canteen, a flagpole with the
-- Thai flag, a sports court, and a low fence with a gate and a sign.
function Houses.SchoolCampus(ground: CFrame, _rng: Random): Model
	local model = newModel("SchoolCampus")
	local cream = Color3.fromRGB(240, 224, 170)
	local red = Color3.fromRGB(178, 62, 46)
	local blue = Color3.fromRGB(36, 70, 140)

	-- Two-storey classroom block along the back.
	local blockA = ground * CFrame.new(-16, 0, 13)
	part(
		model,
		"BlockA",
		Vector3.new(38, 13, 12),
		blockA * CFrame.new(0, 6.5, 0),
		cream,
		Enum.Material.Plaster
	)
	part(
		model,
		"Corridor",
		Vector3.new(38, 0.6, 4),
		blockA * CFrame.new(0, 6.6, -8),
		CONCRETE,
		Enum.Material.Concrete
	)
	part(
		model,
		"Rail",
		Vector3.new(38, 1.6, 0.3),
		blockA * CFrame.new(0, 7.7, -9.9),
		TRIM,
		Enum.Material.Metal
	)
	for column = -2, 2 do
		part(
			model,
			"Pillar",
			Vector3.new(0.8, 13, 0.8),
			blockA * CFrame.new(column * 9, 6.5, -9.6),
			TRIM,
			Enum.Material.Concrete
		)
	end
	for floor = 0, 1 do
		for column = -3, 3 do
			window(model, blockA * CFrame.new(column * 5, 3.4 + floor * 6.5, -6), 2.6, 2.4)
		end
	end
	gableRoof(model, blockA * CFrame.new(0, 13, -1.5), 41, 17, 5, red, Enum.Material.Slate)

	-- Single-storey block on the right.
	local blockB = ground * CFrame.new(24, 0, 13)
	part(
		model,
		"BlockB",
		Vector3.new(26, 7.5, 12),
		blockB * CFrame.new(0, 3.75, 0),
		cream,
		Enum.Material.Plaster
	)
	for column = -2, 2 do
		window(model, blockB * CFrame.new(column * 5, 3.6, -6), 2.6, 2.4)
	end
	gableRoof(model, blockB * CFrame.new(0, 7.5, 0), 28, 14, 4, red, Enum.Material.Slate)

	-- Open-sided canteen pavilion.
	local canteen = ground * CFrame.new(26, 0, -8)
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		part(
			model,
			"CanteenPost",
			Vector3.new(0.7, 6, 0.7),
			canteen * CFrame.new(corner[1] * 8, 3, corner[2] * 5),
			TRIM,
			Enum.Material.Concrete
		)
	end
	part(
		model,
		"CanteenFloor",
		Vector3.new(18, 0.4, 12),
		canteen * CFrame.new(0, 0.2, 0),
		CONCRETE,
		Enum.Material.Concrete
	)
	for row = -1, 1, 2 do
		part(
			model,
			"Table",
			Vector3.new(10, 0.4, 2.2),
			canteen * CFrame.new(0, 2.4, row * 2.5),
			Color3.fromRGB(46, 140, 124),
			nil
		)
	end
	gableRoof(
		model,
		canteen * CFrame.new(0, 6, 0),
		20,
		14,
		3,
		Color3.fromRGB(62, 96, 132),
		Enum.Material.CorrodedMetal
	)

	-- Flagpole with the Thai flag: red, white, blue (double width), white, red.
	local pole = ground * CFrame.new(-2, 0, -6)
	part(
		model,
		"FlagBase",
		Vector3.new(3, 0.8, 3),
		pole * CFrame.new(0, 0.4, 0),
		CONCRETE,
		Enum.Material.Concrete
	)
	part(
		model,
		"FlagPole",
		Vector3.new(0.35, 18, 0.35),
		pole * CFrame.new(0, 9, 0),
		TRIM,
		Enum.Material.Metal
	)
	local stripes = { red, TRIM, blue, blue, TRIM, red }
	for index, color in stripes do
		part(
			model,
			"Flag",
			Vector3.new(0.1, 0.55, 5),
			pole * CFrame.new(0, 17.6 - index * 0.55, 2.6),
			color,
			Enum.Material.Fabric,
			false
		)
	end

	-- Sports court.
	local court = ground * CFrame.new(-22, 0, -8)
	part(
		model,
		"Court",
		Vector3.new(30, 0.2, 16),
		court * CFrame.new(0, 0.1, 0),
		Color3.fromRGB(176, 96, 66),
		Enum.Material.Concrete,
		false
	)
	part(
		model,
		"CourtLine",
		Vector3.new(0.3, 0.22, 16),
		court * CFrame.new(0, 0.12, 0),
		TRIM,
		nil,
		false
	)
	for side = -1, 1, 2 do
		part(
			model,
			"Goal",
			Vector3.new(0.4, 4, 5),
			court * CFrame.new(side * 14.5, 2, 0),
			TRIM,
			Enum.Material.Metal
		)
	end

	-- Low fence with a gate on the -Z side.
	local fence = Color3.fromRGB(214, 206, 190)
	part(
		model,
		"FenceBack",
		Vector3.new(80, 2.4, 0.6),
		ground * CFrame.new(0, 1.2, 21.7),
		fence,
		Enum.Material.Concrete
	)
	for side = -1, 1, 2 do
		part(
			model,
			"FenceSide",
			Vector3.new(0.6, 2.4, 44),
			ground * CFrame.new(side * 39.7, 1.2, 0),
			fence,
			Enum.Material.Concrete
		)
		part(
			model,
			"FenceFront",
			Vector3.new(34, 2.4, 0.6),
			ground * CFrame.new(side * 23, 1.2, -21.7),
			fence,
			Enum.Material.Concrete
		)
		part(
			model,
			"GatePost",
			Vector3.new(1.4, 5, 1.4),
			ground * CFrame.new(side * 6, 2.5, -21.7),
			blue,
			Enum.Material.Concrete
		)
	end
	part(
		model,
		"GateSign",
		Vector3.new(13.4, 2, 0.5),
		ground * CFrame.new(0, 5.2, -21.7),
		blue,
		nil
	)
	-- Shown only on smog days (VillageService): the gate shut and a closure notice.
	local gate = part(
		model,
		"ClosedGate",
		Vector3.new(10.6, 3.6, 0.3),
		ground * CFrame.new(0, 1.8, -21.7),
		Color3.fromRGB(90, 96, 104),
		Enum.Material.DiamondPlate,
		false
	)
	gate.Transparency = 1
	local sign = part(
		model,
		"ClosedSign",
		Vector3.new(9, 3, 0.3),
		ground * CFrame.new(0, 8.2, -22),
		Color3.fromRGB(200, 52, 40),
		nil,
		false
	)
	sign.Transparency = 1
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Notice"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Enabled = false
	surface.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "CLOSED\nSMOG DAY"
	text.TextScaled = true
	text.FontFace =
		Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Parent = surface
	return model
end

-- How much ground each house needs, for keeping clear of other scenery.
Houses.Radius = 16

-- Any house, chosen at random. Shophouses only make sense on a road, so callers ask for them.
function Houses.Random(ground: CFrame, rng: Random, roadside: boolean?): Model
	local roll = rng:NextNumber()
	if roadside and roll < 0.4 then
		return Houses.Shophouse(ground, rng)
	elseif roll < 0.55 then
		return Houses.StiltHouse(ground, rng)
	elseif roll < 0.85 then
		return Houses.ConcreteHouse(ground, rng)
	end
	return Houses.Farmhouse(ground, rng)
end

return Houses
