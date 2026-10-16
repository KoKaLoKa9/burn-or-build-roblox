--!strict

-- Farm A, the player's own rice field. The season opens with harvested straw lying on it and a
-- clearing deadline (spec 2.3 phase 1). After that first batch the field is replanted again and
-- again through PaddyField. Only the first batch decides the field's season result.

local Players = game:GetService("Players")

local PaddyField = require(script.Parent:WaitForChild("PaddyField"))

local FieldService = {}

function FieldService:Initialize(
	world: Model,
	playerStateService: any,
	smokeService: any,
	gameConfig: any,
	machineService: any
)
	local fieldDefinition = gameConfig.Fields.FarmA
	local fieldModel = world:FindFirstChild(fieldDefinition.ModelName, true)
	assert(fieldModel and fieldModel:IsA("Model"), "Farm_A model is missing from the graybox")

	local collectionPoint = fieldModel:FindFirstChild("CollectionPoint")
	local burnPoint = fieldModel:FindFirstChild("BurnPoint")
	local strawArea = fieldModel:FindFirstChild("StrawArea")
	assert(collectionPoint and collectionPoint:IsA("BasePart"), "Farm_A CollectionPoint is missing")
	assert(burnPoint and burnPoint:IsA("BasePart"), "Farm_A BurnPoint is missing")
	assert(strawArea and strawArea:IsA("BasePart"), "Farm_A StrawArea is missing")

	local rows: { BasePart } = {}
	for _, child in fieldModel:GetChildren() do
		if child:IsA("BasePart") and child.Name == "RiceRow" then
			table.insert(rows, child)
		end
	end

	local deadlineAt = workspace:GetServerTimeNow() + fieldDefinition.DeadlineSeconds
	fieldModel:SetAttribute("DisplayName", fieldDefinition.DisplayName)
	fieldModel:SetAttribute("DeadlineAt", deadlineAt)
	fieldModel:SetAttribute("State", "Ready")

	PaddyField.new({
		model = fieldModel,
		title = "Your field",
		displayName = fieldDefinition.DisplayName,
		strawArea = strawArea,
		burnPoint = burnPoint,
		boardPart = collectionPoint,
		boardName = "FieldStatus",
		rows = rows,
		planting = fieldDefinition.Planting,
		burnExposure = fieldDefinition.BurnExposure,
		burnTrustLoss = fieldDefinition.BurnTrustLoss,
		owner = nil,
		startingSheaves = fieldDefinition.Bundles,
		deadlineAt = deadlineAt,
		world = world,
		playerState = playerStateService,
		smokeService = smokeService,
		gameConfig = gameConfig,
		notify = function(player: Player?, message: string)
			if machineService and player then
				machineService:Notify(player, message)
			end
		end,
		onSheafCollected = function(first: boolean)
			if first then
				fieldModel:SetAttribute("State", "Collecting")
			end
		end,
		onCleared = function(how: string, triggeringPlayer: Player?, first: boolean)
			if not first then
				return
			end
			fieldModel:SetAttribute("State", how)
			-- After a player's own burn only that player books the next crop; a clean clear or
			-- a deadline burn books it for everyone (as before replanting existed).
			if how == "Burned" and triggeringPlayer then
				playerStateService:AddNextCropValue(triggeringPlayer, fieldDefinition.NextCropValue)
			else
				for _, player in Players:GetPlayers() do
					playerStateService:AddNextCropValue(player, fieldDefinition.NextCropValue)
				end
			end
		end,
	})
end

return FieldService
