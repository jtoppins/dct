--[[
-- SPDX-License-Identifier: LGPL-3.0
--]]

local class         = require("libs.namedclass")
local PriorityQueue = require("libs.containers.pqueue")
local dctenum       = require("dct.enum")
local dctutils      = require("dct.utils")
local Subordinates  = require("dct.libs.Subordinates")
local AssetBase     = require("dct.assets.AssetBase")
local Marshallable  = require("dct.libs.Marshallable")
local State         = require("dct.libs.State")
local vector        = require("dct.libs.vector")

--- @class Runway
-- Represents a runway object and its state for an airbase.
--
-- @field name Name of the runway
-- @field points points describing the four corners of the runway
-- @field AB 2D vector from point A to B
-- @field BC 2D vector from point B to C
-- @field dotAB vector dot product of AB * AB
-- @field dotBC vector dot product of BC * BC
-- @field life life left for the runway
-- @field max_life total starting life of the runway
local Runway = class("Runway")
function Runway:__init(rwy, health, dmgthreshold)
	local center = vector.Vector2D(rwy.position)
	local theta = rwy.course * -1
	local v1 = vector.Vector2D.create(math.cos(theta), math.sin(theta))
	local v2 = vector.Vector2D.create(-v1.y, v1.x)

	v1 = (rwy.length / 2) * v1
	v2 = (rwy.width / 2) * v2

	self.name   = rwy.name
	self.points = {
		center + v1 + v2,
		center - v1 + v2,
		center - v1 - v2,
		center + v1 - v2,
	}
	self.AB     = self.points[1] - self.points[2]
	self.BC     = self.points[2] - self.points[3]
	self.dotAB  = vector.dot(self.AB,self.AB)
	self.dotBC  = vector.dot(self.BC,self.BC)
	self.threshold = dmgthreshold
	self.life  = health
	self.max_life = health
end

--- Check if runway was hit by a bomb that landed close by.
-- An impact point M is only inside runway area defined by points
-- A, B, & C if and only if (IFF);
--    0 <= dot(AB,AM) <= dot(AB,AB) && 0 <= dot(BC,BM) <= dot(BC,BC)
-- reference: https://stackoverflow.com/a/2763387
--
-- @param p point to test
-- @return bool true if point p is inside bound of runway
function Runway:contains(p)
	local M = vector.Vector2D(p)
	local AM = self.points[1] - M
	local BM = self.points[2] - M
	local dotAM = vector.dot(self.AB, AM)
	local dotBM = vector.dot(self.BC, BM)

	if (0 <= dotAM <= self.dotAB) and
	   (0 <= dotBM <= self.dotBC) then
		return true
	end
	return false
end

--- Is the Runway capable of supporting aircraft.
-- @return bool true if able to support takeoffs and landings
function Runway:isOperational()
	return (self.life / self.max_life) >= self.threshold
end

--- Has the runway been repaired.
-- @return bool true if runway is repaired
function Runway:isRepaired()
	return self.life >= self.max_life
end

--- Apply any damage the bomb inflicts to the runway.
-- @param impact the impact event triggered by the bomb
-- @return nil
function Runway:doDamage(impact)
	-- TODO: define bomb damage in some better way
	local DAMAGE = 20
	if self:contains(impact.point) and
	   impact.initiator.desc.warhead.explosiveMass >= 75 then
		self.life = dctutils.clamp(self.life - DAMAGE, 0,
			self.max_life)
	end
end

--- Account for how much the runway has been repaired over the elapsed
-- time and the given repair rate.
--
-- @param elapsed amount of time in seconds time has passed
-- @param rate repair rate per minute
function Runway:doRepair(elapsed, rate)
	local repair = (elapsed / 60) * rate
	local health = self.life + repair
	self.life = dctutils.clamp(health, 0, self.max_life)
end

local statetypes = {
	["OPERATIONAL"] = 1,
	["REPAIRING"]   = 2,
	["TERMINAL"]    = 3,
}

--- @class TerminalState
-- End state for an Airbase. The Airbase will be marked as dead, and
-- all listeners notified of the Airbase's death.
--
-- Transitions:
--   * enter: set airbase dead
--
-- @field type type of state
local TerminalState = class("Terminal", State, Marshallable)
function TerminalState:__init()
	Marshallable.__init(self)
	self.type = statetypes.TERMINAL
	self:_addMarshalNames({"type",})
end

function TerminalState:enter(asset)
	asset._logger:debug("airbase captured - entering captured state")
	asset:despawn()
	asset:setDead(true)
end

--- @class OperationalState
--
-- Transitions:
--   * enter: notify airbase operational
--   * exit: notify airbase not operational
--   * transition: to RepairingState on runway hit and no runways operational
--   * transition: to TerminalState on DCT capture event
local OperationalState = class("Operational", State, Marshallable)

--- @class RepairingState
--
-- Transitions:
--   * enter: start repair timer
--   * transition: on all runways repaired to OperationalState
--   * transition: on capture event move to TerminalState
local RepairingState = class("Repairing", State, Marshallable)
function RepairingState:__init()
	Marshallable.__init(self)
	self.type = statetypes.REPAIRING
	self:_addMarshalNames({"type",})
end

function RepairingState:enter(asset)
	self.timer = require("dct.libs.Timer")(nil, timer.getAbsTime)
	self.timer:start()
end

--- Repair the runways over a period of time. Runways can only be
-- repaired sequentially and the first runway damaged will continue
-- to be repaired before the next in the sequence is repaired.
--
-- @param airbase the airbase to look at
-- @param timespent time elapsed since last repair credited
-- @return bool true if airbase repair is complete
local function repair(ab, timespent)
	for _, rwy in ipairs(ab._runways) do
		if not rwy:isRepaired() then
			rwy:doRepair(timespent, ab.repairrate)
			return false
		end
	end
	return true
end

function RepairingState:update(asset)
	self.timer:update()
	local timespent = self.timer:reset()
	local state = nil
	if repair(asset, timespent) then
		state = OperationalState()
	end
	return state
end

function RepairingState:onDCTEvent(asset, event)
	local state = nil
	if event.id == dctenum.event.DCT_EVENT_CAPTURED and
	   event.target.name == asset.name then
		state = TerminalState()
	end
	return state
end

function OperationalState:__init()
	Marshallable.__init(self)
	self.type = statetypes.OPERATIONAL
	self:_addMarshalNames({"type", })
end

function OperationalState:enter(asset)
	if asset:isSpawned() then
		asset:notify(dctutils.buildevent.operational(asset, true))
	end
end

function OperationalState:exit(asset)
	asset:notify(dctutils.buildevent.operational(asset, false))
end

function OperationalState:update(asset)
	-- TODO: create departures
	asset._logger:debug("operational state: update called")
end

function OperationalState:onDCTEvent(asset, event)
	local state = nil
	if event.id == dctenum.event.DCT_EVENT_IMPACT and
	   not asset:isOperational() then
		state = RepairingState()
	elseif event.id == dctenum.event.DCT_EVENT_CAPTURED and
		event.target.name == asset.name then
		state = TerminalState()
	end
	return state
end

local allowedtpltypes = {
	[dctenum.assetType.BASEDEFENSE]    = true,
	[dctenum.assetType.SQUADRONPLAYER] = true,
}

local statemap = {
	[statetypes.OPERATIONAL] = OperationalState,
	[statetypes.REPAIRING]   = RepairingState,
	[statetypes.TERMINAL]    = TerminalState,
}

local function associate_slots(ab)
	local filter = function(a)
		if a.type == dctenum.assetType.PLAYERGROUP and
		   a.airbase == ab.name and a.owner == ab.owner then
			return true
		end
		return false
	end
	local assetmgr = dct.Theater.singleton():getAssetMgr()
	local regionmgr = dct.Theater.singleton():getRegionMgr()

	-- Associate player slots that cannot be autodetected by using
	-- a list provided by the campaign designer. First look up the
	-- template defining the airbase so that slots can be updated
	-- without resetting the campaign state.
	local region = regionmgr:getRegion(ab.rgnname)
	local tpl = region:getTemplateByName(ab.tplname)
	for _, name in ipairs(tpl.players) do
		local asset = assetmgr:getAsset(name)
		if asset and asset.airbase == nil then
			asset.airbase = ab.name
		end
	end

	for name, _ in pairs(assetmgr:filterAssets(filter)) do
		local asset = assetmgr:getAsset(name)
		if asset then
			ab:addSubordinate(asset)
			if asset.parking then
				ab._parking_occupied[asset.parking] = true
			end
		end
	end
end

local function process_runways(self, ab)
	local rwys = ab:getRunways() or {}

	self._runways = {}
	for _, rwy in pairs(rwys) do
		local R = Runway(rwy, self.runwayspec.health,
			self.runwayspec.threshold)
		R.life = self._rwyhealth[rwy.name] or self.runwayspec.health
		table.insert(self._runways, R)
	end
	self._rwyhealth = nil
end

--- Replacement function for AssetBase.getLocation for ships.
--
-- @param self DCT Airbase object
-- @return vec3 of the airbase's location
local function get_location(self)
	local dcsab = Airbase.getByName(self.name)
	if dcsab ~= nil then
		self._location = dcsab:getPoint()
	end
	return AssetBase.getLocation(self)
end

local function check_impact(self, event)
	for _, rwy in ipairs(self._runways) do
		rwy:doDamage(event)
	end
end

--- Represents an Airbase within the DCT framework.
--
-- Features:
--   * enable/disable player slots
--   * parking in use by players and AI
--   * runway/infrastructure destruction
--   * spawn AI flights
--
-- Events:
--   Handled outside of a particular state
--   * S_EVENT_DEAD set asset as dead as underlying DCS object is dead
--   * S_EVENT_LAND schedule a/c cleanup
--   * DCT_EVENT_IMPACT distribute damage; if damage limit met
--         transition to Repairing
--
-- States:
--   * Operational
--     - enter: notify airbase operational
--     - exit: notify airbase not operational
--     - transition: to Repairing on damage limit met
--     - transition: to Captured on DCT capture event
--     - update: do AI departures
--
--   * Repairing
--     - enter: start repair timer
--     - transition: on timer expire move to Operational
--     - transition: on capture event move to Captured
--     - event: on DCT_EVENT_IMPACT distribute damage
--
--   * Captured
--     - enter: set airbase dead
--
-- airbase events
--   * an object taken out, could effect;
--     - parking
--     - base resources
--     - runway operation
--
-- airbase has;
--   * resources for aircraft weapons
--
-- Events:
--   * DCT_EVENT_IMPACT
--     Needs to be handled regardless of state.
--     An airbase has potentially been bombed and we need to check
--     for runway damage, ramp, etc damage.
--   * S_EVENT_TAKEOFF
--     An aircraft has taken off from the airbase, we need to
--     remove parking reservations
--   * S_EVENT_LAND
--     An aircraft has landed at the base, no specific action we
--     need to take?
--   * S_EVENT_HIT
--     Any action we need to take from getting a hit event from DCS?
--     Yes if the ship is damaged we should probably disable flight
--     operations for a period of time.
--   * S_EVENT_DEAD
--     Can an airbase even die? Yes if it is a ship.
--     What about aircraft that die on the airport? We need to know this
--     to remove parking reservations.
--   * S_EVENT_BASE_CAPTURED
--     This event has problems should we listen to it?
--
-- Emitted Events:
--   * DCT_EVENT_DEAD
--     Notify listeners when dead
--   * DCT_EVENT_OPERATIONAL
--     signals the base is in an operational state or not
--
-- Player Class and Hooks:
--    The player class and hooks will need to be modified so that a third
--    state is listened to, the states are;
--    spawned - the asset has been spawned, the owning airbase upon
--              despawning will despawn all player slots
--    kicked  - if a player in the slot should be kicked from the slot
--    oper    - if the slot is operational, meaning the slot has been
--              spawned but for some reason the slot cannot be spawned
--              into
--
--   The Player class will need to listen various events and then
--   determine if those events render the slot non-operational.
local AirbaseAsset = class("Airbase", AssetBase, Subordinates)
function AirbaseAsset:__init(template)
	self._eventhandlers = {
		[dctenum.event.DCT_EVENT_IMPACT] = check_impact,
	}
	Subordinates.__init(self)
	self._departures = PriorityQueue()
	self._parking_occupied = {}
	self._rwyhealth = {}
	self._runways = {}
	AssetBase.__init(self, template)
	self:_addMarshalNames({
		"_tplnames",
		"_subordinates",
		"takeofftype",
		"recoverytype",
		"runwayspec",
		"repairrate",
	})
end

function AirbaseAsset.assettypes()
	return {
		dctenum.assetType.AIRBASE,
	}
end

function AirbaseAsset:_completeinit(template)
	AssetBase._completeinit(self, template)
	self._tplnames    = template.subordinates
	self.takeofftype  = template.takeofftype
	self.recoverytype = template.recoverytype
	self.runwayspec   = template.runway
	self.repairrate   = template.repairrate
	self.state = OperationalState()
	self.state:enter(self)
end

function AirbaseAsset:_setup()
	local dcsab = Airbase.getByName(self.name)
	if dcsab == nil then
		self._logger:error("is not a DCS Airbase")
		self:setDead(true)
		return
	end
	self._abcategory = dcsab:getDesc().airbaseCategory
	self._location = dcsab:getPoint()
	if self._abcategory == Airbase.Category.AIRDROME then
		process_runways(self, dcsab)
	elseif self._abcategory == Airbase.Category.SHIP then
		self.getLocation = get_location
	end
end

function AirbaseAsset:getObjectNames()
	return { self.name, }
end

local function filterPlayerGroups(sublist)
	local subs = {}
	for subname, subtype in pairs(sublist) do
		if subtype ~= dctenum.assetType.PLAYERGROUP then
			subs[subname] = subtype
		end
	end
	return subs
end

function AirbaseAsset:marshal()
	local tbl = AssetBase.marshal(self)
	if tbl == nil then
		return nil
	end

	tbl._rwyhealth = {}
	for _, rwy in ipairs(self._runways) do
		tbl._rwyhealth[rwy.name] = rwy.life
	end
	tbl._subordinates = filterPlayerGroups(self._subordinates)
	tbl.state = self.state:marshal()
	return tbl
end

function AirbaseAsset:unmarshal(data)
	AssetBase.unmarshal(self, data)

	-- We must unmarshal the state object after the base asset has
	-- unmarshaled due to how the Marshallable object works
	self.state = State.factory(statemap, data.state.type)
	self.state:unmarshal(data.state)
end

--[[
-- check if we have any departures to do, we only do one departure
-- per run of this function to allow for separation of flights.
function AirbaseAsset:_doOneDeparture()
	if self._departures:empty() then
		return
	end

	local time = timer.getAbsTime()
	local name, prio = self._departures:peek()
	if time < prio then
		return
	end

	self._departures:pop()
	local flight = dct.Theater.singleton():getAssetMgr():getAsset(name)
	-- TODO: need some way to spawn the flight with the data from the
	-- airbase
	local wpt1 = self:_buildWaypoint(flight:getAircraftType())
	flight:spawn(false, wpt1)
	self:addObserver(flight)
end

function AirbaseAsset:addFlight(flight, delay)
	assert(flight, self.__clsname..":addFlight - flight required")
	local delay = delay or 0
	self._departures:push(timer.getAbsTime() + delay, flight.name)
 end
--]]

function AirbaseAsset:update()
	local newstate = self.state:update(self)
	if newstate ~= nil then
		self.state:exit(self)
		self.state = newstate
		self.state:enter(self)
	end
end

function AirbaseAsset:onDCTEvent(event)
	AssetBase.onDCTEvent(self, event)
	local newstate = self.state:onDCTEvent(self, event)
	if newstate ~= nil then
		self.state:exit(self)
		self.state = newstate
		self.state:enter(self)
	end
end

--- Determines if an Airbase is operational and can sortie aircraft.
-- An Airbase is operational IFF it is spawned, in the operational
-- state, and has at least one operational runway if the airbase has
-- runways.
function AirbaseAsset:isOperational()
	local c = self:isSpawned() and
		self.state.type == statetypes.OPERATIONAL

	if c and next(self._runways) then
		local cnt = 0
		for _, rwy in ipairs(self._runways) do
			if rwy:isOperational() then
				cnt = cnt + 1
			end
		end
		c = c and (cnt >= 1)
	end
	return c
end

function AirbaseAsset:getStatus()
	local g = 0
	local life = 0
	local max_life = 0
	if self:isOperational() then
		for _, rwy in ipairs(self._runways) do
			life = life + rwy.life
			max_life = max_life + rwy.max_life
		end
		g = life / max_life
	end
	return math.ceil((1 - g) * 100)
end

function AirbaseAsset:generate(assetmgr, region)
	self._logger:debug("generate called")
	for _, tplname in ipairs(self._tplnames or {}) do
		self._logger:debug("subordinate template: %s", tplname)
		local tpl = region:getTemplateByName(tplname)
		assert(tpl, string.format("runtime error: airbase(%s) defines "..
			"a subordinate template of name '%s', does not exist",
			self.name, tplname))
		assert(allowedtpltypes[tpl.objtype],
			string.format("runtime error: airbase(%s) defines "..
				"a subordinate template of name '%s' and type: %d ;"..
				"not supported type", self.name, tplname, tpl.objtype))
		if tpl.coalition == self.owner then
			tpl.airbase = self.name
			tpl.location = tpl.location or self:getLocation()
			local asset = assetmgr:factory(tpl.objtype)(tpl)
			assetmgr:add(asset)
			self:addSubordinate(asset)
		end
	end
end

function AirbaseAsset:spawn(ignore)
	if not ignore and self:isSpawned() then
		self._logger:error("runtime bug - already spawned")
		return
	end
	associate_slots(self)
	self:spawn_despawn("spawn")
	AssetBase.spawn(self)

	if self:isOperational() then
		self:notify(dctutils.buildevent.operational(self, true))
	end
end

function AirbaseAsset:despawn()
	self:spawn_despawn(self, "despawn")
	AssetBase.despawn(self)
end

return AirbaseAsset
