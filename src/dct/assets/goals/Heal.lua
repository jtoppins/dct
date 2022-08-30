--- SPDX-License-Identifier: LGPL-3.0

local WS = require("dct.assets.worldstate")

--- @class Heal
-- The Agent desires to heal itself.
local Heal = require("libs.namedclass")("Heal", WS.Goal)
function Heal:__init()
	WS.Goal.__init(WS.WorldState({
			WS.Property(WS.ID.DAMAGED, false),
		}))
end

function Heal:relevance(agent)
	local score = 0

	if agent:WS():get(WS.ID.DAMAGED).value then
		score = 1
	end
	return score
end

return Heal
