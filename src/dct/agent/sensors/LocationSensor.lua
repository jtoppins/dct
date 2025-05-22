-- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class        = libs.classnamed
local Timer        = require("dct.libs.Timer")
local WS           = require("dct.agent.worldstate")

--- @classmod LocationSensor
-- Simple sensor that updates the location of the agent based on the first
-- unit in the group.
local LocationSensor = class("LocationSensor", WS.Sensor)
function LocationSensor:__init(agent)
	WS.Sensor.__init(self, agent, 15)
	local update_time = 60
	local is_bit_set = dct.libs.utils.is_bit_set
	local assetType = dct.enum.assetType

	if is_bit_set(assetType.AIR_UNIT, agent.type) then
		update_time = 10
	end

	self.timer = Timer(update_time)
end

function LocationSensor.isSuitable(agent)
	return agent:getDescKey("speedMax") > 0
end

function LocationSensor:update()
	self.timer:update()
	if not self.timer:expired() then
		return false
	end

	self.agent:updateLocation()
	self.timer:reset()
	self.timer:start()
	return false
end

function LocationSensor:spawn()
	self.timer:reset()
	self.timer:start()
end

function LocationSensor:despawn()
	self.timer:stop()
end

return LocationSensor
