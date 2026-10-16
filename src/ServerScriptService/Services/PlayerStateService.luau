--!strict

local PlayerStateService = {}

local DEFAULT_ATTRIBUTES: { [string]: any } = {
	Credits = 1_000,
	Trust = 50,
	Exposure = 0,
	StrawBundles = 0,
	NextCropValue = 0,
	CratesSold = 0,
	-- Spec 13.3: the tutorial ends at the first sale and normal refunds begin.
	TutorialComplete = false,
}

-- Attributes are untyped in strict mode, so numeric reads go through one checked helper.
local function readNumber(player: Player, attribute: string): number
	local value = player:GetAttribute(attribute)
	return if typeof(value) == "number" then value else 0
end

function PlayerStateService:GetCredits(player: Player): number
	return readNumber(player, "Credits")
end

function PlayerStateService:AdjustCredits(player: Player, amount: number)
	player:SetAttribute("Credits", readNumber(player, "Credits") + amount)
end

function PlayerStateService:RecordSale(player: Player)
	player:SetAttribute("CratesSold", readNumber(player, "CratesSold") + 1)
	player:SetAttribute("TutorialComplete", true)
end

function PlayerStateService:InitializePlayer(player: Player)
	for attribute, defaultValue in DEFAULT_ATTRIBUTES do
		if player:GetAttribute(attribute) == nil then
			player:SetAttribute(attribute, defaultValue)
		end
	end
end

function PlayerStateService:AddStraw(player: Player, amount: number)
	local current = readNumber(player, "StrawBundles")
	player:SetAttribute("StrawBundles", current + amount)
end

function PlayerStateService:AdjustTrust(player: Player, amount: number)
	local current = readNumber(player, "Trust")
	player:SetAttribute("Trust", math.clamp(current + amount, 0, 100))
end

function PlayerStateService:AddExposure(player: Player, amount: number)
	local current = readNumber(player, "Exposure")
	player:SetAttribute("Exposure", math.max(0, current + amount))
end

function PlayerStateService:AddNextCropValue(player: Player, amount: number)
	local current = readNumber(player, "NextCropValue")
	player:SetAttribute("NextCropValue", current + amount)
end

return PlayerStateService
