--!strict

-- Neighboring farm commitments for Farm_B and Farm_C (spec v0.2 section 10).
-- The rules live in Simulation/FarmCommitments; this service owns prompts, billboards,
-- rewards, and burns. Missed or unserved farms burn through SmokeService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CommitmentDefinitions = require(Shared:WaitForChild("CommitmentDefinitions"))

local Simulation = script.Parent.Parent:WaitForChild("Simulation")
local FarmCommitments = require(Simulation:WaitForChild("FarmCommitments"))

local CommitmentService = {}

local UPDATE_SECONDS = 0.5

type FarmView = {
	model: Model,
	burnPoint: BasePart,
	label: TextLabel,
	acceptPrompt: ProximityPrompt,
	rejectPrompt: ProximityPrompt,
	collectPrompt: ProximityPrompt,
	extendPrompt: ProximityPrompt,
}

local book: any
local views: { [string]: FarmView } = {}
local world: Model
local playerState: any
local smokeService: any
local machineService: any
local gameConfig: any

local STATE_TEXT: { [string]: string } = {
	Available = "AVAILABLE",
	Accepted = "ACCEPTED",
	Rejected = "REJECTED",
	InProgress = "IN PROGRESS",
	Completed = "COMPLETED",
	Missed = "MISSED, BURNED",
	Extended = "EXTENDED",
	Burned = "BURNED, NO PROMISE",
}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function asPlayer(owner: any): Player?
	if typeof(owner) == "Instance" and owner:IsA("Player") and owner.Parent ~= nil then
		return owner
	end
	return nil
end

local function formatClock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function createPrompt(
	parent: BasePart,
	name: string,
	actionText: string,
	objectText: string,
	key: Enum.KeyCode,
	holdDuration: number
): ProximityPrompt
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = key
	prompt.HoldDuration = holdDuration
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function createStatusLabel(parent: BasePart): TextLabel
	local existing = parent:FindFirstChild("CommitmentStatus")
	if existing then
		existing:Destroy()
	end
	-- The graybox label said FUTURE CONTRACT; the live status replaces it.
	local mapLabel = parent:FindFirstChild("MapLabel")
	if mapLabel and mapLabel:IsA("BillboardGui") then
		mapLabel.Enabled = false
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CommitmentStatus"
	billboard.Size = UDim2.fromOffset(300, 120)
	billboard.StudsOffset = Vector3.new(0, 9, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 220
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 29, 25)
	label.BackgroundTransparency = 0.12
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(247, 241, 220)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	return label
end

local function setRiceVisible(model: Model, visible: boolean)
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name == "RiceRow" then
			child.Transparency = if visible then 0 else 1
		end
	end
end

local function refreshFarm(farmId: string)
	local farm = book:Get(farmId)
	local view = views[farmId]
	if farm == nil or view == nil then
		return
	end
	local definition = farm.definition
	local state: string = farm.state
	local promised = state == "Accepted" or state == "InProgress" or state == "Extended"
	local open = not farm.resolved

	view.model:SetAttribute("State", state)
	view.model:SetAttribute("RemainingBundles", farm.remaining)
	view.model:SetAttribute("DeadlineAt", farm.deadlineAt)
	view.model:SetAttribute("Extended", farm.extended)
	local owner = asPlayer(farm.owner)
	view.model:SetAttribute("OwnerName", if owner then owner.DisplayName else "")

	view.acceptPrompt.Enabled = state == "Available"
	view.rejectPrompt.Enabled = state == "Available"
	view.collectPrompt.Enabled = promised and open and farm.remaining > 0
	view.extendPrompt.Enabled = promised and open and not farm.extended

	local lines = { string.format("%s: %s", definition.DisplayName, STATE_TEXT[state] or state) }
	if open then
		table.insert(
			lines,
			string.format(
				"%d of %d bundles left | deadline in %s%s",
				farm.remaining,
				definition.Bundles,
				formatClock(farm.deadlineAt - now()),
				if farm.extended then " (extended)" else ""
			)
		)
		table.insert(
			lines,
			string.format(
				"Truck %d s each way, %d credits per trip | Burn risk %d exposure",
				definition.TravelSeconds,
				definition.RouteFee,
				definition.BurnExposure
			)
		)
		if world:GetAttribute("WeatherActive") == "Rain" and farm.remaining > 0 then
			-- Spec 11.3: loose straw in the field stays wet while it rains.
			table.insert(lines, "Raining: loose straw stays wet, dryers run slower")
		end
		if state == "Available" then
			table.insert(lines, "[E] accept   hold [T] reject")
		elseif promised then
			table.insert(
				lines,
				if farm.extended
					then "[E] collect 1 bundle"
					else string.format(
						"[E] collect 1 bundle   hold [Y] extend (%d credits)",
						CommitmentDefinitions.ExtensionFee
					)
			)
		end
	elseif state == "Completed" then
		table.insert(lines, "All straw collected before the deadline")
	else
		table.insert(lines, string.format("%d bundles burned", farm.burnedBundles))
	end
	view.label.Text = table.concat(lines, "\n")
end

local function handleEvents(events: { any })
	for _, event in events do
		local farm = book:Get(event.farmId)
		local view = views[event.farmId]
		local definition = farm.definition
		local owner = asPlayer(event.owner)

		if event.type == "Extended" then
			if owner then
				playerState:AdjustCredits(owner, event.credits, "Extension")
			end
		elseif event.type == "Completed" then
			setRiceVisible(view.model, false)
			if owner then
				playerState:AdjustTrust(owner, event.trust)
				playerState:AdjustCredits(owner, event.credits, "Bonus")
				machineService:Notify(
					owner,
					string.format(
						"%s commitment completed: +%d trust, +%d credits reliability bonus.",
						definition.ShortName,
						event.trust,
						event.credits
					)
				)
			end
		elseif event.type == "Burn" then
			setRiceVisible(view.model, false)
			view.burnPoint.Color = Color3.fromRGB(62, 58, 54)
			if owner and event.trust ~= 0 then
				playerState:AdjustTrust(owner, event.trust)
			end
			local responsibility = CommitmentDefinitions.Responsibility[event.responsibility]
				or event.responsibility
			local record = smokeService:BurnField(
				world,
				view.burnPoint,
				event.exposure,
				playerState,
				gameConfig,
				{
					field = definition.DisplayName,
					quantity = event.quantity,
					responsibility = event.responsibility,
				}
			)
			-- Spec 11.4: name the source field, destination, wind, and exposure points.
			machineService:NotifyAll(
				string.format(
					"%s burned %d bundles (%s). Wind %s carries smoke to %s: +%d exposure.%s",
					definition.DisplayName,
					event.quantity,
					responsibility,
					record.wind,
					record.destination,
					record.exposure,
					if event.trust ~= 0 then string.format(" Trust %d.", event.trust) else ""
				)
			)
		end
		refreshFarm(event.farmId)
	end
end

-- Used by trucks and manual collection. Returns how many bundles left the field.
function CommitmentService:TakeStraw(farmId: string, max: number): number
	local taken = book:Take(farmId, max, now())
	handleEvents(book:Drain())
	refreshFarm(farmId)
	return taken
end

function CommitmentService:CanCollect(farmId: string): (boolean, string)
	return book:CanCollect(farmId, now())
end

function CommitmentService:Initialize(
	worldModel: Model,
	playerStateService: any,
	smoke: any,
	machines: any,
	config: any
)
	world = worldModel
	playerState = playerStateService
	smokeService = smoke
	machineService = machines
	gameConfig = config
	book = FarmCommitments.new(CommitmentDefinitions, now())

	for _, farmId in CommitmentDefinitions.FarmOrder do
		local definition = CommitmentDefinitions.Farms[farmId]
		local model = world:FindFirstChild(definition.ModelName, true)
		assert(model and model:IsA("Model"), definition.ModelName .. " is missing from the graybox")
		local collectionPoint = model:FindFirstChild("CollectionPoint")
		local burnPoint = model:FindFirstChild("BurnPoint")
		assert(
			collectionPoint and collectionPoint:IsA("BasePart"),
			definition.ModelName .. " CollectionPoint is missing"
		)
		assert(
			burnPoint and burnPoint:IsA("BasePart"),
			definition.ModelName .. " BurnPoint is missing"
		)

		model:SetAttribute("CommitmentId", farmId)
		model:SetAttribute("DisplayName", definition.DisplayName)
		model:SetAttribute("Bundles", definition.Bundles)
		model:SetAttribute("RouteFee", definition.RouteFee)
		model:SetAttribute("BurnExposure", definition.BurnExposure)

		local view: FarmView = {
			model = model,
			burnPoint = burnPoint,
			label = createStatusLabel(collectionPoint),
			acceptPrompt = createPrompt(
				collectionPoint,
				"AcceptPrompt",
				"Accept commitment",
				definition.DisplayName,
				Enum.KeyCode.E,
				0.5
			),
			rejectPrompt = createPrompt(
				collectionPoint,
				"RejectPrompt",
				"Reject commitment",
				definition.DisplayName,
				Enum.KeyCode.T,
				1.5
			),
			collectPrompt = createPrompt(
				collectionPoint,
				"CollectPrompt",
				"Collect 1 bundle",
				definition.DisplayName,
				Enum.KeyCode.E,
				0.25
			),
			extendPrompt = createPrompt(
				collectionPoint,
				"ExtendPrompt",
				string.format("Request extension (%d credits)", CommitmentDefinitions.ExtensionFee),
				definition.DisplayName,
				Enum.KeyCode.Y,
				1
			),
		}
		views[farmId] = view

		view.acceptPrompt.Triggered:Connect(function(player)
			local _, message = book:Accept(farmId, player)
			machineService:Notify(player, message)
			handleEvents(book:Drain())
			refreshFarm(farmId)
		end)
		view.rejectPrompt.Triggered:Connect(function(player)
			local _, message = book:Reject(farmId, player)
			machineService:Notify(player, message)
			handleEvents(book:Drain())
			refreshFarm(farmId)
		end)
		view.collectPrompt.Triggered:Connect(function(player)
			local ok, reason = book:CanCollect(farmId, now())
			if not ok then
				machineService:Notify(player, reason)
				return
			end
			if self:TakeStraw(farmId, 1) > 0 then
				playerState:AddStraw(player, 1)
			end
		end)
		view.extendPrompt.Triggered:Connect(function(player)
			if playerState:GetCredits(player) < CommitmentDefinitions.ExtensionFee then
				machineService:Notify(
					player,
					string.format(
						"An extension costs %d credits.",
						CommitmentDefinitions.ExtensionFee
					)
				)
				return
			end
			local _, message = book:Extend(farmId, player, now())
			machineService:Notify(player, message)
			handleEvents(book:Drain())
			refreshFarm(farmId)
		end)
		refreshFarm(farmId)
	end

	task.spawn(function()
		while true do
			handleEvents(book:Update(now()))
			for farmId in views do
				refreshFarm(farmId)
			end
			task.wait(UPDATE_SECONDS)
		end
	end)
end

return CommitmentService
