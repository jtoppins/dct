-- SPDX-License-Identifier: LGPL-3.0

local class       = require("libs.namedclass")
local dctenum     = require("dct.enum")
local dctutils    = require("dct.libs.utils")
local Timer       = require("dct.libs.Timer")
local DCTEvents   = require("dct.libs.DCTEvents")
local WS          = require("dct.assets.worldstate")
local UPDATE_TIME = 120

local capturable = {
	[dctenum.assetType.ARMYBASE] = true,
	[dctenum.assetType.AIRBASE]  = true,
	[dctenum.assetType.PORT]     = true,
	[dctenum.assetType.FARP]     = true,
}

--- @classmod AirbaseSensor
-- Represents an Airbase. Airbases can be captured and have various
-- squadrons stationed at the airbase.
local AirbaseSensor = class("AirbaseSensor", WS.Sensor, DCTEvents)
function AirbaseSensor:__init(agent)
	WS.Sensor.__init(self, agent, 50)
	DCTEvents.__init(self)

	self.timer = Timer(UPDATE_TIME)
	self.operational = false

	local handlers = {}

	if capturable[agent.type] == true then
		handlers[dctenum.event.DCT_EVENT_CAPTURED] =
			self.handleCapture
	end

	self:_overridehandlers(handlers)
end

function AirbaseSensor:isOperational()
	local damaged = self.agent:WS():get(WS.ID.DAMAGED).value

	return self.agent:isSpawned() and not self.agent:isDead() and
	       not damaged
end

function AirbaseSensor:notifyOperational()
	if self.agent:isDead() then
		return
	end

	local prev = self.operational

	self.operational = self:isOperational()
	if prev ~= self.operational then
		local ab = Airbase.getByName(self.agent.name)

		ab:setRadioSilentMode(not self.operational)
		self.agent:notify(
			dctutils.buildevent.operational(self.agent,
							self.operational))
		self.agent:replan()
	end
end

function AirbaseSensor:spawnPost()
	self.timer:reset()
	self.timer:start()
	self:notifyOperational()
end

function AirbaseSensor:despawnPost()
	self.timer:stop()
end

function AirbaseSensor:handleCapture(event)
	if event.target.name ~= self.agent.name then
		return
	end

	self.agent._logger:debug("captured - setting dead")
	self.agent:setDead(true)
end

function AirbaseSensor:handleRequestLand(event)
	-- TODO: aircraft can send a request to land, we should queue
	-- the request in the agent's memory
end

function AirbaseSensor:handleRequestDeparture(event)
	-- TODO: a squadron has requested to launch a flight,
	-- queue the request in the agent's memory
end

function AirbaseSensor:update()
	self.agent._logger:debug("jtoppins - airbasesensor.update")
	self.timer:update()
	if not self.timer:expired() then
		return false
	end

	self:notifyOperational()

	self.timer:reset()
	self.timer:start()
	return false
end

return AirbaseSensor
