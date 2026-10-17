--!strict

-- Neighboring farm commitments (spec v0.2 section 10 and 15.2).
-- Pure Luau with no Roblox instances; the caller passes server time in, so Lune can test it.
--
-- Week 6: farms come back. RegrowSeconds after a farm resolves (completed, missed, or burned) it
-- replants and opens a fresh contract with NextDeadlineSeconds to clear it. Completing contracts
-- in a row raises the reliability bonus by StreakBonusStep per completion, up to StreakBonusCap;
-- a missed or unserved round resets the streak. Farms without RegrowSeconds stay closed.

local FarmCommitments = {}
FarmCommitments.__index = FarmCommitments

-- States follow spec 10.2. "Burned" marks a farm that burned without an accepted promise.
export type Farm = {
	id: string,
	definition: any,
	state: string,
	remaining: number,
	deadlineAt: number,
	extended: boolean,
	owner: any,
	resolved: boolean,
	burnedBundles: number,
	resolvedAt: number,
	round: number,
	streak: number,
}

export type Event = {
	type: string,
	farmId: string,
	owner: any,
	trust: number?,
	credits: number?,
	quantity: number?,
	exposure: number?,
	responsibility: string?,
	streak: number?,
}

function FarmCommitments.new(config: any, startTime: number)
	local self = setmetatable({}, FarmCommitments)
	self.config = config
	self.farms = {} :: { [string]: Farm }
	self.events = {} :: { Event }
	for id, definition in config.Farms do
		self.farms[id] = {
			id = id,
			definition = definition,
			state = "Available",
			remaining = definition.Bundles,
			deadlineAt = startTime + definition.DeadlineSeconds,
			extended = false,
			owner = nil,
			resolved = false,
			burnedBundles = 0,
			resolvedAt = 0,
			round = 1,
			streak = 0,
		}
	end
	return self
end

function FarmCommitments:Get(farmId: string): Farm?
	return self.farms[farmId]
end

function FarmCommitments:_emit(event: Event)
	table.insert(self.events, event)
end

local function isPromised(farm: Farm): boolean
	return farm.state == "Accepted" or farm.state == "InProgress" or farm.state == "Extended"
end

function FarmCommitments:Accept(farmId: string, owner: any): (boolean, string)
	local farm = self.farms[farmId]
	if farm == nil then
		return false, "Unknown farm."
	end
	if farm.state ~= "Available" then
		return false, farm.definition.DisplayName .. " has already been answered."
	end
	farm.state = "Accepted"
	farm.owner = owner
	self:_emit({ type = "Accepted", farmId = farmId, owner = owner })
	return true,
		string.format(
			"Accepted %s: clear %d bundles before the deadline.",
			farm.definition.DisplayName,
			farm.remaining
		)
end

-- Spec 10.4: rejecting before accepting costs no trust, but the farmer may still burn later.
function FarmCommitments:Reject(farmId: string, owner: any): (boolean, string)
	local farm = self.farms[farmId]
	if farm == nil then
		return false, "Unknown farm."
	end
	if farm.state ~= "Available" then
		return false, farm.definition.DisplayName .. " has already been answered."
	end
	farm.state = "Rejected"
	farm.owner = owner
	self:_emit({
		type = "Rejected",
		farmId = farmId,
		owner = owner,
		trust = farm.definition.RejectTrust,
	})
	return true,
		string.format(
			"Rejected %s. No promise made, but the farmer may burn at the deadline.",
			farm.definition.DisplayName
		)
end

-- Spec 10.2: one approved extension moves the deadline. A second one is unavailable.
function FarmCommitments:Extend(farmId: string, owner: any, now: number): (boolean, string)
	local farm = self.farms[farmId]
	if farm == nil then
		return false, "Unknown farm."
	end
	if not isPromised(farm) or farm.resolved then
		return false, "Only an open accepted commitment can be extended."
	end
	if farm.owner ~= owner then
		return false, "Only the player who accepted this commitment can extend it."
	end
	if farm.extended then
		return false, "This commitment was already extended once."
	end
	if now > farm.deadlineAt then
		return false, "The deadline has already passed."
	end
	farm.extended = true
	farm.state = "Extended"
	farm.deadlineAt += self.config.ExtensionSeconds
	self:_emit({
		type = "Extended",
		farmId = farmId,
		owner = owner,
		credits = -self.config.ExtensionFee,
	})
	return true,
		string.format(
			"%s extended by %d minutes for %d credits.",
			farm.definition.DisplayName,
			self.config.ExtensionSeconds // 60,
			self.config.ExtensionFee
		)
end

-- Whether straw can leave this farm right now, with a player-facing reason if not.
function FarmCommitments:CanCollect(farmId: string, now: number): (boolean, string)
	local farm = self.farms[farmId]
	if farm == nil then
		return false, "Unknown farm."
	end
	if farm.resolved then
		return false, farm.definition.DisplayName .. " has no straw until it replants."
	end
	if farm.state == "Available" then
		return false, "Accept the " .. farm.definition.ShortName .. " commitment first."
	end
	if farm.state == "Rejected" then
		return false, "You rejected " .. farm.definition.ShortName .. ". Wait for its next harvest."
	end
	if now > farm.deadlineAt then
		return false, "The deadline has passed."
	end
	if farm.remaining <= 0 then
		return false, "No straw is left on this field."
	end
	return true, ""
end

-- Removes up to `count` bundles from the field. Spec 15.2: straw loaded before the deadline
-- counts as collected, and completing on the deadline tick resolves before any burn.
function FarmCommitments:Take(farmId: string, count: number, now: number): number
	local ok = self:CanCollect(farmId, now)
	if not ok or count <= 0 then
		return 0
	end
	local farm = self.farms[farmId] :: Farm
	local taken = math.min(count, farm.remaining)
	farm.remaining -= taken
	if farm.state == "Accepted" then
		farm.state = "InProgress"
	end
	if farm.remaining == 0 then
		farm.state = "Completed"
		farm.resolved = true
		farm.resolvedAt = now
		farm.streak += 1
		-- Spec 16.3: a completed commitment changes trust and credits once. A streak of kept
		-- promises earns a bigger reliability bonus.
		local step = self.config.StreakBonusStep or 0
		local cap = self.config.StreakBonusCap or 0
		local multiplier = 1 + math.min(step * (farm.streak - 1), cap)
		self:_emit({
			type = "Completed",
			farmId = farmId,
			owner = farm.owner,
			trust = farm.definition.CompleteTrust,
			credits = math.floor(farm.definition.ReliabilityBonus * multiplier + 0.5),
			streak = farm.streak,
		})
	end
	return taken
end

-- A resolved farm replants and offers a fresh contract.
function FarmCommitments:_regrow(farm: Farm, now: number)
	local definition = farm.definition
	farm.state = "Available"
	farm.remaining = definition.Bundles
	farm.deadlineAt = now + (definition.NextDeadlineSeconds or definition.DeadlineSeconds)
	farm.extended = false
	farm.owner = nil
	farm.resolved = false
	farm.burnedBundles = 0
	farm.round += 1
	self:_emit({ type = "Regrown", farmId = farm.id, owner = nil })
end

-- Resolves deadlines and regrows resolved farms. Missed promises and unserved farms burn only
-- their remaining straw.
function FarmCommitments:Update(now: number): { Event }
	for farmId, farm in self.farms do
		if farm.resolved then
			local regrow = farm.definition.RegrowSeconds
			if regrow and now >= farm.resolvedAt + regrow then
				self:_regrow(farm, now)
			end
			continue
		end
		if now < farm.deadlineAt then
			continue
		end
		farm.resolved = true
		farm.resolvedAt = now
		farm.streak = 0
		local quantity = farm.remaining
		local definition = farm.definition
		local responsibility: string
		local trust = 0
		if isPromised(farm) then
			farm.state = "Missed"
			responsibility = "MissedCommitment"
			trust = definition.MissTrust
		else
			responsibility = if farm.state == "Rejected" then "Rejected" else "NoAgreement"
			farm.state = "Burned"
		end
		farm.remaining = 0
		farm.burnedBundles = quantity
		self:_emit({
			type = "Burn",
			farmId = farmId,
			owner = farm.owner,
			trust = trust,
			quantity = quantity,
			-- Exposure scales with the straw actually burned (spec 16.3).
			exposure = math.ceil(definition.BurnExposure * quantity / definition.Bundles),
			responsibility = responsibility,
		})
	end
	return self:Drain()
end

function FarmCommitments:Drain(): { Event }
	local events = self.events
	self.events = {}
	return events
end

return FarmCommitments
