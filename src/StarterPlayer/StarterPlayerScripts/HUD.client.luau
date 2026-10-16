--!strict

-- Top-left player status: a status card (season clock and phase, weather forecast, credits,
-- crates, straw, wind, trust, exposure points) and a farm contracts card (spec 10.2 states and
-- 11.4 burn feedback). Values come from player, farm, and world attributes that the server owns;
-- this script only displays them. The end of season screen lives in SeasonResultsScreen.client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CommitmentDefinitions = require(Shared:WaitForChild("CommitmentDefinitions"))
local SeasonDefinitions = require(Shared:WaitForChild("SeasonDefinitions"))
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
grid.LayoutOrder = 4
grid.Parent = statusCard
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0.5, -4, 0, 50)
gridLayout.CellPadding = UDim2.fromOffset(8, 8)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

local function createTile(order: number, caption: string): (TextLabel, TextLabel)
	local tile = Instance.new("Frame")
	tile.Name = caption
	tile.BackgroundColor3 = Colors.Raised
	tile.BackgroundTransparency = 0.2
	tile.BorderSizePixel = 0
	tile.LayoutOrder = order
	tile.Parent = grid
	UITheme.corner(tile, 10)

	local captionLabel = UITheme.text(tile, {
		name = "Caption",
		text = string.upper(caption),
		size = UDim2.new(1, -16, 0, 14),
		textSize = 11,
		font = Fonts.Bold,
		color = Colors.Muted,
	})
	captionLabel.Position = UDim2.fromOffset(12, 8)
	local value = UITheme.text(tile, {
		name = "Value",
		size = UDim2.new(1, -16, 0, 22),
		textSize = 20,
		font = Fonts.Heavy,
	})
	value.Position = UDim2.fromOffset(12, 22)
	value.TextTruncate = Enum.TextTruncate.AtEnd
	return value, captionLabel
end

local creditsValue = createTile(1, "Credits")
local cratesValue = createTile(2, "Crates sold")
local strawValue = createTile(3, "Carrying")
local windValue, windCaption = createTile(4, "Wind")
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

local trustValue, trustFill = createMeter(5, "Farmer trust", Colors.Teal)
-- Spec 11.2: these are exposure points on a teaching scale, never measured PM2.5.
local exposureValue, exposureFill = createMeter(6, "Village exposure", Colors.Danger)

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

	-- Exposure points are a teaching scale, not a measured concentration (spec 11.2).
	local exposure = readNumber("Exposure")
	exposureValue.Text = string.format("%d pts", exposure)
	setFill(exposureFill, exposure / EXPOSURE_SCALE)
end

local function refreshWind()
	local direction = world:GetAttribute("WindDirection")
	local destination = world:GetAttribute("WindDestination")
	windCaption.Text = "WIND "
		.. string.upper(if typeof(direction) == "string" then direction else "East")
	windValue.Text = "To "
		.. string.lower(if typeof(destination) == "string" then destination else "Village")
	-- Smoke heading for people reads as a warning; open land does not.
	windValue.TextColor3 = if destination == "Open land" then Colors.Text else Colors.Straw
end

for _, attribute in { "Credits", "StrawBundles", "Trust", "Exposure", "CratesSold" } do
	player:GetAttributeChangedSignal(attribute):Connect(refreshStatus)
end
world:GetAttributeChangedSignal("WindDirection"):Connect(refreshWind)
world:GetAttributeChangedSignal("WindDestination"):Connect(refreshWind)
refreshStatus()
refreshWind()

-- Season clock (spec 2.3) and weather forecast (spec 11.3) -------------------------------------

local season = Instance.new("Frame")
season.Name = "Season"
season.Size = UDim2.fromScale(1, 0)
season.AutomaticSize = Enum.AutomaticSize.Y
season.BackgroundColor3 = Colors.Raised
season.BackgroundTransparency = 0.2
season.BorderSizePixel = 0
season.LayoutOrder = 2
season.Parent = statusCard
UITheme.corner(season, 10)
UITheme.padding(season, 8, 12)
UITheme.list(season, 6)

local seasonTop = Instance.new("Frame")
seasonTop.Name = "Top"
seasonTop.Size = UDim2.new(1, 0, 0, 30)
seasonTop.BackgroundTransparency = 1
seasonTop.LayoutOrder = 1
seasonTop.Parent = season
local phaseCaption = UITheme.text(seasonTop, {
	name = "PhaseCaption",
	text = "PHASE 1 OF 5",
	size = UDim2.new(0.7, 0, 0, 12),
	font = Fonts.Bold,
	textSize = 10,
	color = Colors.Muted,
})
local phaseValue = UITheme.text(seasonTop, {
	name = "Phase",
	size = UDim2.new(0.64, 0, 0, 16),
	font = Fonts.Heavy,
	textSize = 15,
	color = Colors.Gold,
})
phaseValue.Position = UDim2.fromOffset(0, 14)
phaseValue.TextTruncate = Enum.TextTruncate.AtEnd
local timeValue = UITheme.text(seasonTop, {
	name = "TimeLeft",
	size = UDim2.new(0.36, 0, 0, 24),
	font = Fonts.Heavy,
	textSize = 24,
	alignX = Enum.TextXAlignment.Right,
})
timeValue.AnchorPoint = Vector2.new(1, 0)
timeValue.Position = UDim2.new(1, 0, 0, 6)

local seasonTrack = Instance.new("Frame")
seasonTrack.Name = "Track"
seasonTrack.Size = UDim2.new(1, 0, 0, 6)
seasonTrack.BackgroundColor3 = Colors.Track
seasonTrack.BorderSizePixel = 0
seasonTrack.LayoutOrder = 2
seasonTrack.Parent = season
UITheme.corner(seasonTrack, 3)
local seasonFill = Instance.new("Frame")
seasonFill.Name = "Fill"
seasonFill.Size = UDim2.fromScale(0, 1)
seasonFill.BackgroundColor3 = Colors.Gold
seasonFill.BorderSizePixel = 0
seasonFill.Parent = seasonTrack
UITheme.corner(seasonFill, 3)
-- Phase boundaries as thin notches, so the bar reads as the spec 2.3 timeline.
for index, phase in SeasonDefinitions.Phases do
	if index > 1 then
		local notch = Instance.new("Frame")
		notch.Name = "Notch_" .. phase.Id
		notch.AnchorPoint = Vector2.new(0.5, 0)
		notch.Position = UDim2.fromScale(phase.StartMinute / SeasonDefinitions.BaseMinutes, 0)
		notch.Size = UDim2.new(0, 2, 1, 0)
		notch.BackgroundColor3 = Colors.Panel
		notch.BorderSizePixel = 0
		notch.ZIndex = 2
		notch.Parent = seasonTrack
	end
end

local goalText = UITheme.text(season, {
	name = "Goal",
	size = UDim2.fromScale(1, 0),
	textSize = 12,
	color = Colors.Muted,
	wrap = true,
	order = 3,
})
goalText.AutomaticSize = Enum.AutomaticSize.Y

local forecastBox = Instance.new("Frame")
forecastBox.Name = "Forecast"
forecastBox.Size = UDim2.fromScale(1, 0)
forecastBox.AutomaticSize = Enum.AutomaticSize.Y
forecastBox.BackgroundColor3 = Colors.Teal
forecastBox.BackgroundTransparency = 0.82
forecastBox.BorderSizePixel = 0
forecastBox.LayoutOrder = 3
forecastBox.Visible = false
forecastBox.Parent = statusCard
UITheme.corner(forecastBox, 10)
UITheme.padding(forecastBox, 8, 10)
UITheme.list(forecastBox, 2)
local forecastTitle = UITheme.text(forecastBox, {
	name = "Title",
	size = UDim2.new(1, 0, 0, 16),
	font = Fonts.Heavy,
	textSize = 13,
	color = Colors.Teal,
	order = 1,
})
local forecastText = UITheme.text(forecastBox, {
	name = "Text",
	size = UDim2.fromScale(1, 0),
	textSize = 12,
	wrap = true,
	order = 2,
})
forecastText.AutomaticSize = Enum.AutomaticSize.Y

local function readWorldNumber(attribute: string): number
	local value = world:GetAttribute(attribute)
	return if typeof(value) == "number" then value else 0
end

local function clockText(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function refreshSeason()
	local endsAt = readWorldNumber("SeasonEndsAt")
	local duration = readWorldNumber("SeasonDuration")
	if endsAt == 0 or duration == 0 then
		phaseValue.Text = "Waiting for server"
		timeValue.Text = ""
		goalText.Text = ""
		return
	end

	local over = world:GetAttribute("SeasonOver") == true
	local left = if over then 0 else endsAt - workspace:GetServerTimeNow()
	timeValue.Text = clockText(left)
	-- The last two minutes read as urgent.
	timeValue.TextColor3 = if not over and left < 120 then Colors.Danger else Colors.Text
	seasonFill.Size = UDim2.fromScale(math.clamp(1 - left / duration, 0, 1), 1)

	local phaseId = world:GetAttribute("SeasonPhase")
	local phaseIndex = 0
	for index, phase in SeasonDefinitions.Phases do
		if phase.Id == phaseId then
			phaseIndex = index
		end
	end
	phaseCaption.Text = if over
		then "SEASON OVER"
		else string.format(
			"PHASE %d OF %d  |  TIME LEFT",
			phaseIndex,
			#SeasonDefinitions.Phases
		)
	local phaseName = world:GetAttribute("SeasonPhaseName")
	local goal = world:GetAttribute("SeasonGoal")
	phaseValue.Text = if typeof(phaseName) == "string" then phaseName else ""
	goalText.Text = if typeof(goal) == "string" then goal else ""
end

type WeatherStyle = { title: string, color: Color3 }
local WEATHER_STYLE: { [string]: WeatherStyle } = {
	Forecast = { title = "FORECAST", color = Colors.Teal },
	Active = { title = "WEATHER NOW", color = Colors.Gold },
	Cleared = { title = "WEATHER", color = Colors.Muted },
}

local function refreshForecast()
	local state = world:GetAttribute("WeatherState")
	local name = world:GetAttribute("WeatherName")
	local style = if typeof(state) == "string" then WEATHER_STYLE[state] else nil
	if style == nil or typeof(name) ~= "string" then
		forecastBox.Visible = false
		return
	end
	forecastBox.Visible = true
	forecastBox.BackgroundColor3 = style.color
	forecastTitle.TextColor3 = style.color

	local serverNow = workspace:GetServerTimeNow()
	local endsAt = readWorldNumber("WeatherEndsAt")
	if state == "Forecast" then
		local startsIn = clockText(readWorldNumber("WeatherStartsAt") - serverNow)
		forecastTitle.Text = string.format("%s  %s in %s", style.title, name, startsIn)
	elseif state == "Active" and endsAt > 0 then
		local endsIn = clockText(endsAt - serverNow)
		forecastTitle.Text = string.format("%s  %s, %s left", style.title, name, endsIn)
	elseif state == "Active" then
		forecastTitle.Text = string.format("%s  %s", style.title, name)
	else
		forecastTitle.Text = string.format("%s  %s over", style.title, name)
	end
	local message = world:GetAttribute("WeatherMessage")
	forecastText.Text = if typeof(message) == "string" then message else ""
end

task.spawn(function()
	while true do
		refreshSeason()
		refreshForecast()
		task.wait(0.25)
	end
end)

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
