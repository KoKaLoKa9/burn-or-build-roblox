--!strict

-- Moving parts on textured machine models. A placed machine's model carries the attribute
-- Working (set by MachineService); while it is true, the parts of each group in SPINNERS turn
-- together about one axis. Purely visual and local, so it costs the server nothing.

local RunService = game:GetService("RunService")

type Spinner = { axis: Vector3, speed: number }

-- Part name prefix -> axis in the game frame (+X east towards OUT) and speed in radians per second. Studio's
-- glTF import splits a group into one part per material (DY_Drum, DY_Drum2, ...), so every part
-- whose name starts with the prefix turns, about the centre of the group's largest part, which
-- the models put on the axis.
local TILT = math.rad(3)
local SPINNERS: { [string]: Spinner } = {
	-- The dryer drum leans 3 degrees down from the feed end (-X) to the discharge end (+X).
	DY_Drum = { axis = Vector3.new(math.cos(TILT), -math.sin(TILT), 0), speed = 0.9 },
	-- The shredder's flywheel pulley turns on a shaft along Z.
	SH_Flywheel = { axis = Vector3.new(0, 0, 1), speed = 6 },
}

type Group = {
	machine: Model,
	parts: { [BasePart]: CFrame },
	centre: Vector3,
	largest: number,
	axis: Vector3,
	speed: number,
	angle: number,
}

-- Keyed by machine model, then by spinner prefix.
local groups: { [Model]: { [string]: Group } } = {}

local function machineOf(part: Instance): Model?
	local ancestor = part.Parent
	while ancestor and ancestor ~= workspace do
		if ancestor:IsA("Model") and ancestor:GetAttribute("MachineId") ~= nil then
			return ancestor
		end
		ancestor = ancestor.Parent
	end
	return nil
end

local function spinnerFor(name: string): (string?, Spinner?)
	for prefix, spinner in SPINNERS do
		if string.sub(name, 1, #prefix) == prefix then
			return prefix, spinner
		end
	end
	return nil, nil
end

local function track(instance: Instance)
	if not instance:IsA("BasePart") or instance.Parent == nil then
		return
	end
	local prefix, spinner = spinnerFor(instance.Name)
	if prefix == nil or spinner == nil then
		return
	end
	-- Placement ghosts and menu previews have no machine around them and stay still.
	local machine = machineOf(instance)
	if machine == nil then
		return
	end
	local byPrefix = groups[machine]
	if byPrefix == nil then
		byPrefix = {}
		groups[machine] = byPrefix
	end
	local group = byPrefix[prefix]
	if group == nil then
		-- The axis is in the game frame (+X towards OUT), which the art's pivot carries.
		local art = machine:FindFirstChild("Art")
		local frame = if art and art:IsA("Model") then art:GetPivot() else machine:GetPivot()
		group = {
			machine = machine,
			parts = {},
			centre = instance.Position,
			largest = 0,
			axis = frame:VectorToWorldSpace(spinner.axis).Unit,
			speed = spinner.speed,
			angle = 0,
		}
		byPrefix[prefix] = group
	end
	-- Remember the resting place, undoing any turn already applied to the group.
	local rest = CFrame.new(group.centre)
		* CFrame.fromAxisAngle(group.axis, -group.angle)
		* CFrame.new(-group.centre)
		* instance.CFrame
	group.parts[instance] = rest
	local volume = instance.Size.X * instance.Size.Y * instance.Size.Z
	if volume > group.largest then
		group.largest = volume
		group.centre = rest.Position
	end
end

workspace.DescendantAdded:Connect(function(instance)
	-- Let the server finish pivoting the art into place before remembering where it sits.
	task.defer(track, instance)
end)
for _, instance in workspace:GetDescendants() do
	track(instance)
end

RunService.RenderStepped:Connect(function(dt)
	for machine, byPrefix in groups do
		if machine.Parent == nil then
			groups[machine] = nil
			continue
		end
		if machine:GetAttribute("Working") ~= true then
			continue
		end
		for _, group in byPrefix do
			group.angle = (group.angle + group.speed * dt) % (2 * math.pi)
			local turn = CFrame.new(group.centre)
				* CFrame.fromAxisAngle(group.axis, group.angle)
				* CFrame.new(-group.centre)
			for part, rest in group.parts do
				part.CFrame = turn * rest
			end
		end
	end
end)
