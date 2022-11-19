-- SPDX-License-Identifier: LGPL-3.0

local dctenum  = require("dct.enum")
local dctutils = require("dct.libs.utils")
local Timer    = require("dct.libs.Timer")
local WS       = require("dct.assets.worldstate")
local REPAIR_TIME = 3600 -- 1 hour

--- @classmod RunwayRepair
--
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
	-- TODO: test if the agent have a runway object
	return self.agent.type == dctenum.assetType.AIRBASE
end

function RunwayRepair:enter()
	self.timer:reset()
	self.timer:start()
	self.agent:notify(dctutils.buildevent.operational(self.agent, false))
end

function RunwayRepair:isComplete()
	self.timer:update()

	if not self.timer:expired() then
		return false
	end

	self.agent:WS():get(WS.ID.DAMAGED).value = false
	return true
end

return RunwayRepair
