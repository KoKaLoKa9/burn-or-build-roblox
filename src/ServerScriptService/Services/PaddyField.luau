--!strict

-- One rice paddy's crop cycle, shared by the player's own field (Farm A) and the paddy plots
-- players buy. Straw on the field must be cleared before planting, by hand or by fire. Then each
-- row is planted (seed cost), grows, and is harvested (grain credits), leaving a straw sheaf in
-- the lane beside it. Every batch of straw brings the burn or build choice back.
--
-- A field may start with straw and a clearing deadline (Farm A's first batch). When the deadline
-- passes with straw left, the field burns on its own.
--
-- PaddyField.new returns a handle so farm machines (the transplanter and the combine) can plant
-- and harvest the same rows on behalf of their owner. PaddyField.ForModel finds that handle.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local FarmBoard = require(script.Parent:WaitForChild("FarmBoard"))
local StrawSheaf = require(script.Parent:WaitForChild("StrawSheaf"))

local PaddyField = {}

-- Tag on every paddy model, so the season can tell when crops are still in play. Build mode and
-- farm machine placement also find paddies through it.
PaddyField.Tag = "Paddy"

local UPDATE_SECONDS = 0.5
local CHARRED = Color3.fromRGB(52, 45, 38)
local PREPARED = Color3.fromRGB(128, 104, 70)
local SEEDLING = Color3.fromRGB(160, 214, 96)
local GROWN = Color3.fromRGB(70, 142, 52)
local Colors = FarmBoard.Colors
-- Sheaves stand at varied depths in each lane, as a share of the row length.
local SHEAF_DEPTHS = { -0.31, 0.19, -0.09, 0.34, -0.22, 0.06, 0.28, -0.37 }

-- Planted rice fills most of its lane like a real paddy; bare and stubble rows stay narrow so
-- the straw sheaves have room in the lanes between them.
type Look = { width: number, height: number, color: Color3, material: Enum.Material }
local NARROW, WIDE = 2.2, 6.4
local EMPTY_LOOK: Look = {
	width = NARROW,
	height = 0.5,
	color = Color3.fromRGB(104, 80, 56),
	material = Enum.Material.Ground,
}
local STUBBLE_LOOK: Look = {
	width = NARROW,
	height = 1.2,
	color = Color3.fromRGB(198, 160, 82),
	material = Enum.Material.Grass,
}
local RIPE_LOOK: Look = {
	width = WIDE,
	height = 3.4,
	color = Color3.fromRGB(228, 188, 72),
	material = Enum.Material.Grass,
}

type Row = {
	index: number,
	part: BasePart,
	bottom: CFrame,
	stage: string, -- Stubble, Empty, Growing, Ripe
	plantedAt: number,
	prompt: ProximityPrompt,
}

export type Options = {
	model: Model,
	title: string, -- board title, such as "Your field"
	displayName: string, -- name in burn records and notices
	strawArea: BasePart,
	burnPoint: BasePart,
	boardPart: BasePart,
	boardName: string,
	rows: { BasePart },
	-- Which end of the rows faces the path: 1 is the +Z end (default), -1 the -Z end.
	front: number?,
	planting: any, -- SeedCost, GrowSeconds, GrainCredits, BurnClearSeconds
	burnExposure: number,
	burnTrustLoss: number,
	-- Only the owner may plant, harvest, and burn. No owner means anyone may.
	owner: Player?,
	-- Straw already lying on the field at the start, and when it must be cleared.
	startingSheaves: number?,
	deadlineAt: number?,
	-- Services the field reports to.
	world: Model,
	playerState: any,
	smokeService: any,
	gameConfig: any,
	notify: (player: Player?, message: string) -> (),
	-- Called when the field is clear of straw. `first` is true for the opening batch.
	onCleared: ((how: string, triggeringPlayer: Player?, first: boolean) -> ())?,
	onSheafCollected: ((first: boolean) -> ())?,
}

-- What a farm machine needs to know before it works a row.
export type Status = {
	empty: number,
	growing: number,
	ripe: number,
	sheaves: number,
	clearing: boolean,
}

export type Handle = {
	model: Model,
	strawArea: BasePart,
	owner: Player?,
	planting: any,
	-- Whether this player may farm the paddy (the owner, or anyone on an unowned field).
	CanUse: (player: Player) -> boolean,
	Status: () -> Status,
	-- Plants the first empty row or harvests the first ripe row for this player. Returns
	-- whether a row was worked and, if not, why. Nothing is told to the player, so a machine
	-- can call these every tick.
	PlantNext: (player: Player) -> (boolean, string),
	HarvestNext: (player: Player) -> (boolean, string),
}

local handles: { [Model]: Handle } = setmetatable({}, { __mode = "k" }) :: any

function PaddyField.ForModel(model: Instance): Handle?
	return if model:IsA("Model") then handles[model] else nil
end

local function now(): number
	return workspace:GetServerTimeNow()
end

-- "1 row", "3 rows", "1 sheaf", "4 sheaves".
local function count(amount: number, singular: string, plural: string?): string
	return string.format(
		"%d %s",
		amount,
		if amount == 1 then singular else plural or singular .. "s"
	)
end

local function formatClock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

function PaddyField.Prompt(
	parent: Instance,
	name: string,
	actionText: string,
	objectText: string,
	keyboardKey: Enum.KeyCode,
	holdDuration: number
): ProximityPrompt
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("ProximityPrompt") then
		existing:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = keyboardKey
	prompt.HoldDuration = holdDuration
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function setLook(
	row: Row,
	width: number,
	height: number,
	color: Color3,
	material: Enum.Material
)
	row.part.Size = Vector3.new(width, height, row.part.Size.Z)
	row.part.CFrame = row.bottom * CFrame.new(0, height / 2, 0)
	row.part.Color = color
	row.part.Material = material
end

local function applyLook(row: Row, look: Look)
	setLook(row, look.width, look.height, look.color, look.material)
end

function PaddyField.new(options: Options): Handle
	local planting = options.planting
	local model = options.model
	local strawArea = options.strawArea
	local playerState = options.playerState
	local notify = options.notify

	local firstBatch = (options.startingSheaves or 0) > 0
	local deadlineAt = options.deadlineAt
	local clearing = false
	local batch = 0
	local sheaves: { Model } = {}
	local rows: { Row } = {}

	-- Build mode reads the owner to tell whether a farm machine may be placed here.
	model:SetAttribute("OwnerUserId", if options.owner then options.owner.UserId else 0)
	CollectionService:AddTag(model, PaddyField.Tag)
	local oldSheaves = model:FindFirstChild("Sheaves")
	if oldSheaves then
		oldSheaves:Destroy()
	end
	local sheafFolder = Instance.new("Folder")
	sheafFolder.Name = "Sheaves"
	sheafFolder.Parent = model

	local burnPrompt = PaddyField.Prompt(
		options.burnPoint,
		"BurnPrompt",
		"Allow burning",
		"Immediate field clearing",
		Enum.KeyCode.H,
		2
	)
	local board = FarmBoard.Create(options.boardPart, options.boardName, options.title)

	local function canUse(player: Player): boolean
		local owner = options.owner
		return owner == nil or owner == player
	end

	local function ownerMessage(): string
		local owner = options.owner
		return string.format(
			"This paddy belongs to %s.",
			if owner then owner.DisplayName else "another player"
		)
	end

	local function allowed(player: Player): boolean
		if canUse(player) then
			return true
		end
		notify(player, ownerMessage())
		return false
	end

	-- Lanes sit halfway between neighbouring rows; depths vary so sheaves never line up.
	local function sheafGround(lane: number, pass: number): CFrame
		local laneCount = #rows - 1
		local left = rows[math.clamp(lane, 1, laneCount)]
		local right = rows[math.clamp(lane, 1, laneCount) + 1]
		local x = (left.bottom.Position.X + right.bottom.Position.X) / 2
		local depth = SHEAF_DEPTHS[(lane + pass * 3) % #SHEAF_DEPTHS + 1] * left.part.Size.Z
		local top = strawArea.Position.Y + strawArea.Size.Y / 2
		return CFrame.new(x, top, strawArea.Position.Z + depth)
	end

	local refreshPrompts: () -> ()

	local function refreshBoard()
		local raining = options.world:GetAttribute("WeatherActive") == "Rain"
		local growing, ripe, empty = 0, 0, 0
		local nextRipe = math.huge
		for _, row in rows do
			if row.stage == "Growing" then
				growing += 1
				nextRipe = math.min(nextRipe, row.plantedAt + planting.GrowSeconds)
			elseif row.stage == "Ripe" then
				ripe += 1
			elseif row.stage == "Empty" then
				empty += 1
			end
		end

		if clearing then
			FarmBoard.Set(
				board,
				"BURNING",
				Colors.Red,
				"Straw burning",
				"Smoke is drifting downwind"
			)
		elseif #sheaves > 0 then
			FarmBoard.Set(
				board,
				"STRAW",
				Colors.Gold,
				if deadlineAt
					then string.format(
						"%s left  ·  %s",
						count(#sheaves, "sheaf", "sheaves"),
						formatClock(deadlineAt - now())
					)
					else count(#sheaves, "sheaf", "sheaves") .. " left",
				if raining
					then "Raining: straw stays wet"
					else "Clear it to replant: collect it, or burn it"
			)
		elseif ripe > 0 then
			FarmBoard.Set(
				board,
				"RIPE",
				Colors.Gold,
				count(ripe, "row") .. " ripe",
				string.format(
					"Harvest at the row ends: %d credits of grain each",
					planting.GrainCredits
				)
			)
		elseif growing > 0 then
			FarmBoard.Set(
				board,
				"GROWING",
				Colors.Green,
				string.format(
					"%s growing  ·  ripe in %s",
					count(growing, "row"),
					formatClock(nextRipe - now())
				),
				if empty > 0
					then count(empty, "row") .. " still empty"
					else "Harvest gives grain and new straw"
			)
		else
			FarmBoard.Set(
				board,
				"READY TO PLANT",
				Colors.Teal,
				"Field clear",
				string.format("Plant at the row ends: %d credits a row", planting.SeedCost)
			)
		end

		model:SetAttribute("RemainingBundles", #sheaves)
		-- The opening batch is judged by its own deadline, so it does not hold the season open.
		model:SetAttribute(
			"CropActive",
			not firstBatch and (growing > 0 or ripe > 0 or #sheaves > 0 or clearing)
		)
	end

	-- Straw is gone (picked up or burned): stubble rows turn back into empty, plantable rows.
	local function fieldCleared(how: string, triggeringPlayer: Player?)
		-- Cleared ground reads as a prepared, muddy paddy rather than a stubble field.
		strawArea.Color = PREPARED
		strawArea.Material = Enum.Material.Ground
		for _, row in rows do
			if row.stage == "Stubble" then
				row.stage = "Empty"
				applyLook(row, EMPTY_LOOK)
			end
		end
		local first = firstBatch
		firstBatch = false
		deadlineAt = nil
		if options.onCleared then
			options.onCleared(how, triggeringPlayer, first)
		end
		refreshPrompts()
		refreshBoard()
	end

	local function collectSheaf(player: Player, sheaf: Model)
		local position = table.find(sheaves, sheaf)
		if clearing or position == nil then
			return
		end
		table.remove(sheaves, position)
		sheaf:Destroy()
		playerState:AddStraw(player, 1)
		if options.onSheafCollected then
			options.onSheafCollected(firstBatch)
		end
		if #sheaves == 0 then
			fieldCleared("Collected", nil)
		else
			refreshPrompts()
			refreshBoard()
		end
	end

	local function addSheaf(ground: CFrame, seed: number)
		local sheaf, bundle = StrawSheaf.Build(ground, seed)
		local prompt = PaddyField.Prompt(
			bundle,
			"PickUpPrompt",
			"Pick up",
			"Rice straw sheaf",
			Enum.KeyCode.E,
			0.3
		)
		prompt.MaxActivationDistance = 8
		prompt.Triggered:Connect(function(player)
			collectSheaf(player, sheaf)
		end)
		sheaf.Parent = sheafFolder
		table.insert(sheaves, sheaf)
	end

	local function burn(triggeringPlayer: Player?)
		if clearing or #sheaves == 0 then
			return
		end
		clearing = true
		local burnedBundles = #sheaves
		for _, sheaf in sheaves do
			StrawSheaf.Char(sheaf)
		end
		for _, row in rows do
			if row.stage == "Stubble" then
				row.part.Color = CHARRED
			end
		end

		-- The person who lit it loses trust. A deadline burn on an unowned field costs everyone.
		local blamed: { Player } = if triggeringPlayer
			then { triggeringPlayer }
			elseif options.owner then { options.owner }
			else Players:GetPlayers()
		for _, player in blamed do
			playerState:AdjustTrust(player, -options.burnTrustLoss)
		end
		options.smokeService:BurnField(
			options.world,
			options.burnPoint,
			options.burnExposure,
			playerState,
			options.gameConfig,
			{
				field = options.displayName,
				quantity = burnedBundles,
				responsibility = if triggeringPlayer
					then "PlayerAuthorized"
					else "PlayerFarmDeadline",
			}
		)
		refreshPrompts()
		refreshBoard()

		task.delay(planting.BurnClearSeconds, function()
			for _, sheaf in sheaves do
				sheaf:Destroy()
			end
			table.clear(sheaves)
			clearing = false
			fieldCleared("Burned", triggeringPlayer)
		end)
	end

	-- Plants and harvests return whether the row was worked and, if not, why. The row prompts
	-- tell the player; farm machines show the reason on their own board instead.
	local function plant(player: Player, row: Row): (boolean, string)
		if row.stage ~= "Empty" then
			return false, "This row is not ready to plant."
		end
		if not canUse(player) then
			return false, ownerMessage()
		end
		if #sheaves > 0 or clearing then
			return false, "Clear the straw off the field before you plant."
		end
		if playerState:GetCredits(player) < planting.SeedCost then
			return false, string.format("Seed for a row costs %d credits.", planting.SeedCost)
		end
		playerState:AdjustCredits(player, -planting.SeedCost, "Rice")
		row.stage = "Growing"
		row.plantedAt = now()
		setLook(row, WIDE, 1, SEEDLING, Enum.Material.LeafyGrass)
		refreshPrompts()
		refreshBoard()
		return true, ""
	end

	local function harvest(player: Player, row: Row): (boolean, string)
		if row.stage ~= "Ripe" then
			return false, "This row is not ripe yet."
		end
		if not canUse(player) then
			return false, ownerMessage()
		end
		row.stage = "Stubble"
		applyLook(row, STUBBLE_LOOK)
		playerState:AdjustCredits(player, planting.GrainCredits, "Rice")
		-- Each row leaves one sheaf in the lane beside it; later batches shift the depth.
		local lane = math.min(row.index, #rows - 1)
		local pass = batch * 2 + (if row.index > #rows - 1 then 1 else 0)
		addSheaf(sheafGround(lane, pass), row.index + batch * 17)
		local cropLeft = false
		for _, other in rows do
			if other.stage == "Ripe" or other.stage == "Growing" then
				cropLeft = true
			end
		end
		if not cropLeft then
			batch += 1
		end
		refreshPrompts()
		refreshBoard()
		return true, ""
	end

	refreshPrompts = function()
		burnPrompt.Enabled = #sheaves > 0 and not clearing
		for _, row in rows do
			if row.stage == "Ripe" then
				row.prompt.ActionText = "Harvest rice"
				row.prompt.Enabled = true
			elseif row.stage == "Empty" then
				row.prompt.ActionText = string.format("Plant rice (%d credits)", planting.SeedCost)
				row.prompt.Enabled = #sheaves == 0 and not clearing
			else
				row.prompt.Enabled = false
			end
		end
		for _, sheaf in sheaves do
			local prompt = sheaf:FindFirstChild("PickUpPrompt", true)
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Enabled = not clearing
			end
		end
	end

	-- Rows run north to south, left to right. Each gets a prompt at its south end, so the
	-- player plants and harvests by walking along the front of the field.
	local rowParts = table.clone(options.rows)
	table.sort(rowParts, function(a, b)
		return a.Position.X < b.Position.X
	end)
	local startStage = if firstBatch then "Stubble" else "Empty"
	for index, part in rowParts do
		part.CanCollide = false
		local bottom = part.CFrame * CFrame.new(0, -part.Size.Y / 2, 0)
		local anchor = Instance.new("Attachment")
		anchor.Name = "RowEnd"
		anchor.Position = Vector3.new(0, 0, (options.front or 1) * (part.Size.Z / 2 - 3))
		anchor.Parent = part
		local prompt = PaddyField.Prompt(
			anchor,
			"RowPrompt",
			"Plant rice",
			"Rice row " .. index,
			Enum.KeyCode.E,
			0.6
		)
		prompt.MaxActivationDistance = 9
		local row: Row = {
			index = index,
			part = part,
			bottom = bottom,
			stage = startStage,
			plantedAt = 0,
			prompt = prompt,
		}
		applyLook(row, if firstBatch then STUBBLE_LOOK else EMPTY_LOOK)
		prompt.Triggered:Connect(function(player)
			if row.stage == "Ripe" then
				local ok, reason = harvest(player, row)
				notify(
					player,
					if ok
						then string.format(
							"Harvested a row: +%d credits of grain. Its straw is on the field.",
							planting.GrainCredits
						)
						else reason
				)
			else
				local ok, reason = plant(player, row)
				if not ok then
					notify(player, reason)
				end
			end
		end)
		table.insert(rows, row)
	end
	if not firstBatch then
		strawArea.Color = PREPARED
		strawArea.Material = Enum.Material.Ground
	end

	-- The opening straw keeps Farm A's original layout (spec 2.3: manual collection first).
	for index = 1, options.startingSheaves or 0 do
		addSheaf(StrawSheaf.GroundFor(strawArea, index), index)
	end
	batch = 1

	burnPrompt.Triggered:Connect(function(player)
		if allowed(player) then
			burn(player)
		end
	end)
	refreshPrompts()
	refreshBoard()

	task.spawn(function()
		while model.Parent do
			local current = now()
			for _, row in rows do
				if row.stage == "Growing" then
					local grown = math.clamp((current - row.plantedAt) / planting.GrowSeconds, 0, 1)
					if grown >= 1 then
						row.stage = "Ripe"
						applyLook(row, RIPE_LOOK)
						refreshPrompts()
					else
						setLook(
							row,
							WIDE,
							1 + grown * 2.2,
							SEEDLING:Lerp(GROWN, grown),
							Enum.Material.LeafyGrass
						)
					end
				end
			end
			if deadlineAt and not clearing and #sheaves > 0 and current >= deadlineAt then
				burn(nil)
			end
			refreshBoard()
			task.wait(UPDATE_SECONDS)
		end
	end)

	local function firstRow(stage: string): Row?
		for _, row in rows do
			if row.stage == stage then
				return row
			end
		end
		return nil
	end

	local handle: Handle = {
		model = model,
		strawArea = strawArea,
		owner = options.owner,
		planting = planting,
		CanUse = canUse,
		Status = function(): Status
			local status: Status = {
				empty = 0,
				growing = 0,
				ripe = 0,
				sheaves = #sheaves,
				clearing = clearing,
			}
			for _, row in rows do
				if row.stage == "Empty" then
					status.empty += 1
				elseif row.stage == "Growing" then
					status.growing += 1
				elseif row.stage == "Ripe" then
					status.ripe += 1
				end
			end
			return status
		end,
		PlantNext = function(player: Player): (boolean, string)
			local row = firstRow("Empty")
			if row == nil then
				return false, "No empty rows."
			end
			return plant(player, row)
		end,
		HarvestNext = function(player: Player): (boolean, string)
			local row = firstRow("Ripe")
			if row == nil then
				return false, "No ripe rows."
			end
			return harvest(player, row)
		end,
	}
	handles[model] = handle
	return handle
end

return PaddyField
