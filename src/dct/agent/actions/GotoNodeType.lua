--- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class = libs.classnamed
local agentutils = require("dct.agent.utils")
local WS = require("dct.agent.worldstate")
local aitasks = require("dct.ai.tasks")

local function is_desired_node(nodetype)
	local is_desired_fact = function(fact)
		return (fact.type == WS.Facts.factType.NODE and
			fact.objtype.value == nodetype and
			fact.position ~= nil)
	end
	return is_desired_fact
end

local GotoNodeType = class("GotoNodeType", WS.Action)
function GotoNodeType:__init(agent)
	local is_bit_set = dct.libs.utils.is_bit_set
	local assetType = dct.enum.assetType
	local precond = {}
	local effects = {
		WS.Property(WS.ID.ATNODETYPE, WS.Property.ANYHANDLE),
	}

	self.complete = WS.Action.Result.CONTINUE
	self.airroute = is_bit_set(assetType.AIR_UNIT, agent.type)

	if self.airroute == true then
		table.insert(precond, WS.Property(WS.ID.INAIR, true))
	end

	WS.Action.__init(self, agent, 3, precond, effects, 100)
end

function GotoNodeType.isSuitable(agent)
	return agent:getDescKey("speedMax") > 0
end

--- Check for the existence of a node of the specified type in the
-- agent's memory.
function GotoNodeType:checkProceduralPreconditions(goal)
	local filter_func = is_desired_node(goal:get(WS.ID.ATNODETYPE).value)
	-- TODO: check for a path
	return self.agent:hasFact(filter_func)
end

function GotoNodeType:enter()
	self.complete = WS.Action.Result.CONTINUE
	local plan = self.agent:getPlan()
	local nodetype = plan:getGoal():WS():get(WS.ID.ATNODETYPE).value

	-- find fact of highest confidence
	local fact = agentutils.find_best_fact(self.agent,
					       is_desired_node(nodetype),
					       agentutils.max_obj_confidence)
	if fact == nil then
		self.complete = WS.Action.Result.FAIL
		return
	end

	-- TODO: waypoint construction depends on if the agent is an
	--  aircraft, ground, or ship. This will need to be taken into
	--  account later.
	-- TODO: would use A* to find a path, for now go directly to point
	local wpt = aitasks.Waypoint(fact.position,
		aitasks.Waypoint.wpType.TURNING_POINT,
		aitasks.Waypoint.wpAction.TURNING_POINT,
		self.agent:getDescKey("cruisespeed"),
		self.__clsname)
	-- TODO: dynamically select an altitude approperate for the agent
	-- only need to set an altitude if the route is for an aircraft.
	-- If for other types of agents other waypoint constructors will
	-- need to be used.
	wpt:setAlt(7620, AI.Task.AltitudeType.BARO)
	local route = aitasks.Route(self.airroute, {wpt})

	self.agent:doTasksForeachGroup({
		aitasks.wraptask(route:raw()),
	})
	-- TODO: would set bingo, iff an aircraft agent
	self.agent:setDescKey("destination", fact)
	self.complete = WS.Action.Result.SUCCESS
end

function GotoNodeType:isComplete()
	return self.complete
end

return GotoNodeType
