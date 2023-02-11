-- SPDX-License-Identifier: LGPL-3.0

local dctenum  = require("dct.enum")
local Timer    = require("dct.libs.Timer")
local WS       = require("dct.assets.worldstate")
local REPAIR_TIME = 3600 -- 1 hour

--- @classmod RunwayRepair
-- Repairs a airbase runway based on time remaining to repair.
local RunwayRepair = require("libs.namedclass")("RunwayRepair", WS.Action)
function RunwayRepair:__init(agent, cost)
	WS.Action.__init(self, agent, cost or 10, {
		-- pre-conditions
		WS.Property(WS.ID.DAMAGED, true),
	}, {
		-- effects
		WS.Property(WS.ID.DAMAGED, false),
	}, 100)
	self.timer = Timer(REPAIR_TIME)
end

function RunwayRepair:checkProceduralPreconditions()
	return self.agent.type == dctenum.assetType.AIRBASE
end

function RunwayRepair:enter()
	local health = self.agent:getFact(WS.Facts.factKey.HEALTH).value.value

	self.timer:reset((1 - health) * REPAIR_TIME)
	self.timer:start()
end

function RunwayRepair:isComplete()
	self.timer:update()
	local health = 1 - (self.timer:remain() / self.timer.timeoutlimit)

	self.agent:setFact(WS.Facts.factKey.HEALTH,
		WS.Facts.Value(WS.Facts.factType.HEALTH, health, 1.0))

	if not self.timer:expired() then
		return false
	end

	self.agent:WS():get(WS.ID.DAMAGED).value = false
	return true
end

return RunwayRepair
