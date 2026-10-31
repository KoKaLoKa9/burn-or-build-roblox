--!strict

-- Textured belt and pipe pieces (art/prompts/Conveyor_v2.md). Studio imports the kit as
-- ReplicatedStorage.ConveyorKit: one model per piece (CV_Straight, PP_Elbow, ...), all sharing one
-- origin, which the KitOrigin marker shows. In the kit's frame a piece flows toward +X, -Z is its
-- left, and its origin is the cell centre on the floor (port pieces: the line end on the floor).
-- Everything here is optional: without the kit the tiles keep their part-built look.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConveyorKit = {}

-- Pivots already set to the kit origin, keyed by piece name.
local templates: { [string]: Model } = {}
-- Piece names already looked for and not found.
local missing: { [string]: boolean } = {}

local function library(): Instance?
	return ReplicatedStorage:FindFirstChild("ConveyorKit")
end

local function template(name: string): Model?
	if templates[name] or missing[name] then
		return templates[name]
	end
	local kit = library()
	local source = kit and kit:FindFirstChild(name, true)
	local origin = kit and kit:FindFirstChild("KitOrigin", true)
	if source == nil or not source:IsA("Model") or origin == nil or not origin:IsA("BasePart") then
		missing[name] = true
		return nil
	end
	local art = source:Clone()
	art.Name = name
	for _, descendant in art:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	-- Studio's import turns the kit half around; the pivot turns it back (as in FieldArt).
	art.WorldPivot = CFrame.new(origin.Position) * CFrame.Angles(0, math.pi, 0)
	templates[name] = art
	return art
end

function ConveyorKit.Has(name: string): boolean
	return template(name) ~= nil
end

-- A copy of the piece with its origin at `cframe`, or nil without the kit.
function ConveyorKit.Place(name: string, cframe: CFrame): Model?
	local art = template(name)
	if art == nil then
		return nil
	end
	local copy = art:Clone()
	copy:PivotTo(cframe)
	return copy
end

-- Stretches a placed piece along its own X axis by `scale`, about its pivot. The pieces are built
-- square to their frame, so every part has one axis along X.
function ConveyorKit.StretchX(model: Model, scale: number)
	local pivot = model:GetPivot()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local relative = pivot:ToObjectSpace(descendant.CFrame)
			local axes = { relative.RightVector, relative.UpVector, -relative.LookVector }
			local size = descendant.Size
			local components = { size.X, size.Y, size.Z }
			for index, axis in axes do
				if math.abs(axis.X) > 0.9 then
					components[index] *= scale
				end
			end
			descendant.Size = Vector3.new(components[1], components[2], components[3])
			local p = relative.Position
			descendant.CFrame = pivot
				* CFrame.new(p.X * scale, p.Y, p.Z)
				* (relative - relative.Position)
		end
	end
end

-- Colours the tintable pipe bodies (meshes named *_Tint) for one medium.
function ConveyorKit.Tint(model: Model, color: Color3)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and string.find(descendant.Name, "_Tint") then
			local surface = descendant:FindFirstChildWhichIsA("SurfaceAppearance")
			if surface then
				surface.Color = color
			else
				descendant.Color = color
			end
		end
	end
end

-- Kit pieces open on these local sides (0 +X, 1 -Z, 2 -X, 3 +Z, as in ConveyorTile).
local BELTS: { [string]: string } = {
	-- Keyed by the inputs: back (-X), left (-Z), right (+Z).
	["100"] = "CV_Straight",
	["010"] = "CV_TurnLeft",
	["001"] = "CV_TurnRight",
	["110"] = "CV_MergeLeft",
	["101"] = "CV_MergeRight",
	["011"] = "CV_MergeSides",
	["111"] = "CV_MergeAll",
	["000"] = "CV_Start",
}

-- The belt piece for a tile running toward world side `dir` with these world sides open, and the
-- turn (in quarter turns) that puts it there.
function ConveyorKit.BeltPiece(dir: number, openSides: { [number]: boolean }): (string, number)
	local function open(localSide: number): string
		return if openSides[(localSide + dir) % 4] then "1" else "0"
	end
	return BELTS[open(2) .. open(1) .. open(3)], dir
end

-- Local open sides of each pipe piece.
local PIPES: { { name: string, sides: { number } } } = {
	{ name = "PP_Cross", sides = { 0, 1, 2, 3 } },
	{ name = "PP_Tee", sides = { 0, 1, 2 } },
	{ name = "PP_Straight", sides = { 0, 2 } },
	{ name = "PP_Elbow", sides = { 0, 1 } },
	{ name = "PP_End", sides = { 0 } },
}

-- The pipe piece whose open ends match these world sides, and its turn. Tries the flow direction
-- first so straight runs keep their flanges the same way round.
function ConveyorKit.PipePiece(dir: number, openSides: { [number]: boolean }): (string, number)
	local count = 0
	for side = 0, 3 do
		if openSides[side] then
			count += 1
		end
	end
	if count == 0 then
		return "PP_Straight", dir
	end
	for _, piece in PIPES do
		if #piece.sides == count then
			for step = 0, 3 do
				local turn = (dir + step) % 4
				local fits = true
				for _, localSide in piece.sides do
					if not openSides[(localSide + turn) % 4] then
						fits = false
						break
					end
				end
				if fits then
					return piece.name, turn
				end
			end
		end
	end
	return "PP_Straight", dir
end

-- The straight bridge closest to `length` studs (1, 2 or 3 long), for stretching to fit.
function ConveyorKit.BridgeFor(prefix: string, length: number): (string, number)
	local size = math.clamp(math.floor(length + 0.5), 1, 3)
	return string.format("%s_Bridge%d", prefix, size), length / size
end

return ConveyorKit
