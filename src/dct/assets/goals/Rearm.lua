-- SPDX-License-Identifier: LGPL-3.0

local WS = require("dct.assets.worldstate")

--- The Agent desires to rearm itself.
-- @classmod Rearm
local Rearm = require("libs.namedclass")("Rearm", WS.Goal)
function Rearm:__init()
	WS.Goal.__init(self, WS.WorldState({
			WS.Property(WS.ID.HASAMMO, true),
		}))
end

function Rearm:relevance(agent)
	local score = 0

	if agent:WS():get(WS.ID.HASAMMO).value == false then
		score = 1
	end
	return score
end

return Rearm
