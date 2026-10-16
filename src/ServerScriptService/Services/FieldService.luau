--!strict

local Players = game:GetService("Players")

local StrawSheaf = require(script.Parent:WaitForChild("StrawSheaf"))

local FieldService = {}

local CHARRED_ROW = Color3.fromRGB(52, 45, 38)
-- Sheaves stand in the lanes between rice rows, at varied depths so the field looks harvested.
local LANE_SPACING = 9
local LANE_COUNT = 8
local SHEAF_DEPTHS = { -20, 12, -6, 22, -14, 4, 18, -24 }

local function setFieldState(fieldModel: Model, state: string, remainingBundles: number)
	fieldModel:SetAttribute("State", state)
	fieldModel:SetAttribute("RemainingBundles", remainingBundles)
end

local function createPrompt(
	parent: BasePart,
	name: string,
	actionText: string,
	objectText: string,
	keyboardKey: Enum.KeyCode,
	holdDuration: number
): ProximityPrompt
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("ProximityPrompt") then
		existing:Destroy()
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = keyboardKey
	prompt.HoldDuration = holdDuration
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function createStatusGui(collectionPoint: BasePart, displayName: string): TextLabel
	local old = collectionPoint:FindFirstChild("FieldStatus")
	if old then
		old:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "FieldStatus"
	billboard.Size = UDim2.fromOffset(260, 92)
	billboard.StudsOffset = Vector3.new(0, 7, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = collectionPoint

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

	label.Text = displayName
	return label
end

function FieldService:Initialize(
	world: Model,
	playerStateService: any,
	smokeService: any,
	gameConfig: any
)
	local fieldDefinition = gameConfig.Fields.FarmA
	local fieldModel = world:FindFirstChild(fieldDefinition.ModelName, true)
	assert(fieldModel and fieldModel:IsA("Model"), "Farm_A model is missing from the graybox")

	local collectionPoint = fieldModel:FindFirstChild("CollectionPoint")
	local burnPoint = fieldModel:FindFirstChild("BurnPoint")
	assert(collectionPoint and collectionPoint:IsA("BasePart"), "Farm_A CollectionPoint is missing")
	assert(burnPoint and burnPoint:IsA("BasePart"), "Farm_A BurnPoint is missing")

	local remainingBundles = fieldDefinition.Bundles
	local deadlineAt = workspace:GetServerTimeNow() + fieldDefinition.DeadlineSeconds
	local resolved = false

	fieldModel:SetAttribute("DisplayName", fieldDefinition.DisplayName)
	fieldModel:SetAttribute("DeadlineAt", deadlineAt)
	setFieldState(fieldModel, "Ready", remainingBundles)

	-- Rice rows stay as scenery but no longer block walking down the lanes.
	local riceRows: { BasePart } = {}
	for _, child in fieldModel:GetChildren() do
		if child:IsA("BasePart") and child.Name == "RiceRow" then
			child.CanCollide = false
			table.insert(riceRows, child)
		end
	end

	local strawArea = fieldModel:FindFirstChild("StrawArea")
	assert(strawArea and strawArea:IsA("BasePart"), "Farm_A StrawArea is missing")
	local oldSheaves = fieldModel:FindFirstChild("Sheaves")
	if oldSheaves then
		oldSheaves:Destroy()
	end
	local sheafFolder = Instance.new("Folder")
	sheafFolder.Name = "Sheaves"
	sheafFolder.Parent = fieldModel
	local groundY = strawArea.Size.Y / 2
	local burnPrompt = createPrompt(
		burnPoint,
		"BurnPrompt",
		"Allow burning",
		"Immediate field clearing",
		Enum.KeyCode.H,
		2
	)
	local statusLabel = createStatusGui(collectionPoint, fieldDefinition.DisplayName)

	local function refreshStatus()
		local secondsLeft = math.max(0, math.ceil(deadlineAt - workspace:GetServerTimeNow()))
		statusLabel.Text = string.format(
			"%s\n%d bundles | %d:%02d remaining%s",
			fieldDefinition.DisplayName,
			remainingBundles,
			math.floor(secondsLeft / 60),
			secondsLeft % 60,
			-- Spec 11.3: loose straw left in the field stays wet in the rain.
			if world:GetAttribute("WeatherActive") == "Rain" then "\nRain: straw stays wet" else ""
		)
	end

	local function resolveClean()
		if resolved then
			return
		end
		resolved = true
		setFieldState(fieldModel, "Collected", 0)
		burnPrompt.Enabled = false
		for _, player in Players:GetPlayers() do
			playerStateService:AddNextCropValue(player, fieldDefinition.NextCropValue)
		end
		statusLabel.Text = "FIELD CLEARED\nStraw collected"
	end

	local function resolveBurn(triggeringPlayer: Player?)
		if resolved then
			return
		end
		resolved = true
		local burnedBundles = remainingBundles
		remainingBundles = 0
		setFieldState(fieldModel, "Burned", 0)
		burnPrompt.Enabled = false
		for _, row in riceRows do
			row.Color = CHARRED_ROW
		end
		for _, sheaf in sheafFolder:GetChildren() do
			if sheaf:IsA("Model") then
				StrawSheaf.Char(sheaf)
			end
		end

		if triggeringPlayer then
			playerStateService:AdjustTrust(triggeringPlayer, -fieldDefinition.BurnTrustLoss)
			playerStateService:AddNextCropValue(triggeringPlayer, fieldDefinition.NextCropValue)
		else
			for _, player in Players:GetPlayers() do
				playerStateService:AdjustTrust(player, -fieldDefinition.BurnTrustLoss)
				playerStateService:AddNextCropValue(player, fieldDefinition.NextCropValue)
			end
		end

		statusLabel.Text = string.format(
			"FIELD BURNED\nSmoke moving %s",
			string.lower(tostring(gameConfig.Wind.Label))
		)
		smokeService:BurnField(
			world,
			burnPoint,
			fieldDefinition.BurnExposure,
			playerStateService,
			gameConfig,
			{
				field = fieldDefinition.DisplayName,
				quantity = burnedBundles,
				responsibility = if triggeringPlayer
					then "PlayerAuthorized"
					else "PlayerFarmDeadline",
			}
		)
	end

	local function collectSheaf(player: Player, sheaf: Model)
		if resolved or remainingBundles <= 0 or sheaf.Parent == nil then
			return
		end
		sheaf:Destroy()
		remainingBundles -= 1
		playerStateService:AddStraw(player, 1)
		setFieldState(fieldModel, "Collecting", remainingBundles)
		if remainingBundles == 0 then
			resolveClean()
		else
			refreshStatus()
		end
	end

	-- One sheaf per bundle, walked up to and picked up by hand (spec 2.3: manual collection first).
	for index = 1, fieldDefinition.Bundles do
		local lane = (index - 1) % LANE_COUNT
		local x = (lane - (LANE_COUNT - 1) / 2) * LANE_SPACING
		local z = SHEAF_DEPTHS[(index - 1) % #SHEAF_DEPTHS + 1]
		local ground = strawArea.CFrame * CFrame.new(x, groundY, z)
		local sheaf, bundle = StrawSheaf.Build(ground, index)
		local prompt =
			createPrompt(bundle, "PickUpPrompt", "Pick up", "Rice straw sheaf", Enum.KeyCode.E, 0.3)
		prompt.MaxActivationDistance = 8
		prompt.Triggered:Connect(function(player)
			collectSheaf(player, sheaf)
		end)
		sheaf.Parent = sheafFolder
	end

	burnPrompt.Triggered:Connect(function(player)
		resolveBurn(player)
	end)

	task.spawn(function()
		while not resolved do
			refreshStatus()
			if workspace:GetServerTimeNow() >= deadlineAt then
				resolveBurn(nil)
				break
			end
			task.wait(1)
		end
	end)
end

return FieldService
