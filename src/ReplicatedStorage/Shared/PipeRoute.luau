--!strict

-- Right-angle pipe routes between two ports, like real plant piping: a short straight stub out of
-- the output, one or two flat legs at port height, and a stub into the input.

local PipeRoute = {}

local STUB = 2.5

local function flat(vector: Vector3): Vector3
	local horizontal = Vector3.new(vector.X, 0, vector.Z)
	return if horizontal.Magnitude > 1e-3 then horizontal.Unit else Vector3.zero
end

local function unitOrZero(vector: Vector3): Vector3
	return if vector.Magnitude > 1e-3 then vector.Unit else Vector3.zero
end

-- `outDirection` points away from the sending machine; `inDirection` points away from the
-- receiving machine (out of its input port).
function PipeRoute.Points(
	outPosition: Vector3,
	outDirection: Vector3,
	inPosition: Vector3,
	inDirection: Vector3
): { Vector3 }
	local height = outPosition.Y
	local outStub = outPosition + flat(outDirection) * STUB
	local inStub = inPosition + flat(inDirection) * STUB
	local inStubFlat = Vector3.new(inStub.X, height, inStub.Z)

	-- Pick the elbow that keeps the pipe flowing forward out of the output and into the input.
	local cornerA = Vector3.new(inStubFlat.X, height, outStub.Z)
	local cornerB = Vector3.new(outStub.X, height, inStubFlat.Z)
	local function score(corner: Vector3): number
		return unitOrZero(corner - outStub):Dot(flat(outDirection))
			+ unitOrZero(inStubFlat - corner):Dot(-flat(inDirection))
	end
	local corner = if score(cornerA) >= score(cornerB) then cornerA else cornerB

	local raw = { outPosition, outStub, corner, inStubFlat, inStub, inPosition }
	local points: { Vector3 } = {}
	for _, point in raw do
		if #points == 0 or (point - points[#points]).Magnitude > 0.05 then
			table.insert(points, point)
		end
	end

	-- Drop middle points that sit on a straight line.
	local index = 2
	while index < #points do
		local before = unitOrZero(points[index] - points[index - 1])
		local after = unitOrZero(points[index + 1] - points[index])
		if before:Dot(after) > 0.999 then
			table.remove(points, index)
		else
			index += 1
		end
	end
	return points
end

function PipeRoute.Length(points: { Vector3 }): number
	local total = 0
	for index = 2, #points do
		total += (points[index] - points[index - 1]).Magnitude
	end
	return total
end

-- Position at `distance` studs along the route.
function PipeRoute.Sample(points: { Vector3 }, distance: number): Vector3
	local remaining = math.max(0, distance)
	for index = 2, #points do
		local segment = points[index] - points[index - 1]
		local length = segment.Magnitude
		if remaining <= length or index == #points then
			return points[index - 1]
				+ segment * math.clamp(remaining / math.max(length, 1e-3), 0, 1)
		end
		remaining -= length
	end
	return points[#points]
end

-- One cylinder per leg plus a ball at every bend. Returns the parts so callers can style them.
function PipeRoute.Build(
	points: { Vector3 },
	diameter: number,
	parent: Instance
): ({ BasePart }, { BasePart })
	local legs: { BasePart } = {}
	local joints: { BasePart } = {}
	for index = 2, #points do
		local from, to = points[index - 1], points[index]
		local length = (to - from).Magnitude
		local leg = Instance.new("Part")
		leg.Name = "PipeLeg"
		leg.Shape = Enum.PartType.Cylinder
		leg.Size = Vector3.new(length, diameter, diameter)
		-- Cylinders run along X; turn X onto the leg direction.
		leg.CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0)
		table.insert(legs, leg)
		if index < #points then
			local joint = Instance.new("Part")
			joint.Name = "PipeElbow"
			joint.Shape = Enum.PartType.Ball
			joint.Size = Vector3.one * diameter * 1.18
			joint.CFrame = CFrame.new(to)
			table.insert(joints, joint)
		end
	end
	for _, list in { legs, joints } do
		for _, part in list do
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.Parent = parent
		end
	end
	return legs, joints
end

return PipeRoute
