-- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class = libs.classnamed
local WS = require("dct.agent.worldstate")

--- Guard a location.
-- @classmod Guard
local Guard = class("Guard", WS.Goal)
function Guard:__init()
	WS.Goal.__init(self, WS.WorldState({
		WS.Property(WS.ID.STANCE, WS.Stance.GUARDING),
	}), 0.8)
end

return Guard
