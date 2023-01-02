-- SPDX-License-Identifier: LGPL-3.0

local WS = require("dct.assets.worldstate")

--- Guard a location.
-- @classmod Guard
local Guard = require("libs.namedclass")("Guard", WS.Goal)
function Guard:__init()
	WS.Goal.__init(self, WS.WorldState({
		WS.Property(WS.ID.STANCE, WS.Stance.GUARDING),
	}), 0.8)
end

return Guard
