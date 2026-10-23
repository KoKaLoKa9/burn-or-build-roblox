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

local function countOf(units, item: string): number
	local count = 0
	for _, unit in units do
		if unit.item == item then
			count += 1
		end
	end
	return count
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

-- Week 6: wet straw goes straight into a mushroom house, and a market stall buys the baskets.
do
	local line = ProductionLine.new(MachineDefinitions)
	local intake = line:AddNode("CollectionPoint", "player")
	local house = line:AddNode("MushroomHouse", "player")
	local stall = line:AddNode("MarketStall", "player")
	check("mushroom house takes wet straw", line:Connect(intake.id, house.id, 2) ~= nil)
	check("market stall takes mushroom baskets", line:Connect(house.id, stall.id, 2) ~= nil)
	line:Deposit(intake.id, 4)
	local all = {}
	for _ = 1, 200 do
		for _, event in line:Step(1) do
			table.insert(all, event)
		end
	end
	local revenue, sales = sum(all, "Sale")
	check("4 wet straw make 2 baskets", sales == 2, tostring(sales))
	check("each basket sells for 180", revenue == 360, tostring(revenue))
end

-- Week 6: shredded straw into a pyrolysis kiln makes biochar, sold at a market stall.
do
	local line = ProductionLine.new(MachineDefinitions)
	local intake = line:AddNode("CollectionPoint", "player")
	local dryer = line:AddNode("Dryer", "player")
	local shredder = line:AddNode("Shredder", "player")
	local kiln = line:AddNode("PyrolysisKiln", "player")
	local stall = line:AddNode("MarketStall", "player")
	assert(line:Connect(intake.id, dryer.id, 2))
	assert(line:Connect(dryer.id, shredder.id, 2))
	check("kiln takes shredded straw", line:Connect(shredder.id, kiln.id, 2) ~= nil)
	check("market stall takes biochar", line:Connect(kiln.id, stall.id, 2) ~= nil)
	line:Deposit(intake.id, 6)
	local all = {}
	for _ = 1, 400 do
		for _, event in line:Step(1) do
			table.insert(all, event)
		end
	end
	local revenue, sales = sum(all, "Sale")
	local cost = sum(all, "OperatingCost")
	check("6 straw make 2 biochar sacks", sales == 2, tostring(sales))
	check("each sack sells for 240", revenue == 480, tostring(revenue))
	check("2 kiln cycles cost 20", cost == 20, tostring(cost))
end

-- The big buyer still takes only pellet crates.
do
	local line = ProductionLine.new(MachineDefinitions)
	local kiln = line:AddNode("PyrolysisKiln", "player")
	local buyer = line:AddNode("BuyerDepot", "player")
	local link, message = line:Connect(kiln.id, buyer.id, 2)
	check("buyer depot refuses biochar", link == nil, message)
end

-- Multi-port machines (docs/MachinePorts.md) ---------------------------------------------------

-- The mushroom house layout from MachinePorts.md: straw and water in, mushrooms and spent straw
-- out. Test-only definitions, so the recipe rules are checked apart from catalog balance.
local function multiPortDefinitions()
	local definitions = table.clone(MachineDefinitions) :: any
	definitions.StrawFeed = {
		DisplayName = "Straw feed",
		Kind = "Source",
		AcceptsItem = "WetStraw",
		OutputItem = "WetStraw",
		OutputCapacity = 8,
	}
	definitions.WaterTap = {
		DisplayName = "Water tap",
		Kind = "Source",
		AcceptsItem = "Water",
		OutputItem = "Water",
		OutputCapacity = 8,
	}
	definitions.TwinHouse = {
		DisplayName = "Twin house",
		Kind = "Processor",
		InputItem = "WetStraw",
		OutputItem = "Mushrooms",
		InputPerCycle = 1,
		OutputPerCycle = 2,
		CycleSeconds = 10,
		InputCapacity = 2,
		OutputCapacity = 2,
		ExtraPorts = {
			{ Name = "Water", Direction = "In", Item = "Water", PerCycle = 1, Capacity = 2 },
			{ Name = "Spent", Direction = "Out", Item = "SpentStraw", PerCycle = 1, Capacity = 1 },
		},
	}
	definitions.Compost = {
		DisplayName = "Compost yard",
		Kind = "Sink",
		Prices = { SpentStraw = 5 },
	}
	return definitions
end

-- A recipe waits for every input and names each missing one.
do
	local line = ProductionLine.new(multiPortDefinitions())
	local feed = line:AddNode("StrawFeed")
	local tap = line:AddNode("WaterTap")
	local house = line:AddNode("TwinHouse")
	check("house has four ports", #house.ports == 4, tostring(#house.ports))
	check("straw reaches the straw port", line:Connect(feed.id, house.id, 1) ~= nil)
	local refused = line:Connect(tap.id, house.id, 1, nil, "In")
	check("water cannot use the straw port", refused == nil)
	local water = line:Connect(tap.id, house.id, 1)
	check("water finds the second input", water ~= nil and water.toPort.name == "Water")
	line:Step(0.5)
	check(
		"starved reason names both inputs",
		house.reason == "Missing 1 WetStraw, 1 Water",
		house.reason
	)
	line:Deposit(feed.id, 3)
	line:Step(5)
	check("straw alone does not start a cycle", not house.cycling, house.state)
	check("only water is missing", house.reason == "Missing 1 Water", house.reason)
	check("straw input stops at its capacity", #house.input == 2, tostring(#house.input))
	line:Deposit(tap.id, 1)
	line:Step(3)
	check("both inputs start the cycle", house.cycling and #house.reserved == 2)
end

-- A cycle fills every output, and one full output blocks the machine and is named.
do
	local line = ProductionLine.new(multiPortDefinitions())
	local feed = line:AddNode("StrawFeed", "player")
	local tap = line:AddNode("WaterTap", "player")
	local house = line:AddNode("TwinHouse", "player")
	local stall = line:AddNode("MarketStall", "player")
	assert(line:Connect(feed.id, house.id, 1))
	assert(line:Connect(tap.id, house.id, 1))
	check("mushrooms leave by the main port", line:Connect(house.id, stall.id, 1) ~= nil)
	line:Deposit(feed.id, 4)
	line:Deposit(tap.id, 4)
	local all = {}
	for _ = 1, 60 do
		for _, event in line:Step(1) do
			table.insert(all, event)
		end
	end
	local _, sales = sum(all, "Sale")
	check("first cycle sends 2 baskets to the stall", sales == 2, tostring(sales))
	check("spent straw waits in its own buffer", countOf(house.output, "SpentStraw") == 1)
	check("full spent straw output blocks", house.state == "Blocked", house.state)
	check("blocked reason names the port", house.reason == "SpentStraw output full", house.reason)
	check("later inputs wait their turn", #house.input == 4, tostring(#house.input))

	local yard = line:AddNode("Compost", "player")
	local spent = line:Connect(house.id, yard.id, 1)
	check("second output gets its own belt", spent ~= nil and spent.fromPort.name == "Spent")
	all = {}
	for _ = 1, 120 do
		for _, event in line:Step(1) do
			table.insert(all, event)
		end
	end
	local revenue, count = sum(all, "Sale")
	check("4 cycles in all", house.completedCycles == 4, tostring(house.completedCycles))
	check("6 more baskets and 4 spent straw sold", count == 10, tostring(count))
	check("revenue counts both products", revenue == 6 * 180 + 4 * 5, tostring(revenue))
	check("nothing left inside", line:CountItems() == 0, tostring(line:CountItems()))
end

-- The kiln flares its syngas while no gas pipe is connected, so biochar keeps flowing.
do
	local line = ProductionLine.new(MachineDefinitions)
	local intake = line:AddNode("CollectionPoint", "player")
	local dryer = line:AddNode("Dryer", "player")
	local shredder = line:AddNode("Shredder", "player")
	local kiln = line:AddNode("PyrolysisKiln", "player")
	local gas = line:GetPort(kiln, "Gas")
	check("kiln has a gas port", gas ~= nil and gas.medium == "Gas" and gas.direction == "Out")
	assert(line:Connect(intake.id, dryer.id, 2))
	assert(line:Connect(dryer.id, shredder.id, 2))
	assert(line:Connect(shredder.id, kiln.id, 2))
	line:Deposit(intake.id, 6)
	local all = {}
	for _ = 1, 300 do
		for _, event in line:Step(1) do
			table.insert(all, event)
		end
	end
	local _, vented = sum(all, "Vented")
	check("both cycles ran without a stall", kiln.completedCycles == 2)
	check("each cycle vents one syngas", vented == 2, tostring(vented))
	check("biochar waits at the item port", countOf(kiln.output, "Biochar") == 2)
	check("no syngas is stored", countOf(kiln.output, "Syngas") + #kiln.held == 0)
	local storage = line:AddNode("CoveredStorage")
	check("belts cannot take the gas port", line:Connect(kiln.id, storage.id, 1, "Gas") == nil)
end

-- The buyer depot takes several belts at once, one per loading bay.
do
	local line = ProductionLine.new(MachineDefinitions)
	local buyer = line:AddNode("BuyerDepot", "player")
	local mills = {}
	local links = {}
	for index = 1, 4 do
		local mill = line:AddNode("PelletMill", "player")
		mills[index] = mill
		links[index] = line:Connect(mill.id, buyer.id, 3)
	end
	check("first belt uses the main bay", links[1] ~= nil and links[1].toPort.name == "In")
	check("second belt uses bay 2", links[2] ~= nil and links[2].toPort.name == "In2")
	check("third belt uses bay 3", links[3] ~= nil and links[3].toPort.name == "In3")
	check("a fourth belt is refused", links[4] == nil)
	check("main bay is still the inLink", buyer.inLink == links[1])
	for index = 1, 3 do
		table.insert(mills[index].output, { id = 1000 + index, item = "PelletCrate", owner = "p" })
	end
	local revenue, sales = sum(line:Step(10), "Sale")
	check("crates from all three belts sell", sales == 3 and revenue == 450, tostring(sales))
	check("an empty bay belt disconnects", line:Disconnect(links[2].id))
	local again = line:Connect(mills[4].id, buyer.id, 3, nil, "In2")
	check("a freed bay takes a new belt", again ~= nil and again.toPort.name == "In2")
	check("the depot holds three links", #line:LinksOf(buyer) == 3)
end

-- Power: with power switched on, a machine without a network stops and a brownout slows it.
do
	local line = ProductionLine.new(MachineDefinitions)
	line:SetPowerEnabled(true)
	local dryer = line:AddNode("Dryer", "p")
	table.insert(dryer.input, { id = 1, item = "WetStraw", owner = "p" })
	line:Step(1)
	check("an unpowered dryer starts its cycle", dryer.cycling)
	check("an unpowered dryer asks for power", line:PowerDemand(dryer) == 4)
	line:Step(20)
	check(
		"an unpowered dryer makes nothing",
		#dryer.output == 0 and dryer.state == "NoPower",
		dryer.state
	)
	line:SetPowerRatio(dryer.id, 0.5)
	line:Step(7)
	check("half power is half speed", #dryer.output == 0, tostring(#dryer.output))
	line:Step(8.2)
	check("half power finishes in double time", #dryer.output == 1, tostring(#dryer.output))
	check("a waiting dryer draws nothing", line:PowerDemand(dryer) == 0)
end

-- Power off (the default) keeps every older line at full speed.
do
	local line = ProductionLine.new(MachineDefinitions)
	local dryer = line:AddNode("Dryer", "p")
	table.insert(dryer.input, { id = 1, item = "WetStraw", owner = "p" })
	line:Step(8)
	check("power off runs at full speed", #dryer.output == 1)
end

-- A straw furnace burns dry straw, makes power per cycle and reports each burn for smog.
do
	local line = ProductionLine.new(MachineDefinitions)
	local intake = line:AddNode("CollectionPoint", "p")
	local dryer = line:AddNode("Dryer", "p")
	local furnace = line:AddNode("StrawGenerator", "p")
	assert(line:Connect(intake.id, dryer.id, 1))
	local link = line:Connect(dryer.id, furnace.id, 1)
	check("a belt feeds the furnace", link ~= nil)
	line:Deposit(intake.id, 3, "p")
	line:Step(1)
	check(
		"an empty furnace is out of fuel",
		furnace.state == "Starved" and furnace.powerOutput == 0
	)
	local burned = 0
	for _ = 1, 3 do
		for _, event in line:Step(15) do
			if event.type == "FuelBurned" then
				burned += 1
			end
		end
	end
	check("each bundle burned is reported", burned == 2, tostring(burned))
	check("the furnace generates while fuelled", furnace.powerOutput == 15)
end

-- Diesel charges money per cycle; solar follows the sun; the crank runs down.
do
	local line = ProductionLine.new(MachineDefinitions)
	local diesel = line:AddNode("DieselGenerator", "p")
	local solar = line:AddNode("SolarPanel", "p")
	local crank = line:AddNode("HandCrank", "p")
	local cost = 0
	for _, event in line:Step(20.5) do
		if event.type == "OperatingCost" then
			cost += event.amount
		end
	end
	check("diesel costs money per cycle", cost == 10, tostring(cost))
	check("diesel generates", diesel.powerOutput == 20)
	check("solar generates in sun", solar.powerOutput == 3)
	line:SetSunFactor(0.5)
	line:Step(0.1)
	check("smog dims solar", solar.powerOutput == 1.5, tostring(solar.powerOutput))
	check("an uncranked crank is idle", crank.powerOutput == 0)
	line:Crank(crank.id, 20)
	line:Crank(crank.id, 20)
	line:Crank(crank.id, 40)
	check("cranking caps at a minute", crank.crankSeconds == 60, tostring(crank.crankSeconds))
	line:Step(1)
	check("a cranked crank generates", crank.powerOutput == 8)
	line:Step(60)
	check("the crank runs down", crank.powerOutput == 0)
	line:SetPaused(diesel.id, true)
	line:Step(0.1)
	check("a switched off diesel stops", diesel.powerOutput == 0)
end

-- Fluids: a pump fills a pipe with water, a boiler turns water and dry straw into steam, and a
-- turbine makes power from the steam.
do
	local line = ProductionLine.new(MachineDefinitions)
	local pump = line:AddNode("WaterPump", "p")
	local boiler = line:AddNode("Boiler", "p")
	local turbine = line:AddNode("SteamTurbine", "p")
	local dryer = line:AddNode("Dryer", "p")
	check("the pump has no input port", line:GetPort(pump, "In") == nil)
	check("the pump outputs fluid", (line:GetPort(pump, "Out") :: any).medium == "Fluid")
	local wrong = line:Connect(pump.id, dryer.id, 2)
	check("water cannot run into a dryer", wrong == nil)
	local water = line:Connect(pump.id, boiler.id, 2, "Out", "Water")
	check("a pipe joins the pump to the boiler", water ~= nil)
	local steam = line:Connect(boiler.id, turbine.id, 1)
	check("a gas pipe joins the boiler to the turbine", steam ~= nil)
	table.insert(boiler.input, { id = 5000, item = "DryStraw", owner = "p" })
	line:Step(5)
	check("pumped water reaches the boiler", countOf(boiler.input, "Water") >= 1 or boiler.cycling)
	check(
		"the boiler waits for its second unit of water",
		not boiler.cycling or boiler.state == "Processing"
	)
	local burned = 0
	local generated = false
	for _ = 1, 30 do
		for _, event in line:Step(1) do
			if event.type == "FuelBurned" and event.nodeId == boiler.id then
				burned += 1
			end
		end
		if turbine.powerOutput == 50 then
			generated = true
		end
	end
	check("the boiler reports its smoke", burned == 1, tostring(burned))
	check("steam drives the turbine", generated)
	check(
		"the turbine used the steam",
		turbine.completedCycles >= 4,
		tostring(turbine.completedCycles)
	)
end

-- Pipes carry fluids closer together than belts carry bundles.
do
	local line = ProductionLine.new(MachineDefinitions)
	local pump = line:AddNode("WaterPump", "p")
	local tank = line:AddNode("WaterTank", "p")
	local link = line:Connect(pump.id, tank.id, 10)
	check("a pump fills a water tank", link ~= nil)
	for index = 1, 4 do
		table.insert(pump.output, { id = 6000 + index, item = "Water", owner = "p" })
	end
	line:Step(1)
	check(
		"several water units enter a pipe within a second",
		#(link :: any).items >= 3,
		tostring(#(link :: any).items)
	)
end

-- Biogas: a cattle shed turns straw and water into manure; a digester turns shredded straw,
-- manure and water into biogas (gas pipe) and digestate (belt); a biogas engine burns the gas.
do
	local line = ProductionLine.new(MachineDefinitions)
	local shed = line:AddNode("CattleShed", "p")
	local digester = line:AddNode("Digester", "p")
	local engine = line:AddNode("GasEngine", "p")
	local stall = line:AddNode("MarketStall", "p")
	check(
		"manure belts from the shed to the digester",
		line:Connect(shed.id, digester.id, 2, nil, "Manure") ~= nil
	)
	check("biogas pipes to the engine", line:Connect(digester.id, engine.id, 2) ~= nil)
	local digestateLink = line:Connect(digester.id, stall.id, 2, "Digestate")
	check("digestate belts to a market stall", digestateLink ~= nil)
	for index = 1, 4 do
		table.insert(shed.input, { id = 7000 + index, item = "WetStraw", owner = "p" })
	end
	for index = 1, 2 do
		table.insert(shed.input, { id = 7100 + index, item = "Water", owner = "p" })
	end
	for index = 1, 2 do
		table.insert(digester.input, { id = 7200 + index, item = "ShreddedStraw", owner = "p" })
	end
	for index = 1, 4 do
		table.insert(digester.input, { id = 7300 + index, item = "Water", owner = "p" })
	end
	local sales, revenue, ran = 0, 0, false
	for _ = 1, 90 do
		for _, event in line:Step(1) do
			if event.type == "Sale" then
				sales += 1
				revenue += event.amount
			end
		end
		if engine.powerOutput == 40 then
			ran = true
		end
	end
	check("the shed made manure", shed.completedCycles >= 1, tostring(shed.completedCycles))
	check(
		"the digester ran on shed manure",
		digester.completedCycles >= 1,
		tostring(digester.completedCycles)
	)
	check("biogas ran the engine", ran)
	check(
		"digestate sold at the stall",
		sales >= 1 and revenue == sales * 60,
		sales .. " " .. revenue
	)
end

-- An unhandled by-product stops the digester, like Industrialist's residue.
do
	local line = ProductionLine.new(MachineDefinitions)
	local digester = line:AddNode("Digester", "p")
	for index = 1, 4 do
		table.insert(digester.input, { id = 7400 + index, item = "ShreddedStraw", owner = "p" })
		table.insert(digester.input, { id = 7500 + index, item = "Manure", owner = "p" })
	end
	for index = 1, 8 do
		table.insert(digester.input, { id = 7600 + index, item = "Water", owner = "p" })
	end
	line:Step(200)
	check(
		"a full digestate store blocks the digester",
		digester.state == "Blocked",
		digester.state .. " " .. digester.reason
	)
end

print(string.format("\n%d passed, %d failed", passes, failures))
if failures > 0 then
	error("ProductionLine tests failed")
end
