-- SPDX-License-Identifier: LGPL-3.0

require("math")
require("libs")
local check = libs.check

local max = world.event.S_EVENT_MAX or 1000
local eventbase = math.ceil((max + 2000) / 1000) * 1000
local _event = {}

_event.ID = {
	["DCT_EVENT_INIT_COMPLETE"]  = eventbase + 1,
	["DCT_EVENT_DEAD"]           = eventbase + 2,
	["DCT_EVENT_OPERATIONAL"]    = eventbase + 3,
	["DCT_EVENT_IMPACT"]         = eventbase + 4,
	["DCT_EVENT_ADD_ASSET"]      = eventbase + 5,
	["DCT_EVENT_GOAL_COMPLETE"]  = eventbase + 6,
	["DCT_EVENT_MISSION_START"]  = eventbase + 7,
	["DCT_EVENT_MISSION_UPDATE"] = eventbase + 8,
	["DCT_EVENT_MISSION_DONE"]   = eventbase + 9,
	["DCT_EVENT_MISSION_JOIN"]   = eventbase + 10,
	["DCT_EVENT_MISSION_LEAVE"]  = eventbase + 11,
	["DCT_EVENT_PLAYER_KICK"]    = eventbase + 12,
	["DCT_EVENT_PLAYER_JOIN"]    = eventbase + 13,
	["DCT_EVENT_DEPARTURE"]      = eventbase + 14,
	["DCT_EVENT_AGENT_REQUEST"]  = eventbase + 15,
}

_event.build = {}

--- Build an init complete event.
-- Used to notify that the Theater's initilization is complete.
-- @tparam Theater theater the Theater object sending the event.
-- @return properly formatted event table
function _event.build.initcomplete(theater)
	local event = {}
	event.id = _event.ID.DCT_EVENT_INIT_COMPLETE
	event.initiator = theater
	return event
end

--- Build a dead event.
-- Used to notify the object, obj, is dead.
-- @param obj object sending the dead event.
-- @return properly formatted event table
function _event.build.dead(obj)
	check.table(obj)
	local event = {}
	event.id = _event.ID.DCT_EVENT_DEAD
	event.initiator = obj
	return event
end

--- Build an operational event.
-- Used to notify of an operational state change.
-- @field id of this event
-- @field initiator base sending the operational notification
-- @field state of the base, true == operational
function _event.build.operational(base, state)
	check.table(base)
	check.bool(state)
	local event = {}
	event.id = _event.ID.DCT_EVENT_OPERATIONAL
	event.initiator = base
	event.state = state
	return event
end

--- Build an impact event.
-- Used to notify of a weapon impact.
-- @field id of this event
-- @field initiator DCTWeapon class causing the impact
-- @field point impact point
function _event.build.impact(wpn)
	check.table(wpn)
	local event = {}
	event.id = _event.ID.DCT_EVENT_IMPACT
	event.initiator = wpn
	event.point = wpn:getImpactPoint()
	return event
end

--- Build an add asset event.
-- A new asset was added to the asset manager.
-- @field id of this event
-- @field initiator asset being added
function _event.build.addasset(asset)
	check.table(asset)
	local event = {}
	event.id = _event.ID.DCT_EVENT_ADD_ASSET
	event.initiator = asset
	return event
end

--- Goal event definition:
-- @field id of this event
-- @field initiator goal
function _event.build.goalComplete(goal)
	check.table(goal)
	local event = {}
	event.id = _event.ID.DCT_EVENT_GOAL_COMPLETE
	event.initiator = goal
	return event
end

-- Mission event definitions:
-- @field id of this event
-- @field initiator mission object
function _event.build.missionStart(msn)
	check.table(msn)
	local event = {}
	event.id = _event.ID.DCT_EVENT_MISSION_START
	event.initiator = msn
	return event
end

function _event.build.missionUpdate(msn)
	check.table(msn)
	local event = {}
	event.id = _event.ID.DCT_EVENT_MISSION_UPDATE
	event.initiator = msn
	return event
end

-- Mission event definitions:
-- @field id of this event
-- @field initiator mission object
-- @field result of the mission; success, abort, timeout
function _event.build.missionDone(msn, result)
	check.table(msn)
	check.number(result)
	local event = {}
	event.id = _event.ID.DCT_EVENT_MISSION_DONE
	event.initiator = msn
	event.result = result
	return event
end

--- Mission event definitions:
-- @field id of this event
-- @field initiator mission object
-- @field member that joined or left
function _event.build.missionJoin(msn, member)
	local event = {}
	event.id = _event.ID.DCT_EVENT_MISSION_JOIN
	event.initiator = msn
	event.member = member
	return event
end

function _event.build.missionLeave(msn, member)
	local event = {}
	event.id = _event.ID.DCT_EVENT_MISSION_LEAVE
	event.initiator = msn
	event.member = member
	return event
end

function _event.build.playerKick(code, sensor)
	local event = {}
	event.id = _event.ID.DCT_EVENT_PLAYER_KICK
	event.code = code
	event.psensor = sensor
	return event
end

function _event.build.playerJoin(name)
	local event = {}
	event.id = _event.ID.DCT_EVENT_PLAYER_JOIN
	event.unit = name
	return event
end

function _event.build.departure(agent, takeofftime)
	local event = {}
	event.id = _event.ID.DCT_EVENT_DEPARTURE
	event.agent = agent.name
	event.takeoff = takeofftime
	return event
end

--- Agent Request:
-- @field id of this event
-- @field initiator the agent that initiated the request, for player
--   agents they can receive requests they themselves have generated
--   to allow the actual player to modify the model
-- @field data request data, at minimum must be a table with a field of 'id'
function _event.build.agentRequest(agent, data)
	local event = {}
	event.id = _event.ID.DCT_EVENT_AGENT_REQUEST
	event.initiator = agent
	event.data = data
	return event
end

return _event
