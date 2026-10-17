--!strict

-- First-batch tutorial (spec: tutorial and adaptive help). A small checklist in the top right
-- teaches one interaction at a time, from picking up straw to the first pellet sale. Steps tick
-- off from what the player actually does, in any order, so experienced players can race ahead
-- or hide the card. It ends at the first sale, the same moment the server ends the tutorial.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UITheme = require(script.Parent:WaitForChild("UITheme"))

local Colors = UITheme.Colors
local Fonts = UITheme.Fonts

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local world = workspace:WaitForChild("BurnOrBuildWorld")

local CARD_WIDTH = 300
local DONE_LINGER_SECONDS = 8

type Step = {
	title: string,
	detail: string,
	done: boolean,
	row: Frame?,
	mark: TextLabel?,
	label: TextLabel?,
}

local steps: { Step } = {
	{
		title = "Clear your field",
		detail = "Burn it with H: fast, so you plant on time. Or pick up the straw with E to sell later.",
		done = false,
	},
	{
		title = "Replant for grain",
		detail = "Hold E at a row end to plant. Plant quickly: late rows give less grain.",
		done = false,
	},
	{
		title = "Build a dryer",
		detail = "Pick the dryer on the hotbar and click the factory plot.",
		done = false,
	},
	{
		title = "Build a shredder and pellet mill",
		detail = "Place them in order: dryer, then shredder, then pellet mill.",
		done = false,
	},
	{
		title = "Link them with belts",
		detail = "Pick the conveyor, then drag from each OUT port to the next IN port.",
		done = false,
	},
	{
		title = "Sell your first crate",
		detail = "Run a belt from the pellet mill to the buyer depot's IN port.",
		done = false,
	},
}

if player:GetAttribute("TutorialComplete") == true then
	return
end

-- UI ------------------------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BurnOrBuildTutorial"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local card = UITheme.card("Tutorial", screenGui, CARD_WIDTH)
card.AnchorPoint = Vector2.new(1, 0)
card.Position = UDim2.new(1, -16, 0, 12)
UITheme.padding(card, 12, 14)
UITheme.list(card, 8)

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 22)
header.BackgroundTransparency = 1
header.LayoutOrder = 0
header.Parent = card
local title = UITheme.text(header, {
	name = "Title",
	text = "FIRST BATCH",
	size = UDim2.new(1, -60, 1, 0),
	font = Fonts.Heavy,
	textSize = 16,
	color = Colors.Gold,
})
local progress = UITheme.text(header, {
	name = "Progress",
	size = UDim2.new(0, 40, 1, 0),
	font = Fonts.Bold,
	textSize = 13,
	color = Colors.Muted,
	alignX = Enum.TextXAlignment.Right,
})
progress.AnchorPoint = Vector2.new(1, 0)
progress.Position = UDim2.new(1, -28, 0, 0)

local toggle = Instance.new("TextButton")
toggle.Name = "Toggle"
toggle.AnchorPoint = Vector2.new(1, 0)
toggle.Position = UDim2.fromScale(1, 0)
toggle.Size = UDim2.fromOffset(22, 22)
toggle.BackgroundColor3 = Colors.Raised
toggle.Text = "-"
toggle.FontFace = Fonts.Heavy
toggle.TextSize = 16
toggle.TextColor3 = Colors.Text
toggle.Parent = header
UITheme.corner(toggle, 6)

local body = Instance.new("Frame")
body.Name = "Body"
body.Size = UDim2.fromScale(1, 0)
body.AutomaticSize = Enum.AutomaticSize.Y
body.BackgroundTransparency = 1
body.LayoutOrder = 1
body.Parent = card
UITheme.list(body, 6)

for index, step in steps do
	local row = Instance.new("Frame")
	row.Name = "Step" .. index
	row.Size = UDim2.fromScale(1, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.BackgroundTransparency = 1
	row.LayoutOrder = index
	row.Parent = body

	local mark = UITheme.text(row, {
		name = "Mark",
		size = UDim2.fromOffset(20, 20),
		font = Fonts.Heavy,
		textSize = 12,
		color = Colors.Panel,
		alignX = Enum.TextXAlignment.Center,
	})
	mark.BackgroundTransparency = 0
	UITheme.corner(mark, 10)

	local label = UITheme.text(row, {
		name = "Label",
		size = UDim2.new(1, -28, 0, 0),
		textSize = 14,
		wrap = true,
	})
	label.Position = UDim2.fromOffset(28, 1)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.RichText = true

	step.row, step.mark, step.label = row, mark, label
end

local collapsed = false
toggle.Activated:Connect(function()
	collapsed = not collapsed
	body.Visible = not collapsed
	toggle.Text = if collapsed then "+" else "-"
end)

local function escape(text: string): string
	return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

local function render()
	local current: number? = nil
	local doneCount = 0
	for index, step in steps do
		if step.done then
			doneCount += 1
		elseif current == nil then
			current = index
		end
	end
	progress.Text = string.format("%d/%d", doneCount, #steps)
	for index, step in steps do
		local mark, label = step.mark :: TextLabel, step.label :: TextLabel
		if step.done then
			mark.Text = "✓"
			mark.BackgroundColor3 = Colors.Good
			label.Text = escape(step.title)
			label.TextColor3 = Colors.Muted
		elseif index == current then
			mark.Text = tostring(index)
			mark.BackgroundColor3 = Colors.Gold
			-- Only the current step shows how, so the card teaches one thing at a time.
			label.Text = string.format(
				'<b>%s</b>\n<font color="#92A49D">%s</font>',
				escape(step.title),
				escape(step.detail)
			)
			label.TextColor3 = Colors.Text
		else
			mark.Text = tostring(index)
			mark.BackgroundColor3 = Colors.Track
			label.Text = escape(step.title)
			label.TextColor3 = Colors.Muted
		end
	end
end

-- Progress ------------------------------------------------------------------------------------

local function complete(index: number)
	if steps[index].done then
		return
	end
	steps[index].done = true
	render()
end

-- Your field reports how it was cleared and how many rows have been planted.
local field = world:WaitForChild("Farm_A", 30)
if field then
	local function fieldChanged()
		local state = field:GetAttribute("State")
		if state == "Collecting" or state == "Collected" or state == "Burned" then
			complete(1)
		end
		local planted = field:GetAttribute("RowsPlanted")
		if typeof(planted) == "number" and planted > 0 then
			complete(1)
			complete(2)
		end
	end
	field:GetAttributeChangedSignal("State"):Connect(fieldChanged)
	field:GetAttributeChangedSignal("RowsPlanted"):Connect(fieldChanged)
	fieldChanged()
end

local function ownsThis(instance: Instance): boolean
	return instance:GetAttribute("OwnerUserId") == player.UserId
end

local function scanProduction()
	local production = world:FindFirstChild("Production")
	if production == nil then
		return
	end
	local owned: { [string]: boolean } = {}
	for _, child in production:GetChildren() do
		if child:IsA("Model") and ownsThis(child) then
			local definitionId = child:GetAttribute("DefinitionId")
			if typeof(definitionId) == "string" then
				owned[definitionId] = true
			end
		end
	end
	if owned.Dryer then
		complete(3)
	end
	if owned.Shredder and owned.PelletMill then
		complete(4)
	end
	local conveyors = production:FindFirstChild("Conveyors")
	if conveyors then
		for _, tile in conveyors:GetChildren() do
			if ownsThis(tile) then
				complete(5)
				break
			end
		end
	end
end

local finished = false
local function finish()
	if finished then
		return
	end
	finished = true
	for index in steps do
		steps[index].done = true
	end
	render()
	body.Visible = true
	title.Text = "TUTORIAL COMPLETE"
	title.TextColor3 = Colors.Good
	UITheme.text(card, {
		name = "Wrap",
		text = "First crate sold. Take farm contracts to keep straw out of the fire. Deleting a machine now refunds 70 percent.",
		size = UDim2.fromScale(1, 0),
		textSize = 13,
		color = Colors.Text,
		wrap = true,
		order = 2,
	}).AutomaticSize =
		Enum.AutomaticSize.Y
	task.delay(DONE_LINGER_SECONDS, function()
		local fade = TweenInfo.new(0.6)
		TweenService:Create(card, fade, { BackgroundTransparency = 1 }):Play()
		for _, descendant in card:GetDescendants() do
			if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
				TweenService
					:Create(descendant, fade, { TextTransparency = 1, BackgroundTransparency = 1 })
					:Play()
			elseif descendant:IsA("UIStroke") then
				TweenService:Create(descendant, fade, { Transparency = 1 }):Play()
			end
		end
		task.wait(0.7)
		screenGui:Destroy()
	end)
end

player:GetAttributeChangedSignal("TutorialComplete"):Connect(function()
	if player:GetAttribute("TutorialComplete") == true then
		finish()
	end
end)

-- Machines and belts are rebuilt by the server as they change, so a light poll is simpler and
-- sturdier than wiring every folder event.
local elapsed = 0
RunService.Heartbeat:Connect(function(deltaTime)
	if finished then
		return
	end
	elapsed += deltaTime
	if elapsed >= 0.5 then
		elapsed = 0
		scanProduction()
	end
end)

render()
