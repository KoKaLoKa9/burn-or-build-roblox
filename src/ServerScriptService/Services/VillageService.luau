--!strict

-- Village life (Week 6 reactions pass). The people the smoke lands on speak up, so even a
-- player who only burns sees the cost build:
-- * Neighbours, the teacher, the nurse, and the headman react to every burn in a speech card
--   (Speech.client), getting angrier as the burns add up.
-- * On a smog day (SmogService) the school gate shuts and a closure notice goes up.
-- * After a player's third burn the cooperative lends them a dryer to try the other way.
-- And the start of a season has small, honest work besides waiting for rice:
-- * A cattle farmer by the road buys raw straw as feed, cheap but better than burning it.
-- * A village request board asks for straw deliveries that pay credits and trust.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FarmBoard = require(script.Parent:WaitForChild("FarmBoard"))

local VillageService = {}

-- Where the cattle pen and request board stand: by the main road, west of the village path.
local PEN_CENTER = Vector3.new(182, 0, 26)

type Line = { speaker: string, text: string }

-- Reactions to burns, in order. After the last, the angriest ones repeat.
local BURN_LINES: { Line } = {
	{
		speaker = "Somchai, neighbour farmer",
		text = "Burning already? It is quick, I know. My uncle does the same every year.",
	},
	{
		speaker = "Khru Mali, teacher",
		text = "The smoke is drifting over the school. The children were coughing all morning.",
	},
	{
		speaker = "Somchai, neighbour farmer",
		text = "My granddaughter's asthma is back. Can you not sell that straw instead of burning it?",
	},
	{
		speaker = "Nurse Pim, health centre",
		text = "Three more children came in today with breathing trouble. Please, think about the smoke.",
	},
	{
		speaker = "Village headman",
		text = "People are angry. If the burning goes on, the district will fine the whole cooperative.",
	},
}
local REPEAT_LINES: { Line } = {
	{
		speaker = "Village headman",
		text = "Another fire. Families are keeping their children indoors now.",
	},
	{
		speaker = "Nurse Pim, health centre",
		text = "The clinic is full again. Smoke like this stays in small lungs for years.",
	},
	{
		speaker = "Khru Mali, teacher",
		text = "We could not even raise the flag this morning, the air was so thick.",
	},
}
local SMOG_DAY_LINE: Line = {
	speaker = "Khru Mali, teacher",
	text = "We have closed the school for a smog day. The children cannot study in this air.",
}
local LOAN_LINE: Line = {
	speaker = "Cooperative chair",
	text = "Burning wastes good straw. We will lend you a dryer: put it in the factory, feed it straw, and see what it earns.",
}

-- Small jobs the village asks for. Delivered from straw the player carries.
type Request = { who: string, need: number, reward: number, trust: number }
local REQUESTS: { Request } = {
	{ who = "Mushroom grower", need = 4, reward = 70, trust = 2 },
	{ who = "School craft day", need = 2, reward = 40, trust = 3 },
	{ who = "Cattle farmer", need = 6, reward = 90, trust = 2 },
	{ who = "Temple fair", need = 5, reward = 80, trust = 3 },
	{ who = "Garden compost", need = 3, reward = 50, trust = 2 },
}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	collide: boolean?
): BasePart
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.CFrame = cframe
	item.Color = color
	item.Material = material
	item.Anchored = true
	item.CanCollide = collide ~= false
	item.CanQuery = false
	item.CanTouch = false
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function cow(parent: Instance, at: CFrame, color: Color3)
	part(
		parent,
		"Body",
		Vector3.new(2.4, 2.2, 4.4),
		at * CFrame.new(0, 2.6, 0),
		color,
		Enum.Material.SmoothPlastic
	)
	part(
		parent,
		"Head",
		Vector3.new(1.6, 1.6, 1.8),
		at * CFrame.new(0, 3.2, -2.8),
		color,
		Enum.Material.SmoothPlastic
	)
	for _, leg in { { -0.8, -1.6 }, { 0.8, -1.6 }, { -0.8, 1.6 }, { 0.8, 1.6 } } do
		part(
			parent,
			"Leg",
			Vector3.new(0.5, 1.6, 0.5),
			at * CFrame.new(leg[1], 0.8, leg[2]),
			color:Lerp(Color3.new(0, 0, 0), 0.2),
			Enum.Material.SmoothPlastic
		)
	end
end

-- Builds the cattle pen and request board. Runs before the landscape is planted, so trees keep
-- clear of them.
function VillageService:Prepare(world: Model)
	local old = world:FindFirstChild("CattleFarm")
	if old then
		old:Destroy()
	end
	local farm = Instance.new("Model")
	farm.Name = "CattleFarm"
	farm.Parent = world
	local base = CFrame.new(PEN_CENTER)
	local wood = Color3.fromRGB(128, 100, 70)
	part(
		farm,
		"Ground",
		Vector3.new(20, 0.3, 14),
		base * CFrame.new(0, 0.15, 0),
		Color3.fromRGB(150, 120, 80),
		Enum.Material.Ground,
		false
	)
	for _, side in { -1, 1 } do
		part(
			farm,
			"Rail",
			Vector3.new(20, 0.4, 0.4),
			base * CFrame.new(0, 2.6, side * 7),
			wood,
			Enum.Material.Wood
		)
		part(
			farm,
			"Rail",
			Vector3.new(0.4, 0.4, 14),
			base * CFrame.new(side * 10, 2.6, 0),
			wood,
			Enum.Material.Wood
		)
		for _, x in { -10, -5, 0, 5, 10 } do
			part(
				farm,
				"Post",
				Vector3.new(0.5, 3.4, 0.5),
				base * CFrame.new(x, 1.7, side * 7),
				wood,
				Enum.Material.Wood
			)
		end
	end
	cow(
		farm,
		base * CFrame.new(-4, 0, -1) * CFrame.Angles(0, 0.4, 0),
		Color3.fromRGB(196, 170, 140)
	)
	cow(farm, base * CFrame.new(3, 0, 2) * CFrame.Angles(0, -1.9, 0), Color3.fromRGB(110, 84, 62))
	local hay = part(
		farm,
		"Hay",
		Vector3.new(3, 3, 3),
		base * CFrame.new(6.5, 1.2, -3.5),
		Color3.fromRGB(214, 176, 86),
		Enum.Material.Grass
	) :: Part
	hay.Shape = Enum.PartType.Ball
	-- The farmer's stall at the gate, facing the road (+Z).
	part(
		farm,
		"Stall",
		Vector3.new(4, 4, 3),
		base * CFrame.new(-7, 2, 9),
		Color3.fromRGB(46, 140, 124),
		Enum.Material.SmoothPlastic
	)
	-- The request board, facing the road.
	part(
		farm,
		"BoardPost",
		Vector3.new(0.6, 5, 0.6),
		base * CFrame.new(7, 2.5, 9),
		wood,
		Enum.Material.Wood
	)
end

function VillageService:Initialize(
	world: Model,
	gameConfig: any,
	playerState: any,
	machineService: any
)
	local rules = gameConfig.Village
	local farm = world:FindFirstChild("CattleFarm")
	assert(farm, "VillageService:Prepare must run first")

	-- Speech cards ------------------------------------------------------------------------------
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local old = remotes:FindFirstChild("Speech")
	if old then
		old:Destroy()
	end
	local speech = Instance.new("RemoteEvent")
	speech.Name = "Speech"
	speech.Parent = remotes
	local function sayAll(line: Line)
		speech:FireAllClients(line.speaker, line.text)
	end
	local function say(player: Player, line: Line)
		speech:FireClient(player, line.speaker, line.text)
	end

	-- Every burn in the district (own fields, plots, neighbours) gets a reaction.
	local seen: { [Instance]: boolean } = {}
	local burnCount = 0
	local function reactToBurns()
		local records = ReplicatedStorage:FindFirstChild("BurnRecords")
		if records == nil then
			return
		end
		for _, record in records:GetChildren() do
			if not seen[record] then
				seen[record] = true
				burnCount += 1
				sayAll(
					if burnCount <= #BURN_LINES
						then BURN_LINES[burnCount]
						else REPEAT_LINES[(burnCount - #BURN_LINES - 1) % #REPEAT_LINES + 1]
				)
			end
		end
	end

	-- The school shuts on a smog day ------------------------------------------------------------
	local closedShown = false
	local function refreshSchool()
		local until_ = world:GetAttribute("SchoolClosedUntil")
		local closed = typeof(until_) == "number" and workspace:GetServerTimeNow() < until_
		if closed == closedShown then
			return
		end
		closedShown = closed
		local campus = world:FindFirstChild("SchoolCampus", true)
		if campus then
			local gate = campus:FindFirstChild("ClosedGate")
			local sign = campus:FindFirstChild("ClosedSign")
			if gate and gate:IsA("BasePart") then
				gate.Transparency = if closed then 0 else 1
				gate.CanCollide = closed
			end
			if sign and sign:IsA("BasePart") then
				sign.Transparency = if closed then 0 else 1
				local notice = sign:FindFirstChild("Notice")
				if notice and notice:IsA("SurfaceGui") then
					notice.Enabled = closed
				end
			end
		end
		if closed then
			sayAll(SMOG_DAY_LINE)
		end
	end

	-- The cooperative's dryer loan ---------------------------------------------------------------
	local function watchBurns(player: Player)
		player:GetAttributeChangedSignal("Burns"):Connect(function()
			local burns = player:GetAttribute("Burns")
			if
				typeof(burns) == "number"
				and burns >= rules.LoanAfterBurns
				and player:GetAttribute("LoanGiven") ~= true
			then
				player:SetAttribute("LoanGiven", true)
				local owned = player:GetAttribute("Owned_Dryer")
				player:SetAttribute(
					"Owned_Dryer",
					(if typeof(owned) == "number" then owned else 0) + 1
				)
				say(player, LOAN_LINE)
				machineService:Notify(
					player,
					"The cooperative lent you a dryer. It is in your inventory (B)."
				)
			end
		end)
	end
	Players.PlayerAdded:Connect(watchBurns)
	for _, player in Players:GetPlayers() do
		watchBurns(player)
	end

	-- Cattle feed sales -------------------------------------------------------------------------
	local stall = farm:FindFirstChild("Stall") :: BasePart
	local sell = Instance.new("ProximityPrompt")
	sell.Name = "SellFeedPrompt"
	sell.ActionText = string.format("Sell straw as cattle feed (%d each)", rules.CattleFeedPrice)
	sell.ObjectText = "Cattle farmer"
	sell.KeyboardKeyCode = Enum.KeyCode.E
	sell.HoldDuration = 0.5
	sell.MaxActivationDistance = 12
	sell.RequiresLineOfSight = false
	sell.Parent = stall
	sell.Triggered:Connect(function(player)
		local carried = player:GetAttribute("StrawBundles")
		local bundles = if typeof(carried) == "number" then carried else 0
		if bundles <= 0 then
			machineService:Notify(player, "Bring straw to sell. The cattle farmer buys it as feed.")
			return
		end
		player:SetAttribute("StrawBundles", 0)
		local paid = bundles * rules.CattleFeedPrice
		playerState:AdjustCredits(player, paid, "Sales")
		machineService:Notify(
			player,
			string.format(
				"Sold %d bundles as cattle feed: +%d credits. Pellets would pay far more.",
				bundles,
				paid
			)
		)
	end)

	-- Village requests ----------------------------------------------------------------------------
	local post = farm:FindFirstChild("BoardPost") :: BasePart
	local board = FarmBoard.Create(post, "RequestBoard", "Village request")
	local deliver = Instance.new("ProximityPrompt")
	deliver.Name = "DeliverPrompt"
	deliver.ObjectText = "Village request"
	deliver.KeyboardKeyCode = Enum.KeyCode.E
	deliver.HoldDuration = 0.5
	deliver.MaxActivationDistance = 12
	deliver.RequiresLineOfSight = false
	deliver.Parent = post

	local active: Request? = nil
	local endsAt = 0
	local nextAt = workspace:GetServerTimeNow() + 20
	local lastIndex = 0

	local function refreshBoard()
		local request = active
		local nowTime = workspace:GetServerTimeNow()
		if request then
			local left = math.max(0, math.ceil(endsAt - nowTime))
			FarmBoard.Set(
				board,
				string.format("%d:%02d", left // 60, left % 60),
				FarmBoard.Colors.Gold,
				string.format("%s: %d straw", request.who, request.need),
				string.format("Pays %d credits  ·  +%d trust", request.reward, request.trust)
			)
			deliver.ActionText = string.format("Deliver %d straw", request.need)
			deliver.Enabled = true
		else
			FarmBoard.Set(
				board,
				"NONE",
				FarmBoard.Colors.Muted,
				"No request right now",
				"Check back soon"
			)
			deliver.Enabled = false
		end
	end

	deliver.Triggered:Connect(function(player)
		local request = active
		if request == nil then
			return
		end
		local carried = player:GetAttribute("StrawBundles")
		local bundles = if typeof(carried) == "number" then carried else 0
		if bundles < request.need then
			machineService:Notify(
				player,
				string.format(
					"The %s needs %d straw. You carry %d.",
					string.lower(request.who),
					request.need,
					bundles
				)
			)
			return
		end
		player:SetAttribute("StrawBundles", bundles - request.need)
		playerState:AdjustCredits(player, request.reward, "Sales")
		playerState:AdjustTrust(player, request.trust)
		machineService:Notify(
			player,
			string.format(
				"Delivered to the %s: +%d credits, +%d trust.",
				string.lower(request.who),
				request.reward,
				request.trust
			)
		)
		active = nil
		nextAt = workspace:GetServerTimeNow() + rules.RequestGapSeconds
		refreshBoard()
	end)

	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < 0.5 then
			return
		end
		accumulated = 0
		reactToBurns()
		refreshSchool()
		local nowTime = workspace:GetServerTimeNow()
		if active and nowTime >= endsAt then
			active = nil
			nextAt = nowTime + rules.RequestGapSeconds
		elseif active == nil and nowTime >= nextAt then
			lastIndex = lastIndex % #REQUESTS + 1
			active = REQUESTS[lastIndex]
			endsAt = nowTime + rules.RequestSeconds
			machineService:NotifyAll(
				string.format(
					"Village request: the %s needs %d straw. See the board by the cattle pen.",
					string.lower(REQUESTS[lastIndex].who),
					REQUESTS[lastIndex].need
				)
			)
		end
		refreshBoard()
	end)
	refreshBoard()
end

return VillageService
