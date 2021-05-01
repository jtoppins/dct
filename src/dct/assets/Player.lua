--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents a player asset.
--
-- Player<AssetBase>
-- A player asset doesn't die (the assetmanager prevents this), never
-- reduces status, and is always associated with a squadron.
-- Optionally the player can be associated with an airbase.
--
-- ## Ticket Consumption
-- Players only consume a ticket when a when they die or otherwise
-- leave the slot is an 'invalid' way. A valid way to leave a slot
-- is at an authorized airbase.
--
-- ## Slot Management
-- Spawned player objects are used as a signal for enabling/disabling
-- the slot. This is additionally combined with a transient state
-- potentially defined in the Player's State class (EmptyState or
-- OccupiedState) to ultimately determine if the slot is 'enabled'.
-- The hooks script used for slot management can utilize this by
-- directly asking the Player object if it is enabled via the
-- 'isEnabled()' API call.
-- This API call will combine the spawned(S) and kick pending(K)
-- states to prevent a race between posting a kick request
-- and affecting the kick in the hooks script. The boolean table
-- below shows the logic governing when a slot is considered
-- 'enabled';
--     EmptyState:     enabled = S & !K
--     OccupiedState:  enabled = S; we really don't care through
--                                  because the slot should be
--                                  occupied
--]]

require("math")
local class   = require("libs.namedclass")
local dctenum = require("dct.enum")
local dctutils= require("dct.utils")
local AssetBase = require("dct.assets.AssetBase")
local uimenu  = require("dct.ui.groupmenu")
local loadout = require("dct.systems.loadouts")
local State   = require("dct.libs.State")
local settings = _G.dct.settings

local notifymsg =
	"Please read the loadout limits in the briefing and "..
	"use the F10 Menu to validate your loadout before departing."

local function build_kick_flagname(name)
	return name.."_kick"
end

local function on_birth(asset, event)
	local grp = event.initiator:getGroup()
	local id = grp:getID()
	if asset.groupId ~= id then
		asset._logger:warn(
			string.format("asset.groupId(%d) != object:getID(%d)",
				asset.groupId, id))
	end
	asset.groupId = id
end

local function reset_slot(asset)
	local theater = dct.Theater.singleton()
	if asset.squadron then
		asset._logger:debug("squadron set: "..asset.squadron)
		local sqdn = theater:getAssetMgr():getAsset(asset.squadron)
		if sqdn then
			asset._logger:debug("squadron overriding ato and payload")
			asset.ato = sqdn:getATO()
			asset.payloadlimits = sqdn:getPayloadLimits()
			asset._logger:debug("payloadlimits: "..
				require("libs.json"):encode_pretty(asset.payloadlimits))
			asset._logger:debug("ato: "..
				require("libs.json"):encode_pretty(asset.ato))
		end
	end
	uimenu.createMenu(asset)
	local cmdr = theater:getCommander(asset.owner)
	local msn  = cmdr:getAssigned(asset)

	if msn then
		trigger.action.outTextForGroup(asset.groupId,
			"Welcome. A mission is already assigned to this slot, "..
			"use the F10 menu to get the briefing or find another.",
			20, false)
	else
		trigger.action.outTextForGroup(asset.groupId,
			"Welcome. Use the F10 Menu to get a theater update and "..
			"request a mission.",
			20, false)
	end
	trigger.action.outTextForGroup(asset.groupId, notifymsg, 20, false)
end

local OccupiedState = class("OccupiedState", State)
local EmptyState    = class("EmptyState", State)
function EmptyState:__init(kickcode)
	self.kickcode = kickcode or dctenum.kickCode.UNKNOWN
end

function EmptyState:enter(asset)
	asset:kick(self.kickcode)
	if asset.missionid ~= dctenum.missionInvalidID and
	   settings.server.emptyslottimeout > 0 then
		self.timer =
			require("dct.libs.Timer")(settings.server.emptyslottimeout,
				timer.getAbsTime)
	end
end

function EmptyState:update(asset)
	if self.timer == nil then
		return
	end

	self.timer:update()
	if self.timer:expired() then
		self.timer = nil
		local cmdr = dct.Theater.singleton():getCommander(asset.owner)
		local msn = cmdr:getMission(asset.missionid)
		if msn then
			msn:abort(asset)
		end
	end
end

function EmptyState:onDCTEvent(asset, event)
	if world.event.S_EVENT_BIRTH ~= event.id then
		return nil
	end
	on_birth(asset, event)
	return OccupiedState(event.initiator:inAir())
end

function OccupiedState:__init(inair)
	self.inair = inair
	self.loseticket = false
	self.bleedctr = 0
	self.bleedperiod = 5
	self.bleedwarn = false
	self._eventhandlers = {
		[world.event.S_EVENT_BIRTH]             = self.handleSwitchOccupied,
		[world.event.S_EVENT_TAKEOFF]           = self.handleTakeoff,
		[world.event.S_EVENT_EJECTION]          = self.handleLoseTicket,
		[world.event.S_EVENT_DEAD]              = self.handleLoseTicket,
		[world.event.S_EVENT_PILOT_DEAD]        = self.handleLoseTicket,
		[world.event.S_EVENT_CRASH]             = self.handleLoseTicket,
		[world.event.S_EVENT_LAND]              = self.handleLand,
	}
end

function OccupiedState:enter(asset)
	asset:setDead(false)
	reset_slot(asset)
end

function OccupiedState:exit(asset)
	if self.loseticket then
		asset:setDead(true)
	end
end

function OccupiedState:_bleed(asset)
	local theater = dct.Theater.singleton()
	local tickets = theater:getTickets()
	if not (tickets:getConfig(asset.owner).bleed and
		self.inair == true) then
		return nil
	end

	local cmdr = theater:getCommander(asset.owner)
	local msn  = cmdr:getAssigned(asset)
	if msn then
		self.bleedctr = 0
		self.bleedwarn = false
	else
		self.bleedctr = self.bleedctr + 1
	end

	local state = nil
	if not self.bleedwarn and
	   self.bleedctr > math.floor(self.bleedperiod / 2) then
		self.bleedwarn = true
		trigger.action.outTextForGroup(asset.groupId,
			"WARNING! You do not have a mission assigned, land or obtain "..
			"a mission or you will be kicked.",
			20, true)
	end
	if self.bleedctr >= self.bleedperiod then
		self.loseticket = true
		self.bleedctr = 0
		trigger.action.outTextForGroup(asset.groupId,
			"You have been kicked for not having a mission assigned.",
			20, true)
		state = EmptyState(dctenum.kickCode.MISSION)
	end
	return state
end

function OccupiedState:update(asset)
	local grp = Group.getByName(asset.name)
	if grp == nil then
		return EmptyState(dctenum.kickCode.EMPTY)
	end
	return self:_bleed(asset)
end

function OccupiedState:onDCTEvent(asset, event)
	local handler = self._eventhandlers[event.id]
	asset._logger:debug(string.format(
		"OccupiedState:onDCTEvent; event.id: %d, handler: %s",
		event.id, tostring(handler)))
	local state
	if handler ~= nil then
		state = handler(self, asset, event)
	end
	return state
end

function OccupiedState:handleTakeoff(asset, _ --[[event]])
	self.loseticket = true
	self.inair = true
	local ok = loadout.check(asset)
	if not ok then
		trigger.action.outTextForGroup(asset.groupId,
			"You have been removed to spectator for flying with an "..
			"invalid loadout. "..notifymsg,
			20, true)
		return EmptyState(dctenum.kickCode.LOADOUT)
	end
	return nil
end

-- If returned to an authorized airbase clear loseticket flag.
-- An authorized airbase is any base defined as an asset for
-- the same side.
function OccupiedState:handleLand(asset, event)
	if event.place == nil then
		return nil
	end

	local assetmgr = dct.Theater.singleton():getAssetMgr()
	local airbase = assetmgr:getAsset(event.place:getName())

	if (airbase and airbase.owner == asset.owner) or
	   event.place:getName() == asset.airbase then
		self.loseticket = false
		self.inair = false
		trigger.action.outTextForGroup(asset.groupId,
			"Welcome home. You are able to safely disconnect"..
			" without costing your side tickets.",
			20, true)
	end
	return nil
end

function OccupiedState:handleLoseTicket(--[[asset, event]])
	self.loseticket = true
	return EmptyState(dctenum.kickCode.DEAD)
end

function OccupiedState:handleSwitchOccupied(asset, event)
	asset._logger:warn("player left slot, resetting state for birth event")
	on_birth(asset, event)
	return OccupiedState()
end

--[[
-- Player - represents a player slot in DCS
--]]
local Player = class("Player", AssetBase)
function Player:__init(template)
	AssetBase.__init(self, template)
	self.inair = false
	self._operstate = false
	self.missionid = dctenum.missionInvalidID
	trigger.action.setUserFlag(self.name, false)
	trigger.action.setUserFlag(build_kick_flagname(self.name),
		dctenum.kickCode.NOKICK)
	self.marshal   = nil
	self.unmarshal = nil
end

function Player.assettypes()
	return {
		dctenum.assetType.PLAYERGROUP,
	}
end

local function airbaseId(grp)
	assert(grp, "value error: grp cannot be nil")
	local id = nil
	for _, name in ipairs({"airdromeId", "helipadId", "linkUnit"}) do
		id = grp.data.route.points[1][name]
		if id ~= nil then
			return id
		end
	end
	return id
end

local function airbaseParkingId(grp)
	assert(grp, "value error: grp cannot be nil")
	local wp = grp.data.route.points[1]
	if wp.type == AI.Task.WaypointType.TAKEOFF_PARKING or
	   wp.type == AI.Task.WaypointType.TAKEOFF_PARKING_HOT then
		return grp.data.units[1].parking
	end
	return nil
end

function Player:_completeinit(template)
	AssetBase._completeinit(self, template)
	-- we assume all slots in a player group are the same
	self._tpldata   = template:copyData()
	self.unittype   = self._tpldata.data.units[1].type
	self.cmdpending = false
	self.groupId    = self._tpldata.data.groupId
	self.squadron   = self.name:match("(%w+)(.+)")
	self.airbase    = dctutils.airbaseId2Name(airbaseId(self._tpldata))
	self.parking    = airbaseParkingId(self._tpldata)
	self.ato        = settings.ui.ato[self.unittype] or
		dctenum.missionType
	self.payloadlimits = settings.payloadlimits
	self.gridfmt    = settings.ui.gridfmt[self.unittype] or
		dctutils.posfmt.DMS
	self._logger:debug("airbase: "..tostring(self.airbase))
	self._logger:debug("payloadlimits: "..
		require("libs.json"):encode_pretty(self.payloadlimits))
	self._logger:debug("ato: "..
		require("libs.json"):encode_pretty(self.ato))
end

function Player:_setup()
	self.state = EmptyState(dctenum.kickCode.SETUP)
	self.state:enter(self)
end

-- Player assets cannot die, prevent them from ever being cleaned up
-- by the AssetManager
function Player:isDead()
	return false
end

function Player:inAir()
	self.inair = self.state.inair or false
	return self.inair
end

function Player:getObjectNames()
	return {self.name, }
end

function Player:getLocation()
	local p = Group.getByName(self.name)
	self._location = p:getUnit(1):getPoint()
	return self._location
end

function Player:isEnabled()
	return self:isSpawned() and self._operstate
end

function Player:doEnable()
	trigger.action.setUserFlag(self.name, self:isEnabled())
	self._logger:debug(string.format("setting enable flag: %s",
		tostring(self:isEnabled())))
end

function Player:update()
	self:doEnable()
	local newstate = self.state:update(self)
	if newstate ~= nil then
		self.state:exit(self)
		self.state = newstate
		self.state:enter(self)
	end
end

function Player:handleBaseState(event)
	if event.initiator.name == self.airbase then
		self._operstate = event.state
		self._logger:debug(string.format("setting operstate: %s",
			tostring(event.state)))
		self:doEnable()
	else
		self._logger:warn(string.format("received unknown event "..
			"%s(%d) from initiator(%s)",
			require("libs.utils").getkey(dctenum.event, event.id),
			event.id, event.initiator.name))
	end
end

function Player:onDCTEvent(event)
	if event.id == dctenum.event.DCT_EVENT_OPERATIONAL then
		self:handleBaseState(event)
	end
	local newstate = self.state:onDCTEvent(self, event)
	if newstate ~= nil then
		self.state:exit(self)
		self.state = newstate
		self.state:enter(self)
	end
end

function Player:spawn()
	AssetBase.spawn(self)
	self:doEnable()
end

function Player:despawn()
	AssetBase.despawn(self)
	self:doEnable()
end

--[[
-- kick - request player to be kicked from slot
--
-- Posts a request for the player to be kicked from the slot.
-- This depends on an outside DCS hooks script to be running
-- which will kick the player from the slot and reset the
-- kick flag.
-- This will then allow the player state the be reset allowing
-- another player to join the slot.
--]]
function Player:kick(kickcode)
	local flagname = build_kick_flagname(self.name)
	trigger.action.setUserFlag(flagname, kickcode)
	self._logger:debug(string.format("requesting kick: %s", flagname))
end

return Player
