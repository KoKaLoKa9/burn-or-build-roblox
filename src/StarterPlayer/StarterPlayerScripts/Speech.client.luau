--!strict

-- Speech cards: when a villager speaks (VillageService), their name and words slide in at the
-- top of the screen for a few seconds. A new line replaces the old one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UITheme = require(script.Parent:WaitForChild("UITheme"))

local Colors = UITheme.Colors
local Fonts = UITheme.Fonts

local SHOW_SECONDS = 7

local player = Players.LocalPlayer
local speech = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Speech") :: RemoteEvent

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BurnOrBuildSpeech"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 4
screenGui.Parent = player:WaitForChild("PlayerGui")

local card = UITheme.card("Speech", screenGui, 460)
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.new(0.5, 0, 0, -120)
card.Visible = false
UITheme.padding(card, 10, 14)
UITheme.list(card, 4)

-- A gold outline marks it as someone talking.
local outline = card:FindFirstChildOfClass("UIStroke")
if outline then
	outline.Color = Colors.Gold
	outline.Transparency = 0.2
	outline.Thickness = 2
end

local speaker = UITheme.text(card, {
	name = "Speaker",
	size = UDim2.new(1, 0, 0, 16),
	font = Fonts.Heavy,
	textSize = 13,
	color = Colors.Gold,
	order = 1,
})
local words = UITheme.text(card, {
	name = "Words",
	size = UDim2.fromScale(1, 0),
	textSize = 15,
	wrap = true,
	order = 2,
})
words.AutomaticSize = Enum.AutomaticSize.Y

local shown = 0
local slide = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

speech.OnClientEvent:Connect(function(name: unknown, text: unknown)
	if typeof(name) ~= "string" or typeof(text) ~= "string" then
		return
	end
	shown += 1
	local mine = shown
	speaker.Text = name
	words.Text = '"' .. text .. '"'
	card.Visible = true
	TweenService:Create(card, slide, { Position = UDim2.new(0.5, 0, 0, 12) }):Play()
	task.delay(SHOW_SECONDS, function()
		if shown ~= mine then
			return
		end
		local away = TweenService:Create(card, slide, { Position = UDim2.new(0.5, 0, 0, -120) })
		away:Play()
		away.Completed:Wait()
		if shown == mine then
			card.Visible = false
		end
	end)
end)
