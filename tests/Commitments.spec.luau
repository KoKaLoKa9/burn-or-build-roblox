--!strict

-- Run from the project root with: lune run tests/Commitments.spec.luau
-- Covers farm commitments (spec 10, 15.2, 16.3) and the simplified truck route (spec 7.4).

local FarmCommitments = require("../src/ServerScriptService/Simulation/FarmCommitments")
local TruckRoute = require("../src/ServerScriptService/Simulation/TruckRoute")
local ProductionLine = require("../src/ServerScriptService/Simulation/ProductionLine")
local CommitmentDefinitions = require("../src/ReplicatedStorage/Shared/CommitmentDefinitions")
local MachineDefinitions = require("../src/ReplicatedStorage/Shared/MachineDefinitions")

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

local function find(events, eventType: string, farmId: string?): any
	for _, event in events do
		if event.type == eventType and (farmId == nil or event.farmId == farmId) then
			return event
		end
	end
	return nil
end

local B_DEADLINE = 600
local C_DEADLINE = 960

-- 10.1: farm data matches the spec table.
do
	local farms = CommitmentDefinitions.Farms
	check(
		"farm B has 12 bundles, minute 10",
		farms.FarmB.Bundles == 12 and farms.FarmB.DeadlineSeconds == B_DEADLINE
	)
	check(
		"farm B route costs 50, exposure 35",
		farms.FarmB.RouteFee == 50 and farms.FarmB.BurnExposure == 35
	)
	check(
		"farm C has 16 bundles, minute 16",
		farms.FarmC.Bundles == 16 and farms.FarmC.DeadlineSeconds == C_DEADLINE
	)
	check(
		"farm C route costs 80, exposure 50",
		farms.FarmC.RouteFee == 80 and farms.FarmC.BurnExposure == 50
	)
	check("truck carries 8 bundles per trip", CommitmentDefinitions.Truck.Capacity == 8)
end

-- 10.2 and 10.4: accept, complete, and receive trust once.
do
	local book = FarmCommitments.new(CommitmentDefinitions, 0)
	local farm = book:Get("FarmB") :: any
	check("farms start Available", farm.state == "Available")
	check("cannot collect before accepting", book:Take("FarmB", 1, 10) == 0)
	check("accept succeeds", (book:Accept("FarmB", "p1")))
	check("cannot accept twice", not book:Accept("FarmB", "p1"))
	check(
		"first bundle moves to In Progress",
		book:Take("FarmB", 4, 10) == 4 and farm.state == "InProgress"
	)
	check("take is capped by remaining straw", book:Take("FarmB", 20, 20) == 8)
	check("all straw collected completes", farm.state == "Completed" and farm.resolved)
	local events = book:Update(B_DEADLINE + 5)
	local completed = find(events, "Completed", "FarmB")
	check("completion grants +10 trust", completed ~= nil and completed.trust == 10)
	check("completion grants the reliability bonus", completed ~= nil and completed.credits == 100)
	check("completed farm never burns", find(events, "Burn", "FarmB") == nil)
	check("completion pays only once", find(book:Update(B_DEADLINE + 60), "Completed") == nil)
end

-- 10.3 and 16.3: a missed promise burns only the remaining straw and costs 15 trust.
do
	local book = FarmCommitments.new(CommitmentDefinitions, 0)
	book:Accept("FarmC", "p1")
	book:Take("FarmC", 8, 100)
	check("no burn before the deadline", find(book:Update(C_DEADLINE - 1), "Burn", "FarmC") == nil)
	local burn = find(book:Update(C_DEADLINE), "Burn", "FarmC")
	check("missed commitment burns", burn ~= nil)
	check("burns only remaining 8 bundles", burn ~= nil and burn.quantity == 8)
	check("exposure scales with burned straw", burn ~= nil and burn.exposure == 25)
	check("missed costs 15 trust", burn ~= nil and burn.trust == -15)
	check(
		"responsibility is the missed commitment",
		burn ~= nil and burn.responsibility == "MissedCommitment"
	)
	local farm = book:Get("FarmC") :: any
	check("farm state is Missed", farm.state == "Missed")
	check("burn is recorded once", find(book:Update(C_DEADLINE + 30), "Burn") == nil)
end

-- 10.4 and 15.2: rejecting costs no trust and is not labelled as a broken promise.
do
	local book = FarmCommitments.new(CommitmentDefinitions, 0)
	check("reject succeeds", (book:Reject("FarmB", "p1")))
	local rejected = find(book:Drain(), "Rejected", "FarmB")
	check("reject changes trust by 0", rejected ~= nil and rejected.trust == 0)
	check("cannot collect from a rejected farm", book:Take("FarmB", 1, 10) == 0)
	local events = book:Update(B_DEADLINE)
	local burn = find(events, "Burn", "FarmB")
	check("rejected farm still burns at the deadline", burn ~= nil and burn.quantity == 12)
	check("rejected burn has full exposure", burn ~= nil and burn.exposure == 35)
	check("rejected burn costs no trust", burn ~= nil and burn.trust == 0)
	check("rejected burn is labelled Rejected", burn ~= nil and burn.responsibility == "Rejected")
	local unanswered = find(book:Update(C_DEADLINE), "Burn", "FarmC")
	check(
		"unanswered farm burns as no agreement",
		unanswered ~= nil and unanswered.responsibility == "NoAgreement"
	)
end

-- 10.2: one extension moves the deadline; a second is unavailable.
do
	local book = FarmCommitments.new(CommitmentDefinitions, 0)
	check("cannot extend before accepting", not book:Extend("FarmB", "p1", 10))
	book:Accept("FarmB", "p1")
	check("another player cannot extend", not book:Extend("FarmB", "p2", 10))
	check("extension succeeds", (book:Extend("FarmB", "p1", 10)))
	local farm = book:Get("FarmB") :: any
	check("state is Extended", farm.state == "Extended")
	check("deadline moved by 3 minutes", farm.deadlineAt == B_DEADLINE + 180)
	local extended = find(book:Drain(), "Extended", "FarmB")
	check("extension charges its fee", extended ~= nil and extended.credits == -50)
	check("second extension refused", not book:Extend("FarmB", "p1", 20))
	check("no burn at the old deadline", find(book:Update(B_DEADLINE + 1), "Burn") == nil)
	book:Take("FarmB", 4, B_DEADLINE + 10)
	check("collecting keeps the Extended state", farm.state == "Extended")
	local burn = find(book:Update(B_DEADLINE + 180), "Burn", "FarmB")
	check("extended commitment can still be missed", burn ~= nil and burn.quantity == 8)
end

-- 15.2: completing on the deadline tick resolves as completed before any burn.
do
	local book = FarmCommitments.new(CommitmentDefinitions, 0)
	book:Accept("FarmB", "p1")
	book:Take("FarmB", 8, 300)
	check("loading on the deadline tick counts", book:Take("FarmB", 8, B_DEADLINE) == 4)
	local events = book:Update(B_DEADLINE)
	check("deadline tick completion does not burn", find(events, "Burn") == nil)
	check("deadline tick completion is completed", find(events, "Completed", "FarmB") ~= nil)
	local late = FarmCommitments.new(CommitmentDefinitions, 0)
	late:Accept("FarmB", "p1")
	check("loading after the deadline is refused", late:Take("FarmB", 8, B_DEADLINE + 0.5) == 0)
end

-- 7.4: one truck trip loads 8 bundles, unloads into the intake, and charges the route fee.
local function runTruck(truck, hooks, seconds: number): { any }
	local all = {}
	for _ = 1, math.ceil(seconds / 0.5) do
		for _, event in truck:Step(0.5, hooks) do
			table.insert(all, event)
		end
	end
	return all
end

do
	local book = FarmCommitments.new(CommitmentDefinitions, 0)
	local line = ProductionLine.new(MachineDefinitions)
	local intake = line:AddNode("CollectionPoint", "p1")
	local now = 0
	local hooks = {
		take = function(farmId: string, max: number): number
			return book:Take(farmId, max, now)
		end,
		unload = function(count: number): number
			return line:Deposit(intake.id, count, "p1")
		end,
	}
	local truck = TruckRoute.new(CommitmentDefinitions.Truck, CommitmentDefinitions.Farms)
	check("dispatch needs a farm", not truck:Dispatch())
	check("assign farm B", (truck:Assign("FarmB")))
	book:Accept("FarmB", "p1")
	check("dispatch succeeds", (truck:Dispatch()))
	check("truck is Traveling", truck.state == "Traveling")
	check("cannot reassign while away", not truck:Assign("FarmC"))
	truck:Step(15, hooks)
	check("truck arrives and starts Loading", truck.state == "Loading", truck.state)
	truck:Step(4, hooks)
	check("truck leaves with 8 bundles", truck.cargo == 8 and truck.state == "Returning")
	check("loaded straw left the field", (book:Get("FarmB") :: any).remaining == 4)
	check("cannot cancel once loaded", not truck:Cancel())
	local events = runTruck(truck, hooks, 30)
	local trip = find(events, "TripCompleted", "FarmB")
	check("trip completes", trip ~= nil and trip.cargo == 8)
	check("trip charges the 50 credit route fee", trip ~= nil and trip.fee == 50)
	check("intake holds the 8 delivered bundles", #intake.output == 8)
	check("truck is Idle after the trip", truck.state == "Idle")

	-- Second trip: the intake is still full, so the truck waits as Destination Full.
	truck:Dispatch()
	runTruck(truck, hooks, 40)
	check("second trip carries the last 4", truck.state == "DestinationFull", truck.state)
	check("farm B completed by truck", (book:Get("FarmB") :: any).state == "Completed")
	check("destination full keeps the cargo", truck.cargo == 4)
	table.clear(intake.output)
	local finish = runTruck(truck, hooks, 5)
	check(
		"unloads once space frees up",
		find(finish, "TripCompleted") ~= nil and truck.state == "Idle"
	)

	-- A closed farm blocks the route and the truck returns empty without a fee.
	local blocked
	truck:Dispatch()
	blocked = runTruck(truck, hooks, 20)
	check("closed farm reports Route Blocked", truck.state == "RouteBlocked", truck.state)
	blocked = runTruck(truck, hooks, 30)
	check("blocked truck returns Idle", truck.state == "Idle", truck.state)
	check("blocked trip charges no fee", find(blocked, "TripCompleted") == nil)
end

-- 7.4: cancelling before departure returns the truck empty and takes no straw.
do
	local book = FarmCommitments.new(CommitmentDefinitions, 0)
	book:Accept("FarmC", "p1")
	local taken = 0
	local hooks = {
		take = function(farmId: string, max: number): number
			local count = book:Take(farmId, max, 0)
			taken += count
			return count
		end,
		unload = function(count: number): number
			return count
		end,
	}
	local truck = TruckRoute.new(CommitmentDefinitions.Truck, CommitmentDefinitions.Farms)
	truck:Assign("FarmC")
	truck:Dispatch()
	truck:Step(10, hooks)
	check("eta counts down on the way out", math.abs(truck:EtaSeconds() - 15) < 0.01)
	check("cancel while traveling", (truck:Cancel()))
	local events = runTruck(truck, hooks, 15)
	check("cancelled truck is back Idle", truck.state == "Idle", truck.state)
	check("cancelled truck took no straw", taken == 0)
	check("cancelled trip charges no fee", find(events, "TripCompleted") == nil)
end

-- Week 6: a completed farm replants after RegrowSeconds and opens a fresh contract.
do
	local book = FarmCommitments.new(CommitmentDefinitions, 0)
	local farmB = CommitmentDefinitions.Farms.FarmB
	book:Accept("FarmB", "player")
	book:Take("FarmB", farmB.Bundles, 10)
	book:Drain()
	local early = book:Update(10 + farmB.RegrowSeconds - 1)
	check("farm stays closed before it regrows", find(early, "Regrown", "FarmB") == nil)
	local events = book:Update(10 + farmB.RegrowSeconds)
	local farm = book:Get("FarmB")
	check("farm regrows after RegrowSeconds", find(events, "Regrown", "FarmB") ~= nil)
	check(
		"regrown farm is open with full straw",
		farm.state == "Available" and farm.remaining == farmB.Bundles and not farm.resolved
	)
	check(
		"regrown farm has the shorter next deadline",
		farm.deadlineAt == 10 + farmB.RegrowSeconds + farmB.NextDeadlineSeconds
	)
	check("regrown farm counts its round", farm.round == 2)
end

-- Week 6: completing contracts in a row raises the reliability bonus; a miss resets it.
do
	local book = FarmCommitments.new(CommitmentDefinitions, 0)
	local farmB = CommitmentDefinitions.Farms.FarmB
	local now = 0
	local bonuses = {}
	for _ = 1, 2 do
		book:Accept("FarmB", "player")
		book:Take("FarmB", farmB.Bundles, now + 1)
		local completed = find(book:Drain(), "Completed", "FarmB")
		table.insert(bonuses, completed and completed.credits or 0)
		now += 1 + farmB.RegrowSeconds
		book:Update(now)
	end
	check("first completion pays the base bonus", bonuses[1] == farmB.ReliabilityBonus)
	check(
		"second completion in a row pays 25 percent more",
		bonuses[2] == math.floor(farmB.ReliabilityBonus * 1.25 + 0.5),
		tostring(bonuses[2])
	)
	-- Accept round three and let it lapse: the streak resets.
	book:Accept("FarmB", "player")
	book:Update(now + farmB.NextDeadlineSeconds + 1)
	check("a missed round resets the streak", book:Get("FarmB").streak == 0)
end

-- Rejected and burned farms come back too, so the player gets another chance.
do
	local book = FarmCommitments.new(CommitmentDefinitions, 0)
	local farmC = CommitmentDefinitions.Farms.FarmC
	book:Reject("FarmC", "player")
	book:Update(C_DEADLINE)
	local events = book:Update(C_DEADLINE + farmC.RegrowSeconds)
	check("rejected farm regrows after it burns", find(events, "Regrown", "FarmC") ~= nil)
	check("regrown farm can be accepted again", (book:Accept("FarmC", "player")))
end

print(string.format("\n%d passed, %d failed", passes, failures))
if failures > 0 then
	error("Commitment tests failed")
end
