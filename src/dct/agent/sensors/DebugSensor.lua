-- SPDX-License-Identifier: LGPL-3.0

--- @classmod dct.assets.sensors.DebugSensor

local class   = require("libs.classnamed")
local json    = require("libs.json")
local Timer   = require("dct.libs.Timer")
local human   = require("dct.ui.human")
local WS      = require("dct.agent.worldstate")

local function debug_details(agent)
	local goal = agent:getGoal()
	local msg = tostring(agent).."\n  mission: "..
		    tostring(agent:getMission())

	if goal then
		msg = msg.."\n  goal_ws: "..tostring(goal:WS())
	end

	msg = msg.."\n  agent_ws: "..tostring(agent:WS())
	msg = msg.."\n  facts: "..json:encode_pretty(agent.memory)

	return msg
end

--- Debug sensor that displays various data about the Agent.
local DebugSensor = class("DebugSensor", WS.Sensor)
function DebugSensor:__init(agent)
	WS.Sensor.__init(self, agent, 100)

	local updatetime = agent:getDescKey("debug")
	if updatetime == nil or updatetime <= 0 then
		return
	end

	-- limit timer to have a minimum timeout of 30 seconds
	self.timer  = Timer(math.max(updatetime, 30))
	self.markid = human.getMarkID()
end

function DebugSensor:spawnPost()
	if self.timer then
		self.timer:reset()
		self.timer:start()
	end
end

function DebugSensor:despawnPost()
	if self.timer then
		self.timer:stop()
	end
end

function DebugSensor:update()
	if self.timer == nil then
		return
	end

	self.timer:update()
	if not self.timer:expired() then
		return false
	end

	trigger.action.removeMark(self.markid)
	trigger.action.markToAll(self.markid, tostring(self.agent),
				 self.agent:getDescKey("location"))
	self.agent._logger:info(debug_details(self.agent))
	self.timer:reset()
	self.timer:start()
	return false
end

return DebugSensor
