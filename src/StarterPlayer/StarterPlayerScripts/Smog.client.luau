--!strict

-- The sky shows the smog. As the district smog meter (world attribute Smog, set by SmogService)
-- rises, the haze thickens and turns a dirty brown-grey; as it clears, the warm afternoon sky
-- comes back. Purely visual and local, so it costs the server nothing.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local world = workspace:WaitForChild("BurnOrBuildWorld")

-- Smog at which the haze is at its thickest.
local FULL_SMOG = 80
local SMOG_COLOR = Color3.fromRGB(150, 138, 118)
local SMOG_DECAY = Color3.fromRGB(96, 88, 78)

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
for _ = 1, 60 do
	if atmosphere then
		break
	end
	task.wait(0.5)
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
end
if atmosphere == nil then
	return
end
local haze = atmosphere :: Atmosphere
-- The clear-air look the server set up, remembered once.
local base = {
	density = haze.Density,
	haze = haze.Haze,
	color = haze.Color,
	decay = haze.Decay,
}

local tween: Tween? = nil
local function refresh()
	local value = world:GetAttribute("Smog")
	local share = math.clamp((if typeof(value) == "number" then value else 0) / FULL_SMOG, 0, 1)
	if tween then
		tween:Cancel()
	end
	local next = TweenService:Create(haze, TweenInfo.new(1.5), {
		Density = base.density + share * 0.35,
		Haze = base.haze + share * 2,
		Color = base.color:Lerp(SMOG_COLOR, share),
		Decay = base.decay:Lerp(SMOG_DECAY, share),
	})
	next:Play()
	tween = next
end

world:GetAttributeChangedSignal("Smog"):Connect(refresh)
refresh()
