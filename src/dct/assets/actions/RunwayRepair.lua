-- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class    = libs.classnamed
local utils    = libs.utils
local Timer    = require("dct.libs.Timer")
local WS       = require("dct.assets.worldstate")
local REPAIR_TIME = 3600 -- 1 hour

--- @classmod RunwayRepair
-- Repairs an airbase runway based on time remaining to repair.
local RunwayRepair = class("RunwayRepair", WS.Action)
function RunwayRepair:__init(agent, cost)
	WS.Action.__init(self, agent, cost or 10, {
		-- pre-conditions
		WS.Property(WS.ID.HEALTH, WS.Health.DAMAGED),
	}, {
		-- effects
		WS.Property(WS.ID.HEALTH, WS.Health.OPERATIONAL),
	}, 100)
	self.timer = Timer(REPAIR_TIME)
end

function RunwayRepair:checkProceduralPreconditions()
	return self.agent:getDescKey("hasRunway") == true
end

function RunwayRepair:enter()
	local health = self.agent:getFact(WS.Facts.factKey.HEALTH).value.value

	self.timer:reset((1 - health) * REPAIR_TIME)
	self.timer:start()
end

function RunwayRepair:isComplete()
	self.timer:update()
	local health = self.timer.timeout / self.timer.timeoutlimit

	health = utils.clamp(health, 0, 1)
	self.agent:setFact(WS.Facts.factKey.HEALTH,
		WS.Facts.Value(WS.Facts.factType.HEALTH, health, 1.0))

	if not self.timer:expired() then
		return false
	end

	self.agent:setHealth(WS.Health.OPERATIONAL)
	return true
end

return RunwayRepair
