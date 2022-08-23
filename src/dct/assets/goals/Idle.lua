--- SPDX-License-Identifier: LGPL-3.0

local WS = require("dct.assets.worldstate")

--- @class Idle
-- idle goal in case nothing else is applicable.
local Idle = require("libs.namedclass")("Idle", WS.Goal)
function Idle:__init()
	WS.Goal.__init(WS.WorldState({
			WS.Property(WS.ID.IDLE, true),
		}), 0.01)
end

return Idle
