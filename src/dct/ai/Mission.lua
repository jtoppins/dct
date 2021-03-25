--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents a Mission within the game and this associates an
-- Objective to as assigned group of units responsible for
-- completing the Objective.
--]]

require("os")
require("math")
local utils    = require("libs.utils")
local enum     = require("dct.enum")
local dctutils = require("dct.utils")
local uicmds   = require("dct.ui.cmds")

local MISSION_LIMIT = 60*60*3  -- 3 hours in seconds

local function composeBriefing(msn, tgt)
	local briefing = tgt.briefing
	local interptbl = {
		["TOT"] = os.date("!%F %Rz",
			dctutils.zulutime(msn:getTimeout()*.6)),
	}
	return dctutils.interp(briefing, interptbl)
end

local Mission = require("libs.namedclass")("Mission")
function Mission:__init(cmdr, missiontype, grpname, tgtname)
	self._complete = false
	self.iffcodes  = cmdr:genMissionCodes(missiontype)
	self.id        = self.iffcodes.id
	-- reference to owning commander
	self.cmdr      = cmdr
	self.type      = missiontype
	self.target    = tgtname
	self.assigned  = {}
	self.timestart = timer.getAbsTime()
	self.timeend   = self.timestart + MISSION_LIMIT
	self.station   = {
		["onstation"] = false,
		["total"]     = 0,
		["start"]     = 0,
	}

	-- compose the briefing at mission creation to represent
	-- known intel the pilots were given before departing
	local tgt = self.cmdr:getAsset(tgtname)
	self.briefing  = composeBriefing(self, tgt)
	tgt:addObserver(self.onTgtEvent, self,
		"Mission("..tgtname..").onTgtEvent")
	tgt:setTargeted(self.cmdr.owner, true)
	self:addAssigned(self.cmdr:getAsset(grpname))

	-- TODO: setup remaining mission parameters;
	--   * mission world states
end

function Mission:getID()
	return self.id
end

function Mission:isMember(name)
	local i = utils.getkey(self.assigned, name)
	if i then
		return true, i
	end
	return false
end

function Mission:getAssigned()
	return utils.shallowclone(self.assigned)
end

function Mission:addAssigned(asset)
	if self:isMember(asset.name) then
		return
	end
	table.insert(self.assigned, asset.name)
	asset.missionid = self:getID()
end

function Mission:removeAssigned(asset)
	local member, i = self:isMember(asset.name)
	if not member then
		return
	end
	table.remove(self.assigned, i)
	asset.missionid = enum.misisonInvalidID
end

--[[
-- Abort - aborts a mission for etiher a single group or
--   completely terminating the mission for everyone assigned.
--
-- Things that need to be managed;
--  * remove requesting group from the assigned list
--  * if assigned list is empty or we need to force terminate the
--    mission
--    - remove the mission from the owning commander's mission list(s)
--    - release the targeted asset by resetting the asset's targeted
--      bit
--]]
function Mission:abort(asset)
	self:removeAssigned(asset)
	if next(self.assigned) == nil then
		self.cmdr:removeMission(self.id)
		local tgt = self.cmdr:getAsset(self.target)
		if tgt then
			tgt:setTargeted(self.cmdr.owner, false)
		end
	end
	return self.id
end

function Mission:queueabort(reason)
	self:_setComplete()
	local theater = dct.Theater.singleton()
	for _, name in ipairs(self.assigned) do
		local request = {
			["type"]   = enum.uiRequestType.MISSIONABORT,
			["name"]   = name,
			["value"]  = reason,
		}
		-- We have to use theater:queueCommand() to bypass the
		-- limiting of players sending too many commands
		theater:queueCommand(10, uicmds[request.type](theater, request))
	end
end

function Mission:onTgtEvent(event)
	if event.id ~= enum.event.DCT_EVENT_DEAD then
		return
	end
	local tgt = event.initiator
	dct.Theater.singleton():getTickets():reward(self.cmdr.owner,
		tgt.cost, true)
	tgt:removeObserver(self)
	self:queueabort(enum.missionAbortType.COMPLETE)
end

-- for now just track if the mission has not timmed out and
-- if it has queue an abort command with abort reason
function Mission:update(_)
	if self:isComplete() then
		return
	end

	if timer.getAbsTime() > self.timeend then
		self:queueabort(enum.missionAbortType.TIMEOUT)
	end
	return
end

function Mission:_setComplete()
	self._complete = true
end

function Mission:isComplete()
	return self._complete
end

--[[
-- getTargetInfo - provide target info information
--
-- The target information supplied:
--   * location - centroid of the asset
--   * callsign - a short name the target area can be referenced by
--   * description - short two/three word description of the asset
--       like; factory, ammo bunker, etc.
--   * status - numercal value from 0 to 100 representing percentage
--       completion
--   * intellvl - numercal value representing the amount of 'intel'
--       gathered on the asset, dictates targeting coordinates
--       precision too
--]]
function Mission:getTargetInfo()
	local asset = self.cmdr:getAsset(self.target)
	local tgtinfo = {}
	tgtinfo.location = asset:getLocation()
	tgtinfo.callsign = asset.codename
	tgtinfo.status   = asset:getStatus()
	tgtinfo.intellvl = asset:getIntel(self.cmdr.owner)
	return tgtinfo
end

function Mission:getTimeout()
	return self.timeend
end

function Mission:addTime(time)
	self.timeend = self.timeend + time
	return time
end

function Mission:checkin(time)
	if self.station.onstation == true then
		return
	end
	self.station.onstation = true
	self.station.start = time
end

function Mission:checkout(time)
	if self.station.onstation == false then
		return 0
	end
	self.station.onstation = false
	self.station.total = self.station.total + (time - self.station.start)
	return self.station.total
end

function Mission:getDescription(fmt)
	local tgt = self.cmdr:getAsset(self.target)
	if tgt == nil then
		return "Target destroyed abort mission"
	end
	local interptbl = {
		["LOCATION"] = dctutils.fmtposition(
			tgt:getLocation(),
			tgt:getIntel(self.cmdr.owner),
			fmt)
	}
	return dctutils.interp(self.briefing, interptbl)
end

return Mission
