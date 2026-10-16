--!strict

-- Run from the project root with: lune run tests/ProductionLine.spec.luau

local ProductionLine = require("../src/ServerScriptService/Simulation/ProductionLine")
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

local function buildLine()
	local line = ProductionLine.new(MachineDefinitions)
	local intake = line:AddNode("CollectionPoint", "player")
	local dryer = line:AddNode("Dryer", "player")
	local shredder = line:AddNode("Shredder", "player")
	local mill = line:AddNode("PelletMill", "player")
	local buyer = line:AddNode("BuyerDepot", "player")
	assert(line:Connect(intake.id, dryer.id, 2))
	assert(line:Connect(dryer.id, shredder.id, 2))
	assert(line:Connect(shredder.id, mill.id, 2))
	assert(line:Connect(mill.id, buyer.id, 6))
	return line, intake, dryer, shredder, mill, buyer
end

local function sum(events, eventType: string): (number, number)
	local total, count = 0, 0
	for _, event in events do
		if event.type == eventType then
			total += event.amount or 0
			count += 1
		end
	end
	return total, count
end

-- 16.2: eight wet bundles from the starter field become four pellet crates.
do
	local line, intake, _, _, mill = buildLine()
	check("intake accepts 8 bundles", line:Deposit(intake.id, 10) == 8)
	local all = {}
	for _ = 1, 300 do
		for _, event in line:Step(1) do
			table.insert(all, event)
		end
	end
	local revenue, sales = sum(all, "Sale")
	local cost, cycles = sum(all, "OperatingCost")
	check("4 crates sold", sales == 4, tostring(sales))
	check("revenue is exactly 600", revenue == 600, tostring(revenue))
	check("4 mill cycles charge exactly 120", cycles == 4 and cost == 120, tostring(cost))
	check("mill ends starved", mill.state == "Starved", mill.state)
	check("line is empty afterwards", line:IsEmpty(mill))
end

-- 4.4: the pellet mill is the bottleneck, so 8 bundles take at least 4 mill cycles.
do
	local line, intake = buildLine()
	line:Deposit(intake.id, 8)
	local soldBy80 = 0
	for _ = 1, 80 do
		local _, count = sum(line:Step(1), "Sale")
		soldBy80 += count
	end
	check("mill rate caps sales at 3 per minute", soldBy80 <= 4, tostring(soldBy80))
end

-- 14.2: starved state names the missing material and quantity.
do
	local line, _, dryer, _, mill = buildLine()
	line:Step(0.5)
	check("dryer starved reason", dryer.reason == "Missing 1 WetStraw", dryer.reason)
	check("mill starved reason", mill.reason == "Missing 2 ShreddedStraw", mill.reason)
end

-- 4.3: a mill with no conveyor holds its output and reports Blocked.
do
	local line = ProductionLine.new(MachineDefinitions)
	local intake = line:AddNode("CollectionPoint")
	local dryer = line:AddNode("Dryer")
	local shredder = line:AddNode("Shredder")
	local mill = line:AddNode("PelletMill")
	line:Connect(intake.id, dryer.id, 1)
	line:Connect(dryer.id, shredder.id, 1)
	line:Connect(shredder.id, mill.id, 1)
	line:Deposit(intake.id, 8)
	for _ = 1, 200 do
		line:Step(1)
	end
	check("unconnected mill is blocked", mill.state == "Blocked", mill.state)
	check(
		"blocked reason names missing conveyor",
		mill.reason == "Output full, no conveyor connected",
		mill.reason
	)
	-- The mill checks output room before starting, so it stops after one crate.
	check("finished crate is kept, not discarded", #mill.output + #mill.held == 1)
	check("blocked mill keeps its inputs", #mill.input == 4, tostring(#mill.input))
	local ok = line:RemoveNode(mill.id)
	check("cannot dismantle a machine holding items", not ok)
end

-- 3.3: incompatible ports reject the link with a reason.
do
	local line = ProductionLine.new(MachineDefinitions)
	local dryer = line:AddNode("Dryer")
	local mill = line:AddNode("PelletMill")
	local link, message = line:Connect(dryer.id, mill.id, 2)
	check("dryer cannot feed pellet mill", link == nil)
	check("wrong port message", string.find(message, "cannot carry", 1, true) ~= nil, message)

	local shredder = line:AddNode("Shredder")
	local shredder2 = line:AddNode("Shredder")
	line:Connect(dryer.id, shredder.id, 2)
	local second = line:Connect(dryer.id, shredder2.id, 2)
	check("one output feeds one line without a splitter", second == nil)
end

-- 4.3: pausing preserves progress.
do
	local line = ProductionLine.new(MachineDefinitions)
	local intake = line:AddNode("CollectionPoint")
	local dryer = line:AddNode("Dryer")
	line:Connect(intake.id, dryer.id, 1)
	line:Deposit(intake.id, 1)
	line:Step(4)
	local progress = dryer.progress
	line:SetPaused(dryer.id, true)
	line:Step(20)
	check("paused dryer reports Paused", dryer.state == "Paused")
	check("pause keeps progress", dryer.progress == progress)
	line:SetPaused(dryer.id, false)
	line:Step(10)
	check("resumed dryer completes", dryer.completedCycles == 1)
end

-- 15.3: a crate identifier pays only once.
do
	local line = ProductionLine.new(MachineDefinitions)
	local buyer = line:AddNode("BuyerDepot")
	local crate = { id = 999, item = "PelletCrate", owner = "player" }
	line:_deliver(buyer, crate)
	line:_deliver(buyer, crate)
	local revenue, sales = sum(line:Step(0.1), "Sale")
	check("duplicate crate pays once", sales == 1 and revenue == 150, tostring(revenue))

	local saleLine, intake, _, _, mill, saleBuyer = buildLine()
	mill.owner = "millOwner"
	saleBuyer.owner = nil
	saleLine:Deposit(intake.id, 2, "farmer")
	local owners = {}
	for _ = 1, 120 do
		for _, event in saleLine:Step(1) do
			if event.type == "Sale" then
				table.insert(owners, event.owner)
			end
		end
	end
	check("sale pays the owner of the pellet mill", owners[1] == "millOwner", tostring(owners[1]))
end

-- 7.3: covered storage holds twelve bundles, then backs up its input conveyor.
do
	local line = ProductionLine.new(MachineDefinitions)
	local intake = line:AddNode("CollectionPoint")
	local storage = line:AddNode("CoveredStorage")
	check("storage costs 250 credits", storage.definition.Cost == 250)
	assert(line:Connect(intake.id, storage.id, 1))
	line:Step(0.5)
	check("new storage reports Empty", storage.state == "Empty", storage.state)
	check("empty storage accepts any straw", storage.reason == "Accepts any straw", storage.reason)
	for _ = 1, 2 do
		line:Deposit(intake.id, 8)
		line:Step(40)
	end
	check("storage stops at 12 bundles", #storage.output == 12, tostring(#storage.output))
	check("full storage reports Full", storage.state == "Full", storage.state)
	check("input belt backs up", (storage.inLink :: any).state == "BackedUp")
	check("overflow stays upstream", #intake.output + #(storage.inLink :: any).items == 4)
	check("cannot dismantle storage holding items", not line:RemoveNode(storage.id))
end

-- 7.3: the first accepted item locks the type and wrong material is held at the port.
do
	local line = ProductionLine.new(MachineDefinitions)
	local intake = line:AddNode("CollectionPoint")
	local storage = line:AddNode("CoveredStorage")
	assert(line:Connect(intake.id, storage.id, 1))
	line:Deposit(intake.id, 1)
	line:Step(5)
	check("first wet bundle is stored", #storage.output == 1)
	local ok, message = line:SetStorageFilter(storage.id, "DryStraw")
	check("cannot switch material while holding another", not ok, message)
	check("switch refusal names both materials", string.find(message, "WetStraw", 1, true) ~= nil)

	local dryStore = line:AddNode("CoveredStorage")
	check("filter accepts a straw type", (line:SetStorageFilter(dryStore.id, "DryStraw")))
	check("filter rejects pellet crates", not line:SetStorageFilter(dryStore.id, "PelletCrate"))
	local intake2 = line:AddNode("CollectionPoint")
	local link = line:Connect(intake2.id, dryStore.id, 1)
	check("filtered storage refuses a wet straw line", link == nil)

	-- Changing the filter after connecting holds the wrong item at the port.
	local wetStore = line:AddNode("CoveredStorage")
	local intake3 = line:AddNode("CollectionPoint")
	assert(line:Connect(intake3.id, wetStore.id, 1))
	line:SetStorageFilter(wetStore.id, "DryStraw")
	line:Deposit(intake3.id, 1)
	line:Step(5)
	check("wrong item is not stored", #wetStore.output == 0)
	check("storage reports Wrong Item", wetStore.state == "WrongItem", wetStore.state)
	check(
		"wrong item reason names required and received material",
		wetStore.reason == "Covered storage needs DryStraw, received WetStraw",
		wetStore.reason
	)
	check("wrong item waits on the belt", #(wetStore.inLink :: any).items == 1)
end

-- 7.3: paused output keeps filling; resuming releases into the next machine.
do
	local line = ProductionLine.new(MachineDefinitions)
	local intake = line:AddNode("CollectionPoint")
	local storage = line:AddNode("CoveredStorage")
	local dryer = line:AddNode("Dryer")
	local dryStore = line:AddNode("CoveredStorage")
	assert(line:Connect(intake.id, storage.id, 1))
	assert(line:Connect(storage.id, dryer.id, 1))
	assert(line:Connect(dryer.id, dryStore.id, 1))
	line:SetPaused(storage.id, true)
	line:Deposit(intake.id, 6)
	line:Step(30)
	check("paused storage keeps receiving", #storage.output == 6, tostring(#storage.output))
	check("paused storage reports Paused", storage.state == "Paused", storage.state)
	check("paused storage releases nothing", dryer.completedCycles == 0)
	line:SetPaused(storage.id, false)
	line:Step(2)
	check("resumed storage reports Releasing", storage.state == "Releasing", storage.state)
	line:Step(120)
	check("all stored bundles reach the dryer", dryer.completedCycles == 6)
	check(
		"dry storage locks to dry straw",
		dryStore.reason ~= "" and dryStore.output[1].item == "DryStraw"
	)
	check("drained storage is Empty", storage.state == "Empty", storage.state)
	check("emptied storage unlocks its type", storage.reason == "Accepts any straw")
end

-- 7.3: storage never releases an item the downstream machine cannot use.
do
	local line = ProductionLine.new(MachineDefinitions)
	local intake = line:AddNode("CollectionPoint")
	local storage = line:AddNode("CoveredStorage")
	local mill = line:AddNode("PelletMill")
	assert(line:Connect(intake.id, storage.id, 1))
	local link = line:Connect(storage.id, mill.id, 1)
	check("empty storage may feed any straw machine", link ~= nil)
	line:Deposit(intake.id, 2)
	line:Step(10)
	check("wet straw stays in storage", #storage.output == 2)
	check("mill belt stays empty", link ~= nil and #link.items == 0)
	check("storage reports Output Blocked", storage.state == "OutputBlocked", storage.state)
	check(
		"blocked reason names the downstream need",
		storage.reason == "Pellet mill needs ShreddedStraw",
		storage.reason
	)
end

-- 7.3 and 16.2: a buffer between the dryer and shredder still turns 8 bundles into 4 crates.
do
	local line = ProductionLine.new(MachineDefinitions)
	local intake = line:AddNode("CollectionPoint", "player")
	local dryer = line:AddNode("Dryer", "player")
	local storage = line:AddNode("CoveredStorage", "player")
	local shredder = line:AddNode("Shredder", "player")
	local mill = line:AddNode("PelletMill", "player")
	local buyer = line:AddNode("BuyerDepot", "player")
	assert(line:Connect(intake.id, dryer.id, 2))
	assert(line:Connect(dryer.id, storage.id, 2))
	assert(line:Connect(storage.id, shredder.id, 2))
	assert(line:Connect(shredder.id, mill.id, 2))
	assert(line:Connect(mill.id, buyer.id, 6))
	line:Deposit(intake.id, 8)
	local sales = 0
	for _ = 1, 400 do
		local _, count = sum(line:Step(1), "Sale")
		sales += count
	end
	check("buffered line sells 4 crates", sales == 4, tostring(sales))
	check("buffer is empty afterwards", line:IsEmpty(storage))
end

-- 7.4: the truck terminal is placeable but has no conveyor ports.
do
	local line = ProductionLine.new(MachineDefinitions)
	local intake = line:AddNode("CollectionPoint")
	local terminal = line:AddNode("TruckTerminal")
	local storage = line:AddNode("CoveredStorage")
	check("terminal costs 500 credits", terminal.definition.Cost == 500)
	check("terminal has no output", line:Connect(terminal.id, storage.id, 1) == nil)
	check("terminal has no input", line:Connect(intake.id, terminal.id, 1) == nil)
	check(
		"storage and terminal unlock after the first sale",
		storage.definition.UnlockAfterFirstSale and terminal.definition.UnlockAfterFirstSale
	)
end

-- Belts can be disconnected only when empty, and the ports become free again.
do
	local line = ProductionLine.new(MachineDefinitions)
	local intake = line:AddNode("CollectionPoint")
	local dryer = line:AddNode("Dryer")
	local link = assert(line:Connect(intake.id, dryer.id, 4))
	line:Deposit(intake.id, 1)
	line:Step(0.5)
	local ok = line:Disconnect(link.id)
	check("a belt carrying items stays connected", not ok)
	line:Step(10)
	ok = line:Disconnect(link.id)
	check("an empty belt disconnects", ok and intake.outLink == nil and dryer.inLink == nil)
	check("freed ports can connect again", line:Connect(intake.id, dryer.id, 4) ~= nil)
end

print(string.format("\n%d passed, %d failed", passes, failures))
if failures > 0 then
	error("ProductionLine tests failed")
end
