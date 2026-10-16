--!strict

-- Dresses the graybox district with the imported building models: the pellet buyer depot, the
-- village houses, and the school. Each graybox block stays as an invisible collision box and keeps
-- its label, so gameplay and exposure zones do not change. Missing art leaves the block as it was.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MachineArt = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MachineArt"))

local WorldArtService = {}

local function dress(model: Instance?, artName: string)
	if model == nil or not model:IsA("Model") then
		return
	end
	local body = model:FindFirstChild("Body")
	if body == nil or not body:IsA("BasePart") or model:FindFirstChild("Art") then
		return
	end
	local art = MachineArt.Build(artName)
	if art == nil then
		return
	end
	art:PivotTo(body.CFrame * CFrame.new(0, -body.Size.Y / 2, 0))
	art.Parent = model
	body.Transparency = 1
end

function WorldArtService:Initialize(world: Model)
	local buyer = world:FindFirstChild("PelletBuyer")
	dress(buyer, "BuyerDepot")
	-- The buyer's live status board already names it, so the old graybox sign would overlap it.
	local buyerSign = if buyer then buyer:FindFirstChild("MapLabel", true) else nil
	if buyerSign and buyerSign:IsA("BillboardGui") then
		buyerSign.Enabled = false
	end
	local village = world:FindFirstChild("Village")
	if village then
		for _, child in village:GetChildren() do
			if string.sub(child.Name, 1, 6) == "House_" then
				dress(child, "House")
			elseif child.Name == "School" then
				dress(child, "School")
			end
		end
	end
end

return WorldArtService
