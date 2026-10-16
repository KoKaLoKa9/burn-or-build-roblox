--!strict

-- Placement rules shared by the client ghost preview and server validation (spec 3.1 and 3.5).
-- Machines rotate in 90 degree steps, so every footprint is an axis-aligned rectangle.

local PlacementRules = {
	GridSize = 4,
	-- Keeps a small walkway between a machine and the edge of the plot.
	EdgeMargin = 1,
}

export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }

-- A paddy a farm machine may stand beside. `rect` is the field itself, `fixtures` are the sign,
-- board, and burn spot in front of it, and `usable` says whether this player may farm it.
export type PaddySite = {
	rect: Rect,
	fixtures: { Rect },
	usable: boolean,
	groundY: number,
}

-- Extra checks for staged unlocks (spec 12.2), road access (spec 7.4), and farm machines.
export type Context = {
	unlocked: boolean?,
	roads: { Rect }?,
	roadReach: number?,
	paddies: { PaddySite }?,
}

function PlacementRules.Footprint(definition: any, rotationSteps: number): (number, number)
	local size = definition.Size
	if rotationSteps % 2 == 1 then
		return size.Z, size.X
	end
	return size.X, size.Z
end

function PlacementRules.Snap(position: Vector3): Vector3
	local grid = PlacementRules.GridSize
	return Vector3.new(
		math.round(position.X / grid) * grid,
		position.Y,
		math.round(position.Z / grid) * grid
	)
end

-- Body CFrame for a machine whose base sits on the floor at `position`.
function PlacementRules.BodyCFrame(
	definition: any,
	position: Vector3,
	rotationSteps: number,
	floorTopY: number
): CFrame
	local height = definition.Size.Y
	return CFrame.new(position.X, floorTopY + height / 2, position.Z)
		* CFrame.Angles(0, math.rad(90 * rotationSteps), 0)
end

function PlacementRules.RectAt(definition: any, position: Vector3, rotationSteps: number): Rect
	local width, depth = PlacementRules.Footprint(definition, rotationSteps)
	return {
		minX = position.X - width / 2,
		maxX = position.X + width / 2,
		minZ = position.Z - depth / 2,
		maxZ = position.Z + depth / 2,
	}
end

function PlacementRules.RectFromPart(part: BasePart): Rect
	local extents = part.CFrame:VectorToWorldSpace(part.Size)
	local halfX, halfZ = math.abs(extents.X) / 2, math.abs(extents.Z) / 2
	return {
		minX = part.Position.X - halfX,
		maxX = part.Position.X + halfX,
		minZ = part.Position.Z - halfZ,
		maxZ = part.Position.Z + halfZ,
	}
end

local function overlaps(a: Rect, b: Rect): boolean
	return a.minX < b.maxX and a.maxX > b.minX and a.minZ < b.maxZ and a.maxZ > b.minZ
end

local function gapBetween(a: Rect, b: Rect): number
	local dx = math.max(0, a.minX - b.maxX, b.minX - a.maxX)
	local dz = math.max(0, a.minZ - b.maxZ, b.minZ - a.maxZ)
	return math.sqrt(dx * dx + dz * dz)
end

-- Farm machines stand beside a paddy, never on it. Returns the index of the closest paddy within
-- `reach` of the footprint, or nil and the player-facing reason.
function PlacementRules.PaddyFor(
	rect: Rect,
	paddies: { PaddySite },
	reach: number
): (number?, string)
	local best: number? = nil
	local bestGap = math.huge
	for index, site in paddies do
		if overlaps(rect, site.rect) then
			return nil, "Farm machines stand beside the paddy, not on it."
		end
		for _, fixture in site.fixtures do
			if overlaps(rect, fixture) then
				return nil, "Another object blocks this space."
			end
		end
		local gap = gapBetween(rect, site.rect)
		if gap <= reach and gap < bestGap then
			best, bestGap = index, gap
		end
	end
	if best == nil then
		return nil, string.format("Place this beside a paddy, within %d studs of its edge.", reach)
	end
	if not paddies[best].usable then
		return nil, "This paddy belongs to another player."
	end
	return best, "Valid placement"
end

-- Returns whether the placement is valid and, if not, the player-facing reason from spec 3.5.
function PlacementRules.Validate(
	definition: any,
	position: Vector3,
	rotationSteps: number,
	plot: Rect,
	blockers: { Rect },
	credits: number,
	context: Context?
): (boolean, string)
	if definition.UnlockAfterFirstSale and not (context and context.unlocked) then
		return false, "Sell your first pellet crate to unlock this."
	end
	local rect = PlacementRules.RectAt(definition, position, rotationSteps)
	local margin = PlacementRules.EdgeMargin
	if definition.PlaceNear == "Paddy" then
		local paddies: { PaddySite } = if context and context.paddies then context.paddies else {}
		local site, reason = PlacementRules.PaddyFor(rect, paddies, definition.PaddyReach or 12)
		if site == nil then
			return false, reason
		end
	elseif
		rect.minX < plot.minX + margin
		or rect.maxX > plot.maxX - margin
		or rect.minZ < plot.minZ + margin
		or rect.maxZ > plot.maxZ - margin
	then
		return false, "This object must stay inside your farm or factory plot."
	end
	for _, blocker in blockers do
		if overlaps(rect, blocker) then
			return false, "Another object blocks this space."
		end
	end
	if definition.RequiresRoad then
		local reach = if context and context.roadReach then context.roadReach else 20
		local nearRoad = false
		local roads: { Rect } = if context and context.roads then context.roads else {}
		for _, road in roads do
			if gapBetween(rect, road) <= reach then
				nearRoad = true
				break
			end
		end
		if not nearRoad then
			return false, string.format("Place this within %d studs of a road.", reach)
		end
	end
	if credits < definition.Cost then
		return false, "You need more credits to place this object."
	end
	return true, "Valid placement"
end

return PlacementRules
