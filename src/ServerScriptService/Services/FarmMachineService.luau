--!strict

-- Farm machines, the first automation tier for rice farming (Week 5). Players plant and harvest
-- by hand first; a transplanter placed beside a paddy then plants its empty rows on its own, and
-- a combine harvester harvests its ripe rows. Both work through the same PaddyField rows as the
-- hand prompts, so the owner pays the normal seed cost and earns the normal grain, and harvested
-- rows still leave straw on the field. A transplanter waits until that straw is cleared, so the
-- burn or build choice stays with the player.
--
-- Week 6 adds the straw baler: it lifts the sheaves off its paddy into bales stacked beside it,
-- which counts as a clean clear (good for the soil). Anyone may take the baled straw with E and
-- carry it to the collection point.

local RunService = game:GetService("RunService")

local PaddyField = require(script.Parent:WaitForChild("PaddyField"))

local FarmMachineService = {}

local TICK_SECONDS = 0.25

type Worker = {
	record: any,
	progress: number,
	state: string, -- Working, Waiting, Blocked, Paused
	detail: string,
	rowsWorked: number,
	-- Balers only: bundles of straw waiting to be taken, and the bale stack that shows them.
	stored: number,
	stack: Model?,
}

local STATE_COLORS: { [string]: string } = {
	Working = "#68D88E",
	Waiting = "#F6BE48",
	Blocked = "#F06246",
	Paused = "#92A49D",
}

local workers: { [number]: Worker } = {}
local playerState: any
local machineServiceRef: any

local function set(worker: Worker, state: string, detail: string)
	worker.state, worker.detail = state, detail
	if state ~= "Working" then
		worker.progress = 0
	end
end

-- Decides whether the machine can work its paddy right now and, if not, why. Returns the
-- PaddyField handle to work on when it can.
local function check(worker: Worker): PaddyField.Handle?
	local record = worker.record
	local definition = record.node.definition
	local owner: Player? = record.owner
	local paddy: Model? = record.paddy
	local field = if paddy and paddy.Parent then PaddyField.ForModel(paddy) else nil
	if field == nil then
		set(worker, "Blocked", "No paddy beside this machine")
		return nil
	end
	if owner == nil or owner.Parent == nil then
		set(worker, "Paused", "Owner has left")
		return nil
	end
	if record.node.paused then
		set(worker, "Paused", "Paused")
		return nil
	end
	if not field.CanUse(owner) then
		set(worker, "Blocked", "This paddy belongs to another player")
		return nil
	end

	local status = field.Status()
	if definition.FarmAction == "Bale" then
		if status.clearing then
			set(worker, "Waiting", "Straw is burning")
		elseif worker.stored >= definition.Capacity then
			set(worker, "Blocked", "Full: take the straw with E")
		elseif status.sheaves == 0 then
			set(worker, "Waiting", "No straw on the field")
		else
			set(worker, "Working", string.format("Baling, %d sheaves left", status.sheaves))
			return field
		end
		return nil
	end
	if definition.FarmAction == "Plant" then
		if status.clearing then
			set(worker, "Waiting", "Straw is burning")
		elseif status.sheaves > 0 then
			set(worker, "Waiting", "Clear the straw first")
		elseif status.empty == 0 then
			set(worker, "Waiting", "Every row is planted")
		elseif playerState:GetCredits(owner) < field.planting.SeedCost then
			set(
				worker,
				"Blocked",
				string.format("Needs %d credits for seed", field.planting.SeedCost)
			)
		else
			set(worker, "Working", string.format("Planting, %d rows to go", status.empty))
			return field
		end
	else
		if status.ripe > 0 then
			set(worker, "Working", string.format("Harvesting, %d rows ripe", status.ripe))
			return field
		end
		set(
			worker,
			"Waiting",
			if status.growing > 0 then "Rice is growing" else "No crop to harvest"
		)
	end
	return nil
end

-- Straw bales stacked beside the baler, one bale for every two bundles it holds.
local function refreshStack(worker: Worker)
	local stack = worker.stack
	local body = worker.record.model.PrimaryPart
	if stack == nil or body == nil then
		return
	end
	local bales = math.ceil(worker.stored / 2)
	local current = #stack:GetChildren()
	for index = current + 1, bales do
		local bale = Instance.new("Part")
		bale.Name = "Bale"
		bale.Size = Vector3.new(2.6, 1.6, 1.8)
		local column = (index - 1) % 3
		local layer = (index - 1) // 3
		bale.CFrame = body.CFrame
			* CFrame.new(
				-body.Size.X / 2 - 2,
				-body.Size.Y / 2 + 0.8 + layer * 1.6,
				(column - 1) * 2
			)
		bale.Color = Color3.fromRGB(226, 185, 83)
		bale.Material = Enum.Material.Grass
		bale.Anchored = true
		bale.CanCollide = false
		bale.CanQuery = false
		bale.Parent = stack
	end
	for index = current, bales + 1, -1 do
		local bale = stack:GetChildren()[index]
		if bale then
			bale:Destroy()
		end
	end
end

local function step(worker: Worker, dt: number)
	local field = check(worker)
	if field == nil then
		return
	end
	local definition = worker.record.node.definition
	worker.progress += dt
	if worker.progress < definition.WorkSeconds then
		return
	end
	worker.progress = 0
	if definition.FarmAction == "Bale" then
		if field.TakeSheaf() then
			worker.stored += 1
			worker.rowsWorked += 1
			refreshStack(worker)
		end
		return
	end
	local owner = worker.record.owner :: Player
	local ok, reason
	if definition.FarmAction == "Plant" then
		ok, reason = field.PlantNext(owner)
	else
		ok, reason = field.HarvestNext(owner)
	end
	if ok then
		worker.rowsWorked += 1
	else
		set(worker, "Blocked", (string.gsub(reason, "%.$", "")))
	end
end

local function describe(record: any): string
	local worker = workers[record.node.id]
	local definition = record.node.definition
	if worker == nil then
		return definition.DisplayName
	end
	local progress = ""
	if worker.state == "Working" then
		local share = math.clamp(worker.progress / definition.WorkSeconds, 0, 1)
		local filled = math.floor(share * 5 + 0.5)
		progress = " [" .. string.rep("#", filled) .. string.rep(".", 5 - filled) .. "]"
	end
	local tally = if definition.FarmAction == "Bale"
		then string.format("Baled straw: %d/%d", worker.stored, definition.Capacity)
		elseif definition.FarmAction == "Plant" then string.format(
			"Rows planted: %d",
			worker.rowsWorked
		)
		else string.format("Rows harvested: %d", worker.rowsWorked)
	return string.format(
		'%s\n<font color="%s">%s</font>%s\n%s',
		definition.DisplayName,
		STATE_COLORS[worker.state] or "#F0EEE4",
		worker.detail,
		progress,
		tally
	)
end

function FarmMachineService:Initialize(machineService: any, playerStateService: any)
	playerState = playerStateService
	machineServiceRef = machineService

	machineService:RegisterKindHandler("Farm", {
		onPlaced = function(record: any)
			local worker: Worker = {
				record = record,
				progress = 0,
				state = "Waiting",
				detail = "Starting",
				rowsWorked = 0,
				stored = 0,
				stack = nil,
			}
			workers[record.node.id] = worker
			local body = record.model.PrimaryPart
			if record.node.definition.FarmAction == "Bale" and body then
				local stack = Instance.new("Model")
				stack.Name = "Bales"
				stack.Parent = record.model
				worker.stack = stack
				local take = Instance.new("ProximityPrompt")
				take.Name = "TakePrompt"
				take.ActionText = "Take baled straw"
				take.ObjectText = record.node.definition.DisplayName
				take.KeyboardKeyCode = Enum.KeyCode.E
				take.MaxActivationDistance = 16
				take.RequiresLineOfSight = false
				take.UIOffset = Vector2.new(0, 40)
				take.Parent = body
				local pause = body:FindFirstChild("PausePrompt")
				if pause and pause:IsA("ProximityPrompt") then
					pause.UIOffset = Vector2.new(0, -40)
				end
				take.Triggered:Connect(function(player)
					if worker.stored <= 0 then
						return
					end
					playerState:AddStraw(player, worker.stored)
					machineServiceRef:Notify(
						player,
						string.format(
							"Took %d bundles of baled straw. Carry it to the collection point.",
							worker.stored
						)
					)
					worker.stored = 0
					refreshStack(worker)
				end)
			end
			check(worker)
		end,
		onRemoved = function(record: any)
			workers[record.node.id] = nil
		end,
		describe = describe,
	})

	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < TICK_SECONDS then
			return
		end
		local elapsed = accumulated
		accumulated = 0
		for _, worker in workers do
			step(worker, elapsed)
		end
	end)
end

return FarmMachineService
