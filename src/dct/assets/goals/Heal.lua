-- SPDX-License-Identifier: LGPL-3.0

local WS = require("dct.assets.worldstate")

--- The Agent desires to heal itself.
-- @classmod Heal
local Heal = require("libs.namedclass")("Heal", WS.Goal)
function Heal:__init()
	WS.Goal.__init(self, WS.WorldState({
			WS.Property(WS.ID.HEALTH, WS.Health.OPERATIONAL),
		}))
end

function Heal:relevance(agent)
	local health = agent:WS():get(WS.ID.HEALTH).value
	local score = 0

	if health == WS.Health.DAMAGED then
		score = 1
	end
	return score
end

return Heal
