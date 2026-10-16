--!strict

-- Simplified truck route between one fixed farm stop and the factory intake (spec v0.2 7.4).
-- Pure Luau with no Roblox instances. The caller supplies hooks that take straw from the farm
-- and unload into the factory collection point, so Lune can test the trip logic.
--
-- Trip: Idle -> Traveling (empty, to the farm) -> Loading -> Returning (loaded) -> Unloading
-- -> Idle. Destination Full pauses unloading, Route Blocked waits at a closed farm stop.

local TruckRoute = {}
TruckRoute.__index = TruckRoute

export type Hooks = {
	take: (farmId: string, max: number) -> number,
	unload: (count: number) -> number,
}

export type Event = {
	type: string,
	farmId: string?,
	cargo: number?,
	fee: number?,
}

function TruckRoute.new(truckConfig: any, farms: { [string]: any })
	local self = setmetatable({}, TruckRoute)
	self.config = truckConfig
	self.farms = farms
	self.farmId = nil :: string?
	self.state = "Idle"
	self.reason = "Assign a farm, then dispatch"
	self.cargo = 0
	self.tripCargo = 0
	-- 0 at the factory terminal, 1 at the farm stop.
	self.position = 0
	self.timer = 0
	return self
end

function TruckRoute:_travelSeconds(): number
	local farm = self.farms[self.farmId :: string]
	return if farm then farm.TravelSeconds else 1
end

function TruckRoute:Assign(farmId: string): (boolean, string)
	if self.farms[farmId] == nil then
		return false, "Unknown farm stop."
	end
	if self.state ~= "Idle" then
		return false, "The truck must be idle at the terminal to change its farm."
	end
	self.farmId = farmId
	self.reason = "Ready to dispatch"
	return true, "Route assigned to " .. self.farms[farmId].DisplayName .. "."
end

function TruckRoute:Dispatch(): (boolean, string)
	if self.state ~= "Idle" then
		return false, "The truck is already on a trip."
	end
	if self.farmId == nil then
		return false, "Assign a farm stop first."
	end
	self.state = "Traveling"
	self.reason = "To " .. self.farms[self.farmId].DisplayName
	self.timer = 0
	return true, "Truck dispatched to " .. self.farms[self.farmId].DisplayName .. "."
end

-- Spec 7.4: a trip can be cancelled before the loaded truck departs the farm.
function TruckRoute:Cancel(): (boolean, string)
	if self.state ~= "Traveling" and self.state ~= "Loading" then
		return false, "The truck can only be cancelled before it leaves the farm loaded."
	end
	self.state = "Returning"
	self.reason = "Cancelled, returning empty"
	return true, "Trip cancelled. The truck returns empty and no route fee is charged."
end

-- Seconds until the next arrival (farm on the way out, factory on the way back).
function TruckRoute:EtaSeconds(): number
	local travel = self:_travelSeconds()
	if self.state == "Traveling" then
		return (1 - self.position) * travel
	elseif self.state == "Returning" then
		return self.position * travel
	elseif self.state == "Loading" then
		return self.config.LoadSeconds - self.timer + travel
	end
	return 0
end

function TruckRoute:Step(dt: number, hooks: Hooks): { Event }
	local events: { Event } = {}
	local config = self.config
	local farmId = self.farmId :: string
	local state = self.state

	if state == "Traveling" then
		self.position = math.min(1, self.position + dt / self:_travelSeconds())
		if self.position >= 1 then
			self.state, self.reason, self.timer = "Loading", "Loading straw", 0
		end
	elseif state == "Loading" then
		self.timer += dt
		if self.timer >= config.LoadSeconds then
			local loaded = hooks.take(farmId, config.Capacity)
			if loaded <= 0 then
				self.state, self.reason, self.timer =
					"RouteBlocked", "No straw ready at this farm", 0
			else
				self.cargo = loaded
				self.tripCargo = loaded
				self.state = "Returning"
				self.reason = string.format("Carrying %d bundles to the factory", loaded)
				table.insert(events, { type = "Loaded", farmId = farmId, cargo = loaded })
			end
		end
	elseif state == "RouteBlocked" then
		self.timer += dt
		if self.timer >= config.BlockedSeconds then
			self.state, self.reason = "Returning", "Returning empty"
		end
	elseif state == "Returning" then
		self.position = math.max(0, self.position - dt / self:_travelSeconds())
		if self.position <= 0 then
			if self.cargo > 0 then
				self.state, self.reason, self.timer = "Unloading", "Unloading at the intake", 0
			else
				self.state, self.reason = "Idle", "Ready to dispatch"
			end
		end
	elseif state == "Unloading" or state == "DestinationFull" then
		self.timer += dt
		while self.cargo > 0 and self.timer >= config.UnloadSecondsPerBundle do
			if hooks.unload(1) < 1 then
				-- Spec 7.4: warn when the collection point lacks unloading space.
				self.state = "DestinationFull"
				self.reason = "Factory collection point is full"
				self.timer = config.UnloadSecondsPerBundle
				break
			end
			self.cargo -= 1
			self.timer -= config.UnloadSecondsPerBundle
			self.state, self.reason = "Unloading", "Unloading at the intake"
		end
		if self.cargo == 0 then
			table.insert(events, {
				type = "TripCompleted",
				farmId = farmId,
				cargo = self.tripCargo,
				fee = self.farms[farmId].RouteFee,
			})
			self.tripCargo = 0
			self.state, self.reason = "Idle", "Ready to dispatch"
		end
	end
	return events
end

return TruckRoute
