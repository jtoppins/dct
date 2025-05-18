-- SPDX-License-Identifier: LGPL-3.0

--- utility functions relevant to agents.
-- @module dct.agent.utils

local vector = require("dct.libs.vector")
local WS = require("dct.agent.worldstate")
local utils = {}

--- Compare two facts' confidence levels and return the fact with the
-- highest confidence.
function utils.max_obj_confidence(factA, factB)
	if factA == nil then
		return factB
	elseif factB == nil then
		return factA
	end

	if factA.object.confidence > factB.object.confidence then
		return factA
	end
	return factB
end

--- Find the best fact the agent has in memory.
-- @tparam Agent agent reference
-- @tparam function filter function pointer conforming to the signature
--   required by iterateFacts.
-- @tparam function compare optional compare function which follows the
--   signature `newbest compare(bestsofar, newobj)`. The default is to
--   use math.max.
-- @return best fact or nil if no facts found
function utils.find_best_fact(agent, filter, compare)
	compare = compare or math.max
	local best = nil

	for _, fact in agent:iterateFacts(filter) do
		best = compare(best, fact)
	end
	return best
end

--- Test if the fact provided is a homebase Node fact.
function utils.is_homebase_fact(fact)
	return fact.type == WS.Facts.factType.NODE and
	       fact.objtype.value == WS.Facts.Node.nodeType.HOMEBASE
end

--- Calculate the bingo fuel state of the agent as a percentage of
-- its maximum internal fuel.
-- @tparam Agent agent we are interested in
-- @tparam Vector2D curpos place to calculate the fuel requirement from
-- @treturn number percent of internal fuel required to return home
function utils.fuel_bingo(agent, curpos)
	local bingomass = agent:getDescKey("reservefuel")
	local cruisespeed = agent:getDescKey("cruisespeed")
	local actype = next(agent:getDescKey("unitTypeCnt"))
	local acdesc = Unit.getDescByName(actype)
	local p = curpos
	local dist = 0
	local facts = {}

	for _, fact in agent:iterateFacts(utils.is_homebase_fact) do
		table.insert(facts, fact)
	end
	table.sort(facts, utils.max_obj_confidence)

	-- only consider the top two homebase facts
	local i = 1
	while i <= #facts and i <= 2 do
		local fact = facts[i]
		dist = dist + vector.distance(p, fact.position)
		p = fact.position
		i = i + 1
	end
	bingomass = bingomass + ((0.8 * acdesc.Kmax) * (dist / cruisespeed))
	return bingomass / acdesc.fuelMassMax
end

-- A homebase fact will have
-- @field object = airbase name
-- @field objtype = node type
-- @field path = [optional] path to node
-- @field position = last known location of the airbase
-- @field abdata = local cached airbase data
function utils.build_homebase_fact(airbase, priority)
	local ab = Airbase.getByName(airbase)
	local fact = WS.Facts.Node(airbase, priority,
				   WS.Facts.Node.nodeType.HOMEBASE)
	fact.position = vector.Vector3D(ab:getPoint())
	fact.abdata = {}
	fact.abdata.abid = ab:getID()

	if ab:getUnit() then
		fact.abdata.unitid = ab:getUnit():getID()
	end
	return fact
end

return utils
