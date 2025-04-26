-- SPDX-License-Identifier: LGPL-3.0

--- @classmod dct.assets.sensors.DebugSensor

local class   = require("libs.classnamed")
local json    = require("libs.json")
local Timer   = require("dct.libs.Timer")
local draw    = require("dct.ui.draw")
local WS      = require("dct.agent.worldstate")

local function debug_details(agent)
	local plan = agent:getPlan()
	local msg = agent:printDetail()

	if plan ~= nil then
		msg = msg.."\n  goal_ws: "..tostring(plan:getGoal():WS())
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
	self.mark = draw.Mark(tostring(self.agent),
			      self.agent:getDescKey("location"),
			      true)
end

function DebugSensor.isSuitable(agent)
	local d = agent:getDescKey("debug")
	return d ~= nil and tonumber(d) > 0
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

	self.mark:remove()
	self.mark.text = tostring(self.agent)
	self.mark.pos = self.agent:getDescKey("location")
	self.mark:draw()
	self.agent._logger:info(debug_details(self.agent))
	self.timer:reset()
	self.timer:start()
	return false
end

return DebugSensor
