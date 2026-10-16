--!strict

-- The paddies a farm machine may stand beside, read from the Paddy tag that PaddyField puts on
-- every planted field (Farm A and each bought plot). Shared by the server, which validates and
-- links a placed machine to its paddy, and the build mode ghost, which shows the same verdict.

local CollectionService = game:GetService("CollectionService")

local PlacementRules = require(script.Parent:WaitForChild("PlacementRules"))

local PaddySites = {}

-- Must match PaddyField.Tag on the server.
PaddySites.Tag = "Paddy"

-- Parts of the field itself. Every other part on the paddy model (sign, board, burn spot) is a
-- fixture a machine must not cover.
local FIELD_PARTS: { [string]: boolean } = { StrawArea = true, RiceRow = true }

-- Returns every paddy as a placement site for this player, and the paddy model behind each one.
function PaddySites.Collect(userId: number): ({ PlacementRules.PaddySite }, { Model })
	local sites: { PlacementRules.PaddySite } = {}
	local models: { Model } = {}
	for _, instance in CollectionService:GetTagged(PaddySites.Tag) do
		if not instance:IsA("Model") or not instance:IsDescendantOf(workspace) then
			continue
		end
		local strawArea = instance:FindFirstChild("StrawArea")
		if strawArea == nil or not strawArea:IsA("BasePart") then
			continue
		end
		local fixtures: { PlacementRules.Rect } = {}
		for _, child in instance:GetChildren() do
			if child:IsA("BasePart") and not FIELD_PARTS[child.Name] then
				table.insert(fixtures, PlacementRules.RectFromPart(child))
			end
		end
		local owner = instance:GetAttribute("OwnerUserId")
		table.insert(sites, {
			rect = PlacementRules.RectFromPart(strawArea),
			fixtures = fixtures,
			usable = owner == nil or owner == 0 or owner == userId,
			-- The field slab sits on the ground, so its underside is the ground beside it.
			groundY = strawArea.Position.Y - strawArea.Size.Y / 2,
		})
		table.insert(models, instance)
	end
	return sites, models
end

return PaddySites
