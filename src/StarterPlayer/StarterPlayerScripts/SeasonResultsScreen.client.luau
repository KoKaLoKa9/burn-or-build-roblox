--!strict

-- End of season result screen (spec v0.2 sections 12.3 to 12.5 and 16.4).
-- Profit, Clean Air, and Trust sit in three separate columns, each with its own headline
-- numbers and the causes behind them, followed by the season replay. The server builds the
-- report in Simulation/SeasonResults; this script only lays it out. Exposure is always shown
-- as exposure points with the teaching-scale disclaimer, never as measured PM2.5.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(script.Parent:WaitForChild("UITheme"))

local Colors = UITheme.Colors
local Fonts = UITheme.Fonts

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local world = workspace:WaitForChild("BurnOrBuildWorld")

local PANEL_MAX = Vector2.new(1040, 760)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SeasonResultsScreen"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 20
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled = false
screenGui.Parent = playerGui

-- A small button to bring the results back after closing them.
local reopenGui = Instance.new("ScreenGui")
reopenGui.Name = "SeasonResultsButton"
reopenGui.ResetOnSpawn = false
reopenGui.DisplayOrder = 19
reopenGui.Enabled = false
reopenGui.Parent = playerGui

local function button(parent: Instance, name: string, text: string, color: Color3): TextButton
	local item = Instance.new("TextButton")
	item.Name = name
	item.Text = text
	item.AutoButtonColor = true
	item.Size = UDim2.fromOffset(0, 36)
	item.AutomaticSize = Enum.AutomaticSize.X
	item.BackgroundColor3 = color
	item.BorderSizePixel = 0
	item.FontFace = Fonts.Heavy
	item.TextSize = 15
	item.TextColor3 = Colors.Panel
	item.Parent = parent
	UITheme.corner(item, 10)
	UITheme.padding(item, 0, 18)
	return item
end

local reopenButton = button(reopenGui, "ShowResults", "SEASON RESULTS", Colors.Gold)
reopenButton.AnchorPoint = Vector2.new(0.5, 0)
reopenButton.Position = UDim2.new(0.5, 0, 0, 8)

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.4
backdrop.BorderSizePixel = 0
backdrop.Parent = screenGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(1, -32, 1, -32)
panel.BackgroundColor3 = Colors.Panel
panel.BackgroundTransparency = 0.02
panel.BorderSizePixel = 0
panel.Parent = backdrop
UITheme.corner(panel, 14)
UITheme.outline(panel)
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize = PANEL_MAX
constraint.Parent = panel

local scroller = Instance.new("ScrollingFrame")
scroller.Name = "Content"
scroller.Size = UDim2.new(1, 0, 1, -64)
scroller.BackgroundTransparency = 1
scroller.BorderSizePixel = 0
scroller.ScrollBarThickness = 6
scroller.ScrollBarImageColor3 = Colors.Muted
scroller.CanvasSize = UDim2.new()
scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroller.ScrollingDirection = Enum.ScrollingDirection.Y
scroller.Parent = panel
UITheme.padding(scroller, 20, 22)
UITheme.list(scroller, 14)

local footer = Instance.new("Frame")
footer.Name = "Footer"
footer.AnchorPoint = Vector2.new(0, 1)
footer.Position = UDim2.fromScale(0, 1)
footer.Size = UDim2.new(1, 0, 0, 64)
footer.BackgroundTransparency = 1
footer.Parent = panel
UITheme.padding(footer, 14, 22)
local disclaimerText = UITheme.text(footer, {
	name = "Disclaimer",
	size = UDim2.new(1, -140, 1, 0),
	textSize = 12,
	color = Colors.Muted,
	wrap = true,
})
local closeButton = button(footer, "Close", "CLOSE", Colors.Text)
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.fromScale(1, 0.5)

closeButton.Activated:Connect(function()
	screenGui.Enabled = false
	reopenGui.Enabled = true
end)
reopenButton.Activated:Connect(function()
	screenGui.Enabled = true
	reopenGui.Enabled = false
end)

-- Building blocks ----------------------------------------------------------------------------

local function autoText(parent: Instance, options: UITheme.TextOptions): TextLabel
	local label = UITheme.text(parent, options)
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextWrapped = true
	return label
end

local function clearContent()
	for _, child in scroller:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function box(parent: Instance, name: string, order: number, color: Color3?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromScale(1, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = color or Colors.Raised
	frame.BackgroundTransparency = if color then 0.84 else 0.2
	frame.BorderSizePixel = 0
	frame.LayoutOrder = order
	frame.Parent = parent
	UITheme.corner(frame, 10)
	UITheme.padding(frame, 10, 12)
	UITheme.list(frame, 4)
	return frame
end

-- One headline number: caption on the left, value on the right.
local function stat(parent: Instance, order: number, caption: string, value: string, color: Color3?)
	local row = Instance.new("Frame")
	row.Name = caption
	row.Size = UDim2.new(1, 0, 0, 26)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = parent
	UITheme.text(row, {
		name = "Caption",
		text = caption,
		size = UDim2.fromScale(0.62, 1),
		font = Fonts.Bold,
		textSize = 13,
		color = Colors.Muted,
		wrap = true,
	})
	local valueLabel = UITheme.text(row, {
		name = "Value",
		text = value,
		size = UDim2.fromScale(0.38, 1),
		font = Fonts.Heavy,
		textSize = 20,
		color = color or Colors.Text,
		alignX = Enum.TextXAlignment.Right,
	})
	valueLabel.Position = UDim2.fromScale(0.62, 0)
end

-- One cause line: label and value, then an optional muted detail underneath.
local function causeLine(parent: Instance, order: number, line: any)
	local holder = Instance.new("Frame")
	holder.Name = "Cause"
	holder.Size = UDim2.fromScale(1, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = order
	holder.Parent = parent
	UITheme.list(holder, 1)

	local top = Instance.new("Frame")
	top.Name = "Top"
	top.Size = UDim2.new(1, 0, 0, 18)
	top.BackgroundTransparency = 1
	top.LayoutOrder = 1
	top.Parent = holder
	local label = UITheme.text(top, {
		name = "Label",
		text = tostring(line.label),
		size = UDim2.new(1, -70, 1, 0),
		font = Fonts.Bold,
		textSize = 13,
	})
	label.TextTruncate = Enum.TextTruncate.AtEnd
	local value = UITheme.text(top, {
		name = "Value",
		text = tostring(line.value),
		size = UDim2.fromOffset(70, 18),
		font = Fonts.Heavy,
		textSize = 13,
		alignX = Enum.TextXAlignment.Right,
	})
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.fromScale(1, 0)
	if typeof(line.detail) == "string" and line.detail ~= "" then
		autoText(holder, {
			name = "Detail",
			text = line.detail,
			textSize = 12,
			color = Colors.Muted,
			order = 2,
		})
	end
end

local function sectionTitle(parent: Instance, order: number, text: string)
	autoText(parent, {
		name = "SectionTitle",
		text = string.upper(text),
		font = Fonts.Heavy,
		textSize = 11,
		color = Colors.Muted,
		order = order,
	})
end

local function column(
	parent: Instance,
	order: number,
	title: string,
	color: Color3,
	strong: boolean
)
	local frame = Instance.new("Frame")
	frame.Name = title
	frame.Size = UDim2.new(1 / 3, -8, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = Colors.Raised
	frame.BackgroundTransparency = 0.35
	frame.BorderSizePixel = 0
	frame.LayoutOrder = order
	frame.Parent = parent
	UITheme.corner(frame, 12)
	UITheme.outline(frame, color, 0.6)
	UITheme.padding(frame, 14, 14)
	UITheme.list(frame, 8)

	local heading = Instance.new("Frame")
	heading.Name = "Heading"
	heading.Size = UDim2.new(1, 0, 0, 24)
	heading.BackgroundTransparency = 1
	heading.LayoutOrder = 0
	heading.Parent = frame
	UITheme.text(heading, {
		name = "Title",
		text = string.upper(title),
		size = UDim2.fromScale(0.6, 1),
		font = Fonts.Heavy,
		textSize = 18,
		color = color,
	})
	-- Color never carries the meaning alone (spec 14.3), so the rating is written out.
	local rating = UITheme.text(heading, {
		name = "Rating",
		text = if strong then "STRONG" else "NEEDS WORK",
		size = UDim2.fromScale(0.4, 1),
		font = Fonts.Heavy,
		textSize = 11,
		color = if strong then Colors.Good else Colors.Danger,
		alignX = Enum.TextXAlignment.Right,
	})
	rating.Position = UDim2.fromScale(0.6, 0)
	return frame
end

local function signedText(amount: number): string
	return (if amount > 0 then "+" else "") .. UITheme.formatNumber(amount)
end

-- Report layout ------------------------------------------------------------------------------

local function render(report: any)
	clearContent()

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.fromScale(1, 0)
	header.AutomaticSize = Enum.AutomaticSize.Y
	header.BackgroundTransparency = 1
	header.LayoutOrder = 1
	header.Parent = scroller
	UITheme.list(header, 4)
	autoText(header, {
		name = "Title",
		text = "SEASON RESULTS",
		font = Fonts.Heavy,
		textSize = 28,
		color = Colors.Gold,
		order = 1,
	})
	autoText(header, {
		name = "Reason",
		text = tostring(report.endReason)
			.. "  Profit, Clean Air, and Trust are scored separately.",
		textSize = 14,
		color = Colors.Muted,
		order = 2,
	})

	local lesson = box(scroller, "KeyLesson", 2, Colors.Gold)
	sectionTitle(lesson, 1, "Most important cause")
	autoText(lesson, {
		name = "Text",
		text = tostring(report.keyLesson),
		font = Fonts.Bold,
		textSize = 16,
		order = 2,
	})

	local row = Instance.new("Frame")
	row.Name = "Dimensions"
	row.Size = UDim2.fromScale(1, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.BackgroundTransparency = 1
	row.LayoutOrder = 3
	row.Parent = scroller
	local rowLayout = UITheme.list(row, 12, true)
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Top

	-- Profit (spec 12.3).
	local profit = report.profit
	local profitColumn = column(row, 1, "Profit", Colors.Gold, profit.strong)
	stat(
		profitColumn,
		1,
		"Season profit",
		signedText(profit.seasonProfit),
		if profit.seasonProfit < 0 then Colors.Danger else Colors.Text
	)
	stat(profitColumn, 2, "Ending cash", UITheme.formatNumber(profit.endingCash))
	stat(
		profitColumn,
		3,
		"Cooperative value",
		UITheme.formatNumber(profit.cooperativeValue),
		Colors.Gold
	)
	autoText(profitColumn, {
		name = "Explain",
		text = "Cooperative value is ending cash plus 70 percent of the infrastructure you own.",
		textSize = 11,
		color = Colors.Muted,
		order = 4,
	})
	autoText(profitColumn, {
		name = "Verdict",
		text = tostring(profit.verdict),
		font = Fonts.Bold,
		textSize = 13,
		order = 5,
	})
	sectionTitle(profitColumn, 6, "Causes")
	for index, line in profit.causes do
		causeLine(profitColumn, 6 + index, line)
	end

	-- Clean Air (spec 12.4 and 11.4).
	local air = report.cleanAir
	local airColumn = column(row, 2, "Clean Air", Colors.Teal, air.strong)
	stat(
		airColumn,
		1,
		"District exposure",
		string.format("%d pts", air.districtExposure),
		if air.districtExposure > 0 then Colors.Danger else Colors.Good
	)
	stat(airColumn, 2, "Your decisions", string.format("%d pts", air.playerCausedExposure))
	stat(airColumn, 3, "Unserved farms", string.format("%d pts", air.otherExposure))
	stat(
		airColumn,
		4,
		"Exposure prevented",
		string.format("%d pts", air.exposurePrevented),
		Colors.Good
	)
	if air.smokeReleased > air.districtExposure then
		stat(
			airColumn,
			5,
			"Smoke to open land",
			string.format("%d pts", air.smokeReleased - air.districtExposure)
		)
	end
	autoText(airColumn, {
		name = "Verdict",
		text = tostring(air.verdict),
		font = Fonts.Bold,
		textSize = 13,
		order = 6,
	})
	sectionTitle(airColumn, 7, "Exposure by cause")
	if #air.causes == 0 then
		autoText(airColumn, {
			name = "None",
			text = "No field was burned this season.",
			textSize = 12,
			color = Colors.Muted,
			order = 8,
		})
	end
	for index, line in air.causes do
		causeLine(airColumn, 7 + index, line)
	end
	if #air.prevented > 0 then
		sectionTitle(airColumn, 50, "Prevented by collecting")
		for index, line in air.prevented do
			causeLine(airColumn, 50 + index, line)
		end
	end

	-- Trust (spec 12.4 and 10.4).
	local trust = report.trust
	local trustColumn = column(row, 3, "Trust", Colors.Straw, trust.strong)
	stat(
		trustColumn,
		1,
		"Farmer trust",
		string.format("%d  (%s)", trust.endingTrust, signedText(trust.change)),
		if trust.change < 0 then Colors.Danger else Colors.Text
	)
	stat(trustColumn, 2, "Commitments completed", tostring(trust.completed), Colors.Good)
	stat(
		trustColumn,
		3,
		"Commitments missed",
		tostring(trust.missed),
		if trust.missed > 0 then Colors.Danger else Colors.Text
	)
	stat(trustColumn, 4, "Commitments rejected", tostring(trust.rejected))
	autoText(trustColumn, {
		name = "Counts",
		text = string.format(
			"%d accepted, %d never answered, %d still open.",
			trust.accepted,
			trust.unanswered,
			trust.open
		),
		textSize = 11,
		color = Colors.Muted,
		order = 5,
	})
	autoText(trustColumn, {
		name = "Verdict",
		text = tostring(trust.verdict),
		font = Fonts.Bold,
		textSize = 13,
		order = 6,
	})
	sectionTitle(trustColumn, 7, "Causes")
	for index, line in trust.causes do
		causeLine(trustColumn, 7 + index, line)
	end

	-- Season replay (spec 12.5 and 16.4).
	local replay = box(scroller, "Replay", 4)
	sectionTitle(replay, 1, "Season replay")
	causeLine(replay, 2, { label = "Bottleneck", value = "", detail = report.bottleneck })
	causeLine(
		replay,
		3,
		{ label = "What went well", value = "", detail = report.successfulDecision }
	)
	if #air.events > 0 then
		sectionTitle(replay, 4, "Burns in time order")
		for index, line in air.events do
			causeLine(replay, 4 + index, line)
		end
	end

	disclaimerText.Text = tostring(air.disclaimer)
	scroller.CanvasPosition = Vector2.zero
end

-- Fetching -----------------------------------------------------------------------------------

local shown = false
local function showResults()
	if shown or world:GetAttribute("SeasonOver") ~= true then
		return
	end
	shown = true
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:WaitForChild("GetSeasonResults") :: RemoteFunction
	local ok, report = pcall(function()
		return remote:InvokeServer()
	end)
	if not ok or typeof(report) ~= "table" then
		shown = false
		return
	end
	render(report)
	screenGui.Enabled = true
	reopenGui.Enabled = false
end

world:GetAttributeChangedSignal("SeasonOver"):Connect(showResults)
showResults()
