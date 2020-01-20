--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- UI Commands
--]]

require("os")
local class    = require("libs.class")
local enum     = require("dct.enum")
local dctutils = require("dct.utils")
local human    = require("dct.ui.human")
local Command  = require("dct.Command")
local Logger   = require("dct.Logger").getByName("uiCmds")

-- precision of the coordinates given for a target area
local AO_LOC_PRECISION = 2

local UICmd = class(Command)
function UICmd:__init(theater, data)
	assert(theater ~= nil, "value error: theater required")
	assert(data ~= nil, "value error: data required")
	local grpdata = theater.playergps[data.name]

	self.theater      = theater
	self.type         = data.type
	self.grpid        = grpdata.id
	self.grpname      = data.name
	self.side         = grpdata.side
	self.displaytime  = 30
	self.displayclear = true
	self.actype       = grpdata.unittype
end

function UICmd:isAlive()
	return dctutils.isalive(self.grpname)
end

function UICmd:execute(time)
	-- only process commands from live players unless they are abort
	-- commands
	if not self:isAlive() and
	   self.type ~= enum.uiRequestType.MISSIONABORT then
		Logger:debug("UICmd thinks player is dead, ignore cmd; "..
			debug.traceback())
		self.theater.playergps[self.grpname].cmdpending = false
		return nil
	end

	local cmdr = self.theater:getCommander(self.side)
	local msg  = self:_execute(time, cmdr)
	assert(msg ~= nil and type(msg) == "string", "msg must be a string")
	trigger.action.outTextForGroup(self.grpid, msg, self.displaytime,
		self.displayclear)
	self.theater.playergps[self.grpname].cmdpending = false
	return nil
end


local TheaterUpdateCmd = class(UICmd)
function TheaterUpdateCmd:__init(theater, data)
	UICmd.__init(self, theater, data)
end

function TheaterUpdateCmd:_execute(time, cmdr)
	local update = cmdr:getTheaterUpdate()
	local msg =
		string.format("== Theater Threat Status ==\n") ..
		string.format("  Sea:    %s\n", human.threat(update.enemy.sea)) ..
		string.format("  Air:    %s\n", human.airthreat(update.enemy.air)) ..
		string.format("  ELINT:  %s\n", human.threat(update.enemy.elint))..
		string.format("  SAM:    %s\n", human.threat(update.enemy.sam)) ..
		string.format("\n== Current Active Air Missions ==\n")
	if next(update.missions) ~= nil then
		for k,v in pairs(update.missions) do
			msg = msg .. string.format("  %6s:  %2d\n", k, v)
		end
	else
		msg = msg .. "  No Active Missions\n"
	end
	msg = msg .. string.format("\nRecommended Mission Type: %s\n",
		dctutils.getkey(enum.missionType,
			cmdr:recommendMissionType(self.actype)) or "None")
	return msg
end


local MissionCmd = class(UICmd)
function MissionCmd:__init(theater, data)
	UICmd.__init(self, theater, data)
	self.erequest = true
end

function MissionCmd:_execute(time, cmdr)
	local msg
	local msn = cmdr:getAssigned(self.grpname)
	if msn == nil then
		msg = "You do not have a mission assigned"
		if self.erequest == true then
			msg = msg .. ", use the F10 menu to request one first."
		end
		return msg
	end
	msg = self:_mission(time, cmdr, msn)
	return msg
end


local function briefingmsg(msn, actype)
	local tgtinfo = msn:getTargetInfo()
	local msg = string.format("ID: %s\n", msn:getID())..
		string.format("%s: %s (%s)\n", human.locationhdr(msn.type),
			human.grid2actype(actype, tgtinfo.location,
				AO_LOC_PRECISION),
			tgtinfo.callsign)..
		"Briefing:\n"..msn:getDescription(actype, AO_LOC_PRECISION)
	return msg
end

local MissionRqstCmd = class(MissionCmd)
function MissionRqstCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
	self.missiontype = data.value
	self.displaytime = 120
end

function MissionRqstCmd:_execute(time, cmdr)
	local msn = cmdr:getAssigned(self.grpname)
	local msg

	if msn then
		msg = string.format("You have mission %s already assigned, "..
			"use the F10 Menu to abort first.",
					msn:getID())
		return msg
	end

	msn = cmdr:requestMission(self.grpname, self.missiontype)
	if msn == nil then
		msg = string.format("No %s missions available.",
			human.missiontype(self.missiontype))
	else
		msg = string.format("Mission %s assigned, use F10 menu "..
			"to see this briefing again\n", msn:getID())
		msg = msg..briefingmsg(msn, self.actype)
	end
	return msg
end


local MissionBriefCmd = class(MissionCmd)
function MissionBriefCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
	self.displaytime = 120
end

function MissionBriefCmd:_mission(time, cmdr, msn)
	return briefingmsg(msn, self.actype)
end


local MissionStatusCmd = class(MissionCmd)
function MissionStatusCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
end

function MissionStatusCmd:_mission(time, cmdr, msn)
	local msg
	local tgtinfo  = msn:getTargetInfo()
	local timeout  = msn:getTimeout()
	local minsleft = (timeout - time)
	if minsleft < 0 then
		minsleft = 0
	end
	minsleft = minsleft / 60

	msg = string.format("ID: %s\n", msn:getID()) ..
		string.format("Timeout: %s (in %d mins)\n",
			os.date("%Y-%m-%d %H:%M:%Sz", dctutils.time(timeout)),
			minsleft) ..
		string.format("BDA: %d%% complete\n", tgtinfo.status)

	return msg
end


local MissionAbortCmd = class(MissionCmd)
function MissionAbortCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
	self.erequest = false
	self.reason   = data.value
end

function MissionAbortCmd:_mission(time, cmdr, msn)
	return string.format("Mission %s aborted, %s",
		msn:abort(time), self.reason)
end


local MissionRolexCmd = class(MissionCmd)
function MissionRolexCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
	self.rolextime = data.value
end

function MissionRolexCmd:_mission(time, cmdr, msn)
	return string.format("+%d mins added to mission timeout",
		msn:addTime(self.rolextime)/60)
end


local MissionCheckinCmd = class(MissionCmd)
function MissionCheckinCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
end

function MissionCheckinCmd:_mission(time, cmdr, msn)
	msn:checkin(time)
	return string.format("on-station received")
end


local MissionCheckoutCmd = class(MissionCmd)
function MissionCheckoutCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
end

function MissionCheckoutCmd:_mission(time, cmdr, msn)
	return string.format("off-station received, vul time: %d",
		msn:checkout(time))
end

local cmds = {
	[enum.uiRequestType.THEATERSTATUS]   = TheaterUpdateCmd,
	[enum.uiRequestType.MISSIONREQUEST]  = MissionRqstCmd,
	[enum.uiRequestType.MISSIONBRIEF]    = MissionBriefCmd,
	[enum.uiRequestType.MISSIONSTATUS]   = MissionStatusCmd,
	[enum.uiRequestType.MISSIONABORT]    = MissionAbortCmd,
	[enum.uiRequestType.MISSIONROLEX]    = MissionRolexCmd,
	[enum.uiRequestType.MISSIONCHECKIN]  = MissionCheckinCmd,
	[enum.uiRequestType.MISSIONCHECKOUT] = MissionCheckoutCmd,
}

return cmds
