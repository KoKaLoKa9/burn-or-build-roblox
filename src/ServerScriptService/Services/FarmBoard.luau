--!strict

-- The sign above a farm stop: the farm name and a status pill, one big line, and one small line
-- of detail. Sized in studs so it reads like a real sign and shrinks with distance. Keys are not
-- repeated here because the proximity prompts already show them.

local FarmBoard = {}

export type Board = { pill: Frame, pillText: TextLabel, main: TextLabel, detail: TextLabel }

local FONT = "rbxasset://fonts/families/BuilderSans.json"
local PANEL = Color3.fromRGB(13, 20, 19)
local TEXT = Color3.fromRGB(240, 238, 228)

FarmBoard.Colors = {
	Teal = Color3.fromRGB(64, 200, 176),
	Gold = Color3.fromRGB(246, 190, 72),
	Green = Color3.fromRGB(104, 216, 142),
	Muted = Color3.fromRGB(170, 186, 178),
	Red = Color3.fromRGB(240, 98, 70),
}

local function text(
	parent: Instance,
	name: string,
	position: UDim2,
	size: UDim2,
	weight: Enum.FontWeight,
	color: Color3
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.FontFace = Font.new(FONT, weight)
	label.TextColor3 = color
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

function FarmBoard.Create(parent: BasePart, name: string, title: string): Board
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	-- The graybox sign (FUTURE CONTRACT, COLLECT STRAW) is replaced by the live board.
	local mapLabel = parent:FindFirstChild("MapLabel")
	if mapLabel and mapLabel:IsA("BillboardGui") then
		mapLabel.Enabled = false
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = name
	billboard.Size = UDim2.fromScale(15, 5.4)
	billboard.StudsOffset = Vector3.new(0, 8, 0)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 180
	billboard.Parent = parent

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = PANEL
	card.BackgroundTransparency = 0.08
	card.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.14, 0)
	corner.Parent = card
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.1, 0)
	padding.Parent = card

	text(
		card,
		"Title",
		UDim2.fromScale(0, 0),
		UDim2.fromScale(0.5, 0.28),
		Enum.FontWeight.ExtraBold,
		TEXT
	).Text =
		title

	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Position = UDim2.fromScale(1, 0)
	pill.Size = UDim2.fromScale(0.48, 0.28)
	pill.Parent = card
	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = UDim.new(0.5, 0)
	pillCorner.Parent = pill
	local pillText = text(
		pill,
		"Label",
		UDim2.fromScale(0.08, 0.14),
		UDim2.fromScale(0.84, 0.72),
		Enum.FontWeight.ExtraBold,
		PANEL
	)
	pillText.TextXAlignment = Enum.TextXAlignment.Center

	local main = text(
		card,
		"Main",
		UDim2.fromScale(0, 0.36),
		UDim2.fromScale(1, 0.36),
		Enum.FontWeight.Bold,
		TEXT
	)
	local detail = text(
		card,
		"Detail",
		UDim2.fromScale(0, 0.78),
		UDim2.fromScale(1, 0.22),
		Enum.FontWeight.Medium,
		FarmBoard.Colors.Muted
	)
	return { pill = pill, pillText = pillText, main = main, detail = detail }
end

function FarmBoard.Set(board: Board, status: string, color: Color3, main: string, detail: string)
	board.pillText.Text = status
	board.pill.BackgroundColor3 = color
	board.main.Text = main
	board.detail.Text = detail
end

return FarmBoard
