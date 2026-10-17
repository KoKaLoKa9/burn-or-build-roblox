--!strict

-- End of season results (spec v0.2 sections 12.3 to 12.5 and 11.4).
-- Pure Luau with no Roblox instances so Lune can test it. The server gathers plain tables
-- (ledger, burn records, field and commitment states) and this module turns them into the
-- Profit, Clean Air, and Trust report the result screen shows. Exposure is always called
-- "exposure points", never a measured concentration (spec 11.2 and 16.4).

local SeasonResults = {}

-- Ledger categories. Signed amounts: income is positive, costs are negative.
SeasonResults.CategoryText = {
	Sales = "Pellet sales",
	Rice = "Rice harvest, grain minus seed",
	Research = "Engineers hired and paid",
	Fine = "Burn ban fines",
	Bonus = "Reliability bonuses",
	Processing = "Processing costs",
	RouteFee = "Truck route fees",
	Extension = "Extension fees",
	Utility = "Utility operating costs",
	Construction = "Machines, belts, and plots bought",
	Refund = "Dismantle refunds",
}

-- Spec 12.3: season profit counts these. Construction is investment, shown separately.
SeasonResults.ProfitCategories = {
	"Sales",
	"Rice",
	"Bonus",
	"Processing",
	"RouteFee",
	"Extension",
	"Utility",
	"Research",
	"Fine",
}

-- Burns that came from the player's own decision or broken promise.
SeasonResults.PlayerCaused = {
	PlayerAuthorized = true,
	PlayerFarmDeadline = true,
	MissedCommitment = true,
}

export type Ledger = { [string]: number }

export type Burn = {
	field: string,
	quantity: number,
	-- Elapsed season seconds.
	time: number,
	wind: string,
	destination: string,
	-- Points that reached the village.
	exposure: number,
	-- Points released by the burn wherever the wind took them.
	potential: number,
	responsibility: string,
}

export type Field = {
	name: string,
	bundles: number,
	burnExposure: number,
	resolved: boolean,
	-- Trust change caused by how this field ended (own field burns cost trust).
	trustChange: number,
}

export type Commitment = {
	name: string,
	state: string,
	trustChange: number,
}

export type Bottleneck = { machine: string, at: number, blockedSeconds: number }

export type Input = {
	ledger: Ledger,
	endingCash: number,
	infrastructureValue: number,
	infrastructureRate: number,
	startingTrust: number,
	endingTrust: number,
	burns: { Burn },
	fields: { Field },
	commitments: { Commitment },
	responsibilityText: { [string]: string },
	firstSaleAt: number?,
	bottleneck: Bottleneck?,
	endReason: string,
	disclaimer: string,
}

export type Line = { label: string, value: string, detail: string? }

function SeasonResults.newLedger(): Ledger
	return {}
end

function SeasonResults.record(ledger: Ledger, category: string, amount: number)
	ledger[category] = (ledger[category] or 0) + amount
end

function SeasonResults.seasonProfit(ledger: Ledger): number
	local total = 0
	for _, category in SeasonResults.ProfitCategories do
		total += ledger[category] or 0
	end
	return total
end

function SeasonResults.cooperativeValue(
	endingCash: number,
	infrastructureValue: number,
	rate: number
): number
	return endingCash + math.floor(infrastructureValue * rate + 0.5)
end

local function clock(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function signed(amount: number): string
	if amount > 0 then
		return "+" .. tostring(amount)
	end
	return tostring(amount)
end

local function plural(count: number, word: string): string
	return string.format("%d %s%s", count, word, if count == 1 then "" else "s")
end

-- Profit ----------------------------------------------------------------------------------

local function buildProfit(input: Input)
	local ledger = input.ledger
	local profit = SeasonResults.seasonProfit(ledger)
	local value = SeasonResults.cooperativeValue(
		input.endingCash,
		input.infrastructureValue,
		input.infrastructureRate
	)
	local causes: { Line } = {}
	for _, category in SeasonResults.ProfitCategories do
		local amount = ledger[category] or 0
		if amount ~= 0 then
			table.insert(causes, {
				label = SeasonResults.CategoryText[category],
				value = signed(amount),
			})
		end
	end
	local invested = -((ledger.Construction or 0) + (ledger.Refund or 0))
	table.insert(causes, {
		label = "Infrastructure you own",
		value = tostring(input.infrastructureValue),
		detail = string.format(
			"Net %d spent on machines and belts. Counted at %d percent in cooperative value.",
			invested,
			math.floor(input.infrastructureRate * 100 + 0.5)
		),
	})
	local verdict: string
	if profit > 0 then
		verdict = "Profitable season. The operation can continue and expand."
	elseif (ledger.Sales or 0) > 0 then
		verdict = "Sales did not cover operating costs. Check route and extension fees."
	else
		verdict = "No pellets were sold, so the season earned nothing."
	end
	return {
		seasonProfit = profit,
		endingCash = input.endingCash,
		infrastructureValue = input.infrastructureValue,
		cooperativeValue = value,
		causes = causes,
		verdict = verdict,
		strong = profit > 0,
	}
end

-- Clean Air -------------------------------------------------------------------------------

type CauseGroup = {
	key: string,
	label: string,
	exposure: number,
	potential: number,
	bundles: number,
	fields: { string },
	playerCaused: boolean,
}

local function buildCleanAir(input: Input): (any, CauseGroup?)
	local groups: { [string]: CauseGroup } = {}
	local order: { CauseGroup } = {}
	local district, playerCaused, released = 0, 0, 0
	local burnedByField: { [string]: number } = {}

	for _, burn in input.burns do
		local group = groups[burn.responsibility]
		if group == nil then
			local newGroup: CauseGroup = {
				key = burn.responsibility,
				label = input.responsibilityText[burn.responsibility] or burn.responsibility,
				exposure = 0,
				potential = 0,
				bundles = 0,
				fields = {},
				playerCaused = SeasonResults.PlayerCaused[burn.responsibility] == true,
			}
			groups[burn.responsibility] = newGroup
			table.insert(order, newGroup)
			group = newGroup
		end
		local current = group :: CauseGroup
		current.exposure += burn.exposure
		current.potential += burn.potential
		current.bundles += burn.quantity
		if not table.find(current.fields, burn.field) then
			table.insert(current.fields, burn.field)
		end
		district += burn.exposure
		released += burn.potential
		if current.playerCaused then
			playerCaused += burn.exposure
		end
		burnedByField[burn.field] = (burnedByField[burn.field] or 0) + burn.quantity
	end

	-- Exposure prevented: the share of each settled field's burn risk that never burned.
	local prevented = 0
	local preventedLines: { Line } = {}
	for _, field in input.fields do
		if not field.resolved or field.bundles <= 0 then
			continue
		end
		local saved = math.max(0, field.bundles - (burnedByField[field.name] or 0))
		local points = math.floor(field.burnExposure * saved / field.bundles + 0.5)
		if points > 0 then
			prevented += points
			table.insert(preventedLines, {
				label = field.name,
				value = string.format("%d pts", points),
				detail = string.format("%s collected instead of burned", plural(saved, "bundle")),
			})
		end
	end

	table.sort(order, function(a, b)
		if a.exposure ~= b.exposure then
			return a.exposure > b.exposure
		end
		return a.potential > b.potential
	end)
	local causes: { Line } = {}
	for _, group in order do
		table.insert(causes, {
			label = group.label,
			value = string.format("%d pts", group.exposure),
			detail = string.format(
				"%s, %s burned%s%s",
				table.concat(group.fields, ", "),
				plural(group.bundles, "bundle"),
				if group.potential > group.exposure
					then string.format(
						", %d pts drifted to open land",
						group.potential - group.exposure
					)
					else "",
				if group.playerCaused then ". Your decision" else ". Not your promise"
			),
		})
	end

	local sorted = table.clone(input.burns)
	table.sort(sorted, function(a, b)
		return a.time < b.time
	end)
	local events: { Line } = {}
	for _, burn in sorted do
		table.insert(events, {
			label = clock(burn.time),
			value = string.format("+%d pts", burn.exposure),
			detail = string.format(
				"%s burned %s. Wind %s to %s. %s.",
				burn.field,
				plural(burn.quantity, "bundle"),
				burn.wind,
				burn.destination,
				input.responsibilityText[burn.responsibility] or burn.responsibility
			),
		})
	end

	local verdict: string
	if district == 0 and released == 0 then
		verdict = "No smoke this season. Little or no population exposure occurred."
	elseif district == 0 then
		verdict = "No smoke reached the village, but burns still released pollution."
	elseif playerCaused == 0 then
		verdict = "The village was exposed, though none of it came from a promise you broke."
	else
		verdict = string.format(
			"%d of the %d exposure points on the village came from your decisions.",
			playerCaused,
			district
		)
	end

	return {
		districtExposure = district,
		playerCausedExposure = playerCaused,
		otherExposure = district - playerCaused,
		smokeReleased = released,
		exposurePrevented = prevented,
		causes = causes,
		prevented = preventedLines,
		events = events,
		verdict = verdict,
		strong = district == 0,
		disclaimer = input.disclaimer,
	},
		order[1]
end

-- Trust -----------------------------------------------------------------------------------

local ACCEPTED_STATES = {
	Accepted = true,
	InProgress = true,
	Extended = true,
	Completed = true,
	Missed = true,
}

local function buildTrust(input: Input)
	local accepted, completed, missed, rejected, unanswered, open = 0, 0, 0, 0, 0, 0
	local causes: { Line } = {}
	for _, commitment in input.commitments do
		local state = commitment.state
		if ACCEPTED_STATES[state] then
			accepted += 1
		end
		local detail: string
		if state == "Completed" then
			completed += 1
			detail = "Promise kept"
		elseif state == "Missed" then
			missed += 1
			detail = "Promise broken, remaining straw burned"
		elseif state == "Rejected" then
			rejected += 1
			detail = "Rejected before accepting, no promise broken"
		elseif state == "Burned" or state == "Available" then
			unanswered += 1
			detail = "Never answered, the farmer burned at the deadline"
		else
			open += 1
			detail = "Still open when the season ended"
		end
		table.insert(causes, {
			label = commitment.name,
			value = if commitment.trustChange ~= 0 then signed(commitment.trustChange) else "0",
			detail = detail,
		})
	end
	for _, field in input.fields do
		if field.trustChange ~= 0 then
			table.insert(causes, {
				label = field.name,
				value = signed(field.trustChange),
				detail = "Burning your own field worried the neighbors",
			})
		end
	end

	local verdict: string
	if missed > 0 then
		verdict = string.format("Farmers saw %s.", plural(missed, "broken promise"))
	elseif completed > 0 then
		verdict = "Farmers expect the cooperative to keep future promises."
	elseif accepted > 0 then
		verdict = "Your promises are still open."
	else
		verdict = "You made no promises this season, so farmers do not know you yet."
	end

	return {
		startingTrust = input.startingTrust,
		endingTrust = input.endingTrust,
		change = input.endingTrust - input.startingTrust,
		accepted = accepted,
		completed = completed,
		missed = missed,
		rejected = rejected,
		unanswered = unanswered,
		open = open,
		causes = causes,
		verdict = verdict,
		strong = missed == 0 and completed > 0,
	}
end

-- Replay highlights (spec 12.5 and 16.4) --------------------------------------------------

local function keyLesson(cleanAir: any, top: CauseGroup?, profit: any, trust: any): string
	if top and top.exposure > 0 then
		local cause = string.format(
			"Biggest cause: %s (%s) put %d exposure points on the village.",
			table.concat(top.fields, ", "),
			top.label,
			top.exposure
		)
		if top.playerCaused then
			return cause .. " Collecting that straw in time would have kept it out of the air."
		end
		return cause .. " No promise was broken, but spare capacity could have taken that straw."
	elseif cleanAir.smokeReleased > 0 then
		return string.format(
			"The wind carried %d points of smoke to open land. The village was spared, but the pollution still happened.",
			cleanAir.smokeReleased
		)
	elseif trust.missed > 0 then
		return "A missed commitment cost trust even without smoke reaching the village."
	elseif cleanAir.exposurePrevented > 0 then
		return string.format(
			"Collecting straw instead of burning it kept %d exposure points out of the air.",
			cleanAir.exposurePrevented
		)
	elseif not profit.strong then
		return "Selling the first crate earlier gives the factory money to grow."
	end
	return "A quiet season. Take on more farm work next time to grow."
end

local function successfulDecision(input: Input, trust: any): string
	for _, commitment in input.commitments do
		if commitment.state == "Completed" then
			return string.format(
				"You kept your promise to %s: trust and a reliability bonus, and no smoke.",
				commitment.name
			)
		end
	end
	for _, field in input.fields do
		if field.resolved and field.trustChange == 0 then
			local burned = false
			for _, burn in input.burns do
				if burn.field == field.name then
					burned = true
				end
			end
			if not burned then
				return string.format("You cleared %s by hand instead of burning it.", field.name)
			end
		end
	end
	if input.firstSaleAt then
		return string.format("Your first pellet crate sold at %s.", clock(input.firstSaleAt))
	end
	if trust.rejected > 0 then
		return "You rejected work you could not finish instead of breaking a promise."
	end
	return "No clear success yet. Aim to sell one pellet crate early next season."
end

local function bottleneckText(bottleneck: Bottleneck?): string
	if bottleneck == nil then
		return "No machine stayed backed up for long. The line kept moving."
	end
	return string.format(
		"First bottleneck: the %s backed up at %s (output full for %d s in total). The next step could not keep up.",
		string.lower(bottleneck.machine),
		clock(bottleneck.at),
		math.floor(bottleneck.blockedSeconds + 0.5)
	)
end

function SeasonResults.compute(input: Input)
	local profit = buildProfit(input)
	local cleanAir, topCause = buildCleanAir(input)
	local trust = buildTrust(input)
	local report = {
		endReason = input.endReason,
		profit = profit,
		cleanAir = cleanAir,
		trust = trust,
		keyLesson = keyLesson(cleanAir, topCause, profit, trust),
		successfulDecision = successfulDecision(input, trust),
		bottleneck = bottleneckText(input.bottleneck),
	}
	return report
end

-- Bottleneck tracking ---------------------------------------------------------------------

export type BottleneckLog = {
	running: { [any]: number },
	totals: { [string]: number },
	first: Bottleneck?,
}

function SeasonResults.newBottleneckLog(): BottleneckLog
	return { running = {}, totals = {}, first = nil }
end

-- samples maps a machine key to its display name and state for this tick.
function SeasonResults.trackBottlenecks(
	log: BottleneckLog,
	samples: { [any]: { name: string, state: string } },
	dt: number,
	elapsed: number,
	threshold: number
)
	for key, sample in samples do
		if sample.state == "Blocked" then
			local running = (log.running[key] or 0) + dt
			log.running[key] = running
			log.totals[sample.name] = (log.totals[sample.name] or 0) + dt
			if log.first == nil and running >= threshold then
				log.first = { machine = sample.name, at = elapsed - running, blockedSeconds = 0 }
			end
		else
			log.running[key] = nil
		end
	end
	for key in log.running do
		if samples[key] == nil then
			log.running[key] = nil
		end
	end
	local first = log.first
	if first then
		first.blockedSeconds = log.totals[first.machine] or 0
	end
end

return SeasonResults
