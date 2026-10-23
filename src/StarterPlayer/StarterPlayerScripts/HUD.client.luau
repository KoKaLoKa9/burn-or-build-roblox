--!strict

-- Top-left player status. Credits and carried straw stay on screen as two small chips. A Stats
-- button (or C) opens the rest: a status card (season clock and phase, weather forecast, crates,
-- wind, trust, exposure points) and a farm contracts card (spec 10.2 states and 11.4 burn
-- feedback). A red dot on the button flags a new burn or forecast while the panel is closed. Values come from player, farm, and world attributes that the server owns;
-- this script only displays them. The end of season screen lives in SeasonResultsScreen.client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

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

-- Always-on chips -------------------------------------------------------------------------------
-- Only money and carried straw stay on screen. Everything else waits behind the Stats button.

local CHIP_WIDTH = 168

local function createChip(
	className: string,
	name: string,
	order: number,
	buildIcon: (Frame) -> ()
): (GuiObject, TextLabel, UIStroke)
	local chip = Instance.new(className) :: GuiObject
	chip.Name = name
	chip.Size = UDim2.fromOffset(CHIP_WIDTH, 44)
	chip.BackgroundColor3 = Colors.Panel
	chip.BackgroundTransparency = 0.08
	chip.BorderSizePixel = 0
	chip.LayoutOrder = order
	chip.Parent = column
	if chip:IsA("TextButton") then
		chip.Text = ""
		chip.AutoButtonColor = true
	end
	UITheme.corner(chip, 12)
	local stroke = UITheme.outline(chip)

	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 10, 0.5, 0)
	icon.Size = UDim2.fromOffset(26, 26)
	icon.BackgroundTransparency = 1
	icon.Parent = chip
	buildIcon(icon)

	local value = UITheme.text(chip, {
		name = "Value",
		size = UDim2.new(1, -52, 1, 0),
		font = Fonts.Heavy,
		textSize = 20,
	})
	value.Position = UDim2.fromOffset(44, 0)
	value.TextTruncate = Enum.TextTruncate.AtEnd
	return chip, value, stroke
end

local function iconPart(
	parent: Instance,
	name: string,
	size: UDim2,
	position: UDim2,
	color: Color3
): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

-- A gold coin with a rim and a small shine.
local function coinIcon(icon: Frame)
	local coin =
		iconPart(icon, "Coin", UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), Colors.Gold)
	UITheme.corner(coin, 13)
	UITheme.outline(coin, Color3.fromRGB(176, 124, 30), 0, 2)
	local rim =
		iconPart(coin, "Rim", UDim2.fromOffset(14, 14), UDim2.fromScale(0.5, 0.5), Colors.Gold)
	rim.BackgroundTransparency = 1
	UITheme.corner(rim, 7)
	UITheme.outline(rim, Color3.fromRGB(196, 140, 40), 0, 1.5)
	local shine =
		iconPart(coin, "Shine", UDim2.fromOffset(5, 5), UDim2.fromOffset(8, 7), Color3.new(1, 1, 1))
	shine.BackgroundTransparency = 0.35
	UITheme.corner(shine, 3)
end

-- A tied bundle of rice straw.
local function strawIcon(icon: Frame)
	for index, rotation in { -14, 0, 14 } do
		local stalk = iconPart(
			icon,
			"Stalk" .. index,
			UDim2.fromOffset(6, 24),
			UDim2.fromScale(0.5, 0.5),
			if index == 2 then Color3.fromRGB(240, 208, 118) else Colors.Straw
		)
		stalk.Rotation = rotation
		UITheme.corner(stalk, 3)
	end
	local tie = iconPart(
		icon,
		"Tie",
		UDim2.fromOffset(16, 4),
		UDim2.fromScale(0.5, 0.56),
		Color3.fromRGB(139, 98, 52)
	)
	UITheme.corner(tie, 2)
end

-- A lightning bolt: two slanted bars.
local function powerIcon(icon: Frame)
	local top =
		iconPart(icon, "BoltTop", UDim2.fromOffset(6, 14), UDim2.fromOffset(15, 8), Colors.Gold)
	top.Rotation = 24
	local bottom =
		iconPart(icon, "BoltBottom", UDim2.fromOffset(6, 14), UDim2.fromOffset(11, 18), Colors.Gold)
	bottom.Rotation = 24
	local middle =
		iconPart(icon, "BoltMiddle", UDim2.fromOffset(12, 4), UDim2.fromOffset(13, 13), Colors.Gold)
	middle.Rotation = -20
end

-- Three rising bars.
local function statsIcon(icon: Frame)
	for index, height in { 10, 16, 22 } do
		local bar = iconPart(
			icon,
			"Bar" .. index,
			UDim2.fromOffset(6, height),
			UDim2.new(0, 4 + (index - 1) * 9, 1, -2),
			Colors.Teal
		)
		bar.AnchorPoint = Vector2.new(0, 1)
		UITheme.corner(bar, 2)
	end
end

local _, creditsValue = createChip("Frame", "Credits", 1, coinIcon)
local _, strawValue = createChip("Frame", "Carrying", 2, strawIcon)
-- Power use against supply over the player's networks (PowerService).
local _, powerValue = createChip("Frame", "Power", 3, powerIcon)
local statsChip, statsLabel, statsStroke = createChip("TextButton", "StatsButton", 4, statsIcon)
local statsButton = statsChip :: TextButton
statsLabel.Text = "STATS"
statsLabel.TextSize = 16
local statsKey = UITheme.keyCap(statsButton, "C")
statsKey.AnchorPoint = Vector2.new(1, 0.5)
statsKey.Position = UDim2.new(1, -10, 0.5, 0)
-- A red dot on the button when something new (a burn, a forecast) arrives while it is closed.
local unreadDot = iconPart(
	statsButton,
	"Unread",
	UDim2.fromOffset(10, 10),
	UDim2.fromOffset(34, 10),
	Colors.Danger
)
unreadDot.Visible = false
UITheme.corner(unreadDot, 5)

-- Everything else lives in a scrolling window in the middle of the screen. Its height is capped
-- and it sits a little above centre, so it never reaches the hotbar.
local statsPanel = Instance.new("ScrollingFrame")
statsPanel.Name = "StatsPanel"
statsPanel.AnchorPoint = Vector2.new(0.5, 0.5)
statsPanel.Position = UDim2.new(0.5, 0, 0.5, -60)
statsPanel.Size = UDim2.new(0, CARD_WIDTH + 12, 0.6, 0)
statsPanel.BackgroundTransparency = 1
statsPanel.BorderSizePixel = 0
statsPanel.ScrollBarThickness = 6
statsPanel.ScrollBarImageColor3 = Colors.Muted
statsPanel.CanvasSize = UDim2.new()
statsPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
statsPanel.ScrollingDirection = Enum.ScrollingDirection.Y
statsPanel.Visible = false
statsPanel.Parent = screenGui
local statsLimit = Instance.new("UISizeConstraint")
statsLimit.MaxSize = Vector2.new(CARD_WIDTH + 12, 460)
statsLimit.Parent = statsPanel
UITheme.list(statsPanel, 10)

local statsOpen = false
local function setStatsOpen(open: boolean)
	statsOpen = open
	statsPanel.Visible = open
	statsStroke.Color = if open then Colors.Gold else Colors.Outline
	statsStroke.Transparency = if open then 0 else 0.88
	statsStroke.Thickness = if open then 2 else 1
	if open then
		unreadDot.Visible = false
	end
end

local function markUnread()
	if not statsOpen then
		unreadDot.Visible = true
	end
end

statsButton.Activated:Connect(function()
	setStatsOpen(not statsOpen)
end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.C then
		setStatsOpen(not statsOpen)
	end
end)

-- Status card ---------------------------------------------------------------------------------

local statusCard = UITheme.card("StatusCard", statsPanel, CARD_WIDTH)
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

local cratesValue = createTile(1, "Crates sold")
local windValue, windCaption = createTile(2, "Wind")
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
	local supply = readNumber("PowerSupplyKW")
	local demand = readNumber("PowerDemandKW")
	powerValue.Text = string.format("%.0f / %.0f kW", demand, supply)
	powerValue.TextColor3 = if demand > supply + 0.05 then Colors.Danger else Colors.Text

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

for _, attribute in
	{
		"Credits",
		"StrawBundles",
		"Trust",
		"Exposure",
		"CratesSold",
		"PowerSupplyKW",
		"PowerDemandKW",
	}
do
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
	local year = readWorldNumber("SeasonNumber")
	phaseCaption.Text = if over
		then "SEASON OVER"
		else string.format(
			"YEAR %d  |  PHASE %d OF %d",
			math.max(year, 1),
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

local lastWeatherState: any = nil
local function refreshForecast()
	local state = world:GetAttribute("WeatherState")
	if state ~= lastWeatherState then
		lastWeatherState = state
		if state == "Forecast" or state == "Active" then
			markUnread()
		end
	end
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

local contractsCard = UITheme.card("ContractsCard", statsPanel, CARD_WIDTH)
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
		records.ChildAdded:Connect(function(record)
			showBurnRecord(record)
			markUnread()
		end)
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
