--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents a null collection.
-- A null collection that doesn't die, is always spawned, never
-- reduces status, and is not associated with any DCS objects
--]]

--[[
   PlayerAsset
   * flight groups with player slots in them
   * DCS-objects, has associated DCS objects
     * objects move
     * no death goals, has death goals due to having DCS objects
     * spawn, nothing to spawn
   * invincible, asset cannot die (i.e. be deleted)
   * no associated "team leader" AI
   * player specific isSpawned() test - why?
   * enabled, asset can be enabled/disabled
     * DCS flag associated to control if the slot is enabled
       (think airbase captured so slot should not be joinable)
   * registers with an airbase asset
--]]

local class = require("libs.class")
local IDCSObjectCollection = require("dct.dcscollections.IDCSObjectCollection")
local uimenu  = require("dct.ui.groupmenu")
local Logger  = require("dct.Logger").getByName("Asset")
local loadout = require("dct.systems.loadouts")

local PlayerCollection = class(IDCSObjectCollection)
function PlayerCollection:__init(asset, template, region)
	table.insert(asset._marshalnames, "unittype")
	table.insert(asset._marshalnames, "groupId")
	IDCSObjectCollection.__init(self, asset, template, region)
end

function PlayerCollection:_completeinit(template, _)
	-- we assume all slots in a player group are the same
	self._asset.unittype   = template.tpldata.units[1].type
	self._asset.cmdpending = false
	self._asset.groupId    = template.tpldata.groupId
end

function PlayerCollection:getObjectNames()
	return {[1] = self._asset.name}
end

local function handleBirth(self, event, theater)
	local grp = event.initiator:getGroup()
	local id = grp:getID()
	if self._asset.groupId ~= id then
		Logger:warn(
			string.format("(%s) - asset.groupId(%d) != object:getID(%d)",
				self._asset.name, self._asset.groupId, id))
	end
	self._asset.groupId = id
	uimenu.createMenu(theater, self._asset)
	local cmdr = theater:getCommander(grp:getCoalition())
	local msn  = cmdr:getAssigned(self._asset)

	if msn then
		trigger.action.outTextForGroup(grp:getID(),
			"Welcome. A mission is already assigned to this slot, "..
			"use the F10 menu to get the briefing or find another.",
			20, false)
	else
		trigger.action.outTextForGroup(grp:getID(),
			"Welcome. Use the F10 Menu to get a theater update and "..
			"request a mission.",
			20, false)
	end
	loadout.notify(grp)
end

local function handleTakeoff(_, event, _)
	loadout.kick(event.initiator:getGroup())
end

local handlers = {
	[world.event.S_EVENT_BIRTH] = handleBirth,
	[world.event.S_EVENT_TAKEOFF] = handleTakeoff,
}

function PlayerCollection:onDCSEvent(event, theater)
	local handler = handlers[event.id]
	if handler ~= nil then
		handler(self, event, theater)
	end
end

return PlayerCollection
