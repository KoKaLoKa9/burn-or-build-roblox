--!strict

-- Truck route terminals (spec v0.2 section 7.4, P0 simplified route).
-- Trip logic lives in Simulation/TruckRoute. This service draws the truck on the road, takes
-- straw through CommitmentService, unloads into the factory intake, and charges route fees.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CommitmentDefinitions = require(Shared:WaitForChild("CommitmentDefinitions"))

local Simulation = script.Parent.Parent:WaitForChild("Simulation")
local TruckRoute = require(Simulation:WaitForChild("TruckRoute"))

local TruckService = {}

local TICK_SECONDS = 0.2
local TRUCK_HEIGHT = 3

type Truck = {
	route: any,
	record: any,
	owner: Player?,
	body: BasePart,
	label: TextLabel,
	lastState: string,
}

local trucks: { [number]: Truck } = {}
local world: Model
local playerState: any
local machineService: any
local commitmentService: any
local truckFolder: Folder

local function formatClock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function readable(state: string): string
	return (string.gsub(state, "(%l)(%u)", "%1 %2"))
end

local function findPart(name: string): BasePart?
	local found = world:FindFirstChild(name, true)
	return if found and found:IsA("BasePart") then found else nil
end

-- Road path from the terminal to the fixed farm stop. Farm stops never move (spec 7.4), so
-- distance and deadlines stay predictable. Pathfinding is out of scope for the demo.
local function buildPath(terminalBody: BasePart, farmId: string): { Vector3 }
	local start = terminalBody.Position
	local y = TRUCK_HEIGHT
	local path = { Vector3.new(start.X, y, start.Z) }
	local factoryRoad = findPart("FactoryRoad")
	local mainRoad = findPart("MainRoad")
	local definition = CommitmentDefinitions.Farms[farmId]
	local farm = world:FindFirstChild(definition.ModelName, true)
	local stop = if farm then farm:FindFirstChild("CollectionPoint") else nil
	local stopPosition = if stop and stop:IsA("BasePart") then stop.Position else start
	if factoryRoad and mainRoad then
		table.insert(path, Vector3.new(factoryRoad.Position.X, y, start.Z))
		table.insert(path, Vector3.new(factoryRoad.Position.X, y, mainRoad.Position.Z))
		table.insert(path, Vector3.new(stopPosition.X, y, mainRoad.Position.Z))
	end
	table.insert(path, Vector3.new(stopPosition.X, y, stopPosition.Z + 8))
	return path
end

local function pointAlong(path: { Vector3 }, alpha: number): (Vector3, Vector3)
	local total = 0
	for index = 2, #path do
		total += (path[index] - path[index - 1]).Magnitude
	end
	local target = math.clamp(alpha, 0, 1) * total
	for index = 2, #path do
		local a, b = path[index - 1], path[index]
		local length = (b - a).Magnitude
		if target <= length or index == #path then
			local t = if length > 0 then math.clamp(target / length, 0, 1) else 1
			return a:Lerp(b, t), if length > 0 then (b - a).Unit else Vector3.zAxis
		end
		target -= length
	end
	return path[1], Vector3.zAxis
end

local function describe(truck: Truck): string
	local route = truck.route
	local farm = if route.farmId then CommitmentDefinitions.Farms[route.farmId] else nil
	return string.format(
		"Truck route terminal: %s\n%s\nRoute: %s | Cargo %d/%d%s",
		string.upper(readable(route.state)),
		route.reason,
		if farm
			then string.format("%s, %d credits per trip", farm.ShortName, farm.RouteFee)
			else "none",
		route.cargo,
		CommitmentDefinitions.Truck.Capacity,
		if route.state ~= "Idle" then " | ETA " .. formatClock(route:EtaSeconds()) else ""
	)
end

local function refreshTruck(truck: Truck)
	local route = truck.route
	local farmId = route.farmId
	local terminalBody = truck.record.model.PrimaryPart
	if farmId == nil or terminalBody == nil then
		return
	end
	local position, direction = pointAlong(buildPath(terminalBody, farmId), route.position)
	local facing = if route.state == "Returning" then -direction else direction
	truck.body.CFrame = CFrame.lookAt(position, position + Vector3.new(facing.X, 0, facing.Z))
	local farm = CommitmentDefinitions.Farms[farmId]
	truck.label.Text = string.format(
		"%s\n%s | %d/%d bundles%s",
		string.upper(readable(route.state)),
		farm.ShortName,
		route.cargo,
		CommitmentDefinitions.Truck.Capacity,
		if route.state ~= "Idle" then " | " .. formatClock(route:EtaSeconds()) else ""
	)
end

local function createTruckBody(): (BasePart, TextLabel)
	local body = Instance.new("Part")
	body.Name = "Truck"
	body.Size = Vector3.new(7, 5, 12)
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.Material = Enum.Material.SmoothPlastic
	body.Color = Color3.fromRGB(214, 120, 52)
	body.Parent = truckFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Status"
	billboard.Size = UDim2.fromOffset(200, 54)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 260
	billboard.Parent = body

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 29, 25)
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(247, 241, 220)
	label.TextScaled = true
	label.Parent = billboard
	return body, label
end

local function createPrompt(
	parent: BasePart,
	name: string,
	actionText: string,
	key: Enum.KeyCode,
	holdDuration: number
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = "Truck route terminal"
	prompt.KeyboardKeyCode = key
	prompt.HoldDuration = holdDuration
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function ownsTruck(player: Player, truck: Truck): boolean
	if truck.owner ~= player then
		machineService:Notify(player, "You can only operate your own truck terminal.")
		return false
	end
	return true
end

local function switchFarm(player: Player, truck: Truck)
	if not ownsTruck(player, truck) then
		return
	end
	local order = CommitmentDefinitions.FarmOrder
	local index = table.find(order, truck.route.farmId) or 0
	local nextFarm = order[index % #order + 1]
	local _, message = truck.route:Assign(nextFarm)
	machineService:Notify(player, message)
end

local function dispatch(player: Player, truck: Truck)
	if not ownsTruck(player, truck) then
		return
	end
	local farmId = truck.route.farmId
	if farmId then
		local canCollect, reason = commitmentService:CanCollect(farmId)
		if not canCollect then
			machineService:Notify(player, "Route blocked: " .. reason)
			return
		end
		local fee = CommitmentDefinitions.Farms[farmId].RouteFee
		if playerState:GetCredits(player) < fee then
			machineService:Notify(
				player,
				string.format("This route costs %d credits per trip.", fee)
			)
			return
		end
	end
	local _, message = truck.route:Dispatch()
	machineService:Notify(player, message)
end

local function handleEvents(truck: Truck, events: { any })
	local owner = truck.owner
	for _, event in events do
		local farm = CommitmentDefinitions.Farms[event.farmId]
		if event.type == "Loaded" then
			machineService:Notify(
				owner,
				string.format("Truck loaded %d bundles at %s.", event.cargo, farm.ShortName)
			)
		elseif event.type == "TripCompleted" then
			if owner and owner.Parent then
				playerState:AdjustCredits(owner, -event.fee)
			end
			machineService:Notify(
				owner,
				string.format(
					"Trip complete: %d bundles from %s delivered. Route fee -%d credits.",
					event.cargo,
					farm.ShortName,
					event.fee
				)
			)
		end
	end
	local state = truck.route.state
	if state ~= truck.lastState then
		if state == "DestinationFull" then
			machineService:Notify(owner, "Truck waiting: the factory collection point is full.")
		elseif state == "RouteBlocked" then
			machineService:Notify(owner, "Route blocked: no straw ready at the farm stop.")
		end
		truck.lastState = state
	end
end

local function onPlaced(record: any)
	local body = record.model.PrimaryPart
	local truckBody, label = createTruckBody()
	local owner = record.owner
	local truck: Truck = {
		route = TruckRoute.new(CommitmentDefinitions.Truck, CommitmentDefinitions.Farms),
		record = record,
		owner = owner,
		body = truckBody,
		label = label,
		lastState = "Idle",
	}
	truck.route:Assign(CommitmentDefinitions.FarmOrder[1])
	trucks[record.node.id] = truck

	createPrompt(body, "RoutePrompt", "Switch farm stop", Enum.KeyCode.E, 0).Triggered:Connect(
		function(player)
			switchFarm(player, truck)
		end
	)
	createPrompt(body, "DispatchPrompt", "Dispatch truck", Enum.KeyCode.F, 0.5).Triggered:Connect(
		function(player)
			dispatch(player, truck)
		end
	)
	createPrompt(body, "CancelPrompt", "Cancel trip", Enum.KeyCode.V, 0.5).Triggered:Connect(
		function(player)
			if ownsTruck(player, truck) then
				local _, message = truck.route:Cancel()
				machineService:Notify(player, message)
			end
		end
	)
	refreshTruck(truck)
end

function TruckService:Initialize(
	worldModel: Model,
	playerStateService: any,
	machines: any,
	commitments: any
)
	world = worldModel
	playerState = playerStateService
	machineService = machines
	commitmentService = commitments

	local existing = world:FindFirstChild("Trucks")
	if existing then
		existing:Destroy()
	end
	truckFolder = Instance.new("Folder")
	truckFolder.Name = "Trucks"
	truckFolder.Parent = world

	machineService:RegisterKindHandler("Terminal", {
		onPlaced = onPlaced,
		canDismantle = function(record: any): (boolean, string)
			local truck = trucks[record.node.id]
			if truck and truck.route.state ~= "Idle" then
				return false, "Wait for the truck to finish its trip before dismantling."
			end
			return true, ""
		end,
		onRemoved = function(record: any)
			local truck = trucks[record.node.id]
			if truck then
				truck.body:Destroy()
				trucks[record.node.id] = nil
			end
		end,
		describe = function(record: any): string
			local truck = trucks[record.node.id]
			return if truck then describe(truck) else record.node.definition.DisplayName
		end,
	})

	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < TICK_SECONDS then
			return
		end
		local step = accumulated
		accumulated = 0
		for _, truck in trucks do
			local events = truck.route:Step(step, {
				take = function(farmId: string, max: number): number
					return commitmentService:TakeStraw(farmId, max)
				end,
				unload = function(count: number): number
					return machineService:DepositToIntake(count, truck.owner)
				end,
			})
			handleEvents(truck, events)
			refreshTruck(truck)
		end
	end)
end

return TruckService
