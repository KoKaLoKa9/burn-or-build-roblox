--!strict

-- The district's smog and what it costs (Week 6 burn pass). Every burn adds its burn potential to
-- a smog meter that slowly clears. While the meter is over the threshold the air is smoggy:
-- sick workers slow every machine (and research, see ResearchService), the client hazes the sky
-- (Smog.client), and smoke slows people walking through it (Sprint.client). Separately, each time
-- a player's village exposure passes another step, the school closes for a smog day and farmers
-- lose trust in the cooperative. The burn ban (fines for open burning) is on during the phases
-- GameConfig.Burn.BanPhases names.
--
-- World attributes: Smog (meter), SmogActive, BurnBan.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SmogService = {}

local TICK_SECONDS = 0.5

function SmogService:Initialize(
	world: Model,
	gameConfig: any,
	playerState: any,
	machineService: any
)
	local rules = gameConfig.Smog
	local banPhases = gameConfig.Burn.BanPhases
	local smog = 0
	local active = false
	-- How many smog-day steps each player's exposure has already passed.
	local schoolSteps: { [Player]: number } = {}

	world:SetAttribute("Smog", 0)
	world:SetAttribute("SmogActive", false)
	world:SetAttribute("BurnBan", false)

	-- Burn records appear in ReplicatedStorage.BurnRecords (the folder itself is made at the first
	-- burn), so each tick counts any record not seen before.
	local counted: { [Instance]: boolean } = {}
	local function countNewBurns()
		local records = ReplicatedStorage:FindFirstChild("BurnRecords")
		if records == nil then
			return
		end
		for _, record in records:GetChildren() do
			local potential = record:GetAttribute("Potential")
			if not counted[record] and typeof(potential) == "number" then
				counted[record] = true
				smog += potential
			end
		end
	end

	local function updateBan()
		local phase = world:GetAttribute("SeasonPhase")
		local banned = typeof(phase) == "string" and banPhases[phase] == true
		if banned ~= world:GetAttribute("BurnBan") then
			world:SetAttribute("BurnBan", banned)
			if banned then
				machineService:NotifyAll(
					string.format(
						"Smog season: open burning is now banned. Burning a field costs a %d credit fine.",
						gameConfig.Burn.FineCredits
					)
				)
			end
		end
	end
	world:GetAttributeChangedSignal("SeasonPhase"):Connect(updateBan)
	updateBan()

	local function checkSchool(player: Player)
		local exposure = player:GetAttribute("Exposure")
		if typeof(exposure) ~= "number" then
			return
		end
		local steps = exposure // rules.SchoolStep
		local passed = schoolSteps[player] or 0
		if steps > passed then
			schoolSteps[player] = steps
			playerState:AdjustTrust(player, -rules.SchoolTrustLoss * (steps - passed))
			machineService:Notify(
				player,
				string.format(
					"Smog day: the village school closed to protect the children. Farmers trust the cooperative less (-%d).",
					rules.SchoolTrustLoss * (steps - passed)
				)
			)
		end
	end
	local function watchPlayer(player: Player)
		player:GetAttributeChangedSignal("Exposure"):Connect(function()
			checkSchool(player)
		end)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		schoolSteps[player] = nil
	end)

	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < TICK_SECONDS then
			return
		end
		local elapsed = accumulated
		accumulated = 0
		smog = math.max(0, smog - rules.DecayPerSecond * elapsed)
		countNewBurns()
		world:SetAttribute("Smog", math.floor(smog * 10) / 10)
		local nowActive = smog >= rules.Threshold
		if nowActive ~= active then
			active = nowActive
			world:SetAttribute("SmogActive", active)
			machineService:SetGlobalCycleMultiplier(if active then rules.MachineSlowdown else 1)
			machineService:NotifyAll(
				if active
					then "Smog over the district: workers are coughing, so machines and research slow down."
					else "The smog has cleared. Machines are back to full speed."
			)
		end
	end)
end

return SmogService
