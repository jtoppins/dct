--- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class = libs.classnamed
local WS = require("dct.agent.worldstate")
local InAir = require("dct.agent.actions.InAir")

-- TODO: may need to implement a timeout and despawn the units
-- if the units don't takeoff in a reasonable amount of time.
-- Also, need to consider airbase settings, needing not to taxi
-- and takeoff from runway.

local Takeoff = class("Takeoff", InAir)
function Takeoff:__init(agent)
	InAir.__init(self, agent, 3, {
		-- preconditions
	}, {
		-- effects
		WS.Property(WS.ID.INAIR, true),
	}, 1)
end

function Takeoff.isSuitable(agent)
	local is_bit_set = dct.libs.utils.is_bit_set
	local assetType = dct.enum.assetType

	return is_bit_set(assetType.AIR_UNIT, agent.type)
end

function Takeoff:enter()
	InAir.enter(self)
end

--- Wait until all units of the group takeoff. The airbase that created
-- the group should have initially created the group with a departure
-- path. So the takeoff action is simply to wait for all aircraft to
-- takeoff.
function Takeoff:isComplete()
	self:processChangeState()
	return self.agent:WS():get(WS.ID.INAIR).value == true
end

return Takeoff
