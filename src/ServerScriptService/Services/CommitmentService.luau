--!strict

-- Neighboring farm commitments for Farm_B and Farm_C (spec v0.2 section 10).
-- The rules live in Simulation/FarmCommitments; this service owns prompts, billboards,
-- rewards, and burns. Missed or unserved farms burn through SmokeService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CommitmentDefinitions = require(Shared:WaitForChild("CommitmentDefinitions"))

local FarmBoard = require(script.Parent:WaitForChild("FarmBoard"))
local StrawSheaf = require(script.Parent:WaitForChild("StrawSheaf"))

local Simulation = script.Parent.Parent:WaitForChild("Simulation")
local FarmCommitments = require(Simulation:WaitForChild("FarmCommitments"))

local CommitmentService = {}

local UPDATE_SECONDS = 0.5

type FarmView = {
	model: Model,
	burnPoint: BasePart,
	board: Board,
	acceptPrompt: ProximityPrompt,
	rejectPrompt: ProximityPrompt,
	extendPrompt: ProximityPrompt,
	-- One standing sheaf per bundle still in the field, walked up to and picked up like Farm A.
	sheaves: { Model },
	charred: boolean,
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
	Missed = "MISSED",
	Extended = "EXTENDED",
	Burned = "BURNED",
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

type Board = FarmBoard.Board

local MUTED = FarmBoard.Colors.Muted
local STATE_COLORS: { [string]: Color3 } = {
	Available = FarmBoard.Colors.Teal,
	Accepted = FarmBoard.Colors.Gold,
	InProgress = FarmBoard.Colors.Gold,
	Extended = FarmBoard.Colors.Gold,
	Completed = FarmBoard.Colors.Green,
	Rejected = MUTED,
	Missed = FarmBoard.Colors.Red,
	Burned = FarmBoard.Colors.Red,
}

local function sheafPrompts(view: FarmView, enabled: boolean)
	for _, sheaf in view.sheaves do
		local prompt = sheaf:FindFirstChild("PickUpPrompt", true)
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Enabled = enabled
		end
	end
end

-- Keeps the standing sheaves equal to the straw left, whoever took it (player or truck).
local function syncSheaves(view: FarmView, remaining: number, burned: boolean)
	if burned then
		if not view.charred then
			view.charred = true
			for _, sheaf in view.sheaves do
				StrawSheaf.Char(sheaf)
			end
		end
		return
	end
	while #view.sheaves > remaining do
		local sheaf = table.remove(view.sheaves) :: Model
		sheaf:Destroy()
	end
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
	syncSheaves(view, farm.remaining, state == "Missed" or state == "Burned")
	-- Only the farm you promised to clear lets you pick up its straw.
	sheafPrompts(view, promised and open and farm.remaining > 0)
	view.extendPrompt.Enabled = promised and open and not farm.extended

	local board = view.board
	board.pillText.Text = STATE_TEXT[state] or string.upper(state)
	board.pill.BackgroundColor3 = STATE_COLORS[state] or MUTED
	if open then
		board.main.Text = string.format(
			"%d/%d bundles  ·  %s",
			farm.remaining,
			definition.Bundles,
			formatClock(farm.deadlineAt - now())
		)
		if world:GetAttribute("WeatherActive") == "Rain" and farm.remaining > 0 then
			-- Spec 11.3: loose straw in the field stays wet while it rains.
			board.detail.Text = "Raining: straw stays wet"
		elseif promised then
			board.detail.Text = if farm.extended
				then "Extended. Pick up sheaves or send a truck"
				else "Pick up sheaves or send a truck"
		else
			board.detail.Text = string.format(
				"Truck %d credits a trip  ·  Burn risk %d",
				definition.RouteFee,
				definition.BurnExposure
			)
		end
	elseif state == "Completed" then
		board.main.Text = "Field cleared"
		board.detail.Text = "All straw collected in time"
	else
		board.main.Text = string.format("%d bundles burned", farm.burnedBundles)
		board.detail.Text = "Smoke drifted downwind"
	end
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
			board = FarmBoard.Create(collectionPoint, "CommitmentStatus", definition.ShortName),
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
			extendPrompt = createPrompt(
				collectionPoint,
				"ExtendPrompt",
				string.format("Request extension (%d credits)", CommitmentDefinitions.ExtensionFee),
				definition.DisplayName,
				Enum.KeyCode.Y,
				1
			),
			sheaves = {},
			charred = false,
		}
		views[farmId] = view
		-- Accept and reject show together on the same pad; stack them so neither covers the
		-- other (positive Y moves a prompt up). Extend only shows once a promise is made.
		view.acceptPrompt.UIOffset = Vector2.new(0, 40)
		view.rejectPrompt.UIOffset = Vector2.new(0, -40)

		-- Rice rows stay as scenery but no longer block walking down the lanes.
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") and child.Name == "RiceRow" then
				child.CanCollide = false
			end
		end
		local oldCollect = collectionPoint:FindFirstChild("CollectPrompt")
		if oldCollect then
			oldCollect:Destroy()
		end
		local strawArea = model:FindFirstChild("StrawArea")
		assert(
			strawArea and strawArea:IsA("BasePart"),
			definition.ModelName .. " StrawArea is missing"
		)
		local oldSheaves = model:FindFirstChild("Sheaves")
		if oldSheaves then
			oldSheaves:Destroy()
		end
		local sheafFolder = Instance.new("Folder")
		sheafFolder.Name = "Sheaves"
		sheafFolder.Parent = model
		for index = 1, definition.Bundles do
			local sheaf, bundle = StrawSheaf.Build(StrawSheaf.GroundFor(strawArea, index), index)
			local prompt = createPrompt(
				bundle,
				"PickUpPrompt",
				"Pick up",
				definition.DisplayName .. " straw",
				Enum.KeyCode.E,
				0.3
			)
			prompt.MaxActivationDistance = 8
			prompt.Enabled = false
			prompt.Triggered:Connect(function(player)
				if sheaf.Parent == nil then
					return
				end
				local ok, reason = book:CanCollect(farmId, now())
				if not ok then
					machineService:Notify(player, reason)
					return
				end
				-- Move this sheaf to the end so the sync removes exactly the one picked up.
				local position = table.find(view.sheaves, sheaf)
				if position then
					table.remove(view.sheaves, position)
					table.insert(view.sheaves, sheaf)
				end
				if self:TakeStraw(farmId, 1) > 0 then
					playerState:AddStraw(player, 1)
				end
			end)
			sheaf.Parent = sheafFolder
			table.insert(view.sheaves, sheaf)
		end

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
