--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SmokeService = {}

-- Spec 10.3: one burn creates one source record with field, quantity, time, wind,
-- destination, exposure, and responsibility.
export type SourceInfo = {
	field: string,
	quantity: number,
	responsibility: string,
}

export type SourceRecord = {
	field: string,
	quantity: number,
	time: number,
	wind: string,
	destination: string,
	exposure: number,
	-- Points this burn released wherever the wind carried them. Exposure is the part that
	-- reached the village; the season results show both (spec 11.3: pollution still exists).
	potential: number,
	responsibility: string,
}

local sourceRecords: { SourceRecord } = {}

-- Records are mirrored into ReplicatedStorage so the HUD and later result screen can read them.
local function publishRecord(record: SourceRecord)
	local folder = ReplicatedStorage:FindFirstChild("BurnRecords")
	if folder == nil then
		local newFolder = Instance.new("Folder")
		newFolder.Name = "BurnRecords"
		newFolder.Parent = ReplicatedStorage
		folder = newFolder
	end
	local entry = Instance.new("Configuration")
	entry.Name = string.format("Burn_%02d", #sourceRecords)
	entry:SetAttribute("Field", record.field)
	entry:SetAttribute("Quantity", record.quantity)
	entry:SetAttribute("Time", record.time)
	entry:SetAttribute("Wind", record.wind)
	entry:SetAttribute("Destination", record.destination)
	entry:SetAttribute("Exposure", record.exposure)
	entry:SetAttribute("Potential", record.potential)
	entry:SetAttribute("Responsibility", record.responsibility)
	entry.Parent = folder
end

function SmokeService:GetRecords(): { SourceRecord }
	return table.clone(sourceRecords)
end

local function createPlumeSegment(position: Vector3, parent: Instance, index: number): Part
	local segment = Instance.new("Part")
	segment.Name = string.format("Plume_%02d", index)
	segment.Shape = Enum.PartType.Ball
	segment.Size = Vector3.new(16, 10, 16)
	segment.Position = position
	segment.Anchored = true
	segment.CanCollide = false
	segment.CanQuery = false
	segment.CanTouch = false
	segment.Material = Enum.Material.SmoothPlastic
	segment.Color = Color3.fromRGB(85, 91, 88)
	segment.Transparency = 0.35
	segment.Parent = parent
	return segment
end

local function isPopulationDownwind(
	origin: Vector3,
	exposureZone: BasePart,
	windDirection: Vector3,
	maximumDistance: number
): boolean
	local offset = exposureZone.Position - origin
	if offset.Magnitude < 1 or offset.Magnitude > maximumDistance then
		return false
	end
	return windDirection.Unit:Dot(offset.Unit) >= 0.55
end

function SmokeService:BurnField(
	world: Model,
	originPart: BasePart,
	exposurePoints: number,
	playerStateService: any,
	gameConfig: any,
	source: SourceInfo
): SourceRecord
	local activeSmoke = world:FindFirstChild("ActiveSmoke")
	if activeSmoke == nil then
		local folder = Instance.new("Folder")
		folder.Name = "ActiveSmoke"
		folder.Parent = world
		activeSmoke = folder
	end

	local windDirection: Vector3 = gameConfig.Wind.Direction.Unit
	local plumeDistance: number = gameConfig.Wind.PlumeDistance
	local travelSeconds: number = gameConfig.Wind.PlumeTravelSeconds
	local origin = originPart.Position + Vector3.new(0, 8, 0)
	local segmentCount = 7

	for index = 1, segmentCount do
		local delaySeconds = (index - 1) * 0.35
		task.delay(delaySeconds, function()
			local segment = createPlumeSegment(origin, activeSmoke :: Instance, index)
			local lateral = Vector3.new(0, math.sin(index) * 6, math.cos(index * 1.7) * 8)
			local target = origin + windDirection * plumeDistance + lateral
			local tween = TweenService:Create(
				segment,
				TweenInfo.new(travelSeconds, Enum.EasingStyle.Linear),
				{ Position = target, Transparency = 0.75, Size = Vector3.new(26, 16, 26) }
			)
			tween:Play()
			tween.Completed:Once(function()
				segment:Destroy()
			end)
		end)
	end

	local exposureZone = world:FindFirstChild("ExposureZone", true)
	local exposed = false
	if exposureZone and exposureZone:IsA("BasePart") then
		if
			isPopulationDownwind(
				originPart.Position,
				exposureZone,
				windDirection,
				plumeDistance * 1.25
			)
		then
			exposed = true
			task.delay(travelSeconds * 0.6, function()
				for _, player in Players:GetPlayers() do
					playerStateService:AddExposure(player, exposurePoints)
				end
				exposureZone:SetAttribute("LastExposure", exposurePoints)
			end)
		end
	end

	-- Spec 15.2: the wind at the moment of ignition is stored with the event.
	local record: SourceRecord = {
		field = source.field,
		quantity = source.quantity,
		time = workspace:GetServerTimeNow(),
		wind = gameConfig.Wind.Label,
		destination = if exposed then "Village" else "Open land",
		exposure = if exposed then exposurePoints else 0,
		potential = exposurePoints,
		responsibility = source.responsibility,
	}
	table.insert(sourceRecords, record)
	publishRecord(record)
	return record
end

return SmokeService
