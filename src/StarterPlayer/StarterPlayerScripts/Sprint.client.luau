--!strict

-- Hold Shift to run. The map is wide (fields, factory, buyer, village), so running cuts the walk
-- between them. A small field-of-view kick makes the speed change easy to feel.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local WALK_SPEED = 16
local RUN_SPEED = 40
local WALK_FOV = 70
local RUN_FOV = 80
local SPRINT_KEYS = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift }

local player = Players.LocalPlayer
local held = 0
local fovTween: Tween? = nil

local function apply()
	local running = held > 0
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid.WalkSpeed = if running then RUN_SPEED else WALK_SPEED
	end
	local camera = workspace.CurrentCamera
	-- Leave scripted cameras (cutscenes, results screen) alone.
	if camera and camera.CameraType ~= Enum.CameraType.Scriptable then
		if fovTween then
			fovTween:Cancel()
		end
		local tween = TweenService:Create(
			camera,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ FieldOfView = if running then RUN_FOV else WALK_FOV }
		)
		tween:Play()
		fovTween = tween
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- Shift while typing in chat should not start a run.
	if gameProcessed or not table.find(SPRINT_KEYS, input.KeyCode) then
		return
	end
	held += 1
	apply()
end)

UserInputService.InputEnded:Connect(function(input)
	if not table.find(SPRINT_KEYS, input.KeyCode) or held == 0 then
		return
	end
	held -= 1
	apply()
end)

-- Releasing Shift while the window is unfocused never fires InputEnded.
UserInputService.WindowFocusReleased:Connect(function()
	held = 0
	apply()
end)

player.CharacterAdded:Connect(function(character)
	character:WaitForChild("Humanoid")
	apply()
end)
