-- SPDX-License-Identifier: LGPL-3.0

local Queue  = require("libs.containers.queue")
local WS     = require("dct.assets.worldstate")

local function maxorder(l, r)
	return l.score > r.score
end

local function score_goals(self)
	local scored = {}
	local score

	for _, goal in pairs(self.agent:goals()) do
		score = goal:relevance(self.agent)
		if score > 0 then
			table.insert(scored, {
				["score"] = score,
				["goal"]  = goal,
			})
		end
	end
	table.sort(scored, maxorder)
	return scored
end

local function list2queue(list)
	local p = Queue()

	for _, action in ipairs(list or {}) do
		p:pushtail(action)
	end
	return p
end

--- @classmod Planning
--  * score goals
--  * foreach goal in highest score order; do
--      plan = create_plan(goal)
--      if plan then
--        transition to doplan state
local Planning = require("libs.namedclass")("PlanningSensor", WS.Sensor)
function Planning:__init(agent)
	WS.Sensor.__init(self, agent, 30)
end

function Planning:update()
	if self.agent._plan then
		return false
	end

	for _, entry in ipairs(score_goals(self)) do
		local _, plan = WS.find_plan(self.agent:graph(),
					     self.agent:WS(),
					     entry.goal:WS(),
					     nil, nil, true)
		self.agent._logger:debug("goal: %s", tostring(entry.goal))
		if plan then
			self.agent._logger:debug("plan found for: %s",
				tostring(entry.goal))
			self.agent:setPlan(entry.goal, list2queue(plan))
			break
		end
	end
	return true
end

return Planning
