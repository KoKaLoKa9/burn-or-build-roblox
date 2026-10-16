--!strict

-- Dresses the graybox district with the imported building models: the pellet buyer depot, the
-- village houses, and the school. Each graybox block stays as an invisible collision box and keeps
-- its label, so gameplay and exposure zones do not change. Missing art leaves the block as it was.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MachineArt = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MachineArt"))

local WorldArtService = {}

-- The pellet buyer is the district's big landmark, much larger than the graybox block.
local BUYER_SCALE = 2

local function dress(model: Instance?, artName: string, scale: number?)
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
	if scale and scale ~= 1 then
		-- The art pivot is its bottom centre, so it grows upward and outward from the ground.
		art:ScaleTo(scale)
	end
	art:PivotTo(body.CFrame * CFrame.new(0, -body.Size.Y / 2, 0))
	art.Parent = model
	body.Transparency = 1
end

-- Grows the buyer's collision block before MachineService places its IN port and status board.
-- The west wall stays put, so the loading dock and any belts to it keep lining up.
function WorldArtService:EnlargeBuyer(world: Model)
	local buyer = world:FindFirstChild("PelletBuyer")
	local body = if buyer then buyer:FindFirstChild("Body") else nil
	if body == nil or not body:IsA("BasePart") or body:GetAttribute("Enlarged") then
		return
	end
	local oldSize = body.Size
	local westX = body.Position.X - oldSize.X / 2
	local groundY = body.Position.Y - oldSize.Y / 2
	local newSize = oldSize * BUYER_SCALE
	body.Size = newSize
	body.CFrame = CFrame.new(westX + newSize.X / 2, groundY + newSize.Y / 2, body.Position.Z)
	body:SetAttribute("Enlarged", true)
end

function WorldArtService:Initialize(world: Model)
	local buyer = world:FindFirstChild("PelletBuyer")
	dress(buyer, "BuyerDepot", BUYER_SCALE)
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
