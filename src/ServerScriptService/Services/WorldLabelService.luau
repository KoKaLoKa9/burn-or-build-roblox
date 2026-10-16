--!strict

-- Keeps world labels readable as the district fills up. Billboards that were sized in pixels
-- (farm boards, map signs, trucks, belt warnings) become sized in studs, so they shrink with
-- distance like the objects they describe, and they stop drawing through buildings and machines.
-- Labels already sized in studs are left alone.

local WorldLabelService = {}

local PIXELS_PER_STUD = 18
local MAX_DISTANCE = 180

local function restyle(billboard: BillboardGui)
	local size = billboard.Size
	if size.X.Scale ~= 0 or size.Y.Scale ~= 0 then
		return
	end
	billboard.Size =
		UDim2.fromScale(size.X.Offset / PIXELS_PER_STUD, size.Y.Offset / PIXELS_PER_STUD)
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = if billboard.MaxDistance > 0
		then math.min(billboard.MaxDistance, MAX_DISTANCE)
		else MAX_DISTANCE
	-- Fixed pixel text would overflow a stud-sized board at a distance.
	for _, descendant in billboard:GetDescendants() do
		if descendant:IsA("TextLabel") then
			descendant.TextScaled = true
		end
	end
end

function WorldLabelService:Initialize(world: Model)
	for _, descendant in world:GetDescendants() do
		if descendant:IsA("BillboardGui") then
			restyle(descendant)
		end
	end
	world.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BillboardGui") then
			-- Let the creator finish setting Size and text before restyling.
			task.defer(restyle, descendant)
		end
	end)
end

return WorldLabelService
