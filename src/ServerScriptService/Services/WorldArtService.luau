--!strict

-- Dresses the graybox district with the imported building models: the village houses and the
-- school. Each graybox block stays as an invisible collision box and keeps its label, so gameplay
-- and exposure zones do not change. Missing art leaves the block as it was. MachineService dresses
-- the buyer depot, whose block is already the model's size on map v2.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MachineArt = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MachineArt"))
local Houses = require(script.Parent:WaitForChild("Houses"))

local WorldArtService = {}

-- Village houses read as real buildings next to the machines at this size.
local HOUSE_SCALE = 1.4
-- A row of houses at the back of the village and a school campus between them and the main road,
-- as tools/GenerateGraybox.luau lays them out. Positions are ground centres.
local VILLAGE_CENTER = Vector3.new(255, 0, -125)
local VILLAGE_LAYOUT: { [string]: Vector3 } = {
	House_1 = Vector3.new(195, 0, -170),
	House_2 = Vector3.new(255, 0, -170),
	House_3 = Vector3.new(315, 0, -170),
	School = Vector3.new(255, 0, -95),
}
local CAMPUS_SIZE = Vector3.new(80, 10, 44)
-- One of each village house kind, in House_1, House_2, House_3 order.
local VILLAGE_HOUSES = { Houses.StiltHouse, Houses.ConcreteHouse, Houses.Farmhouse }

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

-- Moves and resizes the village's collision blocks before the landscape is planted, so trees and
-- tracks fit around the new layout. The exposure zone moves with the village, so smoke is still
-- judged against where people live.
function WorldArtService:PrepareVillage(world: Model)
	local village = world:FindFirstChild("Village")
	if village == nil or village:GetAttribute("Prepared") then
		return
	end
	village:SetAttribute("Prepared", true)
	for _, child in village:GetChildren() do
		local target = VILLAGE_LAYOUT[child.Name]
		if child.Name == "ExposureZone" and child:IsA("BasePart") then
			child.Position = Vector3.new(VILLAGE_CENTER.X, child.Position.Y, VILLAGE_CENTER.Z)
		elseif target then
			local body = child:FindFirstChild("Body")
			if body and body:IsA("BasePart") then
				if child.Name == "School" then
					-- The block now stands for the whole campus; the campus parts do the colliding.
					body.Size = CAMPUS_SIZE
					body.CanCollide = false
				else
					body.Size *= HOUSE_SCALE
				end
				body.CFrame = CFrame.new(target + Vector3.new(0, body.Size.Y / 2, 0))
			end
			-- Players can see a house is a house: the graybox name signs go.
			for _, descendant in child:GetDescendants() do
				if descendant:IsA("BillboardGui") and descendant.Name == "MapLabel" then
					descendant.Enabled = false
				end
			end
		end
	end
end

function WorldArtService:Initialize(world: Model)
	local buyer = world:FindFirstChild("PelletBuyer")
	-- The depot is a landmark that needs no sign.
	local buyerSign = if buyer then buyer:FindFirstChild("MapLabel", true) else nil
	if buyerSign and buyerSign:IsA("BillboardGui") then
		buyerSign.Enabled = false
	end
	local village = world:FindFirstChild("Village")
	if village then
		for _, child in village:GetChildren() do
			if string.sub(child.Name, 1, 6) == "House_" then
				local body = child:FindFirstChild("Body")
				local index = tonumber(string.sub(child.Name, 7)) or 1
				local build = VILLAGE_HOUSES[(index - 1) % #VILLAGE_HOUSES + 1]
				local house: Model? = nil
				if body and body:IsA("BasePart") and child:FindFirstChild("Art") == nil then
					local bottom = body.Position - Vector3.new(0, body.Size.Y / 2, 0)
					-- Fronts face -Z; the road is to the south.
					house =
						build(CFrame.new(bottom) * CFrame.Angles(0, math.pi, 0), Random.new(index))
				end
				if house and body and body:IsA("BasePart") then
					house.Name = "Art"
					house.Parent = child
					body.Transparency = 1
				else
					dress(child, "House", HOUSE_SCALE)
				end
			elseif child.Name == "School" then
				local body = child:FindFirstChild("Body")
				if
					body
					and body:IsA("BasePart")
					and child:FindFirstChild("SchoolCampus") == nil
				then
					-- The gate faces the main road (+Z), so the campus turns around.
					local campus = Houses.SchoolCampus(
						CFrame.new(
							body.Position.X,
							body.Position.Y - body.Size.Y / 2,
							body.Position.Z
						) * CFrame.Angles(0, math.pi, 0),
						Random.new(7)
					)
					campus.Parent = child
					body.Transparency = 1
				end
			end
		end
	end
end

return WorldArtService
