--!strict

-- The season loop (spec v0.2 sections 2.3, 11.3, 12.3 to 12.5).
-- Runs the server season clock from GameConfig.Round.DurationSeconds, publishes the phase and
-- time left as world attributes for the HUD, drives the forecast weather event, and builds the
-- end of season report with Simulation/SeasonResults. Players fetch their report through the
-- GetSeasonResults remote once the world attribute SeasonOver turns true. With
-- GameConfig.Round.Endless the clock instead starts a new year (SeasonNumber) when it runs out.
--
-- Play test helpers (Studio server command bar):
--   workspace.BurnOrBuildWorld:SetAttribute("ForcedWeatherEvent", "Rain") -- or "WindShift",
--     before the forecast at minute 13
--   workspace.BurnOrBuildWorld:SetAttribute("EndSeasonNow", true) -- jump to the results
--   workspace.BurnOrBuildWorld:SetAttribute("NewYearNow", true) -- endless mode: start a new year

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CommitmentDefinitions = require(Shared:WaitForChild("CommitmentDefinitions"))
local SeasonDefinitions = require(Shared:WaitForChild("SeasonDefinitions"))

local Simulation = script.Parent.Parent:WaitForChild("Simulation")
local SeasonClock = require(Simulation:WaitForChild("SeasonClock"))
local SeasonResults = require(Simulation:WaitForChild("SeasonResults"))

local SeasonService = {}

local TICK_SECONDS = 1
local SETTLED_FARM_STATES = { Completed = true, Missed = true, Burned = true }
local SETTLED_FIELD_STATES = { Collected = true, Burned = true }

local world: Model
local gameConfig: any
local playerState: any
local machineService: any
local smokeService: any
local weatherService: any
local startTime = 0
local duration = 0
local over = false
local reports: { [Player]: any } = {}
local firstSaleAt: { [Player]: number } = {}
local bottlenecks = SeasonResults.newBottleneckLog()
local endReason = ""

local function now(): number
	return workspace:GetServerTimeNow()
end

local function elapsedNow(): number
	return now() - startTime
end

-- Fields and commitments as plain tables for SeasonResults, read from the world attributes
-- that FieldService and CommitmentService own.
local function gatherFields(): ({ SeasonResults.Field }, { SeasonResults.Commitment })
	local fields: { SeasonResults.Field } = {}
	local commitments: { SeasonResults.Commitment } = {}
	local records = smokeService:GetRecords()

	local own = gameConfig.Fields.FarmA
	local ownModel = world:FindFirstChild(own.ModelName, true)
	local ownState = if ownModel then ownModel:GetAttribute("State") else nil
	table.insert(fields, {
		name = own.DisplayName,
		bundles = own.Bundles,
		burnExposure = own.BurnExposure,
		resolved = typeof(ownState) == "string" and SETTLED_FIELD_STATES[ownState] == true,
		trustChange = if ownState == "Burned" then -own.BurnTrustLoss else 0,
	})

	for _, farmId in CommitmentDefinitions.FarmOrder do
		local definition = CommitmentDefinitions.Farms[farmId]
		local model = world:FindFirstChild(definition.ModelName, true)
		local rawState = if model then model:GetAttribute("State") else nil
		local state = if typeof(rawState) == "string" then rawState else "Available"
		-- A rejected farm burns at its deadline and then reads Burned; the record keeps why.
		for _, record in records do
			if record.field == definition.DisplayName and record.responsibility == "Rejected" then
				state = "Rejected"
			end
		end
		table.insert(fields, {
			name = definition.DisplayName,
			bundles = definition.Bundles,
			burnExposure = definition.BurnExposure,
			resolved = typeof(rawState) == "string" and SETTLED_FARM_STATES[rawState] == true,
			trustChange = 0,
		})
		table.insert(commitments, {
			name = definition.ShortName,
			state = state,
			trustChange = if state == "Completed"
				then definition.CompleteTrust
				elseif state == "Missed" then definition.MissTrust
				else 0,
		})
	end
	return fields, commitments
end

local function buildReport(player: Player): any
	local burns: { SeasonResults.Burn } = {}
	for _, record in smokeService:GetRecords() do
		table.insert(burns, {
			field = record.field,
			quantity = record.quantity,
			time = record.time - startTime,
			wind = record.wind,
			destination = record.destination,
			exposure = record.exposure,
			potential = record.potential,
			responsibility = record.responsibility,
		})
	end
	local fields, commitments = gatherFields()
	return SeasonResults.compute({
		ledger = playerState:GetLedger(player),
		endingCash = playerState:GetCredits(player),
		infrastructureValue = machineService:GetInfrastructureValue(player),
		infrastructureRate = SeasonDefinitions.Results.InfrastructureCreditRate,
		startingTrust = gameConfig.Player.StartingTrust,
		endingTrust = playerState:GetTrust(player),
		burns = burns,
		fields = fields,
		commitments = commitments,
		responsibilityText = CommitmentDefinitions.Responsibility,
		firstSaleAt = firstSaleAt[player],
		bottleneck = bottlenecks.first,
		endReason = endReason,
		disclaimer = SeasonDefinitions.Results.Disclaimer,
	})
end

local function endSeason(reason: string)
	if over then
		return
	end
	over = true
	endReason = reason
	for _, player in Players:GetPlayers() do
		reports[player] = buildReport(player)
	end
	local results = SeasonDefinitions.ResultsPhase
	world:SetAttribute("SeasonPhase", results.Id)
	world:SetAttribute("SeasonPhaseName", results.Name)
	world:SetAttribute("SeasonGoal", results.Goal)
	world:SetAttribute("SeasonEndReason", reason)
	world:SetAttribute("SeasonOver", true)
	machineService:NotifyAll("Season over. " .. reason .. " Your results are ready.")
end

-- Spec 12.5 soft failure: every field is settled and no straw is left to process.
local function factoryIsIdle(): boolean
	-- Rice growing or straw lying on any paddy keeps the season open.
	for _, paddy in CollectionService:GetTagged("Paddy") do
		if paddy:GetAttribute("CropActive") == true then
			return false
		end
	end
	local fields = gatherFields()
	for _, field in fields do
		if not field.resolved then
			return false
		end
	end
	if machineService:CountItems() > 0 then
		return false
	end
	for _, player in Players:GetPlayers() do
		local carried = player:GetAttribute("StrawBundles")
		if typeof(carried) == "number" and carried > 0 then
			return false
		end
	end
	return true
end

function SeasonService:Initialize(
	worldModel: Model,
	config: any,
	playerStateService: any,
	machines: any,
	smoke: any,
	weather: any
)
	world = worldModel
	gameConfig = config
	playerState = playerStateService
	machineService = machines
	smokeService = smoke
	weatherService = weather
	startTime = now()
	duration = config.Round.DurationSeconds

	world:SetAttribute("SeasonNumber", 1)
	world:SetAttribute("SeasonStartedAt", startTime)
	world:SetAttribute("SeasonEndsAt", startTime + duration)
	world:SetAttribute("SeasonDuration", duration)
	world:SetAttribute("SeasonOver", false)
	weatherService:Initialize(world, config, machines, startTime)

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local resultsRemote = Instance.new("RemoteFunction")
	resultsRemote.Name = "GetSeasonResults"
	resultsRemote.OnServerInvoke = function(player: Player): any
		if not over then
			return nil
		end
		-- A player who joined after the end still gets a report of the shared district.
		if reports[player] == nil then
			reports[player] = buildReport(player)
		end
		return reports[player]
	end
	resultsRemote.Parent = remotes

	Players.PlayerRemoving:Connect(function(player)
		reports[player] = nil
		firstSaleAt[player] = nil
	end)

	-- Kind is rolled now; ForcedWeatherEvent can still override it until the forecast.
	local random = Random.new()
	local roll = random:NextNumber()
	local forecastAt = SeasonClock.planWeather(SeasonDefinitions, duration, "Rain").forecastAt
	local stress = SeasonClock.findPhase(SeasonDefinitions, duration, "Stress")
	local stressStart = if stress then stress.startsAt else 0
	local idleSeconds = 0
	local lastPhase = ""

	-- Endless mode: the year starts over. Fields, farms and the factory carry on; the clock,
	-- the phases (and with them the burn ban) and the weather event begin again.
	local function startNewYear()
		startTime = now()
		roll = random:NextNumber()
		lastPhase = ""
		bottlenecks = SeasonResults.newBottleneckLog()
		local year = (world:GetAttribute("SeasonNumber") :: number? or 1) + 1
		world:SetAttribute("SeasonNumber", year)
		world:SetAttribute("SeasonStartedAt", startTime)
		world:SetAttribute("SeasonEndsAt", startTime + duration)
		weatherService:Reset(startTime)
		machineService:NotifyAll(
			string.format(
				"Year %d begins. The harvest comes round again, and so will the smog season.",
				year
			)
		)
	end

	task.spawn(function()
		while not over do
			local elapsed = elapsedNow()

			local phase = SeasonClock.phaseAt(SeasonDefinitions, duration, elapsed)
			if phase.id ~= lastPhase and phase.id ~= SeasonDefinitions.ResultsPhase.Id then
				lastPhase = phase.id
				world:SetAttribute("SeasonPhase", phase.id)
				world:SetAttribute("SeasonPhaseName", phase.name)
				world:SetAttribute("SeasonGoal", phase.goal)
				world:SetAttribute("SeasonPhaseEndsAt", startTime + phase.endsAt)
				if phase.index > 1 then
					machineService:NotifyAll(
						string.format("Season phase: %s. %s", phase.name, phase.goal)
					)
				end
			end

			if weatherService:GetPlan() == nil and elapsed >= forecastAt then
				local forced = world:GetAttribute("ForcedWeatherEvent")
				local kind = SeasonClock.pickEvent(
					SeasonDefinitions,
					roll,
					if typeof(forced) == "string" then forced else nil
				)
				weatherService:SetPlan(SeasonClock.planWeather(SeasonDefinitions, duration, kind))
			end
			weatherService:Update(elapsed)

			for _, player in Players:GetPlayers() do
				if
					firstSaleAt[player] == nil
					and player:GetAttribute("TutorialComplete") == true
				then
					firstSaleAt[player] = elapsed
				end
			end
			SeasonResults.trackBottlenecks(
				bottlenecks,
				machineService:GetProcessorStates(),
				TICK_SECONDS,
				elapsed,
				SeasonDefinitions.Results.BottleneckSeconds
			)

			if world:GetAttribute("NewYearNow") == true then
				world:SetAttribute("NewYearNow", nil)
				startNewYear()
				continue
			end
			if world:GetAttribute("EndSeasonNow") == true then
				endSeason("The season was ended early for a play test.")
				break
			end
			if elapsed >= duration then
				if gameConfig.Round.Endless then
					startNewYear()
					continue
				end
				endSeason(string.format("The %d minute season is over.", math.floor(duration / 60)))
				break
			end
			if not gameConfig.Round.Endless and elapsed >= stressStart and factoryIsIdle() then
				if idleSeconds == 0 then
					machineService:NotifyAll(
						string.format(
							"Every field is settled and the factory is empty. The season closes in %d s.",
							SeasonDefinitions.SoftEnd.IdleSeconds
						)
					)
				end
				idleSeconds += TICK_SECONDS
				if idleSeconds >= SeasonDefinitions.SoftEnd.IdleSeconds then
					endSeason("Every field was settled and no straw was left to process.")
					break
				end
			else
				idleSeconds = 0
			end
			task.wait(TICK_SECONDS)
		end
	end)
end

return SeasonService
