--!strict

-- A harvested rice straw sheaf the player walks up to and picks up: one sheaf is one bundle.
-- Built from parts in the low-poly machine style, so no mesh upload is needed.

local StrawSheaf = {}

local STRAW = Color3.fromRGB(226, 185, 83)
local STRAW_LIGHT = Color3.fromRGB(240, 208, 118)
local TIE = Color3.fromRGB(139, 98, 52)
local CHARRED = Color3.fromRGB(46, 40, 35)

local function part(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.CFrame = cframe
	item.Color = color
	item.Material = Enum.Material.Grass
	item.Anchored = true
	item.CanCollide = false
	item.CanTouch = false
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = model
	return item
end

local function upright(base: CFrame, height: number): CFrame
	-- Part cylinders run along X, so turn them to stand up.
	return base * CFrame.new(0, height, 0) * CFrame.Angles(0, 0, math.rad(90))
end

-- `groundCFrame` is the point on the ground where the sheaf stands; `seed` varies its lean.
function StrawSheaf.Build(groundCFrame: CFrame, seed: number): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "StrawSheaf"
	local random = Random.new(seed)
	local base = groundCFrame
		* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
		* CFrame.Angles(math.rad(random:NextNumber(-6, 6)), 0, math.rad(random:NextNumber(-6, 6)))

	part(model, "Foot", Vector3.new(0.5, 2.1, 2.1), upright(base, 0.25), STRAW)
	local body = part(model, "Bundle", Vector3.new(2.8, 1.7, 1.7), upright(base, 1.7), STRAW)
	local tie = part(model, "Tie", Vector3.new(0.35, 1.85, 1.85), upright(base, 1.9), TIE)
	tie.Material = Enum.Material.Fabric
	part(model, "Tuft", Vector3.new(0.7, 2.3, 2.3), upright(base, 3.3), STRAW_LIGHT)
	for index = 1, 3 do
		local angle = index * math.pi * 2 / 3
		part(
			model,
			"Stalk" .. index,
			Vector3.new(0.15, 1.4, 0.15),
			base
				* CFrame.new(math.cos(angle) * 0.6, 3.9, math.sin(angle) * 0.6)
				* CFrame.Angles(math.sin(angle) * 0.5, 0, -math.cos(angle) * 0.5),
			STRAW_LIGHT
		)
	end

	model.PrimaryPart = body
	return model, body
end

-- Burned straw is left as charred stubs so the field shows what happened.
function StrawSheaf.Char(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Color = CHARRED
			descendant.Material = Enum.Material.Slate
		elseif descendant:IsA("ProximityPrompt") then
			descendant.Enabled = false
		end
	end
end

return StrawSheaf
