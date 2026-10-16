--!strict

-- The season clock (spec v0.2 section 2.3) and the one forecast weather event (11.3).
-- Pure Luau with no Roblox instances; the caller passes elapsed season seconds in, so Lune can
-- test it. Times in a weather plan are elapsed seconds since the season started.

local SeasonClock = {}

export type Phase = {
	id: string,
	name: string,
	goal: string,
	index: number,
	startsAt: number,
	endsAt: number,
}

export type WeatherPlan = {
	kind: string,
	forecastAt: number,
	startsAt: number,
	-- nil means the change lasts for the rest of the season (the wind shift).
	endsAt: number?,
}

-- Phase boundaries in elapsed seconds, scaled from the 20 minute table to the round length.
function SeasonClock.phases(definitions: any, durationSeconds: number): { Phase }
	local scale = durationSeconds / (definitions.BaseMinutes * 60)
	local list: { Phase } = {}
	for index, phase in definitions.Phases do
		local nextPhase = definitions.Phases[index + 1]
		table.insert(list, {
			id = phase.Id,
			name = phase.Name,
			goal = phase.Goal,
			index = index,
			startsAt = phase.StartMinute * 60 * scale,
			endsAt = if nextPhase then nextPhase.StartMinute * 60 * scale else durationSeconds,
		})
	end
	return list
end

function SeasonClock.phaseAt(definitions: any, durationSeconds: number, elapsed: number): Phase
	local list = SeasonClock.phases(definitions, durationSeconds)
	if elapsed >= durationSeconds then
		local results = definitions.ResultsPhase
		return {
			id = results.Id,
			name = results.Name,
			goal = results.Goal,
			index = #list + 1,
			startsAt = durationSeconds,
			endsAt = durationSeconds,
		}
	end
	for index = #list, 1, -1 do
		if elapsed >= list[index].startsAt then
			return list[index]
		end
	end
	return list[1]
end

function SeasonClock.findPhase(definitions: any, durationSeconds: number, id: string): Phase?
	for _, phase in SeasonClock.phases(definitions, durationSeconds) do
		if phase.id == id then
			return phase
		end
	end
	return nil
end

-- roll is in [0, 1). A forced kind (for play tests) wins when it names a known event.
function SeasonClock.pickEvent(definitions: any, roll: number, forced: string?): string
	local kinds: { string } = definitions.Weather.EventKinds
	if forced then
		for _, kind in kinds do
			if kind == forced then
				return kind
			end
		end
	end
	local index = math.clamp(math.floor(roll * #kinds) + 1, 1, #kinds)
	return kinds[index]
end

-- Spec 11.3: one event in the stress phase, forecast about two minutes ahead.
function SeasonClock.planWeather(
	definitions: any,
	durationSeconds: number,
	kind: string
): WeatherPlan
	local stress = SeasonClock.findPhase(definitions, durationSeconds, "Stress")
	assert(stress, "Season definitions need a Stress phase")
	local weather = definitions.Weather
	local scale = durationSeconds / (definitions.BaseMinutes * 60)
	local startsAt =
		math.min(stress.startsAt + weather.StartAfterStressSeconds * scale, stress.endsAt)
	local forecastAt = math.max(0, startsAt - weather.ForecastLeadSeconds * scale)
	local endsAt: number? = nil
	local eventDefinition = weather[kind]
	if eventDefinition and eventDefinition.DurationSeconds then
		endsAt = startsAt + eventDefinition.DurationSeconds * scale
	end
	return { kind = kind, forecastAt = forecastAt, startsAt = startsAt, endsAt = endsAt }
end

-- Calm before the forecast, Forecast while waiting, Active during the event, Cleared after it.
function SeasonClock.weatherState(plan: WeatherPlan, elapsed: number): string
	if elapsed < plan.forecastAt then
		return "Calm"
	elseif elapsed < plan.startsAt then
		return "Forecast"
	elseif plan.endsAt == nil or elapsed < plan.endsAt then
		return "Active"
	end
	return "Cleared"
end

-- The dryer cycle multiplier for the current weather (spec 11.3: rain raises drying demand).
function SeasonClock.dryerMultiplier(definitions: any, plan: WeatherPlan, elapsed: number): number
	if plan.kind == "Rain" and SeasonClock.weatherState(plan, elapsed) == "Active" then
		return definitions.Weather.Rain.DryerCycleMultiplier
	end
	return 1
end

-- The wind label, direction, and destination at this moment. Direction is a flat X, Z pair.
function SeasonClock.windAt(
	definitions: any,
	plan: WeatherPlan,
	elapsed: number,
	base: { label: string, x: number, z: number }
): (string, number, number, string)
	local shift = definitions.Weather.WindShift
	local state = SeasonClock.weatherState(plan, elapsed)
	if plan.kind == "WindShift" and (state == "Active" or state == "Cleared") then
		return shift.Label, shift.X, shift.Z, shift.Destination
	end
	return base.label, base.x, base.z, definitions.Weather.BaseWind.Destination
end

function SeasonClock.formatClock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

return SeasonClock
