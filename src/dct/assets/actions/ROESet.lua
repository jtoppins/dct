--- SPDX-License-Identifier: LGPL-3.0

local aitasks = require("dct.ai.tasks")
local WS = require("dct.assets.worldstate")

local ROESet = require("libs.namedclass")("ROESet", WS.Action)
function ROESet:__init(agent, cost)
	WS.Action.__init(self, agent, cost, {
		-- pre-conditions
	}, {
		-- effects
		WS.Property(WS.ID.ROE, WS.Property.ANYHANDLE),
	})
end

function ROESet:enter()
	local prop = self.agent:getGoal():WS():get(WS.ID.ROE)
	local tasktbl = {
		-- We can use the air definition for any group type
		-- as long as the correct values are used
		aitasks.wraptask(aitasks.option.create(
			AI.Option.Air.id.ROE, prop.value)),
	}

	self.agent:doTasksForeachGroup(tasktbl)
	self.agent:WS():get(prop.id).value = prop.value
end

return ROESet
