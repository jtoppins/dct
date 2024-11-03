--- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class = libs.classnamed
local WS = require("dct.assets.worldstate")

local Idle = class("Idle", WS.Action)
function Idle:__init(agent)
	WS.Action.__init(self, agent, 1, {}, {
		WS.Property(WS.ID.IDLE, true),
	})
end

function Idle:enter()
	self.agent:WS():get(WS.ID.IDLE).value = true
end

--- never complete, we should only ever be executing this
-- action because there is nothing else to do. Force a higher
-- priority goal to be selected and force replanning
function Idle:isComplete()
	return false
end

return Idle
