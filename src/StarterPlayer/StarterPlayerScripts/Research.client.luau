--!strict

-- Week 6 research panel. Opens from the cooperative office's Research prompt (E). Lists every
-- project with its cost and state, and starts the one the player picks. Engineers, points, and
-- finished projects are player attributes that ResearchService owns; this script only shows them.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ResearchDefinitions = require(Shared:WaitForChild("ResearchDefinitions"))
local UITheme = require(script.Parent:WaitForChild("UITheme"))

local Colors = UITheme.Colors
local Fonts = UITheme.Fonts

local player = Players.LocalPlayer
local startRemote =
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StartResearch") :: RemoteEvent

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BurnOrBuildResearch"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 5
screenGui.Parent = player:WaitForChild("PlayerGui")

local panel = UITheme.card("Research", screenGui, 460)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.45)
panel.Visible = false
UITheme.padding(panel, 14, 16)
UITheme.list(panel, 8)

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundTransparency = 1
header.LayoutOrder = 0
header.Parent = panel
UITheme.text(header, {
	name = "Title",
	text = "RESEARCH",
	size = UDim2.new(1, -40, 0, 22),
	font = Fonts.Heavy,
	textSize = 20,
	color = Colors.Gold,
})
local summary = UITheme.text(header, {
	name = "Summary",
	size = UDim2.new(1, -40, 0, 16),
	textSize = 13,
	color = Colors.Muted,
})
summary.Position = UDim2.fromOffset(0, 24)

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.fromScale(1, 0)
closeButton.Size = UDim2.fromOffset(30, 30)
closeButton.BackgroundColor3 = Colors.Raised
closeButton.Text = "X"
closeButton.FontFace = Fonts.Heavy
closeButton.TextSize = 15
closeButton.TextColor3 = Colors.Text
closeButton.Parent = header
UITheme.corner(closeButton, 8)

type Row = { button: TextButton, status: TextLabel, fill: Frame, track: Frame }
local rows: { [string]: Row } = {}

for order, projectId in ResearchDefinitions.Order do
	local project = ResearchDefinitions.Projects[projectId]
	local row = Instance.new("Frame")
	row.Name = projectId
	row.Size = UDim2.new(1, 0, 0, 62)
	row.BackgroundColor3 = Colors.Raised
	row.BackgroundTransparency = 0.2
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.Parent = panel
	UITheme.corner(row, 10)
	UITheme.padding(row, 8, 12)

	UITheme.text(row, {
		name = "Name",
		text = string.format("%s  ·  %d points", project.DisplayName, project.Points),
		size = UDim2.new(1, -112, 0, 18),
		font = Fonts.Bold,
		textSize = 15,
	})
	local blurb = UITheme.text(row, {
		name = "Blurb",
		text = project.Blurb,
		size = UDim2.new(1, -112, 0, 28),
		textSize = 12,
		color = Colors.Muted,
		wrap = true,
		alignY = Enum.TextYAlignment.Top,
	})
	blurb.Position = UDim2.fromOffset(0, 19)

	local button = Instance.new("TextButton")
	button.Name = "Action"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.fromScale(1, 0.5)
	button.Size = UDim2.fromOffset(100, 30)
	button.Text = ""
	button.AutoButtonColor = true
	button.Parent = row
	UITheme.corner(button, 8)
	local status = UITheme.text(button, {
		name = "Label",
		size = UDim2.fromScale(1, 1),
		font = Fonts.Heavy,
		textSize = 12,
		color = Colors.Panel,
		alignX = Enum.TextXAlignment.Center,
	})
	status.ZIndex = 3

	-- Progress fill behind the label while this project is running.
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.fromScale(1, 1)
	track.BackgroundTransparency = 1
	track.ClipsDescendants = true
	track.ZIndex = 2
	track.Parent = button
	UITheme.corner(track, 8)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Colors.Gold
	fill.BorderSizePixel = 0
	fill.ZIndex = 2
	fill.Parent = track
	UITheme.corner(fill, 8)

	button.Activated:Connect(function()
		startRemote:FireServer(projectId)
	end)
	rows[projectId] = { button = button, status = status, fill = fill, track = track }
end

local function readNumber(attribute: string): number
	local value = player:GetAttribute(attribute)
	return if typeof(value) == "number" then value else 0
end

local function isDone(projectId: string): boolean
	return player:GetAttribute("Research_" .. projectId) == true
end

local function refresh()
	local engineers = readNumber("Engineers")
	local points = readNumber("ResearchPoints")
	local trust = math.clamp(readNumber("Trust"), 0, 100)
	local fee = math.floor(ResearchDefinitions.BaseHireFee * (1.5 - trust / 100) + 0.5)
	local hiring = if engineers >= ResearchDefinitions.MaxEngineers
		then "office full"
		else string.format("next hire %d credits (T at the office)", fee)
	summary.Text = if engineers > 0
		then string.format(
			"%d/%d engineers  ·  %.1f points  ·  %s",
			engineers,
			ResearchDefinitions.MaxEngineers,
			points,
			hiring
		)
		else string.format(
			"No engineers yet. Hire one with T at the office for %d credits.",
			fee
		)

	local active = player:GetAttribute("ResearchProject")
	for projectId, row in rows do
		local project = ResearchDefinitions.Projects[projectId]
		local requires = project.Requires
		row.fill.Size = UDim2.fromScale(0, 1)
		if isDone(projectId) then
			row.button.BackgroundColor3 = Colors.Good
			row.status.Text = "DONE"
			row.button.Active = false
		elseif active == projectId then
			row.button.BackgroundColor3 = Colors.Track
			row.fill.Size = UDim2.fromScale(math.clamp(points / project.Points, 0, 1), 1)
			row.status.Text = string.format(
				"%d / %d",
				math.floor(math.min(points, project.Points)),
				project.Points
			)
			row.status.TextColor3 = Colors.Text
			row.button.Active = false
			continue
		elseif requires and not isDone(requires) then
			row.button.BackgroundColor3 = Colors.Track
			row.status.Text = "NEEDS "
				.. string.upper(ResearchDefinitions.Projects[requires].DisplayName)
			row.status.TextColor3 = Colors.Muted
			row.button.Active = false
			continue
		else
			row.button.BackgroundColor3 = Colors.Teal
			row.status.Text = "RESEARCH"
			row.button.Active = true
		end
		row.status.TextColor3 = Colors.Panel
	end
end

local function setOpen(open: boolean)
	panel.Visible = open
	if open then
		refresh()
	end
end

closeButton.Activated:Connect(function()
	setOpen(false)
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ResearchPrompt" then
		setOpen(true)
	end
end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not panel.Visible then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape then
		setOpen(false)
	end
end)
player.AttributeChanged:Connect(function()
	if panel.Visible then
		refresh()
	end
end)
