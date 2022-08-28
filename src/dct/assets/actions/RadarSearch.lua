-- SPDX-License-Identifier: LGPL-3.0

local WS = require("dct.assets.worldstate")

local Search = require("libs.namedclass")("Search", WS.Action)
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
