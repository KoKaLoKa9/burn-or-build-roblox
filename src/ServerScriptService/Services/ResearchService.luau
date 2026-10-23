--!strict

-- Week 6 research. A player builds one cooperative office and hires up to three engineers there.
-- Engineers earn research points over time and draw a small wage. The player picks one project at
-- a time in the research panel (Research.client); when the points cover its cost, the machines
-- that name it in MachineDefinitions unlock. Hiring is cheaper when farmers trust the
-- cooperative, so keeping promises pays off in research too.
--
-- Player attributes the client reads: Engineers, ResearchPoints, ResearchProject (an id or ""),
-- and Research_<Id> = true for every finished project.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ResearchDefinitions = require(Shared:WaitForChild("ResearchDefinitions"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local ResearchService = {}

local TICK_SECONDS = 0.5

local playerState: any
local machineService: any
-- Each player's office record, while they have one.
local offices: { [Player]: any } = {}
local wageTimers: { [Player]: number } = {}

local function readNumber(player: Player, attribute: string): number
	local value = player:GetAttribute(attribute)
	return if typeof(value) == "number" then value else 0
end

local function project(player: Player): string
	local value = player:GetAttribute("ResearchProject")
	return if typeof(value) == "string" then value else ""
end

local function isDone(player: Player, projectId: string): boolean
	return player:GetAttribute("Research_" .. projectId) == true
end

function ResearchService:HireFee(player: Player): number
	local trust = math.clamp(playerState:GetTrust(player), 0, 100)
	return math.floor(ResearchDefinitions.BaseHireFee * (1.5 - trust / 100) + 0.5)
end

local function notify(player: Player, message: string)
	machineService:Notify(player, message)
end

local function startResearch(player: Player, projectId: unknown)
	if typeof(projectId) ~= "string" then
		return
	end
	local definition = ResearchDefinitions.Projects[projectId]
	if definition == nil then
		return
	end
	if isDone(player, projectId) then
		notify(player, definition.DisplayName .. " is already researched.")
		return
	end
	if definition.Requires and not isDone(player, definition.Requires) then
		local needed = ResearchDefinitions.Projects[definition.Requires]
		notify(player, string.format("Research %s first.", string.lower(needed.DisplayName)))
		return
	end
	player:SetAttribute("ResearchProject", projectId)
	notify(
		player,
		if readNumber(player, "Engineers") > 0
			then string.format("Researching %s.", string.lower(definition.DisplayName))
			else string.format(
				"Researching %s. Hire an engineer at the office to earn points.",
				string.lower(definition.DisplayName)
			)
	)
end

local function hire(player: Player)
	if offices[player] == nil then
		notify(player, "Build a cooperative office first.")
		return
	end
	local engineers = readNumber(player, "Engineers")
	if engineers >= ResearchDefinitions.MaxEngineers then
		notify(
			player,
			string.format("The office has room for %d engineers.", ResearchDefinitions.MaxEngineers)
		)
		return
	end
	local fee = ResearchService:HireFee(player)
	if playerState:GetCredits(player) < fee then
		notify(player, string.format("Hiring an engineer costs %d credits.", fee))
		return
	end
	playerState:AdjustCredits(player, -fee, "Research")
	player:SetAttribute("Engineers", engineers + 1)
	notify(
		player,
		string.format(
			"Engineer hired for %d credits. Higher farmer trust makes the next one cheaper.",
			fee
		)
	)
end

-- Points come in, wages go out, and a project finishes once its points are covered.
local function tick(dt: number)
	for _, player in Players:GetPlayers() do
		local engineers = readNumber(player, "Engineers")
		if engineers <= 0 then
			continue
		end
		local world = workspace:FindFirstChild("BurnOrBuildWorld")
		local smoggy = world ~= nil and world:GetAttribute("SmogActive") == true
		local rate = if smoggy then GameConfig.Smog.ResearchRate else 1
		-- The office's computers need power (PowerService): research runs at its power share.
		local office = offices[player]
		if office then
			rate *= office.node.powerRatio
		end
		local points = readNumber(player, "ResearchPoints")
			+ engineers * rate * dt / ResearchDefinitions.SecondsPerPoint
		local active = project(player)
		local definition = ResearchDefinitions.Projects[active]
		if definition and points >= definition.Points then
			points -= definition.Points
			player:SetAttribute("Research_" .. active, true)
			player:SetAttribute("ResearchProject", "")
			notify(
				player,
				string.format(
					"Research complete: %s. Find it in your inventory (B).",
					definition.DisplayName
				)
			)
		end
		player:SetAttribute("ResearchPoints", points)

		local waited = (wageTimers[player] or 0) + dt
		if waited >= ResearchDefinitions.WageIntervalSeconds then
			waited -= ResearchDefinitions.WageIntervalSeconds
			playerState:AdjustCredits(
				player,
				-ResearchDefinitions.WagePerInterval * engineers,
				"Research"
			)
		end
		wageTimers[player] = waited
	end
end

local function describe(record: any): string
	local owner: Player? = record.owner
	if owner == nil then
		return "Cooperative office"
	end
	local engineers = readNumber(owner, "Engineers")
	local active = project(owner)
	local definition = ResearchDefinitions.Projects[active]
	local status = if definition
		then string.format(
			"Researching %s: %d/%d",
			definition.DisplayName,
			math.floor(math.min(readNumber(owner, "ResearchPoints"), definition.Points)),
			definition.Points
		)
		elseif engineers > 0 then "Pick a project: [E] Research"
		else "Hire an engineer: [T]"
	return string.format(
		'Cooperative office\n%d/%d engineers\n<font color="#F6BE48">%s</font>',
		engineers,
		ResearchDefinitions.MaxEngineers,
		status
	)
end

local function initializePlayer(player: Player)
	local defaults: { [string]: any } = { Engineers = 0, ResearchPoints = 0, ResearchProject = "" }
	for attribute, default in defaults do
		if player:GetAttribute(attribute) == nil then
			player:SetAttribute(attribute, default)
		end
	end
end

function ResearchService:Initialize(machines: any, playerStateService: any)
	machineService = machines
	playerState = playerStateService

	Players.PlayerAdded:Connect(initializePlayer)
	for _, player in Players:GetPlayers() do
		initializePlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		offices[player] = nil
		wageTimers[player] = nil
	end)

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local startRemote = remotes:FindFirstChild("StartResearch")
	if startRemote then
		startRemote:Destroy()
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = "StartResearch"
	remote.Parent = remotes
	remote.OnServerEvent:Connect(startResearch)

	machineService:RegisterKindHandler("Office", {
		onPlaced = function(record: any)
			local owner: Player? = record.owner
			local body = record.model.PrimaryPart
			if owner == nil or body == nil then
				return
			end
			offices[owner] = record
			-- E opens the research panel on the owner's screen (Research.client listens for it).
			local research = Instance.new("ProximityPrompt")
			research.Name = "ResearchPrompt"
			research.ActionText = "Research"
			research.ObjectText = "Cooperative office"
			research.KeyboardKeyCode = Enum.KeyCode.E
			research.MaxActivationDistance = 16
			research.RequiresLineOfSight = false
			research.UIOffset = Vector2.new(0, 40)
			research.Parent = body
			local hirePrompt = Instance.new("ProximityPrompt")
			hirePrompt.Name = "HirePrompt"
			hirePrompt.ActionText = "Hire engineer"
			hirePrompt.ObjectText = "Cooperative office"
			hirePrompt.KeyboardKeyCode = Enum.KeyCode.T
			hirePrompt.HoldDuration = 0.5
			hirePrompt.MaxActivationDistance = 16
			hirePrompt.RequiresLineOfSight = false
			hirePrompt.UIOffset = Vector2.new(0, -40)
			hirePrompt.Parent = body
			hirePrompt.Triggered:Connect(function(player)
				if player == owner then
					hire(player)
				else
					notify(player, "This office belongs to " .. owner.DisplayName .. ".")
				end
			end)
			-- Keep the fee on the prompt current, since it follows farmer trust.
			task.spawn(function()
				while hirePrompt.Parent do
					hirePrompt.ActionText =
						string.format("Hire engineer (%d credits)", ResearchService:HireFee(owner))
					task.wait(1)
				end
			end)
		end,
		onRemoved = function(record: any)
			local owner: Player? = record.owner
			if owner and offices[owner] == record then
				offices[owner] = nil
				if readNumber(owner, "Engineers") > 0 then
					owner:SetAttribute("Engineers", 0)
					notify(owner, "The office is gone, so your engineers have left.")
				end
			end
		end,
		describe = describe,
	})

	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated >= TICK_SECONDS then
			tick(accumulated)
			accumulated = 0
		end
	end)
end

return ResearchService
