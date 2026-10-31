--!strict

-- Textured paddy field art (Pack 5): rice row segments for every stage, straw sheaves, bunds and
-- the small items that ride in the pipes. Studio imports the pack as ReplicatedStorage.FieldArt,
-- one model per asset named EV_<Asset>_<Variant>. Everything here is optional: without the pack
-- the callers keep their part-built look.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FieldArt = {}

-- Rice row segments are this long along Z and repeat end to end.
FieldArt.SegmentLength = 8

-- Templates already moved so their pivot is the bottom centre, keyed by asset name.
local templates: { [string]: Model } = {}
-- Asset names already looked for and not found.
local missing: { [string]: boolean } = {}
-- Mesh groups of the flora, house and school packs drawn as alpha cut-out cards.
local CUTOUT_GROUPS: { [string]: boolean } = {
	Blades = true,
	Branches = true,
	Bunch = true,
	Canopy = true,
	Cards = true,
	Culms = true,
	DeadFronds = true,
	DeadLeaves = true,
	Epiphytes = true,
	Flowers = true,
	Fringe = true,
	LeafBases = true,
	Leaves = true,
	Needles = true,
	RoofFringe = true,
	Stems = true,
	Trees = true,
}

local function template(name: string): Model?
	if templates[name] or missing[name] then
		return templates[name]
	end
	local library = ReplicatedStorage:FindFirstChild("FieldArt")
	local source = library and library:FindFirstChild(name, true)
	if source == nil or not source:IsA("Model") then
		missing[name] = true
		return nil
	end

	local art = source:Clone()
	art.Name = name
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = -minimum
	for _, descendant in art:GetDescendants() do
		if descendant:IsA("SurfaceAppearance") and descendant.Parent then
			-- Leaf and frond cards are cut out by their texture's alpha. Overlay (the import's
			-- default) would paint the cut-away parts in the part's white.
			local group = string.match(descendant.Parent.Name, "_(%a+)%d*$")
			if group and CUTOUT_GROUPS[group] then
				descendant.AlphaMode = Enum.AlphaMode.Transparency
			end
		end
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			local half = descendant.Size / 2
			minimum = minimum:Min(descendant.Position - half)
			maximum = maximum:Max(descendant.Position + half)
		end
	end
	if minimum.X == math.huge then
		art:Destroy()
		missing[name] = true
		return nil
	end
	-- Studio's import turns the pack half around; the pivot turns it back (as in MachineArt).
	art.WorldPivot = CFrame.new((minimum.X + maximum.X) / 2, minimum.Y, (minimum.Z + maximum.Z) / 2)
		* CFrame.Angles(0, math.pi, 0)
	templates[name] = art
	return art
end

function FieldArt.Has(name: string): boolean
	return template(name) ~= nil
end

-- A copy of the asset standing with its bottom centre at `ground`, or nil without the pack.
function FieldArt.Place(name: string, ground: CFrame): Model?
	local art = template(name)
	if art == nil then
		return nil
	end
	local copy = art:Clone()
	copy:PivotTo(ground)
	return copy
end

-- The variants of an asset that were imported, such as { "EV_RiceRipe_A", "EV_RiceRipe_B" }.
function FieldArt.Variants(asset: string): { string }
	local found = {}
	for _, letter in { "A", "B", "C" } do
		local name = string.format("EV_%s_%s", asset, letter)
		if template(name) then
			table.insert(found, name)
		end
	end
	return found
end

-- A copy of one of the asset's variants, chosen by `rng`, standing at `ground`, or nil without the
-- pack. The scenery and house builders use it before falling back to their part-built look.
function FieldArt.Pick(asset: string, ground: CFrame, rng: Random): Model?
	local variants = FieldArt.Variants(asset)
	if #variants == 0 then
		return nil
	end
	return FieldArt.Place(variants[rng:NextInteger(1, #variants)], ground)
end

-- Fills `length` studs along the local Z axis of `centre` with copies of the asset's segments,
-- alternating variants by `seed`. Segments overlap a little instead of leaving a gap. Returns nil
-- without the pack.
function FieldArt.Strip(asset: string, centre: CFrame, length: number, seed: number): Model?
	local variants = FieldArt.Variants(asset)
	if #variants == 0 then
		return nil
	end
	local strip = Instance.new("Model")
	strip.Name = asset
	local count = math.max(1, math.ceil(length / FieldArt.SegmentLength - 0.05))
	local spacing = length / count
	local random = Random.new(seed)
	for index = 1, count do
		local z = -length / 2 + spacing * (index - 0.5)
		-- Half the segments turn around, so even one variant repeats less.
		local flip = if random:NextNumber() < 0.5 then math.pi else 0
		local name = variants[random:NextInteger(1, #variants)]
		local segment =
			FieldArt.Place(name, centre * CFrame.new(0, 0, z) * CFrame.Angles(0, flip, 0))
		if segment then
			segment.Parent = strip
		end
	end
	return strip
end

-- Pipe items: the factory item id to its small model.
local ITEMS: { [string]: string } = {
	WetStraw = "EV_ItemWetStraw_A",
	DryStraw = "EV_ItemDryStraw_A",
	ShreddedStraw = "EV_ItemShreddedStraw_A",
	PelletCrate = "EV_ItemPelletCrate_A",
	Biochar = "EV_ItemBiochar_A",
	Mushrooms = "EV_ItemMushrooms_A",
}

function FieldArt.ItemName(itemId: string): string?
	local name = ITEMS[itemId]
	return if name and template(name) then name else nil
end

return FieldArt
