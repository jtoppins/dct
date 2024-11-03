-- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class     = libs.classnamed
local DCTEvents = require("dct.libs.DCTEvents")
local Timer     = require("dct.libs.Timer")
local WS        = require("dct.assets.worldstate")
local UPDATE_TIME = 60

local function is_target(fact)
	return fact.type == WS.Facts.factType.CHARACTER and
	       fact.object and fact.object.confidence >= 1
end

--- @classmod PlayerAttack
-- Monitors the player Agent object and waits until all mission targets
-- are dead.
local PlayerAttack = class("PlayerAttack", WS.Action,
	DCTEvents)
function PlayerAttack:__init(agent, cost)
	WS.Action.__init(self, agent, cost, {
		-- pre-conditions
		-- none
	}, {
		-- effects
		WS.Property(WS.ID.TARGETDEAD, true),
	})
	self.timer = Timer(UPDATE_TIME)
end

function PlayerAttack:enter()
	self.timer:reset()
	self.timer:start()
end

--- Test if the agent's fact list has any targets left. A "target" is defined
-- as any contact fact with a threat of one.
function PlayerAttack:isComplete()
	self.timer:update()
	if not self.timer:expired() then
		return false
	end

	self.timer:reset()
	for _, fact in self.agent:iterateFacts() do
		if is_target(fact) then
			return false
		end
	end
	self:WS():get(WS.IS.TARGETDEAD).value = true
	return true
end

return PlayerAttack
