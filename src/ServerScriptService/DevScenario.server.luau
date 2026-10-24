--!strict

-- Studio-only play test scenarios, picked in DevScenarioConfig (Scenario = "none" in commits).
-- Each one builds a small factory through the same paths players use, runs it, and prints
-- what happened to the Output window, so a test needs no command bar typing.
--   "steam": solar, water pump, boiler, steam turbine, poles, water and steam pipes.
--   "save":  "steam", then a save round trip through JSON (snapshot, wipe, rebuild) and a new year.
--   "biogas": diesel start-up, pumps, cattle shed, digester, biogas engine and a market stall.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

if not RunService:IsStudio() then
	return
end
local config = require(script.Parent:WaitForChild("DevScenarioConfig")) :: any
local scenario = config.Scenario
if scenario == "none" then
	return
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConveyorGrid = require(Shared:WaitForChild("ConveyorGrid"))
local Services = ServerScriptService:WaitForChild("Server"):WaitForChild("Services")
local MachineService = require(Services:WaitForChild("MachineService")) :: any
local SaveService = require(Services:WaitForChild("SaveService")) :: any
local PowerService = require(Services:WaitForChild("PowerService")) :: any

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()

-- Results also go to an on-screen panel, easier to read than a crowded Output window.
local panel = Instance.new("ScreenGui")
panel.Name = "DevScenarioResults"
panel.ResetOnSpawn = false
panel.DisplayOrder = 50
local text = Instance.new("TextLabel")
text.Size = UDim2.fromOffset(760, 420)
text.Position = UDim2.new(0.5, -380, 0, 90)
text.BackgroundColor3 = Color3.new(0, 0, 0)
text.BackgroundTransparency = 0.2
text.TextColor3 = Color3.new(1, 1, 1)
text.TextXAlignment = Enum.TextXAlignment.Left
text.TextYAlignment = Enum.TextYAlignment.Top
text.TextWrapped = true
text.Font = Enum.Font.Code
text.TextSize = 14
text.Text = "DevScenario " .. tostring(scenario)
text.Parent = panel
panel.Parent = player:WaitForChild("PlayerGui")

local function say(...: any)
	local parts = {}
	for index = 1, select("#", ...) do
		table.insert(parts, tostring((select(index, ...))))
	end
	local line = table.concat(parts, " ")
	print("[DevScenario] " .. line)
	text.Text ..= "\n" .. line
end

task.wait(3)
local world = workspace:WaitForChild("BurnOrBuildWorld") :: Model
player:SetAttribute("Credits", 8000)
player:SetAttribute("Research_Steam", true)
player:SetAttribute("TutorialComplete", true)

-- "WaterPump" finds a pump; "WaterPump@-20,128" finds the pump nearest that spot.
local function findModel(query: string): Model?
	local production = world:FindFirstChild("Production")
	if production == nil then
		return nil
	end
	local definitionId, rawX, rawZ = string.match(query, "^(%w+)@(%-?%d+),(%-?%d+)$")
	local near = if rawX and rawZ then Vector3.new(tonumber(rawX), 0, tonumber(rawZ)) else nil
	local best: Model? = nil
	local bestDistance = math.huge
	for _, model in production:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("DefinitionId") == (definitionId or query) then
			local position = model:GetPivot().Position
			local distance = if near
				then (Vector3.new(position.X, 0, position.Z) - near).Magnitude
				else 0
			if distance < bestDistance then
				best, bestDistance = model, distance
			end
		end
	end
	return best
end

-- The cell outside a port and the way it faces, as the build tool works it out.
local function access(definitionId: string, portName: string): (number, number, number)
	local model = findModel(definitionId) :: Model
	local port = model:FindFirstChild(portName) :: BasePart
	local body = model.PrimaryPart :: BasePart
	local offset = port.Position - body.Position
	local facing = Vector3.new(offset.X, 0, offset.Z).Unit
	local point = port.Position + facing * 2
	local ix, iz = ConveyorGrid.CellOf(point.X, point.Z)
	return ix, iz, ConveyorGrid.DirectionOf(facing.X, facing.Z)
end

-- A run of tiles from one port to another, along X then Z (or Z then X), ending into the input.
local function route(
	medium: string,
	fromId: string,
	fromPort: string,
	toId: string,
	toPort: string,
	zFirst: boolean?
)
	local sx, sz = access(fromId, fromPort)
	local ex, ez, away = access(toId, toPort)
	local cells = { { sx, sz } }
	local x, z = sx, sz
	local function alongX()
		while x ~= ex do
			x += if ex > x then 1 else -1
			table.insert(cells, { x, z })
		end
	end
	local function alongZ()
		while z ~= ez do
			z += if ez > z then 1 else -1
			table.insert(cells, { x, z })
		end
	end
	if zFirst then
		alongZ()
		alongX()
	else
		alongX()
		alongZ()
	end
	local tiles = {}
	for index, cell in cells do
		local nextCell = cells[index + 1]
		local dir = if nextCell
			then ConveyorGrid.DirectionBetween(cell[1], cell[2], nextCell[1], nextCell[2])
			else (away + 2) % 4
		table.insert(tiles, { x = cell[1], z = cell[2], dir = dir, medium = medium })
	end
	return tiles
end

-- Strings a wire with the wrench rules: a pole coil to a machine or to another pole's coil.
local function wire(poleQuery: string, coil: number, otherQuery: string, otherCoil: number?)
	local pole = findModel(poleQuery) :: Model
	local other = findModel(otherQuery) :: Model
	local ok, message = PowerService:Connect(
		player,
		{ id = pole:GetAttribute("MachineId"), coil = coil },
		{ id = other:GetAttribute("MachineId"), coil = otherCoil }
	)
	if not ok then
		print("[DevScenario] wire failed", poleQuery, otherQuery, message)
	end
end

local function machine(id: string, x: number, z: number)
	return { id = id, x = x, y = 1, z = z, rot = 0 }
end

local line = MachineService:GetLine()

local function feed(definitionId: string, item: string, count: number)
	for _, node in line.nodes do
		if node.definitionId == definitionId then
			for _ = 1, count do
				table.insert(node.input, line:_newUnit(item, player))
			end
		end
	end
end

local function nodeOf(definitionId: string): any
	for _, node in line.nodes do
		if node.definitionId == definitionId then
			return node
		end
	end
	return nil
end

local function report()
	for _, node in line.nodes do
		if node.definitionId ~= "CollectionPoint" and node.definitionId ~= "BuyerDepot" then
			say(
				node.definitionId,
				node.state,
				node.reason,
				string.format("power %.2f cycles %d", node.powerRatio, node.completedCycles)
			)
		end
	end
	say(
		"player supply",
		player:GetAttribute("PowerSupplyKW"),
		"demand",
		player:GetAttribute("PowerDemandKW")
	)
end

local function buildSteam()
	MachineService:ImportLayout(player, {
		machines = {
			machine("SolarPanel", -40, 86),
			machine("WaterPump", -40, 100),
			machine("PowerPole", -20, 92),
			machine("Boiler", -10, 120),
			machine("PowerPole", 8, 100),
			machine("SteamTurbine", 30, 120),
		},
		tiles = {},
	})
	local pipes = route("Fluid", "WaterPump", "OutputPort", "Boiler", "InputPortWater")
	for _, tile in route("Gas", "Boiler", "OutputPort", "SteamTurbine", "InputPort") do
		table.insert(pipes, tile)
	end
	MachineService:ImportLayout(player, { machines = {}, tiles = pipes })
	wire("PowerPole@-20,92", 1, "SolarPanel")
	wire("PowerPole@-20,92", 1, "WaterPump")
	wire("PowerPole@-20,92", 1, "Boiler")
	wire("PowerPole@-20,92", 1, "PowerPole@8,100", 1)
	wire("PowerPole@8,100", 1, "SteamTurbine")
	feed("Boiler", "DryStraw", 3)
	say(
		"built",
		#MachineService:ExportLayout(player).machines,
		"machines and",
		#pipes,
		"pipe tiles"
	)

	local peak = 0
	for _ = 1, 25 do
		task.wait(1)
		local turbine = nodeOf("SteamTurbine")
		peak = math.max(peak, turbine.powerOutput)
	end
	report()
	say("turbine peak kW", peak)
end

local function buildBiogas()
	player:SetAttribute("Research_Biogas", true)
	player:SetAttribute("Research_Market", true)
	MachineService:ImportLayout(player, {
		machines = {
			machine("DieselGenerator", -20, 105),
			machine("PowerPole", -30, 135),
			machine("PowerPole", -6, 120),
			machine("PowerPole", 24, 128),
			machine("WaterPump", -60, 135),
			machine("WaterPump", -20, 128),
			machine("CattleShed", -40, 150),
			machine("Digester", 0, 150),
			machine("GasEngine", 40, 150),
			machine("MarketStall", 10, 175),
		},
		tiles = {},
	})
	local tiles = {}
	local function add(list: { any })
		for _, tile in list do
			table.insert(tiles, tile)
		end
	end
	add(route("Fluid", "WaterPump@-60,135", "OutputPort", "CattleShed", "InputPortWater"))
	add(route("Fluid", "WaterPump@-20,128", "OutputPort", "Digester", "InputPortWater"))
	add(route("Item", "CattleShed", "OutputPort", "Digester", "InputPortManure", true))
	add(route("Gas", "Digester", "OutputPort", "GasEngine", "InputPort"))
	add(route("Item", "Digester", "OutputPortDigestate", "MarketStall", "InputPort"))
	MachineService:ImportLayout(player, { machines = {}, tiles = tiles })
	wire("PowerPole@-30,135", 1, "WaterPump@-60,135")
	wire("PowerPole@-30,135", 1, "WaterPump@-20,128")
	wire("PowerPole@-30,135", 1, "CattleShed")
	wire("PowerPole@-30,135", 1, "PowerPole@-6,120", 1)
	wire("PowerPole@-6,120", 1, "DieselGenerator")
	wire("PowerPole@-6,120", 1, "Digester")
	wire("PowerPole@-6,120", 1, "PowerPole@24,128", 1)
	wire("PowerPole@24,128", 1, "GasEngine")
	say("built", #MachineService:ExportLayout(player).machines, "machines and", #tiles, "tiles")
	-- Stand south of the plant looking north, so the camera frames it.
	local character = player.Character
	if character then
		character:PivotTo(CFrame.lookAt(Vector3.new(-10, 6, 200), Vector3.new(-10, 6, 140)))
	end
	feed("CattleShed", "WetStraw", 6)
	feed("Digester", "ShreddedStraw", 3)

	local enginePeak = 0
	for _ = 1, 110 do
		task.wait(1)
		local engine = nodeOf("GasEngine")
		enginePeak = math.max(enginePeak, engine.powerOutput)
	end
	report()
	say("engine peak kW", enginePeak, "stall sold", nodeOf("MarketStall").completedCycles)
end

if scenario == "biogas" then
	buildBiogas()
else
	buildSteam()
end

if scenario == "save" then
	local json = HttpService:JSONEncode(SaveService:Snapshot(player))
	local data = HttpService:JSONDecode(json)
	local before = #data.layout.machines
	local wiresBefore = #data.wires
	MachineService:ClearPlayerForTest(player)
	local wiped = #MachineService:ExportLayout(player).machines
	player:SetAttribute("Credits", 1)
	SaveService:Apply(player, data)
	local after = MachineService:ExportLayout(player)
	say(
		string.format(
			"save round trip: %d bytes, machines %d, after wipe %d, rebuilt %d, tiles %d of %d, wires %d of %d, credits %s",
			#json,
			before,
			wiped,
			#after.machines,
			#after.tiles,
			#data.layout.tiles,
			player:GetAttribute("Wires") or 0,
			wiresBefore,
			tostring(player:GetAttribute("Credits"))
		)
	)
	local year = world:GetAttribute("SeasonNumber")
	world:SetAttribute("NewYearNow", true)
	task.wait(2)
	say(
		"year",
		year,
		"->",
		world:GetAttribute("SeasonNumber"),
		"phase",
		world:GetAttribute("SeasonPhase"),
		string.format(
			"%.0f s left",
			(world:GetAttribute("SeasonEndsAt") :: number) - workspace:GetServerTimeNow()
		)
	)
end
say("done")
-- Out of the way once read, so the game UI can be checked too.
task.delay(12, function()
	panel:Destroy()
end)
