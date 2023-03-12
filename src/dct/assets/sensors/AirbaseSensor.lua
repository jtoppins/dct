-- SPDX-License-Identifier: LGPL-3.0

local class       = require("libs.namedclass")
local dctenum     = require("dct.enum")
local dctutils    = require("dct.libs.utils")
local Timer       = require("dct.libs.Timer")
local DCTEvents   = require("dct.libs.DCTEvents")
local WS          = require("dct.assets.worldstate")
local aitasks     = require("dct.ai.tasks")
local UPDATE_TIME = 60
local NAVAID_REFRESH = 5

--- @classmod AirbaseSensor
-- Represents an Airbase. Airbases can be captured and have various
-- squadrons stationed at the airbase.
local AirbaseSensor = class("AirbaseSensor", WS.Sensor, DCTEvents)
function AirbaseSensor:__init(agent)
	WS.Sensor.__init(self, agent, 50)
	DCTEvents.__init(self)
	self.timer = Timer(UPDATE_TIME)

	local handlers = {}

	if AirbaseSensor.capturable[self.agent.type] == true then
		handlers[dctenum.event.DCT_EVENT_CAPTURED] =
			self.handleCapture
	end

	self:_overridehandlers(handlers)
	self.capturable = nil
	self.linkmap = nil
end

AirbaseSensor.capturable = {
	[dctenum.assetType.AIRBASE]  = true,
	[dctenum.assetType.FARP]     = true,
}

AirbaseSensor.linkmap = {
	[dctenum.assetType.AIRBASE] = "airdromeId",
	[dctenum.assetType.CV]      = "linkUnit",
	[dctenum.assetType.FARP]    = "helipadId",
}

--- An airbase is defined to be operational if its health state is
-- operational and it is spawned.
function AirbaseSensor:isOperational()
	local health = self.agent:WS():get(WS.ID.HEALTH).value
	local stance = self.agent:WS():get(WS.ID.STANCE).value

	return health == WS.Health.OPERATIONAL and
	       stance == WS.Stance.LAUNCHING and
	       self.agent:isSpawned()
end

function AirbaseSensor:setSilent(silent)
	local ab = Airbase.getByName(self.agent.name)

	if ab then
		ab:setRadioSilentMode(silent)
	end
end

function AirbaseSensor:notifyOperational()
	local operational = self:isOperational()

	self:setSilent(not operational)
	self.agent:notify(
		dctutils.buildevent.operational(self.agent, operational))
end

function AirbaseSensor:setup()
	self:setSilent(true)
end

function AirbaseSensor:onHealthChange(--[[prev, current]])
	self:notifyOperational()
	self.agent:replan()
end

function AirbaseSensor:spawnPost()
	self.timer:reset()
	self.timer:start()
	self:notifyOperational()
end

--- By definition a despawned airbase cannot have an operational tower
function AirbaseSensor:despawnPost()
	self.timer:stop()
	self:setSilent(true)
end

function AirbaseSensor:handleCapture(event)
	if event.target.name ~= self.agent.name then
		return
	end

	self.agent._logger:debug("captured - setting dead")
	self:setSilent(true)
	self.agent:setHealth(WS.Health.DEAD)
end

return AirbaseSensor
