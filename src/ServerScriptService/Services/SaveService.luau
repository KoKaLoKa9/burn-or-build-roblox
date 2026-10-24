--!strict

-- Saves each player's progress for the endless sandbox (docs/IndustryExpansion.md section 2.6):
-- money, trust, research, inventory and every other player attribute, the paddy plots they
-- bought, and their whole factory layout (machines, belts and pipes). Machines rebuild empty; what
-- was inside a machine or on a belt at the moment of leaving is not kept.
--
-- Saves every AUTOSAVE_SECONDS, when the player leaves and when the server closes. If loading
-- fails (no DataStore access, for example in Studio without API access) the player plays
-- normally but nothing is saved, so a failed load can never overwrite real progress.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local SaveService = {}

local STORE_NAME = "BurnOrBuild_Save_v1"
local AUTOSAVE_SECONDS = 60
-- Live readings and per-visit state that should start fresh every time.
local SKIP_ATTRIBUTES: { [string]: boolean } = {
	PowerSupplyKW = true,
	PowerDemandKW = true,
	Wires = true,
}

local store: DataStore? = nil
local machineService: any
local plotService: any
local powerService: any
local world: Model
-- Players whose save loaded cleanly; only these are ever written back.
local loaded: { [Player]: boolean } = {}

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

function SaveService:Snapshot(player: Player): any
	local attributes: { [string]: any } = {}
	for name, value in player:GetAttributes() do
		local kind = typeof(value)
		if
			not SKIP_ATTRIBUTES[name]
			and (kind == "number" or kind == "string" or kind == "boolean")
		then
			attributes[name] = value
		end
	end
	local layout = machineService:ExportLayout(player)
	-- Wires name their machines by place in the saved list; live ids mean nothing next visit.
	local wires = powerService:ExportWires(player, layout.nodeIds)
	layout.nodeIds = nil
	return {
		version = 1,
		savedAt = os.time(),
		attributes = attributes,
		plots = plotService:Owned(player),
		layout = layout,
		wires = wires,
		year = world:GetAttribute("SeasonNumber"),
	}
end

local function save(player: Player)
	local dataStore = store
	if dataStore == nil or not loaded[player] then
		return
	end
	local data = SaveService:Snapshot(player)
	local ok, err = pcall(function()
		dataStore:SetAsync(keyFor(player), data, { player.UserId })
	end)
	if not ok then
		warn("[SaveService] Could not save " .. player.Name .. ": " .. tostring(err))
	end
end

function SaveService:Apply(player: Player, data: any)
	for name, value in data.attributes or {} do
		player:SetAttribute(name, value)
	end
	for _, index in data.plots or {} do
		plotService:Grant(player, index)
	end
	local year = data.year
	local current = world:GetAttribute("SeasonNumber")
	if typeof(year) == "number" and typeof(current) == "number" and year > current then
		world:SetAttribute("SeasonNumber", year)
	end
	-- After attributes, so research unlocks and the finished tutorial are in place first.
	local newIds = machineService:ImportLayout(player, data.layout)
	powerService:ImportWires(player, data.wires, newIds)
end

local function load(player: Player)
	local dataStore = store
	if dataStore == nil then
		return
	end
	local ok, result = pcall(function()
		return dataStore:GetAsync(keyFor(player))
	end)
	if not ok then
		warn("[SaveService] Could not load " .. player.Name .. ": " .. tostring(result))
		machineService:Notify(
			player,
			"Saving is unavailable right now, so this visit will not be saved."
		)
		return
	end
	if player.Parent == nil then
		return
	end
	loaded[player] = true
	if typeof(result) == "table" then
		SaveService:Apply(player, result)
	end
end

function SaveService:Initialize(worldModel: Model, machines: any, plots: any, power: any)
	world = worldModel
	machineService = machines
	plotService = plots
	powerService = power
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[SaveService] DataStore unavailable: " .. tostring(result))
	end

	local function onJoin(player: Player)
		task.spawn(load, player)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		loaded[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for _, player in Players:GetPlayers() do
				save(player)
			end
		end
	end)
end

return SaveService
