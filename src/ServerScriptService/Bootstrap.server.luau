--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local Services = script.Parent:WaitForChild("Services")
local PlayerStateService = require(Services:WaitForChild("PlayerStateService"))
local SmokeService = require(Services:WaitForChild("SmokeService"))
local FieldService = require(Services:WaitForChild("FieldService"))
local MachineService = require(Services:WaitForChild("MachineService"))
local CommitmentService = require(Services:WaitForChild("CommitmentService"))
local TruckService = require(Services:WaitForChild("TruckService"))
local WorldLabelService = require(Services:WaitForChild("WorldLabelService"))
local WorldArtService = require(Services:WaitForChild("WorldArtService"))
local WeatherService = require(Services:WaitForChild("WeatherService"))
local SeasonService = require(Services:WaitForChild("SeasonService"))

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
MachineService:Initialize(world, PlayerStateService)
FieldService:Initialize(world, PlayerStateService, SmokeService, GameConfig)
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
