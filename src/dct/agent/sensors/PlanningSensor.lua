-- SPDX-License-Identifier: LGPL-3.0

local Queue  = require("libs.containers.queue")
local Timer  = require("dct.libs.Timer")
local WS     = require("dct.agent.worldstate")
local UPDATE_TIME = 180

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
local Planning = require("libs.classnamed")("PlanningSensor", WS.Sensor)
function Planning:__init(agent)
	WS.Sensor.__init(self, agent, 70)
	self.timer = Timer(UPDATE_TIME)
end

function Planning.isSuitable()
	return true
end

function Planning:spawnPost()
	self.timer:reset()
	self.timer:start()
end

function Planning:despawnPost()
	self.timer:stop()
end

function Planning:update()
	self.timer:update()
	local plan = self.agent:getPlan()

	if plan ~= nil and self.timer:expired() == false then
		return false
	end

	self.timer:reset()
	self.timer:start()
	for _, entry in ipairs(score_goals(self)) do
		local _, actions = WS.find_plan(self.agent:graph(),
					     self.agent:WS(),
					     entry.goal:WS(),
					     nil, nil, true)
		if actions then
			if plan ~= nil and plan.goal == entry.goal then
				-- the current goal is still the best goal
				-- stick with the current plan
				break
			end

			self.agent:replan()
			self.agent:setPlan(WS.Plan(list2queue(actions),
						   entry.goal))
			break
		end
	end
	return true
end

return Planning
