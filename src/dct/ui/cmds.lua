-- SPDX-License-Identifier: LGPL-3.0
--
-- UI Commands

require("os")
local class    = require("libs.namedclass")
local utils    = require("libs.utils")
local enum     = require("dct.enum")
local dctutils = require("dct.libs.utils")
local human    = require("dct.ui.human")
local Command  = require("dct.libs.Command")
local Logger   = dct.Logger.getByName("UI")
local loadout  = require("dct.ui.loadouts")

local UICmd = class("UICmd", Command)
function UICmd:__init(theater, data)
	assert(theater ~= nil, "value error: theater required")
	assert(data ~= nil, "value error: data required")
	local asset = theater:getAssetMgr():getAsset(data.name)
	assert(asset, "runtime error: asset was nil, "..data.name)

	Command.__init(self, "UICmd", self.uicmd, self)

	self.prio         = Command.PRIORITY.UI
	self.theater      = theater
	self.asset        = asset
	self.type         = data.type
	self.displaytime  = 30
	self.displayclear = true
end

function UICmd:isAlive()
	return dctutils.isalive(self.asset.name)
end

function UICmd:_print(msg, isError)
	if isError and _G.DCT_TEST then
		return
	end
	assert(msg ~= nil and type(msg) == "string", "msg must be a string")
	trigger.action.outTextForGroup(self.asset.groupId, msg,
		self.displaytime, self.displayclear)
end

function UICmd:uicmd(time)
	-- only process commands from live players unless they are abort
	-- commands
	if not self:isAlive() and
	   self.type ~= enum.uiRequestType.MISSIONABORT then
		Logger:debug("UICmd thinks player is dead, ignore cmd; %s", debug.traceback())
		self.asset.cmdpending = false
		return nil
	end

	xpcall(function()
		local cmdr = self.theater:getCommander(self.asset.owner)
		local msg  = self:_execute(time, cmdr)
		self.asset.cmdpending = false
		self:_print(msg)
	end, function(err)
		self.asset.cmdpending = false
		self:_print("F10 menu command failed to execute, please report a bug", true)
		error(string.format(
			"\nui command failed: %s - %s", self.__clsname, tostring(err)))
	end)
end

--- @class ScratchPadDisplay
local ScratchPadDisplay = class("ScratchPadDisplay", UICmd)
function ScratchPadDisplay:__init(theater, data)
	UICmd.__init(self, theater, data)
	self.name = "ScratchPadDisplay:"..data.name
end

function ScratchPadDisplay:_execute(_, _)
	local msg = string.format("Scratch Pad: '%s'",
		tostring(self.asset.scratchpad))
	return msg
end

--- @class ScratchPadSet
local ScratchPadSet = class("ScratchPadSet", UICmd)
function ScratchPadSet:__init(theater, data)
	UICmd.__init(self, theater, data)
	self.name = "ScratchPadSet:"..data.name
end

function ScratchPadSet:_execute(_, _)
	local mrkid = human.getMarkID()
	local pos   = Group.getByName(self.asset.name):getUnit(1):getPoint()

	self.theater:getSystem("dct.ui.scratchpad"):set(mrkid, self.asset.name)
	trigger.action.markToGroup(mrkid, "edit me", pos,
		self.asset.groupId, false)
	local msg = "Look on F10 MAP for user mark with contents \"edit me"..
		"\"\n Edit body with your scratchpad information. "..
		"Click off the mark when finished. The mark will "..
		"automatically be deleted."
	return msg
end

local TheaterUpdateCmd = class("TheaterUpdateCmd", UICmd)
function TheaterUpdateCmd:__init(theater, data)
	UICmd.__init(self, theater, data)
	self.name = "TheaterUpdateCmd:"..data.name
end

local function addAirbases(allAirbases, outList, side, ownerFilter)
	for _, airbase in utils.sortedpairs(allAirbases) do
		if airbase.owner == ownerFilter then
			table.insert(outList, string.format("%s: %s",
				human.relationship(side, airbase.owner),
				airbase.name))
		end
	end
end

function TheaterUpdateCmd:_execute(_, cmdr)
	local update = cmdr:getTheaterUpdate()
	local available = cmdr:getAvailableMissions(self.asset.ato)
	local recommended = cmdr:recommendMissionType(self.asset.ato)
	local airbases = self.theater:getAssetMgr():filterAssets(
		function(asset) return asset.type == enum.assetType.AIRBASE end)

	local airbaseList = {}
	if cmdr.owner ~= coalition.side.NEUTRAL then
		addAirbases(airbases, airbaseList, cmdr.owner, cmdr.owner)
	end
	addAirbases(airbases, airbaseList, cmdr.owner, coalition.side.NEUTRAL)
	addAirbases(airbases, airbaseList, cmdr.owner, dctutils.getenemy(cmdr.owner))

	local activeMsnList = {}
	if next(update.missions) ~= nil then
		for msntype, count in utils.sortedpairs(update.missions) do
			table.insert(activeMsnList, string.format("%s:  %d", msntype, count))
		end
	else
		table.insert(activeMsnList, "None")
	end

	local availableMsnList = {}
	if next(available) ~= nil then
		for msntype, count in utils.sortedpairs(available) do
			table.insert(availableMsnList, string.format("%s:  %d", msntype, count))
		end
	else
		table.insert(availableMsnList, "None")
	end

	local msg = "== Theater Status ==\n"..
		string.format("Friendly Force Str: %s\n",
			human.strength(update.friendly.str))..
		string.format("Enemy Force Str: %s\n",
			human.strength(update.enemy.str))..
		string.format("\nAirbases:\n  %s\n",
			table.concat(airbaseList, "\n  "))..
		string.format("\nCurrent Active Air Missions:\n  %s\n",
			table.concat(activeMsnList, "\n  "))..
		string.format("\nAvailable missions:\n  %s\n",
			table.concat(availableMsnList, "\n  "))..
		string.format("\nRecommended Mission Type: %s",
			utils.getkey(enum.missionType, recommended) or "None")

	return msg
end

local CheckPayloadCmd = class("CheckPayloadCmd", UICmd)
function CheckPayloadCmd:__init(theater, data)
	UICmd.__init(self, theater, data)
	self.name = "CheckPayloadCmd:"..data.name
end

function CheckPayloadCmd.buildSummary(costs)
	-- print cost summary at the top
	local msg = "== Loadout Summary:"
	for desc, cat in pairs(enum.weaponCategory) do
		if costs[cat].current < enum.WPNINFCOST then
			msg = string.format("%s\n  %s cost: %.4g / %d",
				msg, desc, costs[cat].current, costs[cat].max)
		else
			msg = string.format("%s\n  %s cost: -- / %d",
				msg, desc, costs[cat].max)
		end
	end

	-- group weapons by category
	for desc, cat in pairs(enum.weaponCategory) do
		if next(costs[cat].payload) ~= nil then
			msg = msg..string.format("\n\n== %s Weapons:", desc)
			for _, wpn in pairs(costs[cat].payload) do
				msg = string.format("%s\n  %s\n    ↳ ", msg, wpn.name)
				if wpn.cost == 0 then
					msg = msg..string.format("%d × unrestricted (0 pts)", wpn.count)
				elseif wpn.cost < enum.WPNINFCOST then
					msg = msg..string.format("%d × %.4g pts = %.4g pts",
						wpn.count, wpn.cost, wpn.count * wpn.cost)
				else
					msg = msg.."Weapon cannot be used in this theater [!]"
				end
			end
		end
	end

	return msg
end

function CheckPayloadCmd:_execute(_ --[[time]], _ --[[cmdr]])
	if type(self.asset.inAir) == "function" and self.asset:inAir() then
		return "Payload check is only allowed when landed at a friendly airbase"
	end

	local ok, totals = loadout.check(self.asset)
	if ok then
		return "Valid loadout, you may depart. Good luck!\n\n"
			..self.buildSummary(totals)
	else
		return "You are over budget! Re-arm before departing, or "..
			"you will be punished!\n\n"
			..self.buildSummary(totals)
	end
end

local MissionCmd = class("MissionCmd", UICmd)
function MissionCmd:__init(theater, data)
	UICmd.__init(self, theater, data)
	self.erequest = true
end

function MissionCmd:_execute(time, cmdr)
	local msn = cmdr:getAssigned(self.asset)
	local msg

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


local function briefingmsg(msn, asset)
	local tgtinfo = msn:getTargetInfo()
	local iff = msn:getIFFCodes(asset)
	local msg = string.format("Package: #%s\n", msn:getID())..
		string.format("IFF Codes: M1(%s), M3(%s)\n", iff.m1, iff.m3)..
		string.format("%s: %s (%s)\n",
			human.locationhdr(msn.type),
			dctutils.fmtposition(
				tgtinfo.location,
				tgtinfo.intellvl,
				asset.gridfmt),
			tgtinfo.callsign)..
		"Briefing:\n"..msn:getDescription(asset.gridfmt)
	return msg
end

local function assignedPilots(msn, assetmgr)
	local pilots = {}
	for _, name in pairs(msn:getAssigned()) do
		local asset = assetmgr:getAsset(name)
		if asset:isa(require("dct.assets.Player")) then
			local playerName = asset:getPlayerName()
			if playerName then
				local aircraft = asset:getAircraftName()
				table.insert(pilots, string.format("%s (%s)", playerName, aircraft))
			end
		end
	end
	return table.concat(pilots, "\n")
end

local MissionJoinCmd = class("MissionJoinCmd", MissionCmd)
function MissionJoinCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
	self.name = "MissionJoinCmd:"..data.name
	self.missioncode = data.value
	self.assetmgr = theater:getAssetMgr()
end

function MissionJoinCmd:_execute(_, cmdr)
	local missioncode = self.missioncode or self.asset.scratchpad or 0
	local msn = cmdr:getAssigned(self.asset)
	local msg

	if msn then
		msg = string.format("You have mission %s already assigned, "..
			"use the F10 Menu to abort first.", msn:getID())
		return msg
	end

	msn = cmdr:getMission(missioncode)
	if msn == nil then
		msg = string.format("No mission of ID(%s) available",
				    tostring(missioncode))
	else
		local tgtinfo = msn:getTargetInfo()
		msn:addAssigned(self.asset)
		msg = string.format("Mission %s assigned, use F10 menu "..
			"to see this briefing again\n", msn:getID())
		msg = msg..briefingmsg(msn, self.asset).."\n\n"
		msg = msg..string.format("BDA: %d%% complete\n\n", tgtinfo.status)
		msg = msg.."Assigned Pilots:\n"..assignedPilots(msn, self.assetmgr)
		human.drawTargetIntel(msn, self.asset.groupId, false)
	end
	return msg
end

local MissionRqstCmd = class("MissionRqstCmd", MissionCmd)
function MissionRqstCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
	self.name = "MissionRqstCmd:"..data.name
	self.missiontype = data.value
	self.displaytime = 120
	self.assetmgr = theater:getAssetMgr()
end

function MissionRqstCmd:_execute(_, cmdr)
	local msn = cmdr:getAssigned(self.asset)
	local msg

	if msn then
		msg = string.format("You have mission %s already assigned, "..
			"use the F10 Menu to abort first.", msn:getID())
		return msg
	end

	msn = cmdr:requestMission(self.asset.name, self.missiontype)
	if msn == nil then
		msg = string.format("No %s missions available.",
			human.missiontype(self.missiontype))
	else
		local tgtinfo = msn:getTargetInfo()
		msg = string.format("Mission %s assigned, use F10 menu "..
			"to see this briefing again\n", msn:getID())
		msg = msg..briefingmsg(msn, self.asset)
		msg = msg..string.format("\n\nBDA: %d%% complete", tgtinfo.status)
		msg = msg.."\n\nAssigned Pilots:\n"..assignedPilots(msn, self.assetmgr)
		human.drawTargetIntel(msn, self.asset.groupId, false)
	end
	return msg
end


local MissionBriefCmd = class("MissionBriefCmd", MissionCmd)
function MissionBriefCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
	self.name = "MissionBriefCmd:"..data.name
	self.displaytime = 120
end

function MissionBriefCmd:_mission(_, _, msn)
	return briefingmsg(msn, self.asset)
end


local MissionStatusCmd = class("MissionStatusCmd", MissionCmd)
function MissionStatusCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
	self.name = "MissionStatusCmd:"..data.name
	self.assetmgr = theater:getAssetMgr()
end

function MissionStatusCmd:_mission(_, _, msn)
	local msg
	local missiontime = timer.getAbsTime()
	local tgtinfo     = msn:getTargetInfo()
	local timeout     = msn:getTimeout()
	local minsleft    = (timeout - missiontime)
	if minsleft < 0 then
		minsleft = 0
	end
	minsleft = minsleft / 60

	msg = string.format("Mission State: %s\n", msn:getStateName())..
		string.format("Package: %s\n", msn:getID())..
		string.format("Timeout: %s (in %d mins)\n",
			os.date("%F %Rz", dctutils.zulutime(timeout)),
			minsleft)..
		string.format("BDA: %d%% complete\n\n", tgtinfo.status)..
		string.format("Assigned Pilots:\n")..assignedPilots(msn, self.assetmgr)

	return msg
end


local MissionAbortCmd = class("MissionAbortCmd", MissionCmd)
function MissionAbortCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
	self.name = "MissionAbortCmd:"..data.name
	self.erequest = false
	self.reason   = data.value
end

function MissionAbortCmd:_mission(_ --[[time]], _, msn)
	local msgs = {
		[enum.missionAbortType.ABORT] =
			"aborted",
		[enum.missionAbortType.COMPLETE] =
			"completed",
		[enum.missionAbortType.TIMEOUT] =
			"timed out",
	}
	local msg = msgs[self.reason]
	if msg == nil then
		msg = "aborted - unknown reason"
	end
	human.removeIntel(msn, self.asset.groupId)
	return string.format("Mission %s %s",
		msn:abort(self.asset),
		msg)
end


local MissionRolexCmd = class("MissionRolexCmd", MissionCmd)
function MissionRolexCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
	self.name = "MissionRolexCmd:"..data.name
	self.rolextime = data.value
end

function MissionRolexCmd:_mission(_, _, msn)
	return string.format("+%d mins added to mission timeout",
		msn:addTime(self.rolextime)/60)
end


local MissionCheckinCmd = class("MissionCheckinCmd", MissionCmd)
function MissionCheckinCmd:__init(theater, data)
	self.name = "MissionCheckinCmd:"..data.name
	MissionCmd.__init(self, theater, data)
end

function MissionCheckinCmd:_mission(time, _, msn)
	msn:checkin(time)
	return string.format("on-station received")
end


local MissionCheckoutCmd = class("MissionCheckoutCmd", MissionCmd)
function MissionCheckoutCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
	self.name = "MissionCheckoutCmd:"..data.name
end

function MissionCheckoutCmd:_mission(time, _, msn)
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
	[enum.uiRequestType.SCRATCHPADGET]   = ScratchPadDisplay,
	[enum.uiRequestType.SCRATCHPADSET]   = ScratchPadSet,
	[enum.uiRequestType.CHECKPAYLOAD]    = CheckPayloadCmd,
	[enum.uiRequestType.MISSIONJOIN]     = MissionJoinCmd,
}

return cmds
