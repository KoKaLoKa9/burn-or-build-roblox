--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local Services = script.Parent:WaitForChild("Services")
local PlayerStateService = require(Services:WaitForChild("PlayerStateService"))
local SmokeService = require(Services:WaitForChild("SmokeService"))
local FieldService = require(Services:WaitForChild("FieldService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local MachineService = require(Services:WaitForChild("MachineService"))
local PowerService = require(Services:WaitForChild("PowerService"))
local FarmMachineService = require(Services:WaitForChild("FarmMachineService"))
local ResearchService = require(Services:WaitForChild("ResearchService"))
local SmogService = require(Services:WaitForChild("SmogService"))
local VillageService = require(Services:WaitForChild("VillageService"))
local CommitmentService = require(Services:WaitForChild("CommitmentService"))
local TruckService = require(Services:WaitForChild("TruckService"))
local WorldLabelService = require(Services:WaitForChild("WorldLabelService"))
local WorldArtService = require(Services:WaitForChild("WorldArtService"))
local EnvironmentService = require(Services:WaitForChild("EnvironmentService"))
local WeatherService = require(Services:WaitForChild("WeatherService"))
local SeasonService = require(Services:WaitForChild("SeasonService"))
local SaveService = require(Services:WaitForChild("SaveService"))

local function initializePlayer(player: Player)
	PlayerStateService:InitializePlayer(player)
end

Players.PlayerAdded:Connect(initializePlayer)
for _, player in Players:GetPlayers() do
	initializePlayer(player)
end

local world = workspace:WaitForChild("BurnOrBuildWorld", 10)
if world == nil or not world:IsA("Model") then
	error("BurnOrBuildWorld is missing. Generate or load the approved graybox before playing.")
end

world:SetAttribute("ProjectMilestone", "Week4SeasonLoop")
world:SetAttribute("WindDirection", GameConfig.Wind.Label)
-- MachineService creates the shared remotes, so it starts before the services that notify.
-- Before MachineService, which places the buyer's IN port from its collision block.
WorldArtService:EnlargeBuyer(world)
WorldArtService:PrepareVillage(world)
VillageService:Prepare(world)
-- After the buyer grows and before MachineService reads the road sizes for placement rules.
EnvironmentService:Initialize(world)
MachineService:Initialize(world, PlayerStateService)
PowerService:Initialize(world, MachineService)
-- Registers the transplanter and combine with MachineService before anyone can place one.
FarmMachineService:Initialize(MachineService, PlayerStateService)
ResearchService:Initialize(MachineService, PlayerStateService)
SmogService:Initialize(world, GameConfig, PlayerStateService, MachineService)
VillageService:Initialize(world, GameConfig, PlayerStateService, MachineService)
FieldService:Initialize(world, PlayerStateService, SmokeService, GameConfig, MachineService)
PlotService:Initialize(world, PlayerStateService, SmokeService, GameConfig, MachineService)
CommitmentService:Initialize(world, PlayerStateService, SmokeService, MachineService, GameConfig)
TruckService:Initialize(world, PlayerStateService, MachineService, CommitmentService)
-- The season clock starts with the farm deadlines above and owns the weather event.
SeasonService:Initialize(
	world,
	GameConfig,
	PlayerStateService,
	MachineService,
	SmokeService,
	WeatherService
)
WorldArtService:Initialize(world)
-- Runs last so it restyles every label the other services created.
WorldLabelService:Initialize(world)
-- After every service exists, so a saved factory, plots and research can be restored.
SaveService:Initialize(world, MachineService, PlotService)

-- Studio play tests drive the live line from the command bar, which runs in its own environment
-- and cannot reach these module instances. ServerStorage.DebugBridge answers a few fixed actions:
-- "states" lists every machine, "feed" (definition id, item, count) fills machine inputs.
if game:GetService("RunService"):IsStudio() then
	local bridge = Instance.new("BindableFunction")
	bridge.Name = "DebugBridge"
	bridge.OnInvoke = function(action: string, definitionId: string?, item: string?, count: number?)
		local line = MachineService:GetLine()
		if action == "states" then
			local lines = {}
			for id, node in line.nodes do
				table.insert(
					lines,
					string.format(
						"%d %s %s (%s) power %.2f out %.1f",
						id,
						node.definitionId,
						node.state,
						node.reason,
						node.powerRatio,
						node.powerOutput
					)
				)
			end
			table.sort(lines)
			return table.concat(lines, "\n")
		elseif action == "roundtrip" then
			-- Save, wipe and restore the first player's factory, through JSON like a DataStore.
			local HttpService = game:GetService("HttpService")
			local player = Players:GetPlayers()[1]
			local json = HttpService:JSONEncode(SaveService:Snapshot(player))
			local data = HttpService:JSONDecode(json)
			local before = #data.layout.machines
			MachineService:ClearPlayerForTest(player)
			local cleared = #MachineService:ExportLayout(player).machines
			SaveService:Apply(player, data)
			local after = MachineService:ExportLayout(player)
			return string.format(
				"json %d bytes, machines %d -> %d after wipe -> %d rebuilt, tiles %d -> %d",
				#json,
				before,
				cleared,
				#after.machines,
				#data.layout.tiles,
				#after.tiles
			)
		elseif action == "feed" then
			local fed = 0
			for _, node in line.nodes do
				if node.definitionId == definitionId then
					for _ = 1, count or 1 do
						table.insert(node.input, line:_newUnit(item, node.owner))
						fed += 1
					end
				end
			end
			return fed
		end
		return nil
	end
	bridge.Parent = game:GetService("ServerStorage")
end
