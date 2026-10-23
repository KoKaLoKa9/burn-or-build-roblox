--!strict

-- Imported Blender machine models, shared by the server (placed machines) and the client
-- (hotbar previews and the placement ghost). Models live in ReplicatedStorage.MachineArt and are
-- named by machine definition id. ServerStorage.MachineArt is still read as a fallback. Farm
-- machines without an imported model use the part-built art in FarmMachineArt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FarmMachineArt = require(script.Parent:WaitForChild("FarmMachineArt"))
local PowerArt = require(script.Parent:WaitForChild("PowerArt"))
local MachineArtPalette = require(script.Parent:WaitForChild("MachineArtPalette"))

local MachineArt = {}

local function findSource(definitionId: string): Model?
	local containers: { Instance } = { ReplicatedStorage }
	local ok, serverStorage = pcall(function()
		return game:GetService("ServerStorage")
	end)
	if ok and serverStorage then
		table.insert(containers, serverStorage)
	end
	for _, container in containers do
		local library = container:FindFirstChild("MachineArt")
		local source = library and library:FindFirstChild(definitionId)
		if source and source:IsA("Model") then
			return source
		end
	end
	return nil
end

function MachineArt.Has(definitionId: string): boolean
	return findSource(definitionId) ~= nil
		or FarmMachineArt.Has(definitionId)
		or PowerArt.Has(definitionId)
end

-- Returns a painted, anchored, non-colliding copy whose pivot is the bottom center of the model,
-- already turned so its input side faces -X like the game's IN port. Callers only PivotTo it.
function MachineArt.Build(definitionId: string): Model?
	local source = findSource(definitionId)
	if source == nil then
		return FarmMachineArt.Build(definitionId) or PowerArt.Build(definitionId)
	end

	local art = source:Clone()
	art.Name = "Art"
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = -minimum
	for _, descendant in art:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			local extents = descendant.CFrame:VectorToWorldSpace(descendant.Size)
			local half = Vector3.new(math.abs(extents.X), math.abs(extents.Y), math.abs(extents.Z))
				/ 2
			minimum = minimum:Min(descendant.Position - half)
			maximum = maximum:Max(descendant.Position + half)
		end
	end
	if minimum.X == math.huge then
		art:Destroy()
		return nil
	end
	MachineArtPalette.Apply(art)

	-- Studio imports the Blender FBX facing backwards, so the pivot carries a 180 degree turn
	-- that puts the art's input side on the IN port (-X) and its output side on OUT (+X).
	local bottomCenter =
		Vector3.new((minimum.X + maximum.X) / 2, minimum.Y, (minimum.Z + maximum.Z) / 2)
	art.WorldPivot = CFrame.new(bottomCenter) * CFrame.Angles(0, math.pi, 0)
	return art
end

-- A simple stand-in for machines that have no imported model yet, built from the definition.
function MachineArt.BuildPlaceholder(definition: any): Model
	local model = Instance.new("Model")
	model.Name = "Art"
	local size = Vector3.new(definition.Size.X, definition.Size.Y, definition.Size.Z)
	local color = Color3.fromRGB(table.unpack(definition.Color or { 120, 130, 130 }))

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(size.X, 0.6, size.Z)
	base.CFrame = CFrame.new(0, 0.3, 0)
	base.Color = Color3.fromRGB(178, 176, 163)
	base.Material = Enum.Material.Concrete
	base.Parent = model

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(size.X * 0.7, size.Y * 0.75, size.Z * 0.7)
	body.CFrame = CFrame.new(0, 0.6 + body.Size.Y / 2, 0)
	body.Color = color
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = model

	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Size = Vector3.new(size.X * 0.8, 0.6, size.Z * 0.8)
	roof.CFrame = CFrame.new(0, 0.9 + body.Size.Y, 0)
	roof.Color = color:Lerp(Color3.new(0, 0, 0), 0.3)
	roof.Material = Enum.Material.SmoothPlastic
	roof.Parent = model

	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	model.WorldPivot = CFrame.new()
	return model
end

return MachineArt
