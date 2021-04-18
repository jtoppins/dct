--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents an Airbase.
--
-- AirbaseAsset<AssetBase, Subordinates>:
--
-- airbase events
-- * an object taken out, could effect;
--   - parking
--   - base resources
--   - runway operation
--
-- airbase has;
--  - resources for aircraft weapons
--
-- MVP - Phase 1:
--  - enable/disable player slots
--  - parking in use by players
--
-- MVP - Phase 2:
--  - runway destruction
--  - parking in use by AI or players
--  - spawn AI flights
--
-- Events:
--   * DCT_EVENT_HIT
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
--]]

local class         = require("libs.namedclass")
local PriorityQueue = require("libs.containers.pqueue")
local dctenum       = require("dct.enum")
local dctutils      = require("dct.utils")
local Subordinates  = require("dct.libs.Subordinates")
local AssetBase     = require("dct.assets.AssetBase")
local Marshallable  = require("dct.libs.Marshallable")
local State         = require("dct.libs.State")

local statetypes = {
	["OPERATIONAL"] = 1,
	["REPAIRING"]   = 2,
	["CAPTURED"]    = 3,
}

--[[
-- CapturedState - terminal state
--  * enter: set airbase dead
--]]
local CapturedState = class("Captured", State, Marshallable)
function CapturedState:__init()
	Marshallable.__init(self)
	self.type = statetypes.CAPTURED
	self:_addMarshalNames({"type",})
end

function CapturedState:enter(asset)
	asset._logger:debug("airbase captured - entering captured state")
	asset:despawn()
	asset:setDead(true)
end

--[[
-- RepairingState - airbase repairing
--  * enter: start repair timer
--  * transition: on timer expire move to Operational
--  * transition: on capture event move to Captured
--  * event: on DCT_EVENT_HIT extend repair timer (not implemented yet)
--]]
local OperationalState = class("Operational", State, Marshallable)
local RepairingState = class("Repairing", State, Marshallable)
function RepairingState:__init()
	Marshallable.__init(self)
	self.type = statetypes.REPAIRING
	self.timeout = 12*60*60 -- 12 hour repair time
	self.ctime   = timer.getAbsTime()
	self:_addMarshalNames({"type", "timeout",})
end

-- TODO: if we want to make the repair timer variable we can do that
-- via the enter function and set the timeout based on a variable
-- stored in the airbase asset

function RepairingState:update(_ --[[asset]])
	local time = timer.getAbsTimer()
	self.timeout = self.timeout - (time - self.ctime)
	self.ctime = time

	if self.timeout <= 0 then
		return OperationalState()
	end
	return nil
end

function RepairingState:onDCTEvent(asset, event)
	local state = nil
	if event.id == dctenum.event.DCT_EVENT_CAPTURED and
	   event.target.name == asset.name then
		state = CapturedState()
	end
	-- TODO: listen for hit events and extend the repair timer
	return state
end

--[[
-- OperationalState - airbase does things
--  * enter: reset runway health
--  * enter: notify airbase operational
--  * exit: notify airbase not operational
--  * transition: to Repairing on runway hit
--  * transition: to Captured on DCT capture event
--  * update:
--    - do AI departures
--]]
function OperationalState:__init()
	Marshallable.__init(self)
	self.type = statetypes.OPERATIONAL
	self:_addMarshalNames({"type", })
end

function OperationalState:enter(asset)
	asset:resetDamage()
	if asset:isSpawned() then
		asset:notify(dctutils.buildevent.operational(asset, true))
	end
end

function OperationalState:exit(asset)
	asset:notify(dctutils.buildevent.operational(asset, false))
end

function OperationalState:update(asset)
	-- TODO: create departures
	asset._logger:warn("operational state: update called")
end

function OperationalState:onDCTEvent(asset, event)
	--[[
	-- TODO: write this event handler
	-- events to handle:
	--  * DCT_EVENT_HIT - call airbase:checkHit(); returns: bool, func
	--    - track if runway hit; 50% of the runway must be hit w/
	--      500lb bombs or larger to knock it out, we can track this
	--      by splitting the runway up into 10 smaller rectangles,
	--      then keep a list of which sections have been hit
	--  * S_EVENT_TAKEOFF - call airbase:processDeparture(); returns: none
	--  * S_EVENT_LAND - no need to handle
	--  * S_EVENT_HIT - no need to handle at this time
	--  * S_EVENT_DEAD - no need to handle at this time
	--]]
	asset._logger:warn("operational state: onDCTEvent called event.id"..
		event.id)
end

local allowedtpltypes = {
	[dctenum.assetType.BASEDEFENSE]    = true,
	[dctenum.assetType.SQUADRONPLAYER] = true,
}

local statemap = {
	[statetypes.OPERATIONAL] = OperationalState,
	[statetypes.REPAIRING]   = RepairingState,
	[statetypes.CAPTURED]    = CapturedState,
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

	-- Associate player slots that cannot be autodetected by using
	-- a list provided by the campaign designer. First look up the
	-- template defining the airbase so that slots can be updated
	-- without resetting the campaign state.
	-- TODO: temp solution until a region manager is created
	local region = dct.Theater.singleton().regions[ab.rgnname]
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

local AirbaseAsset = class("Airbase", AssetBase, Subordinates)
function AirbaseAsset:__init(template)
	Subordinates.__init(self)
	self._departures = PriorityQueue()
	self._parking_occupied = {}
	AssetBase.__init(self, template)
	self:_addMarshalNames({
		"_tplnames",
		"_subordinates",
		"takeofftype",
		"recoverytype",
	})
	self._eventhandlers = nil
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
	self._tpldata = self._tpldata or {}
	self.state = OperationalState()
	self.state:enter(self)
	associate_slots(self)
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

	-- do not call the state's enter function because we are not
	-- entering the state we are just restoring the object
	associate_slots(self)
end

function AirbaseAsset:resetDamage()
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
	local newstate = self.state:onDCTEvent(self, event)
	if newstate ~= nil then
		self.state:exit(self)
		self.state = newstate
		self.state:enter(self)
	end
end

function AirbaseAsset:isOperational()
	return self:isSpawned() and self.state.type == statetypes.OPERATIONAL
end

function AirbaseAsset:getStatus()
	local g = 0
	if self:isOperational() then
		g = 1
	end
	return math.floor((1 - g) * 100)
end

function AirbaseAsset:generate(assetmgr, region)
	self._logger:debug("generate called")
	for _, tplname in ipairs(self._tplnames or {}) do
		self._logger:debug("subordinate template: "..tplname)
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
	self._logger:debug("spawn called")
	if not ignore and self:isSpawned() then
		self._logger:error("runtime bug - already spawned")
		return
	end
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
