--!strict

-- Top-left player status: a status card (credits, crates, straw, wind, trust, PM2.5) and a farm
-- contracts card (spec 10.2 states and 11.4 burn feedback). Values come from player and farm
-- attributes that the server owns; this script only displays them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CommitmentDefinitions = require(Shared:WaitForChild("CommitmentDefinitions"))
local UITheme = require(script.Parent:WaitForChild("UITheme"))

local Colors = UITheme.Colors
local Fonts = UITheme.Fonts

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local world = workspace:WaitForChild("BurnOrBuildWorld")

local CARD_WIDTH = 280
local EXPOSURE_SCALE = 100

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BurnOrBuildHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local column = Instance.new("Frame")
column.Name = "LeftColumn"
column.Position = UDim2.fromOffset(16, 12)
column.Size = UDim2.fromOffset(CARD_WIDTH, 0)
column.AutomaticSize = Enum.AutomaticSize.Y
column.BackgroundTransparency = 1
column.Parent = screenGui
UITheme.list(column, 10)

local function readNumber(attribute: string): number
	local value = player:GetAttribute(attribute)
	return if typeof(value) == "number" then value else 0
end

-- Status card ---------------------------------------------------------------------------------

local statusCard = UITheme.card("StatusCard", column, CARD_WIDTH)
statusCard.LayoutOrder = 1
UITheme.padding(statusCard, 14, 14)
UITheme.list(statusCard, 10)

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 36)
header.BackgroundTransparency = 1
header.LayoutOrder = 1
header.Parent = statusCard
UITheme.text(header, {
	name = "Title",
	text = "BURN OR BUILD",
	size = UDim2.new(1, 0, 0, 20),
	font = Fonts.Heavy,
	textSize = 20,
	color = Colors.Gold,
})
UITheme.text(header, {
	name = "Subtitle",
	text = "PM2.5 Factory  |  Rice straw cooperative",
	size = UDim2.new(1, 0, 0, 14),
	textSize = 12,
	color = Colors.Muted,
}).Position =
	UDim2.fromOffset(0, 22)

local grid = Instance.new("Frame")
grid.Name = "Stats"
grid.Size = UDim2.fromScale(1, 0)
grid.AutomaticSize = Enum.AutomaticSize.Y
grid.BackgroundTransparency = 1
grid.LayoutOrder = 2
grid.Parent = statusCard
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0.5, -4, 0, 50)
gridLayout.CellPadding = UDim2.fromOffset(8, 8)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

local function createTile(order: number, caption: string): TextLabel
	local tile = Instance.new("Frame")
	tile.Name = caption
	tile.BackgroundColor3 = Colors.Raised
	tile.BackgroundTransparency = 0.2
	tile.BorderSizePixel = 0
	tile.LayoutOrder = order
	tile.Parent = grid
	UITheme.corner(tile, 10)

	UITheme.text(tile, {
		name = "Caption",
		text = string.upper(caption),
		size = UDim2.new(1, -16, 0, 14),
		textSize = 11,
		font = Fonts.Bold,
		color = Colors.Muted,
	}).Position =
		UDim2.fromOffset(12, 8)
	local value = UITheme.text(tile, {
		name = "Value",
		size = UDim2.new(1, -16, 0, 22),
		textSize = 20,
		font = Fonts.Heavy,
	})
	value.Position = UDim2.fromOffset(12, 22)
	value.TextTruncate = Enum.TextTruncate.AtEnd
	return value
end

local creditsValue = createTile(1, "Credits")
local cratesValue = createTile(2, "Crates sold")
local strawValue = createTile(3, "Carrying")
local windValue = createTile(4, "Wind")
windValue.TextSize = 16

local function createMeter(order: number, caption: string, color: Color3): (TextLabel, Frame)
	local meter = Instance.new("Frame")
	meter.Name = caption
	meter.Size = UDim2.new(1, 0, 0, 30)
	meter.BackgroundTransparency = 1
	meter.LayoutOrder = order
	meter.Parent = statusCard

	UITheme.text(meter, {
		name = "Caption",
		text = caption,
		size = UDim2.new(0.6, 0, 0, 16),
		font = Fonts.Bold,
		textSize = 13,
	})
	local value = UITheme.text(meter, {
		name = "Value",
		size = UDim2.new(0.4, 0, 0, 16),
		font = Fonts.Heavy,
		textSize = 13,
		color = color,
		alignX = Enum.TextXAlignment.Right,
	})
	value.Position = UDim2.fromScale(0.6, 0)

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, 0, 0, 6)
	track.Position = UDim2.fromOffset(0, 22)
	track.BackgroundColor3 = Colors.Track
	track.BorderSizePixel = 0
	track.Parent = meter
	UITheme.corner(track, 3)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = track
	UITheme.corner(fill, 3)
	return value, fill
end

local trustValue, trustFill = createMeter(3, "Farmer trust", Colors.Teal)
local exposureValue, exposureFill = createMeter(4, "PM2.5 exposure", Colors.Danger)

local fillTween = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function setFill(fill: Frame, ratio: number)
	TweenService:Create(fill, fillTween, { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1) })
		:Play()
end

local function refreshStatus()
	creditsValue.Text = UITheme.formatNumber(readNumber("Credits"))
	creditsValue.TextColor3 = if readNumber("Credits") < 0 then Colors.Danger else Colors.Text
	cratesValue.Text = tostring(readNumber("CratesSold"))
	local straw = readNumber("StrawBundles")
	strawValue.Text = string.format("%d %s", straw, if straw == 1 then "bundle" else "bundles")

	local trust = readNumber("Trust")
	trustValue.Text = string.format("%d / 100", trust)
	setFill(trustFill, trust / 100)

	-- Exposure points are a teaching scale, not measured micrograms (spec 11.2).
	local exposure = readNumber("Exposure")
	exposureValue.Text = string.format("%d pts", exposure)
	setFill(exposureFill, exposure / EXPOSURE_SCALE)
end

local function refreshWind()
	local direction = world:GetAttribute("WindDirection")
	windValue.Text = (if typeof(direction) == "string" then direction else "East") .. " -> Village"
end

for _, attribute in { "Credits", "StrawBundles", "Trust", "Exposure", "CratesSold" } do
	player:GetAttributeChangedSignal(attribute):Connect(refreshStatus)
end
world:GetAttributeChangedSignal("WindDirection"):Connect(refreshWind)
refreshStatus()
refreshWind()

-- Contracts card ------------------------------------------------------------------------------

local contractsCard = UITheme.card("ContractsCard", column, CARD_WIDTH)
contractsCard.LayoutOrder = 2
UITheme.padding(contractsCard, 12, 14)
UITheme.list(contractsCard, 8)

UITheme.text(contractsCard, {
	name = "Title",
	text = "FARM CONTRACTS",
	size = UDim2.new(1, 0, 0, 16),
	font = Fonts.Heavy,
	textSize = 13,
	color = Colors.Muted,
	order = 0,
})

type StateStyle = { text: string, color: Color3 }
local STATE_STYLE: { [string]: StateStyle } = {
	Available = { text = "OPEN", color = Colors.Teal },
	Accepted = { text = "ACCEPTED", color = Colors.Gold },
	InProgress = { text = "IN PROGRESS", color = Colors.Gold },
	Extended = { text = "EXTENDED", color = Colors.Gold },
	Completed = { text = "DONE", color = Colors.Good },
	Rejected = { text = "REJECTED", color = Colors.Muted },
	Missed = { text = "MISSED", color = Colors.Danger },
	Burned = { text = "BURNED", color = Colors.Danger },
}

type FarmRow = { detail: TextLabel, timer: TextLabel, pill: Frame, pillText: TextLabel }
local farmRows: { [string]: FarmRow } = {}

for index, farmId in CommitmentDefinitions.FarmOrder do
	local definition = CommitmentDefinitions.Farms[farmId]
	local row = Instance.new("Frame")
	row.Name = farmId
	row.Size = UDim2.new(1, 0, 0, 46)
	row.BackgroundColor3 = Colors.Raised
	row.BackgroundTransparency = 0.2
	row.BorderSizePixel = 0
	row.LayoutOrder = index
	row.Parent = contractsCard
	UITheme.corner(row, 10)
	UITheme.padding(row, 6, 10)

	UITheme.text(row, {
		name = "Name",
		text = definition.ShortName,
		size = UDim2.new(1, -96, 0, 18),
		font = Fonts.Bold,
		textSize = 15,
	})
	local detail = UITheme.text(row, {
		name = "Detail",
		size = UDim2.new(1, -96, 0, 14),
		textSize = 12,
		color = Colors.Muted,
	})
	detail.Position = UDim2.fromOffset(0, 19)

	local timer = UITheme.text(row, {
		name = "Timer",
		size = UDim2.fromOffset(90, 18),
		font = Fonts.Heavy,
		textSize = 15,
		alignX = Enum.TextXAlignment.Right,
	})
	timer.AnchorPoint = Vector2.new(1, 0)
	timer.Position = UDim2.fromScale(1, 0)

	local pill = Instance.new("Frame")
	pill.Name = "State"
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Position = UDim2.new(1, 0, 0, 19)
	pill.Size = UDim2.fromOffset(0, 15)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BorderSizePixel = 0
	pill.BackgroundTransparency = 0.75
	pill.Parent = row
	UITheme.corner(pill, 8)
	UITheme.padding(pill, 0, 6)
	local pillText = UITheme.text(pill, {
		name = "Label",
		size = UDim2.fromScale(0, 1),
		font = Fonts.Heavy,
		textSize = 10,
		alignX = Enum.TextXAlignment.Center,
	})
	pillText.AutomaticSize = Enum.AutomaticSize.X

	farmRows[farmId] = { detail = detail, timer = timer, pill = pill, pillText = pillText }
end

local burnBox = Instance.new("Frame")
burnBox.Name = "LastBurn"
burnBox.Size = UDim2.fromScale(1, 0)
burnBox.AutomaticSize = Enum.AutomaticSize.Y
burnBox.BackgroundColor3 = Colors.Danger
burnBox.BackgroundTransparency = 0.82
burnBox.BorderSizePixel = 0
burnBox.LayoutOrder = 99
burnBox.Visible = false
burnBox.Parent = contractsCard
UITheme.corner(burnBox, 10)
UITheme.padding(burnBox, 8, 10)
local burnText = UITheme.text(burnBox, {
	name = "Text",
	size = UDim2.fromScale(1, 0),
	textSize = 12,
	color = Color3.fromRGB(255, 214, 200),
	wrap = true,
})
burnText.AutomaticSize = Enum.AutomaticSize.Y

local OPEN_STATES =
	{ Available = true, Accepted = true, InProgress = true, Extended = true, Rejected = true }

local function refreshContracts()
	for farmId, row in farmRows do
		local definition = CommitmentDefinitions.Farms[farmId]
		local model = world:FindFirstChild(definition.ModelName)
		local state = if model then model:GetAttribute("State") else nil
		if model == nil or typeof(state) ~= "string" then
			row.detail.Text = "Waiting for server"
			row.timer.Text = ""
			row.pill.Visible = false
			continue
		end

		local style = STATE_STYLE[state] or { text = string.upper(state), color = Colors.Muted }
		row.pill.Visible = true
		row.pill.BackgroundColor3 = style.color
		row.pillText.Text = style.text
		row.pillText.TextColor3 = style.color

		local remaining = model:GetAttribute("RemainingBundles")
		local deadlineAt = model:GetAttribute("DeadlineAt")
		if
			OPEN_STATES[state]
			and typeof(deadlineAt) == "number"
			and typeof(remaining) == "number"
		then
			local seconds = math.max(0, math.ceil(deadlineAt - workspace:GetServerTimeNow()))
			row.timer.Text = string.format("%d:%02d", seconds // 60, seconds % 60)
			-- Under a minute left reads as urgent.
			row.timer.TextColor3 = if seconds < 60 then Colors.Danger else Colors.Text
			row.detail.Text = string.format("%d bundles left", remaining)
		else
			row.timer.Text = ""
			row.detail.Text = if state == "Completed" then "Field cleared" else "Season closed"
		end
	end
end

local function showBurnRecord(record: Instance)
	local responsibilityKey = record:GetAttribute("Responsibility")
	local responsibility = if typeof(responsibilityKey) == "string"
		then CommitmentDefinitions.Responsibility[responsibilityKey] or responsibilityKey
		else "Unknown"
	burnText.Text = string.format(
		"LAST BURN  %s, %d bundles\nWind %s to %s, +%d exposure. %s.",
		tostring(record:GetAttribute("Field")),
		tonumber(record:GetAttribute("Quantity")) or 0,
		tostring(record:GetAttribute("Wind")),
		tostring(record:GetAttribute("Destination")),
		tonumber(record:GetAttribute("Exposure")) or 0,
		responsibility
	)
	burnBox.Visible = true
end

task.spawn(function()
	local records = ReplicatedStorage:WaitForChild("BurnRecords", math.huge)
	if records then
		records.ChildAdded:Connect(showBurnRecord)
		local children = records:GetChildren()
		if #children > 0 then
			showBurnRecord(children[#children])
		end
	end
end)

task.spawn(function()
	while true do
		refreshContracts()
		task.wait(0.5)
	end
end)
