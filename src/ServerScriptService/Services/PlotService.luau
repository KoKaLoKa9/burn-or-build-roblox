--!strict

-- Paddy plots the player can buy (Week 5). Each lot starts as staked-out grass with a FOR SALE
-- board. Buying it turns the lot into a small paddy that runs the same cycle as the player's
-- own field through PaddyField: plant, grow, harvest for grain, and clear the straw by hand or
-- by fire. Only the buyer may farm their plot; anyone may carry its straw away.

local Flora = require(script.Parent:WaitForChild("Flora"))
local FarmBoard = require(script.Parent:WaitForChild("FarmBoard"))
local PaddyField = require(script.Parent:WaitForChild("PaddyField"))

local PlotService = {}

local ROW_SPACING = 9
local STAKE = Color3.fromRGB(128, 100, 70)

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.CFrame = cframe
	item.Color = color
	item.Material = material
	item.Anchored = true
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

function PlotService:Initialize(
	world: Model,
	playerState: any,
	smokeService: any,
	gameConfig: any,
	machineService: any
)
	local config = gameConfig.Plots
	local planting = gameConfig.Fields.FarmA.Planting
	local oldFolder = world:FindFirstChild("Plots")
	if oldFolder then
		oldFolder:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = world

	local function notify(player: Player?, message: string)
		if player then
			machineService:Notify(player, message)
		end
	end

	for index, lot in config.Lots do
		local model = Instance.new("Model")
		model.Name = "Plot_" .. index
		model:SetAttribute("DisplayName", lot.Name)
		model:SetAttribute("OwnerUserId", 0)
		model.Parent = folder

		local width, depth, front = config.Width, config.Depth, lot.Front
		local center = CFrame.new(lot.X, 0, lot.Z)
		local frontZ = front * (depth / 2 + 6)

		-- Corner stakes mark the lot while it is for sale.
		local stakes = Instance.new("Model")
		stakes.Name = "Stakes"
		stakes.Parent = model
		for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			local stake = part(
				stakes,
				"Stake",
				Vector3.new(0.6, 3, 0.6),
				center * CFrame.new(corner[1] * width / 2, 1.5, corner[2] * depth / 2),
				STAKE,
				Enum.Material.Wood
			)
			stake.CanCollide = false
		end

		local sign = part(
			model,
			"Sign",
			Vector3.new(0.8, 5, 0.8),
			center * CFrame.new(-width / 2 + 6, 2.5, frontZ),
			STAKE,
			Enum.Material.Wood
		)
		local board = FarmBoard.Create(sign, "PlotBoard", lot.Name)
		FarmBoard.Set(
			board,
			"FOR SALE",
			FarmBoard.Colors.Teal,
			string.format("%d credits", config.Price),
			string.format("Hold E to buy: a paddy with %d rows", config.Rows)
		)
		local buyPrompt = PaddyField.Prompt(
			sign,
			"BuyPrompt",
			string.format("Buy plot (%d credits)", config.Price),
			lot.Name,
			Enum.KeyCode.E,
			1
		)

		local function build(owner: Player)
			stakes:Destroy()
			local strawArea = part(
				model,
				"StrawArea",
				Vector3.new(width, 1, depth),
				center * CFrame.new(0, 0.5, 0),
				Color3.fromRGB(128, 104, 70),
				Enum.Material.Ground
			)
			local rows: { BasePart } = {}
			for row = 1, config.Rows do
				local x = (row - (config.Rows + 1) / 2) * ROW_SPACING
				local rice = part(
					model,
					"RiceRow",
					Vector3.new(2.2, 0.5, depth - 8),
					center * CFrame.new(x, 1.05, 0),
					Color3.fromRGB(104, 80, 56),
					Enum.Material.Ground
				)
				rice.CanCollide = false
				table.insert(rows, rice)
			end
			local burnPoint = part(
				model,
				"BurnPoint",
				Vector3.new(6, 0.4, 6),
				center * CFrame.new(-width / 2 + 18, 0.2, frontZ),
				Color3.fromRGB(150, 80, 50),
				Enum.Material.Slate
			)
			burnPoint.CanCollide = false

			-- Bunds on three sides; the front stays open onto the path.
			local bunds = Instance.new("Model")
			bunds.Name = "Bunds"
			bunds.Parent = model
			local backZ = -front * depth / 2
			Flora.Bund(bunds, center * CFrame.new(0, 0, backZ), width + 2.2)
			Flora.Bund(
				bunds,
				center * CFrame.new(-width / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0),
				depth
			)
			Flora.Bund(
				bunds,
				center * CFrame.new(width / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0),
				depth
			)

			PaddyField.new({
				model = model,
				title = lot.Name,
				displayName = string.format("%s's %s", owner.DisplayName, string.lower(lot.Name)),
				strawArea = strawArea,
				burnPoint = burnPoint,
				boardPart = sign,
				boardName = "PlotBoard",
				rows = rows,
				front = front,
				planting = planting,
				burnExposure = gameConfig.Fields.FarmA.BurnExposure,
				burnTrustLoss = gameConfig.Fields.FarmA.BurnTrustLoss,
				owner = owner,
				world = world,
				playerState = playerState,
				smokeService = smokeService,
				gameConfig = gameConfig,
				notify = notify,
			})
		end

		buyPrompt.Triggered:Connect(function(player)
			if model:GetAttribute("OwnerUserId") ~= 0 then
				return
			end
			if playerState:GetCredits(player) < config.Price then
				notify(player, string.format("A paddy plot costs %d credits.", config.Price))
				return
			end
			playerState:AdjustCredits(player, -config.Price, "Construction")
			model:SetAttribute("OwnerUserId", player.UserId)
			buyPrompt:Destroy()
			build(player)
			notify(
				player,
				string.format("You bought %s. Plant rice at the row ends.", string.lower(lot.Name))
			)
		end)
	end
end

return PlotService
