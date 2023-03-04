-- SPDX-License-Identifier: LGPL-3.0

--- @classmod dct.libs.Mission
-- Represents a series of goals to be completed.

local class      = require("libs.namedclass")
local utils      = require("libs.utils")
local dctenum    = require("dct.enum")
local dctutils   = require("dct.libs.utils")
local Observable = require("dct.libs.Observable")
local DCTEvents  = require("dct.libs.DCTEvents")
local Subordinates = require("dct.libs.Subordinates")
local Memory     = require("dct.libs.Memory")

local missionmt = {}
function missionmt.__tostring(tbl)
	return tbl.__clsname or "__unknown__"
end

--- Mission class definition. The following members are part of a class
-- instance.
-- @field cmdr reference to controlling commander
-- @field id ID of the mission
-- @field goalq queue of mission WS.Goal objects
-- @field facts set of facts (intel and targets) that will be passed
--  to agents that get assigned to the mission
-- @field _playable controls if a player can be assigned to this mission
-- @field _assigned list of Agents assigned to this Mission
-- @field _assignedcnt total number of Agents assigned to this Mission
-- @field _timer timeout timer
local Mission = utils.override_ops(class("Mission", Observable, DCTEvents,
				Subordinates, Memory), missionmt)
function Mission:__init(msntype, cmdr, goalq, timer)
	Observable.__init(self)
	DCTEvents.__init(self)
	Subordinates.__init(self)
	Memory.__init(self)
	self.cmdr         = cmdr
	self.goalq        = goalq
	self.id           = cmdr:missionNextID()
	self.type         = msntype
	self._playable    = false
	self._assigned    = {}
	self._assignedcnt = 0
	self._timer       = timer

	self:_overridehandlers({
		[dctenum.event.DCT_EVENT_GOAL_COMPLETE] =
			self.eventGoalComplete,
	})

	if goalq then
		local g = goalq:peekhead()

		if g then
			g:addObserver(self.onDCTEvent, self, string.format(
			"Misison(%s).onDCTEvent", self.__clsname))
		end
	end

	self.typeData = nil
	self.factFilter = nil
	self.factPrefix = nil
end

--- typeData provides human readable mission information for all air
-- missions.
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

--- factPrefix is the fact key prefix used when adding mission facts
-- to a participating agent.
Mission.factPrefix = "mission_intel"

--- Determines if the given fact is a mission fact. This function can
-- be used in various functions defined in dct.libs.Memory.
--
-- @param key the fact key from the agent
function Mission.factTest(key)
	if string.match(key, Mission.factPrefix) ~= nil then
		return true
	end
	return false
end

--- event handler used when one of the mission's goals is completed
function Mission:eventGoalComplete(_--[[event]])
	local g = self.goalq:pophead()

	g:removeObserver(self)
	g = self.goalq:peekhead()

	if g == nil then
		self:notify(dctutils.buildevent.missionDone(self,
			dctenum.missionResult.SUCCESS))
		return
	end

	g:addObserver(self.onDCTEvent, self, string.format(
		      "Misison(%s).onDCTEvent", self.__clsname))
	self:notify(dctutils.buildevent.missionUpdate(self))
end

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
function Mission:goal(_ --[[agent]])
	return self.goalq:peekhead()
end

--- Aborts a mission for all observers of the mission.
function Mission:abort()
	self:notify(dctutils.buildevent.missionDone(self,
		dctenum.missionResult.ABORT))
end

--- Get any timer assigned to the mission.
function Mission:getTimer()
	return self._timer
end

--- Set mission timeout timer.
function Mission:setTimer(timer)
	self._timer = timer
end

--- Is this mission playable by players.
function Mission:isPlayable()
	return self._playable
end

--- Interate over Agents assigned to this mission
--
-- @return an iterator to be used in a for loop where key is
--  Agent.name and value is the order in which the agent was
--  assigned to the mission
function Mission:iterateAssigned()
	return next, self._assigned, nil
end

--- Tests if a given agent is assigned to this mission.
--
-- @param agent reference to agent to test
function Mission:isAssigned(agent)
	return self._assigned[agent.name] ~= nil
end

--- Assign a new Agent to the Mission
--
-- @param agent to assign to this Mission
function Mission:assign(agent)
	self:notify(dctutils.buildevent.missionJoin(self, agent))
	self._assignedcnt = self._assignedcnt + 1
	self:addObserver(agent.onDCTEvent, agent, agent.name)
	self._assigned[agent.name] = self._assignedcnt
	agent:setMission(self)

	local intel = 0
	for _, fact in self:iterateFacts() do
		agent:setFact(Mission.factPrefix..intel, fact)
		intel = intel + 1
	end
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
	agent:deleteFacts(Mission.factTest)

	-- abort the mission once no one is assigned
	if self._assignedcnt <= 0 then
		self:abort()
	else
		self:notify(dctutils.buildevent.missionLeave(self, agent))
	end
end

--- Update function which is periodically run
function Mission:update()
	if self._timer == nil then
		return
	end

	self._timer:update()
	if self._timer:expired() then
		self:notify(dctutils.buildevent.missionDone(self,
			dctenum.missionResult.TIMEOUT))
	end
end

return Mission
