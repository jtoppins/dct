-- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class = libs.classnamed
local WS = require("dct.assets.worldstate")

--- Idle goal in case nothing else is applicable.
-- @classmod Idle
local Idle = class("Idle", WS.Goal)
function Idle:__init()
	WS.Goal.__init(self, WS.WorldState({
			WS.Property(WS.ID.IDLE, true),
		}), 0.01)
end

return Idle
