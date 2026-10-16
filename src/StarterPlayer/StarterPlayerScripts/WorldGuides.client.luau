--!strict

-- Local world guides. A gold arrow bobs over the factory intake with a sign above it, so new
-- players can find where carried straw goes. It glows while the player is carrying straw.
-- Built on the client so the motion is smooth and costs the server nothing.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UITheme = require(script.Parent:WaitForChild("UITheme"))

local player = Players.LocalPlayer
local world = workspace:WaitForChild("BurnOrBuildWorld")
local factory = world:WaitForChild("CooperativeFactory")
local intake = factory:WaitForChild("FactoryIntake") :: Model
local pad = intake:WaitForChild("Body") :: BasePart

local GOLD = UITheme.Colors.Gold
-- Clears the collection shed roof and its count board.
local HOVER_HEIGHT = 14.5
local BOB_HEIGHT = 0.8

local arrow = Instance.new("Model")
arrow.Name = "IntakeGuide"

local function arrowPart(name: string, size: Vector3, offsetY: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = size
	-- Cylinders run along X; turn them upright.
	part.CFrame = CFrame.new(0, offsetY, 0) * CFrame.Angles(0, 0, math.rad(90))
	part.Color = GOLD
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = arrow
	return part
end

-- A stepped cone pointing down, then the shaft. Offsets are from the arrow tip.
local discs = { { 1.4, 0.4 }, { 2.8, 1.2 }, { 4.2, 2.0 }, { 5.6, 2.8 } }
for index, disc in discs do
	arrowPart("Head" .. index, Vector3.new(0.8, disc[1], disc[1]), disc[2])
end
local shaft = arrowPart("Shaft", Vector3.new(5, 1.8, 1.8), 5.7)
arrow.WorldPivot = CFrame.new()

local sign = Instance.new("BillboardGui")
sign.Name = "Sign"
sign.Size = UDim2.fromScale(13, 2.4)
sign.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
sign.LightInfluence = 0
-- Drawn over the shaft so the arrow never cuts through the words.
sign.AlwaysOnTop = true
sign.MaxDistance = 250
sign.Parent = shaft

local signBack = Instance.new("Frame")
signBack.Name = "Back"
signBack.Size = UDim2.fromScale(1, 1)
signBack.BackgroundColor3 = UITheme.Colors.Panel
signBack.BackgroundTransparency = 0.08
signBack.BorderSizePixel = 0
signBack.Parent = sign
UITheme.corner(signBack, 12)
UITheme.outline(signBack, GOLD, 0.2, 2)
local signText = UITheme.text(signBack, {
	name = "Text",
	text = "DEPOSIT YOUR STRAW HERE",
	size = UDim2.fromScale(1, 1),
	font = UITheme.Fonts.Heavy,
	color = GOLD,
	alignX = Enum.TextXAlignment.Center,
})
signText.TextScaled = true
UITheme.padding(signBack, 4, 10)

arrow.Parent = workspace

local function carrying(): boolean
	local value = player:GetAttribute("StrawBundles")
	return typeof(value) == "number" and value > 0
end

local function refreshEmphasis()
	local active = carrying()
	for _, part in arrow:GetChildren() do
		if part:IsA("BasePart") then
			part.Material = if active then Enum.Material.Neon else Enum.Material.SmoothPlastic
			part.Transparency = if active then 0 else 0.25
		end
	end
end

player:GetAttributeChangedSignal("StrawBundles"):Connect(refreshEmphasis)
refreshEmphasis()

local padTop = pad.Position + Vector3.new(0, pad.Size.Y / 2 + HOVER_HEIGHT, 0)
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local bob = math.sin(t * 2.4) * BOB_HEIGHT
	arrow:PivotTo(CFrame.new(padTop + Vector3.new(0, bob, 0)) * CFrame.Angles(0, t * 0.8, 0))
end)
