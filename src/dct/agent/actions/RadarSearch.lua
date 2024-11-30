-- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class = libs.classnamed
local WS = require("dct.agent.worldstate")

local Search = class("RadarSearch", WS.Action)
function Search:__init(agent, cost)
	WS.Action.__init(self, agent, cost, {
		WS.Property(WS.ID.SENSORSON, true),
	}, {
		WS.Property(WS.ID.STANCE, WS.Stance.SEARCHING),
	})
end

function Search:enter()
	self.agent:WS():get(WS.ID.STANCE).value = WS.ID.Stance.SEARCHING
end

function Search:isComplete()
	return false
end

return Search
