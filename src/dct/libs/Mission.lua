-- SPDX-License-Identifier: LGPL-3.0

--- @classmod dct.libs.Mission
-- Represents a series of goals to be completed.

local class      = require("libs.namedclass")
local utils      = require("libs.utils")
local check      = require("libs.check")
local dctenum    = require("dct.enum")
local dctutils   = require("dct.libs.utils")
local Observable = require("dct.libs.Observable")
local DCTEvents  = require("dct.libs.DCTEvents")
local Memory     = require("dct.libs.Memory")
local WS         = require("dct.assets.worldstate")

local missionResult = {
	["ABORT"]   = 0,
	["TIMEOUT"] = 1,
	["SUCCESS"] = 2,
}

local missiondata = {
	[dctenum.missionType.INVALID] = {
		["name"]        = "invalid",
		["short"]       = "invalid",
	},
	[dctenum.missionType.MOVETO] = {
		["name"]        = "moveto",
		["short"]       = "moveto",
	},
	[dctenum.missionType.GUARD] = {
		["name"]        = "guard",
		["short"]       = "guard",
	},
	[dctenum.missionType.JTAC] = {
		["name"]        = "jtac",
		["short"]       = "jtac",
		["mType"]       = dctenum.missionType.GUARD,
	},
	[dctenum.missionType.AFAC] = {
		["name"]        = "Airborne Forward Air Controller",
		["short"]       = "AFAC",
		["mType"]       = dctenum.missionType.GUARD,
		["codeType"]    = 5,
		["codeSubType"] = 3,
	},
	[dctenum.missionType.CAS] = {
		["name"]        = "Close Air Support",
		["short"]       = "CAS",
		["mType"]       = dctenum.missionType.GUARD,
		["codeType"]    = 5,
		["codeSubType"] = 3,
	},
	[dctenum.missionType.CAP] = {
		["name"]        = "Combat Air Patrol",
		["short"]       = "CAP",
		["mType"]       = dctenum.missionType.GUARD,
		["codeType"]    = 2,
		["codeSubType"] = 0,
	},
	[dctenum.missionType.TANKER] = {
		["name"]        = "Refueling Tanker",
		["short"]       = "TKR",
		["mType"]       = dctenum.missionType.GUARD,
		["codeType"]    = 0,
		["codeSubType"] = 0,
	},
	[dctenum.missionType.AWACS] = {
		["name"]        = "Airborne Warning And Control",
		["short"]       = "AWACS",
		["mType"]       = dctenum.missionType.GUARD,
		["codeType"]    = 0,
		["codeSubType"] = 0,
	},
	[dctenum.missionType.ATTACK] = {
		["name"]        = "attack",
		["short"]       = "attack",
	},
	[dctenum.missionType.STRIKE] = {
		["name"]        = "Precision Strike",
		["short"]       = "STRIKE",
		["mType"]       = dctenum.missionType.ATTACK,
		["codeType"]    = 5,
		["codeSubType"] = 0,
	},
	[dctenum.missionType.BAI] = {
		["name"]        = "Interdiction",
		["short"]       = "IA",
		["mType"]       = dctenum.missionType.ATTACK,
		["codeType"]    = 5,
		["codeSubType"] = 1,
	},
	[dctenum.missionType.OCA] = {
		["name"]        = "Offensive Counter Air",
		["short"]       = "OCA",
		["mType"]       = dctenum.missionType.ATTACK,
		["codeType"]    = 5,
		["codeSubType"] = 0,
	},
	[dctenum.missionType.ANTISHIP] = {
		["name"]        = "Anti-Shipping",
		["short"]       = "SHP",
		["mType"]       = dctenum.missionType.ATTACK,
		["codeType"]    = 5,
	},
	[dctenum.missionType.DEAD] = {
		["name"]        = "Destruction of Enemy Air Defense",
		["short"]       = "DEAD",
		["mType"]       = dctenum.missionType.ATTACK,
		["codeType"]    = 5,
	},
	[dctenum.missionType.SWEEP] = {
		["name"]        = "Fighter Sweep",
		["short"]       = "SWP",
		["mType"]       = dctenum.missionType.ATTACK,
		["codeType"]    = 5,
		["codeSubType"] = 0,
	},
	[dctenum.missionType.AREASTRIKE] = {
		["name"]        = "Area Bombing",
		["short"]       = "AREA",
		["mType"]       = dctenum.missionType.ATTACK,
		["codeType"]    = 5,
		["codeSubType"] = 0,
	},
	[dctenum.missionType.SEARCH] = {
		["name"]        = "search",
		["short"]       = "search",
	},
	[dctenum.missionType.RECON] = {
		["name"]        = "Recon",
		["short"]       = "RCN",
		["mType"]       = dctenum.missionType.SEARCH,
		["codeType"]    = 0,
		["codeSubType"] = 0,
	},
	[dctenum.missionType.INTERCEPT] = {
		["name"]        = "Air Intercept",
		["short"]       = "ITC",
		["mType"]       = dctenum.missionType.SEARCH,
		["codeType"]    = 2,
		["codeSubType"] = 1,
	},
	[dctenum.missionType.ESCORT] = {
		["name"]        = "escort",
		["short"]       = "escort",
	},
	[dctenum.missionType.SEAD] = {
		["name"]        = "Suppression of Enemy Air Defense",
		["short"]       = "SEAD",
		["mType"]       = dctenum.missionType.ESCORT,
		["codeType"]    = 3,
	},
	[dctenum.missionType.FIGHTERCOVER] = {
		["name"]        = "Fighter Escort",
		["short"]       = "ESC",
		["codeType"]    = 5,
		["codeSubType"] = 0,
	},
	[dctenum.missionType.TRANSPORT] = {
		["name"]        = "transport",
		["short"]       = "transport",
	},
	[dctenum.missionType.CSAR] = {
		["name"]        = "Combat Search and Rescue",
		["short"]       = "CSAR",
		["mType"]       = dctenum.missionType.TRANSPORT,
		["codeType"]    = 5,
		["codeSubType"] = 2,
	},
	[dctenum.missionType.RESUPPLY] = {
		["name"]        = "Resupply",
		["short"]       = "RES",
		["mType"]       = dctenum.missionType.TRANSPORT,
		["codeType"]    = 0,
		["codeSubType"] = 0,
	},
}

for k, v in pairs(dctenum.missionType) do
	assert(missiondata[v] ~= nil, "missiondata missing type entry: "..k)
end

local function is_character_fact(fact)
	return fact.type == WS.Facts.factType.CHARACTER
end

local function check_desc(desc)
	if desc == nil then
		return nil
	end

	local default_values = {
		description = "No mission description available.",
	}

	check.table(desc.location)
	for k, v in pairs(default_values) do
		if desc[k] == nil then
			desc[k] = v
		end
	end

	return desc
end

local missionmt = {}
function missionmt.__tostring(msn)
	local msg

	if missiondata[msn.type] then
		local d = msn:getDescKey("target_short_desc")
		msg = missiondata[msn.type].short

		if d then
			msg = msg..string.format(" (%s)", d)
		end
	else
		msg = msn.__clsname or "_unknown_"
	end
	return msg
end

--- Mission class definition. The following members are part of a class
-- instance.
-- @field cmdr reference to controlling commander
-- @field id ID of the mission
-- @field goalq queue of mission WS.Goal objects
-- @field desc description table of the mission. The description table holds
--  metadata used mainly by Player agents to provide human readiable data
--  about the mission.
-- @field facts set of facts (intel and targets) that will be passed
--  to agents that get assigned to the mission
-- @field _playable controls if a player can be assigned to this mission
-- @field _assigned list of Agents assigned to this Mission
-- @field _assignedcnt total number of Agents assigned to this Mission
-- @field _timer timeout timer
local Mission = utils.override_ops(class("Mission", Observable, DCTEvents,
				Memory), missionmt)

--- Mission constructor.
-- @param msntype the type of mission the object represents,
--          enum.missionType
-- @param cmdr reference to controlling commander
-- @param goalq queue of mission WS.Goal objects
-- @param desc [optional] description table of the mission
-- @param timer [optional] timeout timer
function Mission:__init(msntype, cmdr, desc, goalq, timer)
	Observable.__init(self)
	DCTEvents.__init(self)
	Memory.__init(self)
	self.cmdr         = cmdr
	self.goalq        = goalq
	self.id           = cmdr:missionNextID()
	self.type         = check.tblkey(msntype, dctenum.missionType,
				"enum.missionType")
	self.desc         = check_desc(desc)
	self._playable    = (desc ~= nil)
	self._assigned    = {}
	self._assignedcnt = 0
	self._suptmsns    = {}
	self._parent      = nil
	self._timer       = timer

	setmetatable(self._suptmsns, { __mode = "k", })
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
	self.typeResult = nil
	self.factFilter = nil
	self.factPrefix = nil
end

--- typeData provides human readable mission information for all air
-- missions.
Mission.typeData = missiondata
Mission.typeResult = missionResult

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

--- Get the entry defined by key in the description table for this Mission.
-- If the key doesn't exist nil will be returned.
--
-- @return value in the Mission's desc table nil will be returned if the
-- key doesn't exist
function Mission:getDescKey(key)
	return self.desc[key]
end

--- Set a description table entry in the Mission's description table.
function Mission:setDescKey(key, val)
	self.desc[key] = val
end

--- Set parent mission
function Mission:setParent(msn)
	self._parent = msn
end

--- Get parent mission
function Mission:getParent()
	return self._parent
end

--- Add msn as a child/support mission to this Mission
function Mission:addChild(msn)
	assert(msn ~= nil, "value error: 'obj' must not be nil")
	self._suptmsns[msn] = true
	msn:setParent(self)
end

--- Remove msn as a child of this Mission
function Mission:removeChild(msn)
	self._suptmsns[msn] = nil

	if msn:getParent() == self then
		msn:setParent(nil)
	end
end

--- Iterate over all child missions
function Mission:iterateChildren()
	return next, self._suptmsns, nil
end

--- event handler used when one of the mission's goals is completed
function Mission:eventGoalComplete(--[[event]])
	local g = self.goalq:pophead()

	g:removeObserver(self)
	g = self.goalq:peekhead()

	if g == nil then
		self:notify(dctutils.buildevent.missionDone(self,
			missionResult.SUCCESS))
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
function Mission:getID()
	return self.id
end

--- get the current Mission goal
--
-- @return the current Mission WS.Goal
function Mission:goal(--[[agent]])
	if self.goalq == nil then
		return nil
	end
	return self.goalq:peekhead()
end

--- Aborts a mission for all observers of the mission.
function Mission:abort()
	self:notify(dctutils.buildevent.missionDone(self,
		missionResult.ABORT))
end

--- Get any timer assigned to the mission.
function Mission:getTimer()
	return self._timer
end

--- Set mission timeout timer.
function Mission:setTimer(timer)
	self._timer = timer
end

--- Set playable state. Generally only used by mission constructors.
function Mission:_setPlayable(state)
	self._playable = state
end

--- Is this mission playable by players.
function Mission:isPlayable()
	return self._playable
end

--- Tests if this mission is assigned to any agent.
function Mission:isAssigned()
	return next(self._assigned) ~= nil
end

--- Tests if a given agent is assigned to this mission.
--
-- @param agent reference to agent to test
function Mission:isMember(agent)
	return self._assigned[agent.name] ~= nil
end

--- Iterate over Agents assigned to this mission
--
-- @return an iterator to be used in a for loop where key is
--  Agent.name and value is the order in which the agent was
--  assigned to the mission
function Mission:iterateAssigned()
	return next, self._assigned, nil
end

--- Copy character facts in the mission to the agent.
-- That way each agent only needs to be concerned with what
-- it knows about concerning threats.
--
-- @param agent to copy the facts to
function Mission:copyFacts(agent)
	local intel = 0
	for _, fact in self:iterateFacts(is_character_fact) do
		agent:setFact(Mission.factPrefix..intel, fact)
		intel = intel + 1
	end
end

--- Assign a new Agent to the Mission
--
-- @param agent to assign to this Mission
function Mission:assign(agent)
	self._assignedcnt = self._assignedcnt + 1
	self:addObserver(agent.onDCTEvent, agent, agent.name)
	self._assigned[agent.name] = self._assignedcnt
	self:copyFacts(agent)
	self:notify(dctutils.buildevent.missionJoin(self, agent))
end

--- Remove Agent from this Mission
--
-- @param agent to remove
function Mission:remove(agent)
	if self._assigned[agent.name] == nil then
		return
	end

	self:notify(dctutils.buildevent.missionLeave(self, agent))
	self:removeObserver(agent)
	self._assigned[agent.name] = nil
	self._assignedcnt = self._assignedcnt - 1
	agent:deleteFacts(Mission.factTest)

	-- abort the mission once no one is assigned
	if self._assignedcnt <= 0 then
		self:abort()
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
			missionResult.TIMEOUT))
	end
end

return Mission
