--!strict

-- One look for every Burn or Build screen: palette, type, and small constructors.
-- Dark glass panels, a thin light outline, and color only as an accent next to words and numbers
-- (spec 14.3: color never carries meaning alone).

local UITheme = {}

UITheme.Colors = {
	Panel = Color3.fromRGB(13, 20, 19),
	Raised = Color3.fromRGB(26, 37, 35),
	Hover = Color3.fromRGB(36, 50, 47),
	Outline = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(240, 238, 228),
	Muted = Color3.fromRGB(146, 164, 157),
	Teal = Color3.fromRGB(64, 200, 176),
	Gold = Color3.fromRGB(246, 190, 72),
	Straw = Color3.fromRGB(226, 185, 83),
	Danger = Color3.fromRGB(240, 98, 70),
	Good = Color3.fromRGB(104, 216, 142),
	Track = Color3.fromRGB(42, 56, 52),
}

local FAMILY = "rbxasset://fonts/families/BuilderSans.json"
UITheme.Fonts = {
	Regular = Font.new(FAMILY, Enum.FontWeight.Medium),
	Bold = Font.new(FAMILY, Enum.FontWeight.Bold),
	Heavy = Font.new(FAMILY, Enum.FontWeight.ExtraBold),
}

function UITheme.corner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function UITheme.outline(
	parent: Instance,
	color: Color3?,
	transparency: number?,
	thickness: number?
): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color or UITheme.Colors.Outline
	stroke.Transparency = transparency or 0.88
	stroke.Thickness = thickness or 1
	stroke.Parent = parent
	return stroke
end

function UITheme.padding(parent: Instance, vertical: number, horizontal: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, vertical)
	padding.PaddingBottom = UDim.new(0, vertical)
	padding.PaddingLeft = UDim.new(0, horizontal)
	padding.PaddingRight = UDim.new(0, horizontal)
	padding.Parent = parent
end

function UITheme.list(parent: Instance, gap: number, horizontal: boolean?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = if horizontal
		then Enum.FillDirection.Horizontal
		else Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.Parent = parent
	return layout
end

-- A rounded dark glass card that grows with its content.
function UITheme.card(name: string, parent: Instance, width: number): Frame
	local card = Instance.new("Frame")
	card.Name = name
	card.Size = UDim2.fromOffset(width, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = UITheme.Colors.Panel
	card.BackgroundTransparency = 0.04
	card.BorderSizePixel = 0
	card.Parent = parent
	UITheme.corner(card, 14)
	UITheme.outline(card)
	return card
end

export type TextOptions = {
	name: string,
	text: string?,
	size: UDim2?,
	font: Font?,
	textSize: number?,
	color: Color3?,
	alignX: Enum.TextXAlignment?,
	alignY: Enum.TextYAlignment?,
	order: number?,
	wrap: boolean?,
}

function UITheme.text(parent: Instance, options: TextOptions): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = options.name
	label.Text = options.text or ""
	label.Size = options.size or UDim2.new(1, 0, 0, 18)
	label.BackgroundTransparency = 1
	label.FontFace = options.font or UITheme.Fonts.Regular
	label.TextSize = options.textSize or 14
	label.TextColor3 = options.color or UITheme.Colors.Text
	label.TextXAlignment = options.alignX or Enum.TextXAlignment.Left
	label.TextYAlignment = options.alignY or Enum.TextYAlignment.Center
	label.TextWrapped = options.wrap == true
	label.LayoutOrder = options.order or 0
	label.Parent = parent
	return label
end

-- A small rounded key cap such as [E] or [LMB], used in control hints and on hotbar slots.
function UITheme.keyCap(parent: Instance, key: string, order: number?): Frame
	local cap = Instance.new("Frame")
	cap.Name = "Key_" .. key
	cap.Size = UDim2.fromOffset(0, 22)
	cap.AutomaticSize = Enum.AutomaticSize.X
	cap.BackgroundColor3 = UITheme.Colors.Text
	cap.BackgroundTransparency = 0.05
	cap.BorderSizePixel = 0
	cap.LayoutOrder = order or 0
	cap.Parent = parent
	UITheme.corner(cap, 6)
	UITheme.padding(cap, 0, 7)
	UITheme.text(cap, {
		name = "Label",
		text = key,
		size = UDim2.fromScale(0, 1),
		font = UITheme.Fonts.Heavy,
		textSize = 13,
		color = UITheme.Colors.Panel,
		alignX = Enum.TextXAlignment.Center,
	}).AutomaticSize =
		Enum.AutomaticSize.X
	return cap
end

function UITheme.formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""):gsub("^%-,", "-"))
end

return UITheme
