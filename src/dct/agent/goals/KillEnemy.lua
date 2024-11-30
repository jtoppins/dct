-- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class = libs.classnamed
local IAUS = require("libs.IAUS")
local WS = require("dct.agent.worldstate")

local function is_character(fact)
	return fact.type == WS.Facts.factType.CHARACTER
end

local function get_closest_contact(agent)
	local dist = 0

	for _, fact in agent:iterateFacts(is_character) do
		if fact.owner.value ~= agent.owner and
		   fact.object.confidence > dist then
			dist = fact.object.confidence
		end
	end

	return dist
end

local iaus = IAUS.IAUS(IAUS.Axis(get_closest_contact,
				 IAUS.curveTypes.LINEAR,
				 1, 1, 0, 0))

--- Attempt to kill the nearest enemy to the agent.
-- @classmod KillEnemy
local KillEnemy = class("KillEnemy", WS.Goal)
function KillEnemy:__init()
	WS.Goal.__init(self, WS.WorldState({
		WS.Property(WS.ID.TARGETDEAD, true),
	}), 1, iaus)
end

return KillEnemy
