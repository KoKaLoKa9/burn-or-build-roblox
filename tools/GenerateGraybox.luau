-- Run once in the Roblox Studio Command Bar while not playing.
-- This deletes and recreates only Workspace.BurnOrBuildWorld.

return function()
	local Workspace = game:GetService("Workspace")
	local Lighting = game:GetService("Lighting")

	local oldWorld = Workspace:FindFirstChild("BurnOrBuildWorld")
	if oldWorld then
		oldWorld:Destroy()
	end

	local world = Instance.new("Model")
	world.Name = "BurnOrBuildWorld"
	world:SetAttribute("WorldVersion", "GateB-Graybox-01")
	world.Parent = Workspace

	local function part(name, size, position, color, material, parent)
		local item = Instance.new("Part")
		item.Name = name
		item.Size = size
		item.Position = position
		item.Anchored = true
		item.TopSurface = Enum.SurfaceType.Smooth
		item.BottomSurface = Enum.SurfaceType.Smooth
		item.Color = color
		item.Material = material or Enum.Material.SmoothPlastic
		item.Parent = parent or world
		return item
	end

	local function label(target, text, color, width)
		local gui = Instance.new("BillboardGui")
		gui.Name = "MapLabel"
		gui.Size = UDim2.fromOffset(width or 220, 56)
		gui.StudsOffset = Vector3.new(0, target.Size.Y / 2 + 4, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 175
		gui.Parent = target

		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.fromScale(1, 1)
		textLabel.BackgroundColor3 = Color3.fromRGB(20, 29, 25)
		textLabel.BackgroundTransparency = 0.12
		textLabel.BorderSizePixel = 0
		textLabel.Font = Enum.Font.GothamBold
		textLabel.Text = text
		textLabel.TextColor3 = color or Color3.fromRGB(247, 241, 220)
		textLabel.TextScaled = true
		textLabel.TextWrapped = true
		textLabel.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = textLabel
		return textLabel
	end

	local function createFarm(name, displayName, center, fieldSize, accent, isPlayerFarm)
		local farm = Instance.new("Model")
		farm.Name = name
		farm.Parent = world

		local field = part(
			"StrawArea",
			Vector3.new(fieldSize.X, 1, fieldSize.Y),
			center + Vector3.new(0, 0.5, 0),
			Color3.fromRGB(193, 147, 52),
			Enum.Material.Grass,
			farm
		)
		farm.PrimaryPart = field

		for row = -4, 4 do
			part(
				"RiceRow",
				Vector3.new(2.2, 2.4, fieldSize.Y - 8),
				center + Vector3.new(row * 9, 2, 0),
				Color3.fromRGB(222, 181, 66),
				Enum.Material.Grass,
				farm
			)
		end

		local collectionPoint = part(
			"CollectionPoint",
			Vector3.new(10, 1, 10),
			center + Vector3.new(-fieldSize.X / 2 + 8, 1.1, fieldSize.Y / 2 + 8),
			Color3.fromRGB(47, 155, 123),
			Enum.Material.Neon,
			farm
		)
		local collectionLabel = if isPlayerFarm
			then displayName .. "\nCOLLECT STRAW"
			else displayName .. "\nFUTURE CONTRACT"
		label(collectionPoint, collectionLabel, Color3.fromRGB(216, 255, 237))

		local burnPoint = part(
			"BurnPoint",
			Vector3.new(10, 1, 10),
			center + Vector3.new(-fieldSize.X / 2 + 22, 1.1, fieldSize.Y / 2 + 8),
			accent,
			Enum.Material.Neon,
			farm
		)
		local burnLabel = if isPlayerFarm then "BURN STRAW" else "BURN RISK"
		label(burnPoint, burnLabel, Color3.fromRGB(255, 235, 210), 140)
		return farm
	end

	local function createBuilding(name, position, size, color, displayName, parent)
		local model = Instance.new("Model")
		model.Name = name
		model.Parent = parent or world

		local body = part(
			"Body",
			size,
			position + Vector3.new(0, size.Y / 2, 0),
			color,
			Enum.Material.Metal,
			model
		)
		model.PrimaryPart = body
		label(body, displayName, Color3.fromRGB(247, 241, 220), 190)
		return model
	end

	part(
		"DistrictGround",
		Vector3.new(520, 2, 420),
		Vector3.new(0, -1, 0),
		Color3.fromRGB(118, 148, 82),
		Enum.Material.Grass,
		world
	)

	part(
		"MainRoad",
		Vector3.new(500, 1, 24),
		Vector3.new(0, 0.15, 55),
		Color3.fromRGB(104, 94, 78),
		Enum.Material.Ground,
		world
	)
	part(
		"FactoryRoad",
		Vector3.new(24, 1.1, 300),
		Vector3.new(20, 0.2, 55),
		Color3.fromRGB(104, 94, 78),
		Enum.Material.Ground,
		world
	)
	local canal = part(
		"Canal",
		Vector3.new(500, 0.8, 14),
		Vector3.new(0, 0.05, -145),
		Color3.fromRGB(56, 139, 164),
		Enum.Material.Glass,
		world
	)
	canal.Transparency = 0.2

	createFarm(
		"Farm_A",
		"YOUR FARM",
		Vector3.new(-150, 0, -75),
		Vector2.new(100, 72),
		Color3.fromRGB(226, 91, 47),
		true
	)
	createFarm(
		"Farm_B",
		"NEAR FARM",
		Vector3.new(-25, 0, -75),
		Vector2.new(90, 72),
		Color3.fromRGB(226, 128, 47),
		false
	)
	createFarm(
		"Farm_C",
		"DISTANT FARM",
		Vector3.new(105, 0, -75),
		Vector2.new(105, 72),
		Color3.fromRGB(226, 128, 47),
		false
	)

	local factory = Instance.new("Model")
	factory.Name = "CooperativeFactory"
	factory.Parent = world
	local factoryFloor = part(
		"FactoryFloor",
		Vector3.new(175, 1, 115),
		Vector3.new(15, 0.5, 130),
		Color3.fromRGB(178, 176, 163),
		Enum.Material.Concrete,
		factory
	)
	factory.PrimaryPart = factoryFloor
	label(factoryFloor, "COOPERATIVE FACTORY\nSNAP GRID", Color3.fromRGB(217, 255, 244), 280)

	for x = -65, 95, 20 do
		local gridLine = part(
			"GridLine",
			Vector3.new(0.35, 0.08, 105),
			Vector3.new(x, 1.05, 130),
			Color3.fromRGB(52, 125, 115),
			Enum.Material.Neon,
			factory
		)
		gridLine.CanCollide = false
	end
	for z = 85, 175, 20 do
		local gridLine = part(
			"GridLine",
			Vector3.new(165, 0.08, 0.35),
			Vector3.new(15, 1.06, z),
			Color3.fromRGB(52, 125, 115),
			Enum.Material.Neon,
			factory
		)
		gridLine.CanCollide = false
	end

	createBuilding(
		"DryerPlaceholder",
		Vector3.new(-45, 1, 120),
		Vector3.new(26, 18, 24),
		Color3.fromRGB(219, 157, 55),
		"DRYER",
		factory
	)
	createBuilding(
		"ShredderPlaceholder",
		Vector3.new(5, 1, 120),
		Vector3.new(26, 14, 24),
		Color3.fromRGB(58, 98, 93),
		"SHREDDER",
		factory
	)
	createBuilding(
		"PelletMillPlaceholder",
		Vector3.new(55, 1, 120),
		Vector3.new(28, 22, 26),
		Color3.fromRGB(43, 63, 59),
		"PELLET MILL",
		factory
	)

	local village = Instance.new("Model")
	village.Name = "Village"
	village.Parent = world
	local exposureZone = part(
		"ExposureZone",
		Vector3.new(100, 1, 95),
		Vector3.new(185, 0.3, -30),
		Color3.fromRGB(224, 208, 166),
		Enum.Material.Sand,
		village
	)
	exposureZone.Transparency = 0.45
	exposureZone.CanCollide = false
	label(exposureZone, "VILLAGE + SCHOOL\nEXPOSURE ZONE", Color3.fromRGB(255, 231, 207), 260)

	for index, offset in
		{
			Vector3.new(-30, 0, -22),
			Vector3.new(12, 0, -24),
			Vector3.new(-24, 0, 22),
		}
	do
		createBuilding(
			"House_" .. index,
			exposureZone.Position + offset,
			Vector3.new(22, 12, 18),
			Color3.fromRGB(211, 161, 98),
			"HOUSE",
			village
		)
	end
	createBuilding(
		"School",
		exposureZone.Position + Vector3.new(25, 0, 20),
		Vector3.new(34, 16, 22),
		Color3.fromRGB(228, 218, 186),
		"SCHOOL",
		village
	)

	local buyer = createBuilding(
		"PelletBuyer",
		Vector3.new(165, 1, 145),
		Vector3.new(44, 20, 36),
		Color3.fromRGB(45, 131, 119),
		"PELLET BUYER",
		world
	)
	buyer:SetAttribute("Purpose", "Future pellet sales")

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlayerSpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(-150, 1, 5)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Color = Color3.fromRGB(47, 155, 123)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = world
	label(spawn, "START", Color3.fromRGB(218, 255, 239), 120)

	local windSign = part(
		"WindSign",
		Vector3.new(38, 8, 2),
		Vector3.new(60, 9, 10),
		Color3.fromRGB(31, 69, 66),
		Enum.Material.Metal,
		world
	)
	label(windSign, "WIND -> EAST\nTOWARD VILLAGE", Color3.fromRGB(137, 231, 225), 250)

	Lighting.ClockTime = 16.2
	Lighting.Brightness = 2.2
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.35
	Workspace.FallenPartsDestroyHeight = -100

	print("Burn or Build graybox created: GateB-Graybox-01")
end
