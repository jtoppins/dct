--- SPDX-License-Identifier: LGPL-3.0

local class      = require("libs.namedclass")
local dctenum    = require("dct.enum")
local dctutils   = require("dct.libs.utils")
local Timer      = require("dct.libs.Timer")
local Observable = require("dct.libs.Observable")
local DCTEvents  = require("dct.libs.DCTEvents")

local function goal_complete(msn, _ --[[event]])
	msn.goalq:pophead()
	if msn:goal() == nil then
		msn:notify(dctutils.buildevent.missionDone(msn,
			dctenum.missionResult.SUCCESS))
		return
	end
	msn:notify(dctutils.buildevent.missionUpdate(msn))
end

--- @class Mission
-- Represents a series of goals to be completed.
--
-- @cmdr reference to controlling commander
-- @type type of mission
-- @goalq queue of mission WS.Goal objects
-- @iffcodes base set of IFF codes used for this mission
-- @id ID of the mission
-- @facts set of facts (intel and targets) that will be passed to agents
--        that get assigned to the mission
-- @_assigned list of Agents assigned to this Mission
-- @_assignedcnt total number of Agents assigned to this Mission
-- @_timer timeout timer
local Mission = class("Mission", Observable, DCTEvents)
function Mission:__init(cmdr, missiontype, goalq, timeout)
	Observable.__init(self)
	DCTEvents.__init(self)
	self.cmdr         = cmdr
	self.type         = missiontype
	self.goalq        = goalq
	self.iffcodes     = cmdr:genMissionCodes(missiontype)
	self.id           = self.iffcodes.id
	self.facts        = {}
	self._assigned    = {}
	self._assignedcnt = 0
	self._timer       = Timer(timeout, timer.getAbsTime)

	self:_overridehandlers({
		[dctenum.event.DCT_EVENT_GOAL_COMPLETE] = goal_complete,
	})
	for _, g in self.goalq:iterate() do
		g:addObserver(self.onDCTEvent, self, string.format(
			"Misison(%s).onDCTEvent", self.__clsname))
	end

	self.typeData = nil
end

Mission.typeData = {
	[dctenum.missionType.CAS] = {
		["name"]        = "Close Air Support",
		["short"]       = "CAS",
		["symbol"]      = "B",
		["mType"]       = dctenum.missionType.GUARD,
		["codeType"]    = 5,
		["codeSubType"] = 3,
	},
	[dctenum.missionType.CAP] = {
		["name"]        = "Combat Air Patrol",
		["short"]       = "CAP",
		["symbol"]      = "A",
		["mType"]       = dctenum.missionType.GUARD,
		["codeType"]    = 2,
		["codeSubType"] = 0,
	},
	[dctenum.missionType.SEAD] = {
		["name"]        = "Suppression of Enemy Air Defense",
		["short"]       = "SEAD",
		["symbol"]      = "A",
		["mType"]       = dctenum.missionType.GUARD,
		["codeType"]    = 3,
	},
	[dctenum.missionType.TANKER] = {
		["name"]        = "Refueling Tanker",
		["short"]       = "TKR",
		["symbol"]      = "C",
		["mType"]       = dctenum.missionType.GUARD,
		["codeType"]    = 0,
		["codeSubType"] = 0,
	},
	[dctenum.missionType.STRIKE] = {
		["name"]        = "Precision Strike",
		["short"]       = "STRIKE",
		["symbol"]      = "B",
		["mType"]       = dctenum.missionType.ATTACK,
		["codeType"]    = 5,
		["codeSubType"] = 0,
	},
	[dctenum.missionType.BAI] = {
		["name"]        = "Interdiction",
		["short"]       = "IA",
		["symbol"]      = "B",
		["mType"]       = dctenum.missionType.ATTACK,
		["codeType"]    = 5,
		["codeSubType"] = 1,
	},
	[dctenum.missionType.OCA] = {
		["name"]        = "Offensive Counter Air",
		["short"]       = "OCA",
		["symbol"]      = "B",
		["mType"]       = dctenum.missionType.ATTACK,
		["codeType"]    = 5,
		["codeSubType"] = 0,
	},
	[dctenum.missionType.ANTISHIP] = {
		["name"]        = "Anti-Shipping",
		["short"]       = "SHP",
		["symbol"]      = "B",
		["mType"]       = dctenum.missionType.ATTACK,
		["codeType"]    = 5,
	},
	[dctenum.missionType.DEAD] = {
		["name"]        = "Destruction of Enemy Air Defense",
		["short"]       = "DEAD",
		["symbol"]      = "B",
		["mType"]       = dctenum.missionType.ATTACK,
		["codeType"]    = 5,
	},
	[dctenum.missionType.TRANSPORT] = {
		["name"]        = "Air Transport",
		["short"]       = "TRANS",
		["symbol"]      = "C",
		["mType"]       = dctenum.missionType.TRANSPORT,
		["codeType"]    = 0,
		["codeSubType"] = 0,
	},
	[dctenum.missionType.CSAR] = {
		["name"]        = "Combat Search and Rescue",
		["short"]       = "CSAR",
		["symbol"]      = "A",
		["mType"]       = dctenum.missionType.TRANSPORT,
		["codeType"]    = 5,
		["codeSubType"] = 2,
	},
	[dctenum.missionType.RESUPPLY] = {
		["name"]        = "Resupply",
		["short"]       = "RES",
		["symbol"]      = "C",
		["mType"]       = dctenum.missionType.TRANSPORT,
		["codeType"]    = 0,
		["codeSubType"] = 0,
	},
	[dctenum.missionType.RECON] = {
		["name"]        = "Recon",
		["short"]       = "RCN",
		["symbol"]      = "B",
		["mType"]       = dctenum.missionType.INVESTIGATE,
		["codeType"]    = 0,
		["codeSubType"] = 0,
	},
	[dctenum.missionType.INTERCEPT] = {
		["name"]        = "Air Intercept",
		["short"]       = "ITC",
		["symbol"]      = "A",
		["mType"]       = dctenum.missionType.INVESTIGATE,
		["codeType"]    = 2,
		["codeSubType"] = 1,
	},
	[dctenum.missionType.ESCORT] = {
		["name"]        = "Escort",
		["short"]       = "ESC",
		["symbol"]      = "B",
		["mType"]       = dctenum.missionType.ESCORT,
		["codeType"]    = 5,
		["codeSubType"] = 0,
	},
}

--- remove any references or return any targets that may have been
-- assigned back to the commander before the Misison object is destroyed.
function Mission:destroy()
end

--- return the ID of the Mission
--
-- @return mission ID
function Mission:ID()
	return self.id
end

--- get the current Mission goal
--
-- @return the current Mission WS.Goal
function Mission:goal()
	return self.goalq:peekhead()
end

--- determines if the Mission is currently active
--
-- @return bool true if Mission is active/started
function Mission:active()
	return self._timer:started()
end

--- Start the Mission timer
function Mission:start()
	if self._timer:started() then
		return
	end
	self._timer:start()
	self:notify(dctutils.buildevent.missionStart(self))
end

--- Aborts a mission for all observers of the mission.
function Mission:abort()
	self:notify(dctutils.buildevent.missionDone(self,
		dctenum.missionResult.ABORT))
end

--- return the time at which this Mission will expire
--
-- @return time at which the Mission will expire
function Mission:getTimeout()
	local remain, ctime = self.timer:remain()
	return ctime + remain
end

--- add time in seconds the Mission should be extended by
--
-- @param time seconds to extend the Mission by
-- @return amount of time the mission was extended by
function Mission:addTime(time)
	self._timer:extend(time)
	return time
end

--- get the IFF code for the given Agent
--
-- @agent the Agent to look up the IFF codes for
-- @return the Agent's assigned IFF codes
function Mission:getIFFCodes(agent)
	if agent == nil then
		return nil
	end
	return self._assigned[agent.name]
end

--- return the table of assigned Agent names
--
-- @return table of Agent names where key is Agent.name and value is the
--         Agent's IFF code
function Mission:getAssigned()
	return self._assigned
end

--- Assign a new Agent to the Mission
--
-- @param agent to assign to this Mission
function Mission:add(agent)
	self:notify(dctutils.buildevent.missionJoin(self, agent))
	self._assignedcnt = self._assignedcnt + 1
	self:addObserver(agent.onDCTEvent, agent, agent.name)
	local cnt = self._assignedcnt % 8
	local m1 = string.format("%o", self.iffcodes.m1)
	local m3 = string.format("%o", self.iffcodes.m3 + cnt)
	self._assigned[agent.name] = { ["m1"] = m1, ["m3"] = m3 }
	agent:setMission(self)

	-- TODO: add all mission facts to agent and for target(s)
	-- add the agent as an observer for the target.
end

--- Remove Agent from this Mission
--
-- @param agent to remove
function Mission:remove(agent)
	if self._assigned[agent.name] == nil then
		return
	end
	self:removeObserver(agent)
	self._assigned[agent.name] = nil
	self._assignedcnt = self._assignedcnt - 1

	-- TODO: remove all mission facts from the agent and for target(s)
	-- remove the agent as an observer for those targets.

	-- abort the mission once no one is assigned
	if self._assignedcnt <= 0 then
		self:abort()
	else
		self:notify(dctutils.buildevent.missionLeave(self, agent))
	end
end

--- Update function which is periodically run
function Mission:update()
	self._timer:update()
	if self._timer:expired() then
		self:notify(dctutils.buildevent.missionDone(self,
			dctenum.missionResult.TIMEOUT))
	end
end

return Mission
