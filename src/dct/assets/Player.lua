--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents a player asset.
--
-- Player<AssetBase>
-- A player asset doesn't die, is always spawned, never
-- reduces status, and is associated with a squadron.
-- Optionally the player can be associated with an airbase.
--]]

local class = require("libs.class")
local AssetBase = require("dct.assets.AssetBase")
local uimenu  = require("dct.ui.groupmenu")
local Logger  = dct.Logger.getByName("Asset")
local loadout = require("dct.systems.loadouts")
local settings = _G.dct.settings

local Player = class(AssetBase)
function Player:__init(template, region)
	self.__clsname = "Player"
	self._eventhandlers = {
		[world.event.S_EVENT_BIRTH]   = self.handleBirth,
		[world.event.S_EVENT_TAKEOFF] = self.handleTakeoff,
	}
	AssetBase.__init(self, template, region)
	self:_addMarshalNames({
		"unittype",
		"groupId",
		"airbase",
		"parking",
	})
end

function Player:_completeinit(template, region)
	AssetBase._completeinit(self, template, region)
	-- we assume all slots in a player group are the same
	self._tpldata   = template:copyData()
	self.unittype   = self._tpldata.data.units[1].type
	self.cmdpending = false
	self.groupId    = self._tpldata.data.groupId
	self.ato        = settings.ui.ato[self.unittype]
	if self.ato == nil then
		self.ato = require("dct.enum").missionType
	end
	self.payloadlimits = settings.payloadlimits
end

function Player:getObjectNames()
	return {self.name, }
end

function Player:getLocation()
	local p = Group.getByName(self.name)
	self._location = p:getUnit(1):getPoint()
	return self._location
end

function Player:handleBirth(event)
	local theater = require("dct.Theater").singleton()
	local grp = event.initiator:getGroup()
	local id = grp:getID()
	if self.groupId ~= id then
		Logger:warn(
			string.format("(%s) - asset.groupId(%d) != object:getID(%d)",
				self.name, self.groupId, id))
	end
	self.groupId = id
	uimenu.createMenu(theater, self)
	local cmdr = theater:getCommander(grp:getCoalition())
	local msn  = cmdr:getAssigned(self)

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

function Player:handleTakeoff(event)
	loadout.kick(event.initiator:getGroup())
end

return Player
