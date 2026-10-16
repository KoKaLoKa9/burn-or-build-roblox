--!strict

-- Run from the project root with: lune run tests/Season.spec.luau
-- Covers the season clock (spec 2.3), the forecast weather event (11.3), rain in the production
-- line, and the end of season results (12.3 to 12.5, 16.4).

local SeasonClock = require("../src/ServerScriptService/Simulation/SeasonClock")
local SeasonResults = require("../src/ServerScriptService/Simulation/SeasonResults")
local ProductionLine = require("../src/ServerScriptService/Simulation/ProductionLine")
local SeasonDefinitions = require("../src/ReplicatedStorage/Shared/SeasonDefinitions")
local MachineDefinitions = require("../src/ReplicatedStorage/Shared/MachineDefinitions")
local CommitmentDefinitions = require("../src/ReplicatedStorage/Shared/CommitmentDefinitions")

local failures = 0
local passes = 0

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passes += 1
		print("PASS  " .. name)
	else
		failures += 1
		print("FAIL  " .. name .. (if detail then "  (" .. detail .. ")" else ""))
	end
end

local ROUND = 20 * 60
local BASE_WIND = { label = "East", x = 1, z = 0 }

-- 2.3: five phases at minutes 0, 3, 8, 14, and 18, then results at minute 20.
do
	local phases = SeasonClock.phases(SeasonDefinitions, ROUND)
	check("five phases", #phases == 5, tostring(#phases))
	local starts = {}
	for _, phase in phases do
		table.insert(starts, phase.startsAt / 60)
	end
	check(
		"phase starts match spec 2.3",
		table.concat(starts, ",") == "0,3,8,14,18",
		table.concat(starts, ",")
	)
	check("last phase ends at minute 20", phases[5].endsAt == ROUND)
	check("minute 0 is harvest", SeasonClock.phaseAt(SeasonDefinitions, ROUND, 0).id == "Harvest")
	check(
		"2:59 is still harvest",
		SeasonClock.phaseAt(SeasonDefinitions, ROUND, 179).id == "Harvest"
	)
	check(
		"minute 3 is first line",
		SeasonClock.phaseAt(SeasonDefinitions, ROUND, 180).id == "FirstLine"
	)
	check(
		"minute 10 is expansion",
		SeasonClock.phaseAt(SeasonDefinitions, ROUND, 600).id == "Expansion"
	)
	check("minute 14 is stress", SeasonClock.phaseAt(SeasonDefinitions, ROUND, 840).id == "Stress")
	check(
		"minute 19 is closing",
		SeasonClock.phaseAt(SeasonDefinitions, ROUND, 1140).id == "Closing"
	)
	check(
		"minute 20 shows results",
		SeasonClock.phaseAt(SeasonDefinitions, ROUND, ROUND).id == "Results"
	)
	local short = SeasonClock.phases(SeasonDefinitions, 10 * 60)
	check("a 10 minute round halves every phase", short[4].startsAt == 7 * 60)
	check("clock text", SeasonClock.formatClock(61.2) == "1:02", SeasonClock.formatClock(61.2))
	check("clock never negative", SeasonClock.formatClock(-5) == "0:00")
end

-- 11.3: one event in the stress phase, forecast two minutes ahead.
do
	local rain = SeasonClock.planWeather(SeasonDefinitions, ROUND, "Rain")
	check("rain starts at minute 15", rain.startsAt == 15 * 60, tostring(rain.startsAt))
	check("rain forecast at minute 13", rain.forecastAt == 13 * 60, tostring(rain.forecastAt))
	check("rain ends inside the stress phase", rain.endsAt ~= nil and rain.endsAt <= 18 * 60)
	check("calm before the forecast", SeasonClock.weatherState(rain, 700) == "Calm")
	check("forecast before rain", SeasonClock.weatherState(rain, 800) == "Forecast")
	check("rain active at minute 16", SeasonClock.weatherState(rain, 960) == "Active")
	check("rain clears afterwards", SeasonClock.weatherState(rain, 1100) == "Cleared")
	check(
		"dryers normal before rain",
		SeasonClock.dryerMultiplier(SeasonDefinitions, rain, 800) == 1
	)
	check(
		"dryers slow during rain",
		SeasonClock.dryerMultiplier(SeasonDefinitions, rain, 960) == 1.5
	)
	check(
		"dryers normal after rain",
		SeasonClock.dryerMultiplier(SeasonDefinitions, rain, 1100) == 1
	)
	local label = SeasonClock.windAt(SeasonDefinitions, rain, 960, BASE_WIND)
	check("rain keeps the wind", label == "East")

	local shift = SeasonClock.planWeather(SeasonDefinitions, ROUND, "WindShift")
	check("wind shift has no end", shift.endsAt == nil)
	local before, bx, _, beforeDestination =
		SeasonClock.windAt(SeasonDefinitions, shift, 800, BASE_WIND)
	check(
		"forecast does not move the wind yet",
		before == "East" and bx == 1 and beforeDestination == "Village"
	)
	local after, ax, _, afterDestination =
		SeasonClock.windAt(SeasonDefinitions, shift, 905, BASE_WIND)
	check(
		"wind turns west at minute 15",
		after == "West" and ax == -1 and afterDestination == "Open land"
	)
	local late = SeasonClock.windAt(SeasonDefinitions, shift, 1190, BASE_WIND)
	check("wind stays west to the end", late == "West")
	check(
		"wind shift never slows dryers",
		SeasonClock.dryerMultiplier(SeasonDefinitions, shift, 905) == 1
	)

	check("roll 0 picks rain", SeasonClock.pickEvent(SeasonDefinitions, 0) == "Rain")
	check("roll 0.99 picks wind", SeasonClock.pickEvent(SeasonDefinitions, 0.99) == "WindShift")
	check(
		"forced event wins",
		SeasonClock.pickEvent(SeasonDefinitions, 0, "WindShift") == "WindShift"
	)
	check(
		"unknown forced event is ignored",
		SeasonClock.pickEvent(SeasonDefinitions, 0, "Snow") == "Rain"
	)
end

-- 11.3: rain slows the dryer in the production line, and progress survives the change.
do
	local line = ProductionLine.new(MachineDefinitions)
	local intake = line:AddNode("CollectionPoint", "player")
	local dryer = line:AddNode("Dryer", "player")
	assert(line:Connect(intake.id, dryer.id, 1))
	line:Deposit(intake.id, 1)
	line:Step(1.5)
	check("dryer started", dryer.state == "Processing", dryer.state)
	local normal = MachineDefinitions.Dryer.CycleSeconds
	line:SetCycleMultiplier("Dryer", 1.5)
	check("rain cycle time", line:CycleSeconds(dryer) == normal * 1.5)
	line:Step(normal)
	check("rain keeps the dryer busy past the normal cycle", dryer.completedCycles == 0)
	line:Step(normal * 0.5)
	check("rain cycle finishes", dryer.completedCycles == 1, tostring(dryer.completedCycles))
	line:SetCycleMultiplier("Dryer", 1)
	check("multiplier resets", line:CycleSeconds(dryer) == normal)
	check("item count sees the dried bundle", line:CountItems() == 1, tostring(line:CountItems()))
	local shredder = line:AddNode("Shredder", "player")
	line:SetCycleMultiplier("Dryer", 2)
	check("rain leaves the shredder alone", line:CycleSeconds(shredder) == 6)
end

-- 12.3: profit, ending cash, and cooperative value.
do
	local ledger = SeasonResults.newLedger()
	SeasonResults.record(ledger, "Construction", -800)
	SeasonResults.record(ledger, "Sales", 600)
	SeasonResults.record(ledger, "Processing", -120)
	SeasonResults.record(ledger, "RouteFee", -100)
	SeasonResults.record(ledger, "Extension", -50)
	SeasonResults.record(ledger, "Bonus", 100)
	SeasonResults.record(ledger, "Refund", 140)
	check("season profit ignores construction", SeasonResults.seasonProfit(ledger) == 430)
	check("cooperative value", SeasonResults.cooperativeValue(670, 1000, 0.7) == 1370)
end

local RESPONSIBILITY = CommitmentDefinitions.Responsibility

local function baseInput(): any
	local ledger = SeasonResults.newLedger()
	SeasonResults.record(ledger, "Construction", -850)
	SeasonResults.record(ledger, "Sales", 600)
	SeasonResults.record(ledger, "Processing", -120)
	return {
		ledger = ledger,
		endingCash = 630,
		infrastructureValue = 850,
		infrastructureRate = SeasonDefinitions.Results.InfrastructureCreditRate,
		startingTrust = 50,
		endingTrust = 50,
		burns = {},
		fields = {
			{
				name = "Your rice field",
				bundles = 8,
				burnExposure = 20,
				resolved = true,
				trustChange = 0,
			},
			{
				name = "Nearby farm B",
				bundles = 12,
				burnExposure = 35,
				resolved = true,
				trustChange = 0,
			},
			{
				name = "Distant farm C",
				bundles = 16,
				burnExposure = 50,
				resolved = true,
				trustChange = 0,
			},
		},
		commitments = {
			{ name = "Farm B", state = "Completed", trustChange = 10 },
			{ name = "Farm C", state = "Rejected", trustChange = 0 },
		},
		responsibilityText = RESPONSIBILITY,
		firstSaleAt = 400,
		bottleneck = nil,
		endReason = "The 20 minute season is over.",
		disclaimer = SeasonDefinitions.Results.Disclaimer,
	}
end

-- 12.4: each dimension is reported separately with causes.
do
	local input = baseInput()
	input.endingTrust = 60
	input.burns = {
		{
			field = "Distant farm C",
			quantity = 16,
			time = 960,
			wind = "East",
			destination = "Village",
			exposure = 50,
			potential = 50,
			responsibility = "Rejected",
		},
	}
	local report = SeasonResults.compute(input)
	check("profit 480", report.profit.seasonProfit == 480, tostring(report.profit.seasonProfit))
	check("ending cash kept", report.profit.endingCash == 630)
	check("cooperative value 630 + 595", report.profit.cooperativeValue == 1225)
	check("profit is strong", report.profit.strong)
	check("district exposure counts the rejected farm", report.cleanAir.districtExposure == 50)
	check("rejected farm is not player caused", report.cleanAir.playerCausedExposure == 0)
	check(
		"prevented counts collected fields",
		report.cleanAir.exposurePrevented == 55,
		tostring(report.cleanAir.exposurePrevented)
	)
	check("one exposure cause", #report.cleanAir.causes == 1)
	check(
		"cause names the rejection",
		report.cleanAir.causes[1].label == RESPONSIBILITY.Rejected,
		report.cleanAir.causes[1].label
	)
	check("trust counts", report.trust.completed == 1 and report.trust.rejected == 1)
	check("accepted counts the completed promise", report.trust.accepted == 1)
	check("trust change +10", report.trust.change == 10)
	check("trust is strong", report.trust.strong)
	check(
		"lesson names the rejected farm",
		string.find(report.keyLesson, "Distant farm C", 1, true) ~= nil,
		report.keyLesson
	)
	check(
		"success names the kept promise",
		string.find(report.successfulDecision, "Farm B", 1, true) ~= nil,
		report.successfulDecision
	)
	check("no bottleneck text", string.find(report.bottleneck, "No machine", 1, true) ~= nil)
	check("top cause is not sent to the client", report.cleanAir.topCause == nil)
end

-- 11.4 and 16.3: missed promises and own burns are player caused and listed in time order.
do
	local input = baseInput()
	input.ledger = SeasonResults.newLedger()
	SeasonResults.record(input.ledger, "Construction", -500)
	SeasonResults.record(input.ledger, "Extension", -50)
	input.endingCash = 450
	input.endingTrust = 30
	input.fields[1].trustChange = -5
	input.commitments = {
		{ name = "Farm B", state = "Missed", trustChange = -15 },
		{ name = "Farm C", state = "Burned", trustChange = 0 },
	}
	input.burns = {
		{
			field = "Nearby farm B",
			quantity = 6,
			time = 780,
			wind = "East",
			destination = "Village",
			exposure = 18,
			potential = 18,
			responsibility = "MissedCommitment",
		},
		{
			field = "Your rice field",
			quantity = 8,
			time = 60,
			wind = "East",
			destination = "Village",
			exposure = 20,
			potential = 20,
			responsibility = "PlayerAuthorized",
		},
		{
			field = "Distant farm C",
			quantity = 16,
			time = 960,
			wind = "West",
			destination = "Open land",
			exposure = 0,
			potential = 50,
			responsibility = "NoAgreement",
		},
	}
	local report = SeasonResults.compute(input)
	check("loss when nothing sold", report.profit.seasonProfit == -50)
	check("profit not strong", not report.profit.strong)
	check("district exposure 38", report.cleanAir.districtExposure == 38)
	check("player caused 38", report.cleanAir.playerCausedExposure == 38)
	check("smoke released 88", report.cleanAir.smokeReleased == 88)
	check(
		"prevented counts the 6 farm B bundles saved",
		report.cleanAir.exposurePrevented == 18,
		tostring(report.cleanAir.exposurePrevented)
	)
	check("three causes", #report.cleanAir.causes == 3)
	check(
		"largest cause first",
		report.cleanAir.causes[1].label == RESPONSIBILITY.PlayerAuthorized,
		report.cleanAir.causes[1].label
	)
	check(
		"open land burn shows drifted smoke",
		string.find(report.cleanAir.causes[3].detail or "", "open land", 1, true) ~= nil,
		report.cleanAir.causes[3].detail
	)
	check("events in time order", report.cleanAir.events[1].label == "1:00")
	check("last event at 16:00", report.cleanAir.events[3].label == "16:00")
	check("missed counted", report.trust.missed == 1 and report.trust.unanswered == 1)
	check("trust not strong", not report.trust.strong)
	check(
		"own burn listed under trust",
		report.trust.causes[3] ~= nil and report.trust.causes[3].value == "-5"
	)
	check(
		"lesson blames the early burn",
		string.find(report.keyLesson, "Your rice field", 1, true) ~= nil,
		report.keyLesson
	)
end

-- 16.4: exposure points are never presented as measured PM2.5.
do
	local input = baseInput()
	input.burns = {
		{
			field = "Your rice field",
			quantity = 8,
			time = 240,
			wind = "East",
			destination = "Village",
			exposure = 20,
			potential = 20,
			responsibility = "PlayerFarmDeadline",
		},
	}
	input.bottleneck = { machine = "Pellet mill", at = 400, blockedSeconds = 32 }
	local report = SeasonResults.compute(input)
	local offending: { string } = {}
	local function scan(value: any, path: string)
		if typeof(value) == "string" then
			local lower = string.lower(value)
			local mentions = string.find(lower, "pm2.5", 1, true)
				or string.find(lower, "microgram", 1, true)
				or string.find(lower, "ug/m", 1, true)
			if mentions and path ~= "cleanAir.disclaimer" then
				table.insert(offending, path)
			end
		elseif typeof(value) == "table" then
			for key, child in value do
				scan(child, if path == "" then tostring(key) else path .. "." .. tostring(key))
			end
		end
	end
	scan(report, "")
	check("no result text calls points PM2.5", #offending == 0, table.concat(offending, ", "))
	local disclaimer = string.lower(report.cleanAir.disclaimer)
	check(
		"disclaimer says the points are not measured",
		string.find(disclaimer, "not measured", 1, true) ~= nil
	)
	check(
		"bottleneck names the machine and time",
		string.find(report.bottleneck, "pellet mill backed up at 6:40", 1, true) ~= nil,
		report.bottleneck
	)
	check("em dash free", string.find(report.keyLesson, "\u{2014}", 1, true) == nil)
end

-- 12.5: the first machine blocked past the threshold is the bottleneck.
do
	local log = SeasonResults.newBottleneckLog()
	for second = 1, 10 do
		SeasonResults.trackBottlenecks(log, {
			[1] = { name = "Dryer", state = "Processing" },
			[2] = { name = "Shredder", state = "Blocked" },
		}, 1, 100 + second, 15)
	end
	check("not yet a bottleneck", log.first == nil)
	SeasonResults.trackBottlenecks(log, {
		[2] = { name = "Shredder", state = "Starved" },
	}, 1, 111, 15)
	for second = 1, 15 do
		SeasonResults.trackBottlenecks(log, {
			[2] = { name = "Shredder", state = "Blocked" },
		}, 1, 200 + second, 15)
	end
	local first = log.first
	check("bottleneck found", first ~= nil and first.machine == "Shredder")
	check(
		"bottleneck start time",
		first ~= nil and first.at == 200,
		if first then tostring(first.at) else "nil"
	)
	check("total blocked time", first ~= nil and first.blockedSeconds == 25)
end

print(string.format("\n%d passed, %d failed", passes, failures))
if failures > 0 then
	error(string.format("%d season checks failed", failures))
end
