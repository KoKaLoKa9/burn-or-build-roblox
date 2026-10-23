--!strict

-- The one forecast weather event of the stress phase (spec v0.2 section 11.3).
-- SeasonClock decides when it is forecast, starts, and ends; this service applies it to the
-- world: rain slows dryers and shows rain over the district, a wind shift turns the wind that
-- SmokeService reads for new plumes. State is mirrored to world attributes for the HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SeasonDefinitions = require(Shared:WaitForChild("SeasonDefinitions"))

local Simulation = script.Parent.Parent:WaitForChild("Simulation")
local SeasonClock = require(Simulation:WaitForChild("SeasonClock"))

local WeatherService = {}

local RAIN_HEIGHT = 90

local world: Model
local gameConfig: any
local machineService: any
local seasonStart = 0
local plan: SeasonClock.WeatherPlan? = nil
local lastState = "Calm"
local baseWind: { label: string, x: number, z: number }
local rainCloud: Part? = nil

local function eventDefinition(kind: string): any
	return SeasonDefinitions.Weather[kind]
end

local function setRainVisible(visible: boolean)
	if visible and rainCloud == nil then
		local center, size = world:GetBoundingBox()
		local cloud = Instance.new("Part")
		cloud.Name = "RainCloud"
		cloud.Anchored = true
		cloud.CanCollide = false
		cloud.CanQuery = false
		cloud.CanTouch = false
		cloud.CastShadow = false
		cloud.Transparency = 1
		cloud.Size = Vector3.new(math.min(size.X, 600), 1, math.min(size.Z, 500))
		cloud.Position = Vector3.new(center.Position.X, RAIN_HEIGHT, center.Position.Z)

		local drops = Instance.new("ParticleEmitter")
		drops.Name = "Drops"
		drops.EmissionDirection = Enum.NormalId.Bottom
		drops.Orientation = Enum.ParticleOrientation.VelocityParallel
		drops.Rate = 900
		drops.Lifetime = NumberRange.new(1.4, 1.8)
		drops.Speed = NumberRange.new(60, 70)
		drops.SpreadAngle = Vector2.new(4, 4)
		drops.Size = NumberSequence.new(0.18)
		drops.Squash = NumberSequence.new(-2.5)
		drops.Color = ColorSequence.new(Color3.fromRGB(170, 196, 214))
		drops.Transparency = NumberSequence.new(0.35)
		drops.LightEmission = 0.1
		drops.Parent = cloud
		cloud.Parent = world
		rainCloud = cloud
	elseif not visible and rainCloud then
		rainCloud:Destroy()
		rainCloud = nil
	end
end

local function applyWind(label: string, x: number, z: number, destination: string)
	if gameConfig.Wind.Label == label then
		return
	end
	-- SmokeService reads this table at each ignition, so new plumes follow the new wind.
	gameConfig.Wind.Direction = Vector3.new(x, 0, z)
	gameConfig.Wind.Label = label
	world:SetAttribute("WindDirection", label)
	world:SetAttribute("WindDestination", destination)
end

function WeatherService:Initialize(worldModel: Model, config: any, machines: any, startTime: number)
	world = worldModel
	gameConfig = config
	machineService = machines
	seasonStart = startTime
	local direction: Vector3 = config.Wind.Direction
	baseWind = { label = config.Wind.Label, x = direction.X, z = direction.Z }
	world:SetAttribute("WindDirection", baseWind.label)
	world:SetAttribute("WindDestination", SeasonDefinitions.Weather.BaseWind.Destination)
	world:SetAttribute("WeatherState", "Calm")
	world:SetAttribute("WeatherActive", "")
end

-- Called once the forecast is due. The kind is fixed from then on.
function WeatherService:SetPlan(newPlan: SeasonClock.WeatherPlan)
	plan = newPlan
	local definition = eventDefinition(newPlan.kind)
	world:SetAttribute("WeatherEvent", newPlan.kind)
	world:SetAttribute("WeatherName", definition.Name)
	world:SetAttribute("WeatherStartsAt", seasonStart + newPlan.startsAt)
	world:SetAttribute("WeatherEndsAt", if newPlan.endsAt then seasonStart + newPlan.endsAt else 0)
end

-- A new year (endless mode): clear this year's event and go back to the usual wind.
function WeatherService:Reset(startTime: number)
	plan = nil
	seasonStart = startTime
	lastState = "Calm"
	machineService:SetCycleMultiplier("Dryer", 1)
	applyWind(
		baseWind.label,
		baseWind.x,
		baseWind.z,
		SeasonDefinitions.Weather.BaseWind.Destination
	)
	setRainVisible(false)
	world:SetAttribute("WeatherState", "Calm")
	world:SetAttribute("WeatherActive", "")
	world:SetAttribute("WeatherEvent", nil)
	world:SetAttribute("WeatherMessage", nil)
end

function WeatherService:GetPlan(): SeasonClock.WeatherPlan?
	return plan
end

function WeatherService:Update(elapsed: number)
	local current = plan
	if current == nil then
		return
	end
	local state = SeasonClock.weatherState(current, elapsed)
	local definition = eventDefinition(current.kind)

	machineService:SetCycleMultiplier(
		"Dryer",
		SeasonClock.dryerMultiplier(SeasonDefinitions, current, elapsed)
	)
	local label, x, z, destination =
		SeasonClock.windAt(SeasonDefinitions, current, elapsed, baseWind)
	applyWind(label, x, z, destination)
	setRainVisible(current.kind == "Rain" and state == "Active")

	if state == lastState then
		return
	end
	lastState = state
	world:SetAttribute("WeatherState", state)
	world:SetAttribute("WeatherActive", if state == "Active" then current.kind else "")
	local message = definition[state]
	if typeof(message) == "string" then
		world:SetAttribute("WeatherMessage", message)
		if state == "Forecast" then
			machineService:NotifyAll(
				string.format(
					"Forecast: %s in %s. %s",
					string.lower(definition.Name),
					SeasonClock.formatClock(current.startsAt - elapsed),
					message
				)
			)
		else
			machineService:NotifyAll(message)
		end
	end
end

return WeatherService
