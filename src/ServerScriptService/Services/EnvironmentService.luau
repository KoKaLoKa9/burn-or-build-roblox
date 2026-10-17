--!strict

-- Turns the flat graybox district into a Thai rice-farming landscape at startup: terrain grass,
-- green and flooded paddies beyond the district, a water canal, hazy mountains to the north, a
-- dry pine hill, laterite tracks to every farm stop, scattered sugar palms and shade trees, and
-- warm late-afternoon light. Gameplay parts never move (except two graybox fixes noted below),
-- and nothing is placed on a field, road, plot, building, or track.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Flora = require(script.Parent:WaitForChild("Flora"))
local Houses = require(script.Parent:WaitForChild("Houses"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local EnvironmentService = {}

type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }

local SEED = 20261016
local HALF_X = 640
local HALF_Z = 560
local DISTRICT: Rect = { minX = -264, maxX = 264, minZ = -212, maxZ = 212 }
local CANAL: Rect = { minX = -HALF_X, maxX = HALF_X, minZ = -152, maxZ = -136 }
local FOREST_EDGE_Z = -476
local PINE_HILL: Rect = { minX = -620, maxX = -380, minZ = 320, maxZ = 540 }
local PADDY_X, PADDY_Z = 48, 36
-- Houses line the main road (graybox z 43 to 67) on both sides, so paddies stay out of that band.
local HOUSE_BAND: Rect = { minX = -HALF_X, maxX = HALF_X, minZ = 10, maxZ = 100 }
-- Small hamlets out in the countryside.
local HAMLETS = { { 330, 400 }, { -210, 460 }, { -420, -420 }, { 360, -420 }, { 520, 180 } }
local PATH_WIDTH = 12

local terrain = Workspace.Terrain
-- Terrain voxels are centred on multiples of 4, so a fill that stops at height h shows its
-- surface at h + 2. Every fill stops 2 studs low to keep the ground level with the graybox (y 0).
local SURFACE_LIFT = 2
local rng = Random.new(SEED)
local folder: Folder
local blockers: { Rect } = {}
local placed: { { x: number, z: number, r: number } } = {}

local function rect(minX: number, maxX: number, minZ: number, maxZ: number): Rect
	return { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ }
end

local function grow(area: Rect, margin: number): Rect
	return rect(area.minX - margin, area.maxX + margin, area.minZ - margin, area.maxZ + margin)
end

local function overlaps(a: Rect, b: Rect): boolean
	return a.minX < b.maxX and a.maxX > b.minX and a.minZ < b.maxZ and a.maxZ > b.minZ
end

local function contains(area: Rect, x: number, z: number): boolean
	return x >= area.minX and x <= area.maxX and z >= area.minZ and z <= area.maxZ
end

-- The flat footprint of a box, even when it is turned.
local function footprint(cframe: CFrame, size: Vector3): Rect
	local halfX = math.abs(cframe.RightVector.X) * size.X / 2
		+ math.abs(cframe.UpVector.X) * size.Y / 2
		+ math.abs(cframe.LookVector.X) * size.Z / 2
	local halfZ = math.abs(cframe.RightVector.Z) * size.X / 2
		+ math.abs(cframe.UpVector.Z) * size.Y / 2
		+ math.abs(cframe.LookVector.Z) * size.Z / 2
	local p = cframe.Position
	return rect(p.X - halfX, p.X + halfX, p.Z - halfZ, p.Z + halfZ)
end

local function footprintOf(instance: Instance): Rect?
	if instance:IsA("BasePart") then
		return footprint(instance.CFrame, instance.Size)
	elseif instance:IsA("Model") then
		local cframe, size = instance:GetBoundingBox()
		return footprint(cframe, size)
	end
	return nil
end

local function paint(area: Rect, material: Enum.Material)
	local width, depth = area.maxX - area.minX, area.maxZ - area.minZ
	if width <= 0 or depth <= 0 then
		return
	end
	local cframe =
		CFrame.new((area.minX + area.maxX) / 2, -2 - SURFACE_LIFT, (area.minZ + area.maxZ) / 2)
	local size = Vector3.new(width, 4, depth)
	if material == Enum.Material.Water then
		-- Water only fills empty space, so dig the ground out first.
		terrain:FillBlock(cframe, size, Enum.Material.Air)
	end
	terrain:FillBlock(cframe, size, material)
end

-- Swaps the grass surface for another material without touching the ground height. A FillBlock
-- here would raise the surface by half a voxel and bury the fields, floors, and roads.
local function recolor(area: Rect, material: Enum.Material)
	local region =
		Region3.new(Vector3.new(area.minX, -8, area.minZ), Vector3.new(area.maxX, 4, area.maxZ))
			:ExpandToGrid(4)
	terrain:ReplaceMaterial(region, 4, Enum.Material.Grass, material)
end

local function findPart(world: Model, name: string): BasePart?
	local found = world:FindFirstChild(name, true)
	return if found and found:IsA("BasePart") then found else nil
end

-- Light -----------------------------------------------------------------------------------------

local function ensure(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent
	return created
end

-- Warm late-afternoon light over the paddies, with haze that softens the far mountains.
local function applyLighting()
	Lighting.ClockTime = 16.8
	Lighting.GeographicLatitude = 14
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(78, 70, 62)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 138, 120)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 226, 184)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.ShadowSoftness = 0.3
	Lighting.GlobalShadows = true

	local atmosphere = ensure(Lighting, "Atmosphere", "Haze") :: Atmosphere
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(214, 192, 164)
	atmosphere.Decay = Color3.fromRGB(150, 122, 104)
	atmosphere.Glare = 0.45
	atmosphere.Haze = 1.1

	local sky = ensure(Lighting, "Sky", "Sky") :: Sky
	sky.SunAngularSize = 14
	sky.CelestialBodiesShown = true

	local clouds = ensure(terrain, "Clouds", "Clouds") :: Clouds
	clouds.Cover = 0.58
	clouds.Density = 0.62
	clouds.Color = Color3.fromRGB(255, 236, 214)

	local bloom = ensure(Lighting, "BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.5
	bloom.Size = 30
	bloom.Threshold = 1.4

	local rays = ensure(Lighting, "SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = 0.06
	rays.Spread = 0.7

	local grade = ensure(Lighting, "ColorCorrectionEffect", "Grade") :: ColorCorrectionEffect
	grade.Brightness = 0.02
	grade.Contrast = 0.08
	grade.Saturation = 0.18
	grade.TintColor = Color3.fromRGB(255, 246, 232)
end

-- Terrain ---------------------------------------------------------------------------------------

local function setMaterialColors()
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(104, 150, 62))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(122, 178, 64))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(196, 166, 98))
	terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(160, 104, 66))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(208, 186, 146))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(124, 118, 108))
	terrain.WaterColor = Color3.fromRGB(70, 112, 118)
	terrain.WaterTransparency = 0.3
	terrain.WaterReflectance = 0.85
	terrain.WaterWaveSize = 0.05
	terrain.WaterWaveSpeed = 4
	-- Grass blades on open ground. Some Studio builds lock this property, so it is optional.
	pcall(function()
		(terrain :: any).Decoration = true
	end)
end

-- What each paddy was painted with, so scenery can skip water without raycasting terrain that
-- was only just created this frame.
local paddyMaterial: { [string]: Enum.Material } = {}
local PINE_HILL_BALLS = { { -500, 420, 72 }, { -430, 488, 60 }, { -566, 356, 56 } }

local function paddyKey(x: number, z: number): string
	return string.format("%d,%d", (x + HALF_X) // PADDY_X, (z + HALF_Z) // PADDY_Z)
end

local function buildPaddies()
	for x = -HALF_X, HALF_X - PADDY_X, PADDY_X do
		for z = -HALF_Z, HALF_Z - PADDY_Z, PADDY_Z do
			local cell = rect(x, x + PADDY_X, z, z + PADDY_Z)
			local skip = overlaps(cell, DISTRICT)
				or overlaps(cell, HOUSE_BAND)
				or overlaps(cell, grow(CANAL, 4))
				or cell.minZ < FOREST_EDGE_Z
				or overlaps(cell, PINE_HILL)
			if not skip then
				-- The grass left between paddies reads as the bunds in the reference photos.
				local inner = grow(cell, -2)
				local roll = rng:NextNumber()
				local material = if roll < 0.52
					then Enum.Material.LeafyGrass
					elseif roll < 0.78 then Enum.Material.Water
					else Enum.Material.Ground
				if material == Enum.Material.Water then
					-- A muddy bed under shallow water, so flooded paddies read as water.
					terrain:FillBlock(
						CFrame.new(
							(inner.minX + inner.maxX) / 2,
							-6 - SURFACE_LIFT,
							(inner.minZ + inner.maxZ) / 2
						),
						Vector3.new(inner.maxX - inner.minX, 4, inner.maxZ - inner.minZ),
						Enum.Material.Mud
					)
				end
				paint(inner, material)
				paddyMaterial[paddyKey(x, z)] = material
			end
		end
	end
end

local function buildHills()
	-- A broken ridge of mountains on the northern horizon.
	for index = 1, 9 do
		local radius = rng:NextNumber(95, 150)
		local center = Vector3.new(
			-HALF_X + (index - 1) * 160 + rng:NextNumber(-40, 40),
			-radius * 0.5,
			rng:NextNumber(-700, -610)
		)
		terrain:FillBall(center, radius, Enum.Material.Grass)
		terrain:FillBall(
			center + Vector3.new(0, radius * 0.38, 0),
			radius * 0.55,
			Enum.Material.Rock
		)
	end
	-- Low wooded rises on the east and west edges close the view.
	for index = 1, 6 do
		local side = if index % 2 == 0 then 1 else -1
		local radius = rng:NextNumber(70, 105)
		terrain:FillBall(
			Vector3.new(side * rng:NextNumber(700, 760), -radius * 0.55, rng:NextNumber(-420, 420)),
			radius,
			Enum.Material.Grass
		)
	end
	-- Rolling hills on the southern horizon.
	for index = 1, 7 do
		local radius = rng:NextNumber(80, 120)
		terrain:FillBall(
			Vector3.new(
				-HALF_X + (index - 1) * 210 + rng:NextNumber(-40, 40),
				-radius * 0.55,
				rng:NextNumber(680, 760)
			),
			radius,
			Enum.Material.Grass
		)
	end
	-- A dry grassy hill for the pine stand.
	for _, ball in PINE_HILL_BALLS do
		terrain:FillBall(
			Vector3.new(ball[1], -ball[3] * 0.62, ball[2]),
			ball[3],
			Enum.Material.Ground
		)
	end
end

-- Graybox fixes --------------------------------------------------------------------------------

local function tidyGraybox(world: Model)
	-- The terrain is the ground now. The old slab stays only as an invisible floor.
	local ground = findPart(world, "DistrictGround")
	if ground then
		ground.Transparency = 1
	end
	local canal = findPart(world, "Canal")
	if canal then
		canal.Transparency = 1
		canal.CanCollide = false
	end
	local zone = findPart(world, "ExposureZone")
	if zone then
		zone.Transparency = 1
	end

	local mainRoad = findPart(world, "MainRoad")
	local factoryRoad = findPart(world, "FactoryRoad")
	if mainRoad and factoryRoad then
		-- The factory road used to run on past the main road into Farm B. It now starts at the
		-- main road and only serves the factory and buyer. Trucks only use its X position.
		local southEdge = factoryRoad.Position.Z + factoryRoad.Size.Z / 2
		local northEdge = mainRoad.Position.Z
		if southEdge > northEdge then
			factoryRoad.Size =
				Vector3.new(factoryRoad.Size.X, factoryRoad.Size.Y, southEdge - northEdge)
			factoryRoad.Position = Vector3.new(
				factoryRoad.Position.X,
				factoryRoad.Position.Y,
				(southEdge + northEdge) / 2
			)
		end
		for _, road in { mainRoad, factoryRoad } do
			road.Material = Enum.Material.Asphalt
			road.Color = Color3.fromRGB(74, 73, 72)
		end
	end

	-- The wind sign stood across the Farm C truck lane. Move it beside the lane instead.
	local windSign = findPart(world, "WindSign")
	if windSign then
		windSign.Position = Vector3.new(100, windSign.Position.Y, windSign.Position.Z)
	end
end

-- Tracks ------------------------------------------------------------------------------------------

-- Laterite tracks: one along the front of the farms, spokes from it to the main road at each
-- truck stop and at the spawn, and short lanes to the village and the buyer.
local function trackRects(world: Model): { Rect }
	local tracks: { Rect } = {}
	local mainRoad = findPart(world, "MainRoad")
	if mainRoad == nil then
		return tracks
	end
	local roadNorth = mainRoad.Position.Z - mainRoad.Size.Z / 2
	local roadSouth = mainRoad.Position.Z + mainRoad.Size.Z / 2

	local fieldMinX, fieldMaxX, fieldSouth = math.huge, -math.huge, -math.huge
	local stops: { number } = {}
	for _, name in { "Farm_A", "Farm_B", "Farm_C" } do
		local farm = world:FindFirstChild(name, true)
		local area = if farm then farm:FindFirstChild("StrawArea") else nil
		if area and area:IsA("BasePart") then
			fieldMinX = math.min(fieldMinX, area.Position.X - area.Size.X / 2)
			fieldMaxX = math.max(fieldMaxX, area.Position.X + area.Size.X / 2)
			fieldSouth = math.max(fieldSouth, area.Position.Z + area.Size.Z / 2)
		end
		local stop = if farm and name ~= "Farm_A"
			then farm:FindFirstChild("CollectionPoint")
			else nil
		if stop and stop:IsA("BasePart") then
			table.insert(stops, stop.Position.X)
		end
	end
	if fieldSouth == -math.huge then
		return tracks
	end
	local trackNorth, trackSouth = fieldSouth + 1, fieldSouth + 17
	table.insert(tracks, rect(fieldMinX - 6, fieldMaxX + 6, trackNorth, trackSouth))

	local spawn = findPart(world, "PlayerSpawn")
	if spawn then
		table.insert(stops, spawn.Position.X)
	end
	for _, x in stops do
		table.insert(tracks, rect(x - PATH_WIDTH / 2, x + PATH_WIDTH / 2, trackSouth, roadNorth))
	end

	local zone = findPart(world, "ExposureZone")
	if zone then
		local x = zone.Position.X
		table.insert(
			tracks,
			rect(
				x - PATH_WIDTH / 2,
				x + PATH_WIDTH / 2,
				zone.Position.Z + zone.Size.Z / 2,
				roadNorth
			)
		)
	end
	local buyer = world:FindFirstChild("PelletBuyer")
	local buyerBody = if buyer then buyer:FindFirstChild("Body") else nil
	if buyerBody and buyerBody:IsA("BasePart") then
		local x = buyerBody.Position.X - buyerBody.Size.X / 2 + 20
		local north = buyerBody.Position.Z - buyerBody.Size.Z / 2
		table.insert(tracks, rect(x - PATH_WIDTH / 2, x + PATH_WIDTH / 2, roadSouth, north))
	end
	return tracks
end

-- Keep-out areas ----------------------------------------------------------------------------------

local BELT_CORRIDOR: Rect = { minX = 90, maxX = 160, minZ = 110, maxZ = 180 }
local SKIP_BLOCKERS = { DistrictGround = true, Canal = true, ExposureZone = true }

local function collectBlockers(world: Model, tracks: { Rect })
	for _, child in world:GetChildren() do
		if SKIP_BLOCKERS[child.Name] then
			continue
		end
		if child.Name == "Village" then
			-- Shade trees may stand in the village, just not on the houses or the school.
			for _, building in child:GetChildren() do
				local area = if SKIP_BLOCKERS[building.Name] then nil else footprintOf(building)
				if area then
					table.insert(blockers, grow(area, 5))
				end
			end
		else
			local area = footprintOf(child)
			if area then
				table.insert(blockers, grow(area, 6))
			end
		end
	end
	for _, track in tracks do
		table.insert(blockers, grow(track, 3))
	end
	-- Paddy plot lots stay open, with room for their sign and burn spot.
	local plots = GameConfig.Plots
	for _, lot in plots.Lots do
		table.insert(
			blockers,
			grow(
				rect(
					lot.X - plots.Width / 2,
					lot.X + plots.Width / 2,
					lot.Z - plots.Depth / 2,
					lot.Z + plots.Depth / 2
				),
				10
			)
		)
	end
	-- Belts may run from the factory plot out to the buyer's dock, so keep that gap clear.
	table.insert(blockers, BELT_CORRIDOR)
end

local function paintUnderGameplay(world: Model, tracks: { Rect })
	-- Bare earth under every gameplay part, so no grass pokes through floors and fields.
	for _, child in world:GetChildren() do
		if child.Name == "Village" then
			local zone = child:FindFirstChild("ExposureZone")
			local area = if zone then footprintOf(zone) else nil
			if area then
				recolor(area, Enum.Material.Sand)
			end
		elseif not SKIP_BLOCKERS[child.Name] then
			local area = footprintOf(child)
			if area and overlaps(area, DISTRICT) then
				recolor(area, Enum.Material.Mud)
			end
		end
	end
	for _, track in tracks do
		recolor(track, Enum.Material.Mud)
	end
	paint(CANAL, Enum.Material.Water)
end

-- Scatter -----------------------------------------------------------------------------------------

-- Ground height and surface at a point, worked out from the layout above.
local function groundAt(x: number, z: number): (CFrame?, Enum.Material?)
	if contains(grow(CANAL, 3), x, z) then
		return nil, nil
	end
	local material = paddyMaterial[paddyKey(x, z)] or Enum.Material.Grass
	if material == Enum.Material.Water then
		return nil, nil
	end
	local height = 0
	for _, ball in PINE_HILL_BALLS do
		local radius = ball[3]
		local dx, dz = x - ball[1], z - ball[2]
		local flat = dx * dx + dz * dz
		if flat < radius * radius then
			height = math.max(height, -radius * 0.62 + math.sqrt(radius * radius - flat))
		end
	end
	-- Sink a little so trunks never float on a slope.
	return CFrame.new(x, height - 0.4, z), material
end

local function isFree(x: number, z: number, radius: number): boolean
	if math.abs(x) > HALF_X - 16 or math.abs(z) > HALF_Z - 16 then
		return false
	end
	for _, area in blockers do
		if contains(grow(area, radius * 0.6), x, z) then
			return false
		end
	end
	for _, other in placed do
		local dx, dz = other.x - x, other.z - z
		local gap = (other.r + radius) * 0.7
		if dx * dx + dz * dz < gap * gap then
			return false
		end
	end
	return true
end

type Builder = (CFrame, Random) -> Model

local RADIUS: { [Builder]: number } = {
	[Flora.SugarPalm] = 4,
	[Flora.RainTree] = 9,
	[Flora.UmbrellaPine] = 8,
	[Flora.Frangipani] = 4,
	[Flora.Bush] = 3,
	[Flora.Rock] = 3,
	[Flora.StrawStack] = 5,
	[Flora.FieldHut] = 9,
}

local function place(builder: Builder, x: number, z: number): boolean
	local radius = RADIUS[builder] or 4
	if not isFree(x, z, radius) then
		return false
	end
	local ground, material = groundAt(x, z)
	if ground == nil then
		return false
	end
	-- Stubble and straw stacks belong on dry ground, not in green paddies.
	if builder == Flora.StrawStack and material ~= Enum.Material.Ground then
		return false
	end
	local model = builder(ground, rng)
	model.Parent = folder
	table.insert(placed, { x = x, z = z, r = radius })
	return true
end

local function pick(weights: { { any } }): Builder
	local total = 0
	for _, entry in weights do
		total += entry[2]
	end
	local roll = rng:NextNumber(0, total)
	for _, entry in weights do
		roll -= entry[2]
		if roll <= 0 then
			return entry[1]
		end
	end
	return weights[1][1]
end

local function scatter(area: Rect, attempts: number, weights: { { any } })
	for _ = 1, attempts do
		place(
			pick(weights),
			rng:NextNumber(area.minX, area.maxX),
			rng:NextNumber(area.minZ, area.maxZ)
		)
	end
end

local function scatterOutside(attempts: number, weights: { { any } })
	local everywhere = rect(-HALF_X, HALF_X, FOREST_EDGE_Z, HALF_Z)
	for _ = 1, attempts do
		local x, z =
			rng:NextNumber(everywhere.minX, everywhere.maxX),
			rng:NextNumber(everywhere.minZ, everywhere.maxZ)
		if not contains(DISTRICT, x, z) then
			place(pick(weights), x, z)
		end
	end
end

-- One house, kept off gameplay areas, water, and other scenery. `yaw` turns its front door.
local function placeHouse(x: number, z: number, yaw: number, roadside: boolean): boolean
	if not isFree(x, z, Houses.Radius) then
		return false
	end
	local ground = groundAt(x, z)
	if ground == nil then
		return false
	end
	local model = Houses.Random(ground * CFrame.Angles(0, yaw, 0), rng, roadside)
	model.Parent = folder
	table.insert(placed, { x = x, z = z, r = Houses.Radius })
	return true
end

-- Houses face the road from both sides of it, then a few hamlets dot the countryside.
local function placeHouses(world: Model)
	local mainRoad = findPart(world, "MainRoad")
	if mainRoad then
		local north = mainRoad.Position.Z - mainRoad.Size.Z / 2 - 22
		local south = mainRoad.Position.Z + mainRoad.Size.Z / 2 + 22
		local x = -HALF_X + 30
		while x < HALF_X - 30 do
			if rng:NextNumber() < 0.75 then
				-- Fronts face -Z, so houses north of the road turn around to face it.
				placeHouse(x, north + rng:NextNumber(-3, 3), math.pi, true)
			end
			if rng:NextNumber() < 0.75 then
				placeHouse(x + rng:NextNumber(-8, 8), south + rng:NextNumber(-3, 3), 0, true)
			end
			x += rng:NextNumber(34, 46)
		end
	end
	for _, hamlet in HAMLETS do
		for _ = 1, rng:NextInteger(4, 6) do
			local yaw = rng:NextInteger(0, 3) * math.pi / 2
			placeHouse(
				hamlet[1] + rng:NextNumber(-45, 45),
				hamlet[2] + rng:NextNumber(-45, 45),
				yaw,
				false
			)
		end
	end
end

-- The main road carries on past the district to the map edge on both sides.
local function buildRoadExtension(world: Model)
	local mainRoad = findPart(world, "MainRoad")
	if mainRoad == nil then
		return
	end
	local model = Instance.new("Model")
	model.Name = "RoadExtension"
	model.Parent = folder
	local half = mainRoad.Size.X / 2
	for side = -1, 1, 2 do
		local inner = mainRoad.Position.X + side * half
		local outer = side * HALF_X
		local length = math.abs(outer - inner)
		local road = Instance.new("Part")
		road.Name = "Road"
		road.Size = Vector3.new(length, mainRoad.Size.Y, mainRoad.Size.Z)
		road.Position = Vector3.new((inner + outer) / 2, mainRoad.Position.Y, mainRoad.Position.Z)
		road.Color = mainRoad.Color
		road.Material = mainRoad.Material
		road.Anchored = true
		road.CanQuery = false
		road.CanTouch = false
		road.Parent = model
		table.insert(blockers, grow(footprint(road.CFrame, road.Size), 3))
		local top = road.Position.Y + road.Size.Y / 2 + 0.03
		local x = math.min(inner, outer) + 6
		while x < math.max(inner, outer) - 6 do
			local dash = Instance.new("Part")
			dash.Name = "Dash"
			dash.Size = Vector3.new(7, 0.05, 0.6)
			dash.Position = Vector3.new(x, top, road.Position.Z)
			dash.Color = Color3.fromRGB(236, 228, 204)
			dash.Anchored = true
			dash.CanCollide = false
			dash.CanQuery = false
			dash.CanTouch = false
			dash.Parent = model
			x += 16
		end
	end
end

local function plantScenery()
	local palm, rain, pine = Flora.SugarPalm, Flora.RainTree, Flora.UmbrellaPine
	local frangipani, bush, rock, stack = Flora.Frangipani, Flora.Bush, Flora.Rock, Flora.StrawStack

	-- A field hut with palms and a big shade tree beside the start, like the first photo.
	place(Flora.FieldHut, -228, 16)
	place(palm, -244, 4)
	place(palm, -238, 30)
	place(rain, -250, 46)
	place(stack, -214, 34)

	-- Tree lines along both canal banks.
	for _, bankZ in { CANAL.minZ - 8, CANAL.maxZ + 6 } do
		local x = -HALF_X + 10
		while x < HALF_X - 10 do
			place(pick({ { palm, 5 }, { rain, 3 }, { bush, 3 } }), x, bankZ + rng:NextNumber(-3, 3))
			x += rng:NextNumber(14, 26)
		end
	end

	-- Palms standing in twos and threes out on the paddy bunds.
	for _ = 1, 55 do
		local x, z = rng:NextNumber(-HALF_X, HALF_X), rng:NextNumber(FOREST_EDGE_Z, HALF_Z)
		if not contains(grow(DISTRICT, 8), x, z) then
			for _ = 1, rng:NextInteger(1, 4) do
				place(palm, x + rng:NextNumber(-10, 10), z + rng:NextNumber(-10, 10))
			end
		end
	end
	scatterOutside(260, { { rain, 3 }, { bush, 5 }, { frangipani, 1 }, { stack, 4 }, { rock, 1 } })
	place(Flora.FieldHut, 330, -96)
	place(Flora.FieldHut, -360, 150)
	place(Flora.FieldHut, 120, 300)

	-- Inside the district, between the farms, roads, factory, and village.
	scatter(DISTRICT, 320, {
		{ palm, 4 },
		{ rain, 3 },
		{ frangipani, 2 },
		{ bush, 6 },
		{ rock, 2 },
	})

	-- Woodland at the foot of the northern mountains.
	scatter(
		rect(-HALF_X, HALF_X, -HALF_Z, FOREST_EDGE_Z),
		260,
		{ { rain, 5 }, { palm, 2 }, { bush, 3 } }
	)
	-- Thick tree belts on the east and west edges.
	scatter(
		rect(-HALF_X, -HALF_X + 50, -HALF_Z, HALF_Z),
		120,
		{ { rain, 4 }, { palm, 3 }, { bush, 2 } }
	)
	scatter(
		rect(HALF_X - 50, HALF_X, -HALF_Z, HALF_Z),
		120,
		{ { rain, 4 }, { palm, 3 }, { bush, 2 } }
	)
	-- Pines and boulders on the dry hill.
	scatter(PINE_HILL, 90, { { pine, 6 }, { rock, 2 }, { bush, 1 } })
end

local function buildPowerLine(world: Model)
	local mainRoad = findPart(world, "MainRoad")
	if mainRoad == nil then
		return
	end
	local model = Instance.new("Model")
	model.Name = "PowerLine"
	model.Parent = folder
	local z = mainRoad.Position.Z - mainRoad.Size.Z / 2 - 6
	local lastA: Vector3?, lastB: Vector3? = nil, nil
	for x = -HALF_X + 20, HALF_X - 20, 44 do
		local blocked = false
		for _, area in blockers do
			if contains(area, x, z) then
				blocked = true
				break
			end
		end
		if not blocked then
			local pole, a, b =
				Flora.PowerPole(CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(90), 0))
			pole.Parent = model
			table.insert(placed, { x = x, z = z, r = 3 })
			if lastA and lastB then
				Flora.Wire(model, lastA, a)
				Flora.Wire(model, lastB, b)
			end
			lastA, lastB = a, b
		end
	end
end

local function buildRoadMarks(world: Model)
	local mainRoad = findPart(world, "MainRoad")
	local factoryRoad = findPart(world, "FactoryRoad")
	if mainRoad == nil then
		return
	end
	local model = Instance.new("Model")
	model.Name = "RoadMarks"
	model.Parent = folder
	local top = mainRoad.Position.Y + mainRoad.Size.Y / 2 + 0.03
	local half = mainRoad.Size.X / 2
	for x = mainRoad.Position.X - half + 6, mainRoad.Position.X + half - 6, 16 do
		local crossing = factoryRoad
			and math.abs(x - factoryRoad.Position.X) < factoryRoad.Size.X / 2 + 4
		if not crossing then
			local dash = Instance.new("Part")
			dash.Name = "Dash"
			dash.Size = Vector3.new(7, 0.05, 0.6)
			dash.Position = Vector3.new(x, top, mainRoad.Position.Z)
			dash.Color = Color3.fromRGB(236, 228, 204)
			dash.Material = Enum.Material.SmoothPlastic
			dash.Anchored = true
			dash.CanCollide = false
			dash.CanQuery = false
			dash.CanTouch = false
			dash.Parent = model
		end
	end
end

local function buildBunds(world: Model)
	for _, name in { "Farm_A", "Farm_B", "Farm_C" } do
		local farm = world:FindFirstChild(name, true)
		local area = if farm then farm:FindFirstChild("StrawArea") else nil
		if area and area:IsA("BasePart") then
			local p, size = area.Position, area.Size
			local y = p.Y - size.Y / 2
			-- North, west, and east edges. The south edge stays open onto the farm track.
			Flora.Bund(folder, CFrame.new(p.X, y, p.Z - size.Z / 2), size.X + 2.2)
			Flora.Bund(
				folder,
				CFrame.new(p.X - size.X / 2, y, p.Z) * CFrame.Angles(0, math.rad(90), 0),
				size.Z
			)
			Flora.Bund(
				folder,
				CFrame.new(p.X + size.X / 2, y, p.Z) * CFrame.Angles(0, math.rad(90), 0),
				size.Z
			)
		end
	end
end

local function buildBoundary()
	local model = Instance.new("Model")
	model.Name = "Boundary"
	model.Parent = folder
	for _, wall in
		{
			{ Vector3.new(HALF_X - 8, 150, 0), Vector3.new(4, 300, HALF_Z * 2) },
			{ Vector3.new(-HALF_X + 8, 150, 0), Vector3.new(4, 300, HALF_Z * 2) },
			{ Vector3.new(0, 150, HALF_Z - 8), Vector3.new(HALF_X * 2, 300, 4) },
			{ Vector3.new(0, 150, -HALF_Z + 8), Vector3.new(HALF_X * 2, 300, 4) },
		}
	do
		local part = Instance.new("Part")
		part.Name = "Wall"
		part.Position = wall[1]
		part.Size = wall[2]
		part.Transparency = 1
		part.Anchored = true
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = model
	end
end

-- Must run before MachineService, which reads the road sizes for placement rules.
function EnvironmentService:Initialize(world: Model)
	local started = os.clock()
	applyLighting()
	tidyGraybox(world)

	local existing = Workspace:FindFirstChild("Environment")
	if existing then
		existing:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Environment"
	folder.Parent = Workspace

	terrain:Clear()
	setMaterialColors()
	-- Plain grass runs far past the playable area so the horizon fades into haze, not into sky.
	terrain:FillBlock(
		CFrame.new(0, -6 - SURFACE_LIFT, 0),
		Vector3.new(2400, 12, 2400),
		Enum.Material.Grass
	)
	buildPaddies()
	buildHills()

	local tracks = trackRects(world)
	paintUnderGameplay(world, tracks)
	collectBlockers(world, tracks)

	buildBunds(world)
	buildRoadMarks(world)
	buildRoadExtension(world)
	buildPowerLine(world)
	-- Houses go down before trees, so the trees grow around them.
	placeHouses(world)
	plantScenery()
	buildBoundary()
	world:SetAttribute("EnvironmentBuildSeconds", math.floor((os.clock() - started) * 100) / 100)
end

return EnvironmentService
