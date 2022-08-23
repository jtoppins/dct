--- SPDX-License-Identifier: LGPL-3.0

local WS = require("dct.assets.worldstate")

local function is_event(fact)
	return fact.type == WS.Facts.types.EVENT
end

--- @class ReactToEvent
-- Have an agent react to an event registered in the Agent's memory.
local ReactToEvent = require("libs.namedclass")("ReactToEvent", WS.Goal)
function ReactToEvent:__init()
	WS.Goal.__init(WS.WorldState({
			WS.Property(WS.ID.REACTEDTOEVENT, true),
		}), 2)
end

function ReactToEvent:relevance(agent)
	local score = 0

	if agent:hasFact(is_event) then
		score = self.weight
	end
	return score
end

return ReactToEvent
